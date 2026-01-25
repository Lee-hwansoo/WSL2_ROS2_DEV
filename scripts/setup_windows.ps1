<#
.SYNOPSIS
    Sets up a complete Ubuntu 22.04 dev environment on WSL2.
.DESCRIPTION
    This script automates the deployment of a ROS2 development environment.
    It handles WSL feature enablement, distro import, and Linux bootstrapping.
.PARAMETER DistroName
    Name of the WSL distribution to register (default: Ubuntu-22.04)
.PARAMETER TargetUser
    Username to create inside Linux. If not provided, attempts to read from devcontainer.json.
.PARAMETER InstallPath
    Custom path to install the distro. If not provided, determined automatically based on available drives.
.PARAMETER DryRun
    If set, only prints commands without executing them.
#>
[CmdletBinding()]
Param(
    [string]$DistroName = "Ubuntu-22.04",
    [string]$TargetUser,
    [string]$InstallPath,
    [Switch]$DryRun
)

$ErrorActionPreference = "Stop"

# --- Configuration ---
$CONFIG = @{
    UbuntuUrl = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64-root.tar.xz"
    TarFilename = "ubuntu-22.04.tar.xz"
    RequiredFeatures = @("Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform")
}

# --- Helper Functions ---

function Log-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Log-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Log-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Log-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Exec-Command {
    param(
        [string]$Command,
        [string[]]$Arguments
    )

    if ($DryRun) {
        Write-Host "[DRY-RUN] $Command $Arguments" -ForegroundColor Gray
        return
    }

    try {
        & $Command $Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Command '$Command' failed with exit code $LASTEXITCODE"
        }
    } catch {
        throw "Failed to execute: $Command $Arguments. Error: $_"
    }
}

function Check-Admin {
    $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
        throw "This script must be run as Administrator."
    }
}

function Get-ProjectUser {
    if (-not [string]::IsNullOrWhiteSpace($TargetUser)) {
        return $TargetUser
    }

    $devContainerPath = Join-Path (Split-Path -Parent $PSScriptRoot) ".devcontainer\devcontainer.json"
    if (Test-Path $devContainerPath) {
        $content = Get-Content -Path $devContainerPath -Raw
        if ($content -match '"remoteUser"\s*:\s*"([^"]+)"') {
            return $matches[1]
        }
    }

    Log-Warn "Could not detect user from devcontainer.json. Defaulting to 'ros'."
    return "ros"
}

function Get-WslInstallPath {
    if (-not [string]::IsNullOrWhiteSpace($InstallPath)) {
        return $InstallPath
    }

    $drive = "C:\"
    if (Test-Path "D:\") { $drive = "D:\" }

    return Join-Path $drive "WSL\$DistroName"
}

# --- Core Logic ---

function Enable-WslFeatures {
    Log-Info "Checking Windows Features..."
    $restartNeeded = $false

    foreach ($feature in $CONFIG.RequiredFeatures) {
        $state = Get-WindowsOptionalFeature -Online -FeatureName $feature
        if ($state.State -ne "Enabled") {
            Log-Info "Enabling $feature..."
            if (-not $DryRun) {
                Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart | Out-Null
            }
            $restartNeeded = $true
        }
    }

    if ($restartNeeded) {
        Log-Warn "WSL features enabled. REBOOT REQUIRED."
        if ($DryRun) { return }
        exit 0
    }
}

function Configure-GlobalWsl {
    Log-Info "Configuring global .wslconfig..."
    $source = Join-Path (Split-Path -Parent $PSScriptRoot) "config\.wslconfig"
    $dest = "$env:USERPROFILE\.wslconfig"

    if (Test-Path $source) {
        if (-not $DryRun) {
            Copy-Item -Path $source -Destination $dest -Force
        }
        Log-Success "Updated .wslconfig"
    }
}

function Install-Dependencies {
    Log-Info "Checking external dependencies..."
    if ($DryRun) { return }

    if (-not (Get-Command "winget" -ErrorAction SilentlyContinue)) {
        Log-Warn "Winget not found. Skipping USBIPD check."
        return
    }

    $usbipd = winget list --id "dorssel.usbipd-win" --exact --accept-source-agreements
    if (-not $usbipd) {
        Log-Info "Installing usbipd-win..."
        winget install --id "dorssel.usbipd-win" --exact --accept-source-agreements --accept-package-agreements
    }
}

function Restart-Wsl {
    Write-Host ""
    Log-Warn "To apply global settings (.wslconfig) and systemd, a full WSL restart is required."
    Log-Warn "WARNING: This will terminate ALL running WSL distributions."

    if ($DryRun) {
        Log-Info "[DRY-RUN] Would prompt for restart here."
        return
    }

    $response = Read-Host "Restart WSL now? (Y/n)"
    if ($response -eq "" -or $response -match "^[Yy]") {
        Log-Info "Stopping WSL..."
        wsl --shutdown
        Log-Success "WSL has been shut down."
        Log-Info "You can now reopen your project in VS Code."
    } else {
        Log-Info "Skipping restart. Please run 'wsl --shutdown' manually before using the environment."
    }
}

function Setup-Distro {
    param([string]$User)

    $installPath = Get-WslInstallPath
    Log-Info "Target Install Path: $installPath"

    # Check existing
    if (wsl --list --quiet | Select-String -Pattern $DistroName) {
        Log-Success "Distro '$DistroName' already registered."
    } else {
        # Prepare Import
        $tarDir = Join-Path (Split-Path $installPath -Parent) "Cache"
        $tarPath = Join-Path $tarDir $CONFIG.TarFilename

        if (-not $DryRun) {
            if (-not (Test-Path $installPath)) { New-Item -ItemType Directory -Path $installPath -Force | Out-Null }
            if (-not (Test-Path $tarDir)) { New-Item -ItemType Directory -Path $tarDir -Force | Out-Null }

            if (-not (Test-Path $tarPath)) {
                Log-Info "Downloading RootFS..."
                Invoke-WebRequest -Uri $CONFIG.UbuntuUrl -OutFile $tarPath
            }
        }

        Log-Info "Importing Distro..."
        Exec-Command "wsl" @("--import", $DistroName, $installPath, $tarPath, "--version", "2")
    }

    # Configure Linux inside
    Log-Info "Bootstrapping Linux environment..."

    # Resolve paths for mounting
    $scriptDir = $PSScriptRoot
    $driveLetter = $scriptDir.Substring(0,1).ToLower()
    $pathRest = $scriptDir.Substring(3).Replace("\", "/")
    $linuxScriptPath = "/mnt/$driveLetter/$pathRest/setup_linux.sh"

    # Execute Linux Setup
    # Pass arguments: [TargetUser]
    Exec-Command "wsl" @("-d", $DistroName, "-u", "root", "--", "bash", $linuxScriptPath, $User)

    if (-not $DryRun) {
        Log-Success "Setup Complete!"
        Log-Info "Run 'wsl -d $DistroName' to enter."
    }
}

# --- Main ---
Try {
    Clear-Host
    Log-Info "Starting WSL Setup for '$DistroName'"

    Check-Admin
    Enable-WslFeatures

    if (-not $DryRun) {
        wsl --update
    }

    Configure-GlobalWsl
    Install-Dependencies

    $user = Get-ProjectUser
    Log-Info "Target User: $user"

    Setup-Distro -User $user

    Log-Success "Installation Completed Successfully!"
    Restart-Wsl

} Catch {
    Log-Error $_
    exit 1
}