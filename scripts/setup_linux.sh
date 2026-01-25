#!/bin/bash
# setup_linux.sh
# Bootstraps Ubuntu 22.04 environment on WSL2
# Run this as root (which is default for fresh WSL rootfs imports)

set -e

LOG_PREFIX="[Linux Setup]"

log() {
    echo -e "\033[0;32m$LOG_PREFIX $1\033[0m"
}

error() {
    echo -e "\033[0;31m$LOG_PREFIX [ERROR] $1\033[0m"
}

log "Updating package lists..."
apt-get update

log "Installing base development dependencies..."
apt-get install -y build-essential curl wget git unzip

log "Installing hardware/embedded utilities (CAN, USB)..."
# can-utils: CAN bus tools
# net-tools: ifconfig etc
# linux-tools-generic: Perf, usbip tools integration
# hwdata: Hardware ID lists
# usbutils: lsusb etc
apt-get install -y can-utils net-tools linux-tools-generic hwdata usbutils

# Docker Installation
if ! command -v docker &> /dev/null; then
    log "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    
    # Create docker group if it doesn't exist (installer usually does this)
    # No user to add yet since we are root, but setting up for future users
    log "Docker installed successfully."
else
    log "Docker is already installed."
fi

# Configure WSL-specific settings
# This ensures systemd and metadata mounting are enabled
log "Configuring /etc/wsl.conf..."

# Determine script directory to locate config
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CONFIG_DIR=$(dirname "$SCRIPT_DIR")/config
WSL_CONF_SRC="$CONFIG_DIR/wsl.conf"

if [ -f "$WSL_CONF_SRC" ]; then
    cp "$WSL_CONF_SRC" /etc/wsl.conf
    log "Copied wsl.conf from $WSL_CONF_SRC"
else
    error "wsl.conf not found at $WSL_CONF_SRC"
    # Fallback or exit? For now, we warn but maybe we should fail if strictly required.
    # Given requirements, let's create a minimal one if missing or just exit.
    exit 1
fi

# Optional: Add a standard user if one doesn't exist? 
# For now, we keep it as root/default per requirements or let user manage it.

log "Cleanup..."
apt-get autoremove -y
apt-get clean

log "Setup Complete! Please restart this WSL instance (wsl --terminate <distro>)."
