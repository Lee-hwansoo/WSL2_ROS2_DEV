#!/bin/bash
# setup_linux.sh
# Bootstraps Ubuntu 22.04 environment on WSL2
# Calling convention: bash setup_linux.sh [TARGET_USER]

set -e
set -o pipefail

# --- Arguments ---
TARGET_USER=${1:-ros}
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"

# --- Logging ---
LOG_PREFIX="[Linux Setup]"
log() { echo -e "\033[0;32m$LOG_PREFIX $1\033[0m"; }
warn() { echo -e "\033[0;33m$LOG_PREFIX [WARN] $1\033[0m"; }
error() { echo -e "\033[0;31m$LOG_PREFIX [ERROR] $1\033[0m"; }

# --- Functions ---

update_system() {
    log "Updating package sources..."
    apt-get update
}

install_packages() {
    log "Installing base dependencies..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        build-essential curl wget git unzip \
        can-utils net-tools linux-tools-generic hwdata usbutils \
        sudo
}

install_docker() {
    if command -v docker &> /dev/null; then
        log "Docker already installed."
        return
    fi

    log "Installing Docker (Native Engine via official repo)..."

    # Remove conflicting packages if present
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        apt-get remove -y $pkg || true
    done

    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/docker.asc ]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
    fi

    # Add the repository to Apt sources
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_nvidia_ctk() {
    if command -v nvidia-ctk &> /dev/null; then
        log "NVIDIA Container Toolkit already installed."
        return
    fi

    log "Installing NVIDIA Container Toolkit..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
      tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    apt-get update
    apt-get install -y nvidia-container-toolkit

    nvidia-ctk runtime configure --runtime=docker
}

create_user() {
    local username=$1
    if id -u "$username" &>/dev/null; then
        log "User '$username' already exists."
    else
        log "Creating user '$username'..."
        useradd -m -s /bin/bash -G sudo,docker,adm,dialout,plugdev "$username"
        echo "$username:$username" | chpasswd
        log "User created. Password set to '$username'."
    fi
    # Ensure groups even if user existed
    usermod -aG sudo,docker "$username"
}

configure_wsl_boot() {
    local wsl_conf_src="$CONFIG_DIR/wsl.conf"

    log "Configuring /etc/wsl.conf..."
    if [ -f "$wsl_conf_src" ]; then
        cp "$wsl_conf_src" /etc/wsl.conf

        # Idempotently append user config
        if ! grep -q "\[user\]" /etc/wsl.conf; then
            echo -e "\n[user]\ndefault=$TARGET_USER" >> /etc/wsl.conf
        fi
        log "Updated wsl.conf"
    else
        warn "wsl.conf not found at $wsl_conf_src. Skipping."
    fi
}

configure_devcontainer() {
    local devcontainer_json="$(dirname "$SCRIPT_DIR")/.devcontainer/devcontainer.json"

    if [ ! -f "$devcontainer_json" ]; then return; fi

    log "Configuring devcontainer.json Hardware Acceleration..."

    # Check for NVIDIA GPU presence in WSL
    if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
        log "GPU Detected. Enabling --gpus=all."
        # Ensure clean state first (remove potential double comments)
        sed -i 's|// // "--gpus=all"|// "--gpus=all"|g' "$devcontainer_json"
        # Uncomment
        sed -i 's|// "--gpus=all"|"--gpus=all"|g' "$devcontainer_json"
    else
        log "No GPU detected. Disabling --gpus=all."
        # Comment out (might create double comments if already commented)
        sed -i 's|"--gpus=all"|// "--gpus=all"|g' "$devcontainer_json"
        # Fix double comments
        sed -i 's|// // "--gpus=all"|// "--gpus=all"|g' "$devcontainer_json"
    fi
}

start_services() {
    # Provide helpful feedback about Systemd status
    if pidof systemd > /dev/null; then
        log "Systemd is active. Enabling and starting Docker..."
        systemctl enable docker
        systemctl start docker || true
    else
        # WSL2 specific behavior during first install (systemd only starts after reboot)
        log "Systemd is not yet active (expected during initial setup)."
        log "Enabling Docker service for next boot..."
        # Force symlink creation even if systemd isn't running
        systemctl enable docker 2>/dev/null || true
        log "Docker service enabled. It will start automatically after you reboot WSL."
    fi
}

cleanup() {
    apt-get autoremove -y
    apt-get clean
}

# --- Main ---

log "Starting setup for user: $TARGET_USER"

update_system
install_packages
install_docker
install_nvidia_ctk

create_user "$TARGET_USER"
configure_wsl_boot
configure_devcontainer

start_services
cleanup

log "Setup Complete actions."
