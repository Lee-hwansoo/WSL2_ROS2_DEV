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
TARGET_USER=${1:-ros}
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
if [ -n "$HOST_CACHE_DIR" ] && [ -d "$HOST_CACHE_DIR" ]; then
    log_info "[0/6] Configuring persistent cache at $HOST_CACHE_DIR..."
    
    # 1. APT Cache
    APT_CACHE="$HOST_CACHE_DIR/apt"
    APT_LISTS="$HOST_CACHE_DIR/apt/lists"
    mkdir -p "$APT_CACHE" "$APT_LISTS"
    
    # Clean existing if it's not a symlink/mount
    if [ ! -L /var/cache/apt/archives ]; then
        rm -rf /var/cache/apt/archives
    fi
    if [ ! -L /var/lib/apt/lists ]; then
        rm -rf /var/lib/apt/lists
    fi
    mkdir -p /var/cache/apt/archives /var/lib/apt/lists
    
    # Bind mount
    mount --bind "$APT_CACHE" /var/cache/apt/archives
    mount --bind "$APT_LISTS" /var/lib/apt/lists
    log_success "APT cache bound to persistent storage."
    
    # 2. UV/Pip Cache (Prepare Environment Variables)
    UV_CACHE_DIR="$HOST_CACHE_DIR/uv"
    PIP_CACHE_DIR="$HOST_CACHE_DIR/pip"
    mkdir -p "$UV_CACHE_DIR" "$PIP_CACHE_DIR"
    
    # Export for current script execution
    export UV_CACHE_DIR
    export PIP_CACHE_DIR
    
    # Persist for USER in .bashrc
    USER_HOME=$(eval echo "~$TARGET_USER")
    BASHRC="$USER_HOME/.bashrc"
    
    if grep -q "UV_CACHE_DIR" "$BASHRC"; then
        # Update existing
        sed -i "s|export UV_CACHE_DIR=.*|export UV_CACHE_DIR=\"$UV_CACHE_DIR\"|" "$BASHRC"
        sed -i "s|export PIP_CACHE_DIR=.*|export PIP_CACHE_DIR=\"$PIP_CACHE_DIR\"|" "$BASHRC"
    else
        # Append new
        echo "" >> "$BASHRC"
        echo "# [Persistent Cache]" >> "$BASHRC"
        echo "export UV_CACHE_DIR=\"$UV_CACHE_DIR\"" >> "$BASHRC"
        echo "export PIP_CACHE_DIR=\"$PIP_CACHE_DIR\"" >> "$BASHRC"
    fi
    chown "$TARGET_USER:$TARGET_USER" "$BASHRC"
    
    log_success "Package caches configured (Apt, UV, Pip)."
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
# 4. Mesa PPA (GPU Acceleration)
# ─────────────────────────────────────────────────────────────────────────────
log_info "[4/6] Installing latest Mesa GPU drivers..."
install_mesa_latest

# ─────────────────────────────────────────────────────────────────────────────
# 5. Development Tools
# ─────────────────────────────────────────────────────────────────────────────
log_info "[5/6] Installing development tools..."
install_dev_tools
install_d2coding_font
install_uv "$TARGET_USER"

# ─────────────────────────────────────────────────────────────────────────────
# 6. User & Environment Configuration
# ─────────────────────────────────────────────────────────────────────────────
log_info "[6/6] Configuring user and environment..."
setup_user "$TARGET_USER"

if [ "$IS_WSL" = true ]; then
    setup_wsl_conf "$TARGET_USER"
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
log_info "Next steps:"
log_info "  1. Open a new terminal or run: source ~/.bashrc"
log_info "  2. Verify ROS2: ros2 --version"
log_info "  3. Check GPU: hw_check"
log_info "  4. Start coding in ~/ros_ws"
echo ""
