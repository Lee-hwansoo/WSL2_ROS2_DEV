#!/bin/bash
# scripts/02_setup_ubuntu.sh
# Main entry point for setting up ROS2 development environment
# Works on both WSL2 and Native Linux

set -e
set -o pipefail

# =============================================================================
# CONTEXT
# =============================================================================
SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"

# =============================================================================
# LOAD LIBRARIES (SSO)
# =============================================================================
source "$CONFIG_DIR/install_config.sh"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/installers.sh"

# =============================================================================
# ARGUMENTS
# =============================================================================
TARGET_USER=${1:-ubuntu}
HOST_CACHE_DIR=$2

# =============================================================================
# MAIN
# =============================================================================
ensure_root

# Detect Environment
if grep -q "WSL" /proc/version; then
    IS_WSL=true
    log_info "Detected WSL2 environment."
else
    IS_WSL=false
    log_info "Detected Native Linux environment."
fi

# ─────────────────────────────────────────────────────────────────────────────
# 0. Cache Configuration (Persistent)
# ─────────────────────────────────────────────────────────────────────────────
if [ -n "$HOST_CACHE_DIR" ]; then
    configure_system_cache "$HOST_CACHE_DIR"
fi

echo ""
log_info "╔══════════════════════════════════════════════════════════════╗"
log_info "║        ROS2 ${ROS_DISTRO} Development Environment Setup      ║"
log_info "╚══════════════════════════════════════════════════════════════╝"
echo ""
log_info "Target user: $TARGET_USER"
log_info "Environment: $([ "$IS_WSL" = true ] && echo 'WSL2' || echo 'Native Linux')"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 1. HWE Kernel (Native Linux only)
# ─────────────────────────────────────────────────────────────────────────────
if [ "$IS_WSL" = false ]; then
    log_info "[1/6] Installing HWE Kernel..."
    install_hwe_kernel
    HWE_RESULT=$?

    if [ "$HWE_RESULT" -eq 100 ]; then
        echo ""
        log_warn "═══════════════════════════════════════════════════════════════"
        log_warn " HWE kernel installed. REBOOT required before continuing."
        log_warn "═══════════════════════════════════════════════════════════════"
        echo ""
        log_info "Please run: sudo reboot"
        log_info "Then re-run this script to continue."
        exit 0
    fi
else
    log_info "[1/6] Skipping HWE kernel (WSL2 uses Windows kernel)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 2. Base Packages
# ─────────────────────────────────────────────────────────────────────────────
log_info "[2/6] Installing base packages..."
install_base_packages

# ─────────────────────────────────────────────────────────────────────────────
# 3. ROS2 Installation
# ─────────────────────────────────────────────────────────────────────────────
log_info "[3/6] Installing ROS2 ${ROS_DISTRO}..."
install_ros2

# ─────────────────────────────────────────────────────────────────────────────
# 4. GPU Drivers (Native vs WSL)
# ─────────────────────────────────────────────────────────────────────────────
if [ "$IS_WSL" = false ]; then
    log_info "[4/6] Detecting GPU for Native Linux..."
    GPU_VENDOR=$(detect_gpu_vendor)
    log_info "Detected GPU Vendor: $GPU_VENDOR"

    install_gpu_drivers "$GPU_VENDOR"
    GPU_RESULT=$?

    if [ "$GPU_RESULT" -eq 100 ]; then
        echo ""
        log_warn "═══════════════════════════════════════════════════════════════"
        log_warn " GPU drivers installed. REBOOT required before continuing."
        log_warn "═══════════════════════════════════════════════════════════════"
        echo ""
        log_info "Please run: sudo reboot"
        log_info "Then re-run this script to continue."
        exit 0
    fi
else
    log_info "[4/6] WSL2 Environment detected. Installing Mesa utils only..."
    # WSL2 uses Windows drivers, but needs mesa-utils for some tools
    DEBIAN_FRONTEND=noninteractive apt-get install -y mesa-utils

    # Check for Nvidia GPU in WSL (via Passthrough)
    if command -v nvidia-smi &>/dev/null; then
        log_info "Nvidia GPU detected in WSL2 (via Passthrough)."
        log_info "Installing CUDA Toolkit for development..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y "${CUDA_PACKAGES[@]}"
        log_success "CUDA Toolkit installed."
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# 5. Development Tools
# ─────────────────────────────────────────────────────────────────────────────
log_info "[5/6] Installing development tools..."
install_dev_tools
install_d2coding_font
install_uv

# ─────────────────────────────────────────────────────────────────────────────
# 6. User & Environment Configuration
# ─────────────────────────────────────────────────────────────────────────────
log_info "[6/6] Configuring user and environment..."
setup_user "$TARGET_USER"

if [ "$IS_WSL" = true ]; then
    setup_wsl_conf "$TARGET_USER"
fi

# Configure persistent cache for USER in .bashrc (if applicable)
if [ -n "$HOST_CACHE_DIR" ]; then
    configure_user_cache "$TARGET_USER" "$HOST_CACHE_DIR"
fi

configure_ros_environment "$TARGET_USER"

# Initialize rosdep
if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
    log_info "Initializing rosdep..."
    rosdep init || true
fi

# Run rosdep update as target user
su - "$TARGET_USER" -c "rosdep update" || true

# ─────────────────────────────────────────────────────────────────────────────
# Cleanup
# ─────────────────────────────────────────────────────────────────────────────
log_info "Cleaning up..."
apt-get autoremove -y
# apt-get clean  <-- DISABLED to persist cache

# ─────────────────────────────────────────────────────────────────────────────
# Complete
# ─────────────────────────────────────────────────────────────────────────────
echo ""
log_success "╔══════════════════════════════════════════════════════════════╗"
log_success "║              Setup Complete!                                  ║"
log_success "╚══════════════════════════════════════════════════════════════╝"
echo ""
log_info "ROS2: $ROS_DISTRO"
log_info "User: $TARGET_USER"
log_info "User change: su - $TARGET_USER"
log_info "Next steps:"
log_info "  1. Open a new terminal or run: source ~/.bashrc"
log_info "  2. Verify ROS2: echo \$ROS_DISTRO"
log_info "  3. Check GPU: hw_check"
log_info "  4. Start coding in ~/ros_ws"
echo ""
