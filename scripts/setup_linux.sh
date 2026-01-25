#!/bin/bash
# setup_linux.sh
# Main entry point for bootstrapping Ubuntu on WSL2

set -e
set -o pipefail

# --- Context ---
SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"

# --- Load Libraries ---
source "$SCRIPT_DIR/install_config.sh"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/installers.sh"

# --- Arguments ---
TARGET_USER=${1:-ros}

# --- Main ---
ensure_root

log_info "Starting Linux Environment Setup for user: $TARGET_USER"

# 1. Base Setup
install_base_packages

# 2. Docker
install_docker
enable_docker_service

# 3. GPU Support
install_nvidia_toolkit

# 4. User Configuration
setup_user "$TARGET_USER"
setup_wsl_conf "$TARGET_USER"

# 5. Cleanup
apt-get autoremove -y
apt-get clean

log_success "Linux Setup Complete!"
