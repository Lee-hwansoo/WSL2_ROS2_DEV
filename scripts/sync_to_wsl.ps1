# scripts/sync_to_wsl.ps1
# Helper to manually sync changes from Windows to WSL
# Useful if you edited config files in Windows and need them applied to the running environment.

Param(
    [string]$DistroName = "ROS2-Humble",
    [string]$TargetUser = "ros"
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$ProjectRoot = Split-Path $ScriptDir -Parent

Write-Host "[Sync] Syncing Windows -> WSL ($DistroName)..." -ForegroundColor Cyan

# 1. Sync Config/Scripts
# We use rsync-like behavior with cp -u (update only if newer) to be safe, or just force copy.
# Since Windows is "Installer", we assume it is the source of truth for CONFIGURATION.

$wslPath = "\\wsl.localhost\$DistroName\home\$TargetUser\env"

if (-not (Test-Path $wslPath)) {
    Write-Error "WSL Path not found: $wslPath"
    exit 1
}

# Copy specific directories that contain logic
$dirsToSync = @("config", "scripts", ".devcontainer")

foreach ($dir in $dirsToSync) {
    $src = Join-Path $ProjectRoot $dir
    $dest = Join-Path $wslPath $dir
    
    if (Test-Path $src) {
        Write-Host "  -> Syncing $dir..."
        Copy-Item -Path $src -Destination $wslPath -Recurse -Force
    }
}

Write-Host "[Sync] Done! You may need to rebuild the container or restart the terminal." -ForegroundColor Green
