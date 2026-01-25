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

function Configure-DevContainer-GPU {
    Log-Info "Checking GPU availability for Dev Container..."
    
    # Simple check for NVIDIA driver service or SMI
    $hasNvidia = $false
    try {
        if (Get-Command "nvidia-smi" -ErrorAction SilentlyContinue) { $hasNvidia = $true }
    } catch {}

    $devContainerFile = Join-Path (Split-Path $ScriptDir -Parent) $SetupConfig.DevContainerPath
    
    if (-not (Test-Path $devContainerFile)) {
        Log-Warn "devcontainer.json not found at $devContainerFile"
        return
    }

    if ($DryRun) { 
        Log-Info "[DRY-RUN] Would update devcontainer.json (GPU: $hasNvidia)"
        return 
    }

    $content = Get-Content -Path $devContainerFile -Raw
    $newContent = $content

    if ($hasNvidia) {
        Log-Success "NVIDIA GPU Detected. Enabling GPU support in devcontainer.json."
        # Uncomment "// "--gpus=all"" -> ""--gpus=all""
        # Regex to handle potential existing variations
        $newContent = $newContent -replace '//\s*"--gpus=all"', '"--gpus=all"'
    } else {
        Log-Warn "No NVIDIA GPU Detected. Disabling GPU support."
        # Comment out ""--gpus=all"" -> "// "--gpus=all""
        # Make sure we don't double comment
        $newContent = $newContent -replace '^\s*"--gpus=all"', '// "--gpus=all"'
        # Also clean up previous comments to standard format if needed, but simple replace is safer.
        # Actually, let's just valid JSON string replace.
        if ($newContent -match '\s{6,}"--gpus=all"') {
             $newContent = $newContent -replace '"--gpus=all"', '// "--gpus=all"'
        }
    }
    
    if ($content -ne $newContent) {
        Set-Content -Path $devContainerFile -Value $newContent -NoNewline
        Log-Info "Updated devcontainer.json."
    }
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
    $linuxScript = "/mnt/$driveLetter/$relativePath/setup_linux.sh"

    # We must ensure line endings of linux script are LF if we run it directly? 
    # Usually WSL handles it, but safer to run via bash
    
    Exec-Command "wsl" @("-d", $DistroName, "-u", "root", "--", "bash", $linuxScript, $TargetUser)
}

# --- Main Execution ---

try {
    Clear-Host
    Log-Info "Starting ROS2 Environment Setup ($DistroName)"
    
    Assert-Admin
    Enable-WslFeatures
    
    if (-not $DryRun) { wsl --update }

    Update-GlobalWslConfig
    Configure-DevContainer-GPU
    
    Install-WslDistro
    Bootstrap-Linux

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