<#
.SYNOPSIS
    Synchronizes local Windows project files to WSL2 environment.
    Solves the "Split-Brain" problem where Windows edits are not reflected in WSL/Container.

.DESCRIPTION
    This script uses 'robocopy' to efficiently mirror the current directory to
    WSL2 home directory (~/env). Ideally used when you edit config files in Windows
    and need to apply them to the running WSL setup.

    Excludes: .git, .vscode, ros_ws (User Data), build artifacts

.EXAMPLE
    .\scripts\sync_to_wsl.ps1
#>

param (
    [string]$DistroName = "Ubuntu-22.04",
    [string]$TargetDir = "env",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# --- Colors ---
$Green = [ConsoleColor]::Green
$Yellow = [ConsoleColor]::Yellow
$Red = [ConsoleColor]::Red
$Cyan = [ConsoleColor]::Cyan
$Reset = [ConsoleColor]::White

function Log-Info($Message) { Write-Host "[Sync] $Message" -ForegroundColor $Cyan }
function Log-Success($Message) { Write-Host "[Sync] $Message" -ForegroundColor $Green }
function Log-Warn($Message) { Write-Host "[Sync] $Message" -ForegroundColor $Yellow }
function Log-Error($Message) { Write-Host "[Sync] $Message" -ForegroundColor $Red }

# --- Check WSL ---
Log-Info "Checking WSL distribution: $DistroName"

# --- Check WSL (Robust Encoding Fix) ---
Log-Info "Checking WSL distribution: $DistroName"

try {
    # Run wsl.exe via .NET Process to control encoding explicitly
    $StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $StartInfo.FileName = "wsl.exe"
    $StartInfo.Arguments = "--list"
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.UseShellExecute = $false
    $StartInfo.StandardOutputEncoding = [System.Text.Encoding]::Unicode # WSL outputs UTF-16
    $StartInfo.CreateNoWindow = $true

    $Process = [System.Diagnostics.Process]::Start($StartInfo)
    $WslOutput = $Process.StandardOutput.ReadToEnd()
    $Process.WaitForExit()
} catch {
    Log-Warn "Failed to check distro list via .NET method. Falling back to simple check..."
    $WslOutput = wsl --list | Out-String
}

if ($WslOutput -notmatch $DistroName) {
    Log-Error "Distribution '$DistroName' not found!"
    Write-Host "Raw Output (Debug):"
    Write-Host $WslOutput
    exit 1
}

# --- Paths ---
$SourcePath = Get-Location
$WslPath = "\\wsl.localhost\$DistroName\home\ros\$TargetDir"

Log-Info "Source: $SourcePath"
Log-Info "Target: $WslPath"

if (!(Test-Path $WslPath)) {
    Log-Warn "Target directory does not exist. Creating..."
    # Try to create via WSL command to ensure permissions
    wsl -d $DistroName mkdir -p "~/env"
    if (!(Test-Path $WslPath)) {
        Log-Error "Failed to access target path via UNC. Is WSL running?"
        exit 1
    }
}

# --- Robocopy Sync ---
Log-Info "Starting synchronization..."

# Exclude list
$Excludes = @(
    ".git",
    ".vscode",
    "ros_ws",      # User workspace (Don't overwrite code!)
    "build",
    "install",
    "log",
    "*.swp"
)

# Robocopy options:
# /MIR : Mirror a directory tree (equivalent to /E plus /PURGE)
# /XD  : Exclude Directories
# /XF  : Exclude Files
# /FFT : Assume fat file times (2-second granularity)
# /R:0 : 0 Retries on failed copies
# /W:0 : Wait time between retries
# /NJH : No Job Header
# /NJS : No Job Summary (Minimal output)

$RobocopyArgs = @(
    "$SourcePath",
    "$WslPath",
    "/MIR",
    "/FFT",
    "/R:0",
    "/W:0",
    "/XD"
) + $Excludes

# --- Fix Permissions (Pre-Sync) ---
Log-Info "Ensuring target directory permissions..."
# Force ownership to 'ros' user (or default UID 1000) to allow Windows access
# We use 'wsl -u root' to ensure we have permission to run chown
wsl -d $DistroName -u root chown -R 1000:1000 "/home/ros/$TargetDir"

try {
    # Run Robocopy using Call Operator (&) to handle spaces in paths correctly
    # Valid exit codes: 0-7 (Refer to Robocopy doc)
    & robocopy $RobocopyArgs
    
    # Robocopy exit codes:
    # 0: No errors occurred, and no copying was done.
    # 1: One or more files were copied successfully.
    # 2: Some Extra files or directories were detected.
    # 4: Some Mismatched files or directories were detected.
    # 8: Some files or directories could not be copied.
    
    if ($LASTEXITCODE -ge 8) {
        throw "Robocopy failed with exit code $LASTEXITCODE"
    }
    
    Log-Success "Synchronization complete!"
    Log-Info "Changes applied to WSL($DistroName): ~/env"
    
} catch {
    Log-Error "Sync failed: $_"
    exit 1
}
