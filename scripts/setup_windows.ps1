# setup_windows.ps1
# Sets up a complete Ubuntu 22.04 dev environment on WSL2
# Features: Drive auto-detection, Docker, USB-CAN support, Resource optimization

$ErrorActionPreference = "Stop"

# --- Constants ---
$DISTRO_NAME = "Ubuntu-22.04"
$UBUNTU_URL = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64-root.tar.xz"
$TAR_FILENAME = "ubuntu-22.04.tar.xz"

# --- Helper Functions ---

function Check-Admin {
    $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
        Write-Error "This script must be run as Administrator."
        exit 1
    }
}

function Get-InstallDrive {
    if (Test-Path "D:\") {
        return "D:\"
    }
    return "C:\"
}

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

# --- Core Logic ---

function Enable-WslFeatures {
    Log-Info "Checking Windows Features ..."
    $features = @(
        "Microsoft-Windows-Subsystem-Linux",
        "VirtualMachinePlatform"
    )
    
    $restartNeeded = $false
    foreach ($feature in $features) {
        $state = Get-WindowsOptionalFeature -Online -FeatureName $feature
        if ($state.State -ne "Enabled") {
            Log-Info "Enabling $feature ..."
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart | Out-Null
            $restartNeeded = $true
        } else {
            Log-Info "$feature is already enabled."
        }
    }

    if ($restartNeeded) {
        Write-Warning "WSL features were enabled. You MUST reboot your computer now."
        Write-Warning "Please restart and run this script again."
        exit 0
    }
}

function Configure-WslGlobal {
    Log-Info "Configuring global .wslconfig ..."
    $wslConfigDest = "$env:USERPROFILE\.wslconfig"
    
    # Locate source config relative to script
    $ScriptDir = $PSScriptRoot
    $ConfigDir = Join-Path (Split-Path -Parent $ScriptDir) "config"
    $SourceConfig = Join-Path $ConfigDir ".wslconfig"

    if (Test-Path $SourceConfig) {
        Copy-Item -Path $SourceConfig -Destination $wslConfigDest -Force
        Log-Success ".wslconfig updated from $SourceConfig"
    } else {
        Log-Warn "Config file not found at $SourceConfig. Skipping."
    }
}

function Install-WindowsDependencies {
    Log-Info "Checking for 'usbipd' (USB/CAN support) ..."
    try {
        $usbipd = winget list --id "dorssel.usbipd-win" --exact --accept-source-agreements
        if (-not $usbipd) {
            Log-Info "Installing 'usbipd' ..."
            winget install --id "dorssel.usbipd-win" --exact --accept-source-agreements --accept-package-agreements
        } else {
            Log-Success "'usbipd' is already installed."
        }
    } catch {
        Log-Warn "Failed to query winget for usbipd. Please install manually if needed."
    }
}

function Import-UbuntuDistro {
    param([string]$TargetDrive, [string]$InstallPath)

    if (wsl --list --quiet | Select-String -Pattern "$DISTRO_NAME") {
        Log-Success "Distro '$DISTRO_NAME' already exists. Skipping import."
        return
    }

    Log-Info "Preparing to import '$DISTRO_NAME' to $InstallPath ..."
    
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }

    # Determine WSL Base Directory (e.g., D:\WSL) to store the tarball
    $WslBaseDir = Join-Path $TargetDrive "WSL"
    if (-not (Test-Path $WslBaseDir)) {
        New-Item -ItemType Directory -Path $WslBaseDir -Force | Out-Null
    }

    $tarPath = Join-Path $WslBaseDir $TAR_FILENAME

    if (-not (Test-Path $tarPath)) {
        Log-Info "Downloading $DISTRO_NAME RootFS Tarball ..."
        Invoke-WebRequest -Uri $UBUNTU_URL -OutFile $tarPath
    } else {
        Log-Info "Found cached Tarball at $tarPath."
    }

    Log-Info "Importing WSL Distro (this may take a minute) ..."
    wsl --import $DISTRO_NAME $InstallPath $tarPath --version 2
    Log-Success "Import complete."
}

function Configure-LinuxDistro {
    Log-Info "Bootstrapping Linux Environment ..."
    
    # Locate the linux setup script
    $ScriptDir = $PSScriptRoot
    $LinuxScriptHostPath = Join-Path $ScriptDir "setup_linux.sh"

    if (-not (Test-Path $LinuxScriptHostPath)) {
        Write-Error "Could not find 'setup_linux.sh' at $LinuxScriptHostPath"
        exit 1
    }

    # Convert Windows path to WSL mounted path
    # e.g., C:\Users\... -> /mnt/c/Users/...
    # We must ensure to use the correct drive letter casing (lower) and slashes
    $DriveLetter = $ScriptDir.Substring(0,1).ToLower()
    $PathWithoutDrive = $ScriptDir.Substring(3).Replace("\", "/")
    $MountedScriptDir = "/mnt/$DriveLetter/$PathWithoutDrive"
    $MountedScriptPath = "$MountedScriptDir/setup_linux.sh"

    Log-Info "Executing setup_linux.sh from mounted path: $MountedScriptPath"

    # Ensure the script is executable
    # Note: If located on NTFS metadata mounted drive, chmod might not persist without 'metadata' option
    # but we can try executing with 'bash' explicitly
    wsl -d $DISTRO_NAME -u root -- bash $MountedScriptPath
    
    Log-Success "Linux environment configured."
}

# --- Main Execution Flow ---

Try {
    Clear-Host
    Log-Info "Starting WSL2 ($DISTRO_NAME) Setup ..."

    Check-Admin
    Enable-WslFeatures
    
    Log-Info "Updating WSL Kernel ..."
    wsl --update
    
    Configure-WslGlobal
    Install-WindowsDependencies

    $drive = Get-InstallDrive
    $installPath = Join-Path $drive "WSL\$DISTRO_NAME"
    Log-Info "Target Drive: $drive"
    Log-Info "Install Path: $installPath"

    Import-UbuntuDistro -TargetDrive $drive -InstallPath $installPath
    Configure-LinuxDistro

    Log-Success "Installation Completed Successfully!"
    Log-Info "To access your new environment run: wsl -d $DISTRO_NAME"
    Log-Info "Note: You are logged in as 'root' by default. You may want to create a user with 'adduser <username>'."

} Catch {
    Write-Error "An error occurred: $_"
    exit 1
}