# scripts/install_config.ps1
# Centralized configuration for Windows setup script

$SetupConfig = @{
    # WSL / Distro Settings
    DistroName        = "Ubuntu-22.04"
    DistroImage       = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64-root.tar.xz"
    DistroFilename    = "ubuntu-22.04.tar.xz"

    # Default User (can be overridden by arguments)
    DefaultUser       = "ubuntu"

    # Setup Requirements
    RequiredWslFeatures = @(
        "Microsoft-Windows-Subsystem-Linux",
        "VirtualMachinePlatform"
    )

    # Windows Dependencies (Direct MSI Download & Install)
    WindowsDependencies = @(
        @{
            Name         = "usbipd-win"
            CheckCommand = "usbipd"
            Url          = "https://github.com/dorssel/usbipd-win/releases/download/v5.3.0/usbipd-win_5.3.0_x64.msi"
            FileName     = "usbipd-win.msi"
        }
    )
}
