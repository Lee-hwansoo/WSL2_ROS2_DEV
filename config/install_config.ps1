# scripts/install_config.ps1
# Centralized configuration for Windows setup script

$SetupConfig = @{
    # WSL / Distro Settings
    DistroName        = "Ubuntu-22.04"
    DistroImage       = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64-root.tar.xz"
    DistroFilename    = "ubuntu-22.04.tar.xz"
    
    # Default User (can be overridden by arguments)
    DefaultUser       = "ros"

    # Setup Requirements
    RequiredWslFeatures = @(
        "Microsoft-Windows-Subsystem-Linux", 
        "VirtualMachinePlatform"
    )

    # Windows Dependencies (installed via winget)
    WindowsDependencies = @(
        "usbipd-win"  # USB device sharing to WSL
    )
}
