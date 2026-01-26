<#
.SYNOPSIS
    Sets up a complete Ubuntu 22.04 dev environment on WSL2 with robust error handling and configuration management.
.DESCRIPTION
    Automates the deployment of the ROS2 development environment.
    - Enables WSL2 features
    - Downloads/Imports Ubuntu RootFS
    - Bootstraps Linux environment
    - Configures Hardware Acceleration (GPU)
.PARAMETER DistroName
    Name of the WSL distribution to register. Defaults to config value.
.PARAMETER TargetUser
    Username to create inside Linux.
.PARAMETER InstallPath
    Custom path to install the distro. Determined automatically if omitted.
.PARAMETER DryRun
    If set, prints commands without executing.
#>
[CmdletBinding()]
Param(
    [string]$DistroName,
    [string]$TargetUser,
    [string]$InstallPath,
    [Switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot

# Load Configuration
try {
    . "$ScriptDir\install_config.ps1"
} catch {
    Write-Host "[FATAL] Failed to load configuration file 'install_config.ps1'." -ForegroundColor Red
    exit 1
}

# Apply Defaults from Config if not provided
if ([string]::IsNullOrWhiteSpace($DistroName)) { $DistroName = $SetupConfig.DistroName }
if ([string]::IsNullOrWhiteSpace($TargetUser)) { $TargetUser = $SetupConfig.DefaultUser }

# --- Logging Functions ---

function Log-Info { Write-Host "[INFO] $($args[0])" -ForegroundColor Cyan }
function Log-Success { Write-Host "[SUCCESS] $($args[0])" -ForegroundColor Green }
function Log-Warn { Write-Host "[WARN] $($args[0])" -ForegroundColor Yellow }
function Log-Error { Write-Host "[ERROR] $($args[0])" -ForegroundColor Red }

function Exec-Command {
    param([string]$Command, [string[]]$Arguments)
    if ($DryRun) {
        Write-Host "[DRY-RUN] $Command $Arguments" -ForegroundColor Gray
        return
    }
    try {
        & $Command $Arguments
        if ($LASTEXITCODE -ne 0) { throw "Exit code $LASTEXITCODE" }
    } catch {
        throw "Command failed: $Command $Arguments. $_"
    }
}

function Assert-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = [Security.Principal.WindowsPrincipal]$id
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script accepts Administrator privileges only. Please run as Admin."
    }
}

# --- Functional Logic ---

function Enable-WslFeatures {
    Log-Info "Verifying Windows Features for WSL2..."
    $restartRequired = $false
    
    foreach ($feature in $SetupConfig.RequiredWslFeatures) {
        $status = Get-WindowsOptionalFeature -Online -FeatureName $feature
        if ($status.State -ne "Enabled") {
            Log-Info "Enabling feature: $feature"
            if (-not $DryRun) {
                Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart | Out-Null
            }
            $restartRequired = $true
        }
    }

    if ($restartRequired) {
        Log-Warn "Windows features enabled. A system reboot is required."
        if ($DryRun) { return }
        exit 0 # Exit gracefully to allow reboot
    }
}

