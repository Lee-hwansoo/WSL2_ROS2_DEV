#!/bin/bash
# 02_setup_ubuntu.sh
# Main entry point for bootstrapping Ubuntu (WSL2 or Native)

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

# Detect Environment
if grep -q "WSL" /proc/version; then
    IS_WSL=true
    log_info "Detected WSL environment."
else
    IS_WSL=false
    log_info "Detected Native Linux environment."
fi

log_info "Starting Linux Environment Setup for user: $TARGET_USER"

# 1. HWE Kernel (Native Linux only - improves Intel GPU support)
# WSL2 uses Windows-provided kernel, so HWE is not applicable
if [ "$IS_WSL" = false ]; then
    install_hwe_kernel
    HWE_RESULT=$?
    
    if [ "$HWE_RESULT" -eq 100 ]; then
        echo ""
        log_warn "═══════════════════════════════════════════════════════════════"
        log_warn "HWE kernel was installed. REBOOT is required before continuing."
        log_warn "═══════════════════════════════════════════════════════════════"
        echo ""
        log_info "Please reboot now with: sudo reboot"
        log_info "Then re-run this script to continue setup."
        echo ""
        exit 0
    fi
else
    log_info "Skipping HWE kernel (WSL2 uses Windows kernel)"
fi

# 2. Base Setup
install_base_packages

# 3. Docker
install_docker
enable_docker_service

# 4. GPU Support (Native Linux only)
# WSL2 uses D3D12/dxg for GPU passthrough, not nvidia-container-toolkit
if [ "$IS_WSL" = false ]; then
    install_nvidia_toolkit
else
    log_info "Skipping NVIDIA Container Toolkit (WSL2 uses D3D12 GPU passthrough)"
fi

# 5. User Configuration
setup_user "$TARGET_USER"

if [ "$IS_WSL" = true ]; then
    setup_wsl_conf "$TARGET_USER"
fi

# 6. Cleanup
apt-get autoremove -y
apt-get clean

log_success "Linux Setup Complete!"