function Get-OptimalInstallPath {
    if (-not [string]::IsNullOrWhiteSpace($InstallPath)) { return $InstallPath }
    
    # Smart Drive Detection: Prefer D:\ or E:\ over C:\ if they exist
    $targetDrive = "C:\"
    foreach ($drive in @("D:\", "E:\")) {
        if (Test-Path $drive) { 
            $targetDrive = $drive
            break 
        }
    }
    return Join-Path $targetDrive "WSL\$DistroName"
}

function Update-GlobalWslConfig {
    Log-Info "Updating global .wslconfig..."
    $src = Join-Path (Split-Path $ScriptDir -Parent) "config\.wslconfig"
    $dest = "$env:USERPROFILE\.wslconfig"

    if (Test-Path $src) {
        if (-not $DryRun) {
            Copy-Item -Path $src -Destination $dest -Force
        }
    } else {
        Log-Warn "Config file not found: $src"
    }
}

function Get-HardwareProfile {
    $profile = @{
        HasNvidia = $false
        HasIntel  = $false
        HasNPU    = $false
        Description = ""
    }

    try {
        if (Get-Command "nvidia-smi" -ErrorAction SilentlyContinue) { 
            $profile.HasNvidia = $true 
            $profile.Description += "[NVIDIA RTX] "
        }
    } catch {}

    try {
        $video = Get-CimInstance Win32_VideoController
        foreach ($v in $video) {
            if ($v.Name -match "Intel" -or $v.Name -match "Iris") {
                $profile.HasIntel = $true
                $profile.Description += "[Intel Iris/Arc] "
            }
        }
    } catch {}

    # NPU Detection (Simple heuristics for Intel AI Boost / NPU devices)
    try {
        if (Get-PnpDevice -FriendlyName "*NPU*" -ErrorAction SilentlyContinue) {
            $profile.HasNPU = $true
            $profile.Description += "[Intel NPU] "
        }
    } catch {}
    
    if ($profile.Description -eq "") { $profile.Description = "[CPU Only]" }
    
    return $profile
}

function Get-SystemHealth {
    Log-Info "Running System Health 'Doctor' Checks..."
    
    # WSL Version Check
    $wslStatus = wsl --status
    if ($wslStatus -match "Kernel version: 5\.10\.102\.1") {
        # This is a loose check, mainly we want to ensure it's not ancient
        Log-Info "wsl kernel looks up to date."
    }
}

function Update-DevContainer-Hardware {
    param([hashtable]$HardwareProfile)

    Log-Info "Configuring Dev Container runtime args..."
    if ($HardwareProfile) { Log-Info "Hardware Context: $($HardwareProfile.Description)" }

    $devContainerFile = Join-Path (Split-Path $ScriptDir -Parent) $SetupConfig.DevContainerPath

    if (-not (Test-Path $devContainerFile)) {
        Log-Warn "devcontainer.json not found at $devContainerFile"
        return
    }

    $content = Get-Content -Path $devContainerFile -Raw
    $originalContent = $content

    # 1. Handle NVIDIA Specific Args
    # If Hardware has Nvidia, we ensure "--gpus=all" is present (uncommented)
    # If Hardware has NO Nvidia, we ensure "--gpus=all" is commented out or removed
    
    if ($HardwareProfile.HasNvidia) {
        # Enable it: Replace commented out version with active version
        if ($content -match '//\s*"--gpus=all"') {
             $content = $content -replace '//\s*"--gpus=all"', '"--gpus=all"'
             Log-Info "Enabled NVIDIA GPU flags."
        }
    } else {
        # Disable it: Comment it out if it's active
        # We look for "--gpus=all" acting as a value in the array
        if ($content -match '^\s*"--gpus=all"') {
             $content = $content -replace '^\s*"--gpus=all"', '// "--gpus=all"'
             Log-Info "Disabled NVIDIA GPU flags (Not detected)."
        } elseif ($content -match '\s{4,}"--gpus=all"') {
             $content = $content -replace '"--gpus=all"', '// "--gpus=all"'
             Log-Info "Disabled NVIDIA GPU flags (Not detected)."
        }
    }

    # 2. Verify Universal Mounts (Always Required)
    if ($content -notmatch "/usr/lib/wsl/lib") {
        Log-Warn "MISSING: /usr/lib/wsl/lib mount in devcontainer.json. Attempting to fix..."
        # This is a complex patch, for now just warn. simpler to rely on the static file having it.
        Log-Error "The devcontainer.json is outdated. Please pull the latest version or manually add the WSL driver mounts."
    }

    if ($content -ne $originalContent) {
        Set-Content -Path $devContainerFile -Value $content -NoNewline
        Log-Success "Updated devcontainer.json configuration."
    } else {
        Log-Success "DevContainer configuration is already optimal."
    }
}

function Configure-HardwareEnvironment {
    $hw = Get-HardwareProfile
    Log-Success "Hardware Detected: $($hw.Description)"
    
    Update-DevContainer-Hardware -HardwareProfile $hw
}

function Verify-WslDriverProjection {
    param([string]$DistroName)
    Log-Info "Verifying Driver Projection..."
    try {
        $check = wsl -d $DistroName -- ls /usr/lib/wsl/lib/libd3d12.so 2>&1
        if ($LASTEXITCODE -eq 0) {
            Log-Success "Driver Projection (/usr/lib/wsl/lib) verified active in WSL."
        } else {
            Log-Warn "Driver Projection NOT active in WSL. GPU acceleration may fail."
            Log-Warn "Try 'wsl --update' and reboot."
        }
    } catch {}
}

function Install-WslDistro {
    $targetPath = Get-OptimalInstallPath
    Log-Info "Installation Target: $targetPath"

    # Check if already installed
    $list = wsl --list --quiet
    if ($list -match $DistroName) {
        Log-Success "WSL Distro '$DistroName' is already registered."
        return
    }

    # Prepare Cache
    $cacheDir = Join-Path (Split-Path $targetPath -Parent) "Cache"
    $tarPath = Join-Path $cacheDir $SetupConfig.DistroFilename

    if (-not $DryRun) {
        if (-not (Test-Path $targetPath)) { New-Item -ItemType Directory -Path $targetPath -Force | Out-Null }
        if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
        
        if (-not (Test-Path $tarPath)) {
            Log-Info "Downloading Ubuntu Core RootFS..."
            Invoke-WebRequest -Uri $SetupConfig.DistroImage -OutFile $tarPath
            Log-Success "Download Complete."
        }
    }

    Log-Info "Importing WSL Distro..."
    Exec-Command "wsl" @("--import", $DistroName, $targetPath, $tarPath, "--version", "2")
}

function Bootstrap-Linux {
    Log-Info "Bootstrapping Linux Environment inside WSL..."
    
    # Calculate path to Linux script visible from WSL
    # e.g. C:\Users\... -> /mnt/c/Users/...
    $driveLetter = $ScriptDir.Substring(0,1).ToLower()
    $relativePath = $ScriptDir.Substring(3).Replace("\", "/")
    $linuxScript = "/mnt/$driveLetter/$relativePath/02_setup_ubuntu.sh"

    # We must ensure line endings of linux script are LF if we run it directly? 
    # Usually WSL handles it, but safer to run via bash
    
    Exec-Command "wsl" @("-d", $DistroName, "-u", "root", "--", "bash", $linuxScript, $TargetUser)
}

function Copy-Project-To-WSL {
    Log-Info "Copying Setup Project to WSL user home..."
    
    $projectRoot = Split-Path $ScriptDir -Parent
    $wslDest = "\\wsl.localhost\$DistroName\home\$TargetUser\env"
    
    if ($DryRun) {
        Log-Info "[DRY-RUN] Would copy '$projectRoot' to '$wslDest'"
        return
    }

    try {
        if (-not (Test-Path $wslDest)) {
            New-Item -ItemType Directory -Path $wslDest -Force | Out-Null
        }
        
        Log-Info "Copying files (this may take a moment)..."
        # Exclude unnecessary files to keep WSL clean
        # - .git: Repo history not needed in env
        # - Cache: Downloaded artifacts
        # - .vscode: Local VS Code settings
        # - *.ps1: Windows scripts not needed in Linux
        Get-ChildItem -Path $projectRoot -Exclude ".git", "Cache", ".vscode", "tmp" | Where-Object { $_.Name -notlike "*.ps1" } | Copy-Item -Destination $wslDest -Recurse -Force
        
        Log-Success "Project copied dynamically to WSL: ~/env"

        # Create sibling workspace directory for data persistence (ros_ws)
        $wslWorkspace = "\\wsl.localhost\$DistroName\home\$TargetUser\ros_ws"
        if (-not (Test-Path $wslWorkspace)) {
            New-Item -ItemType Directory -Path $wslWorkspace -Force | Out-Null
            # Create src inside it too
            New-Item -ItemType Directory -Path "$wslWorkspace\src" -Force | Out-Null
            Log-Success "Created sibling workspace directory: ~/ros_ws"
        }
    } catch {
        Log-Warn "Failed to copy project to WSL automatically: $_"
        Log-Warn "You may need to manually copy the project to WSL to use the bind-mount features."
    }
}

# --- Main Execution ---

try {
    Clear-Host
    Log-Info "Starting ROS2 Environment Setup ($DistroName)"
    
    Assert-Admin
    Enable-WslFeatures
    
    if (-not $DryRun) { wsl --update }

    Update-GlobalWslConfig
    Configure-HardwareEnvironment
    
    Install-WslDistro
    Bootstrap-Linux
    Copy-Project-To-WSL

    Verify-WslDriverProjection -DistroName $DistroName

    Log-Success "Setup Completed Successfully!"
    
    if (-not $DryRun) {
        Write-Host ""
        Log-Warn "NOTE: A 'wsl --shutdown' is recommended to fully apply all settings."
        $ans = Read-Host "Restart WSL now? (Y/n)"
        if ($ans -eq "" -or $ans -match "^[Yy]") {
            wsl --shutdown
            Log-Success "WSL Restarted."
        }
    }

} catch {
    Log-Error "Setup Failed: $_"
    exit 1
}