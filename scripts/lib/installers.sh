#!/bin/bash
# scripts/lib/installers.sh
# Core installation logic - Reusable functions

# =============================================================================
# KERNEL
# =============================================================================
install_hwe_kernel() {
    # HWE kernel for better Intel GPU support on Native Linux
    # Returns: 0 = no action needed, 100 = kernel installed (reboot required)
    
    log_info "Checking for HWE kernel availability..."
    apt-get update -qq
    
    local codename=$(lsb_release -cs)
    local hwe_package=""
    
    case "$codename" in
        jammy)  hwe_package="linux-generic-hwe-22.04" ;;
        focal)  hwe_package="linux-generic-hwe-20.04" ;;
        noble)  hwe_package="linux-generic-hwe-24.04" ;;
        *)
            log_info "No HWE kernel available for $codename, skipping."
            return 0
            ;;
    esac
    
    if dpkg -l | grep -q "$hwe_package"; then
        log_success "HWE kernel ($hwe_package) is already installed."
        return 0
    fi
    
    log_info "Installing HWE kernel: $hwe_package"
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$hwe_package"
    
    log_success "HWE kernel installed."
    return 100
}

# =============================================================================
# BASE PACKAGES
# =============================================================================
install_base_packages() {
    log_info "Updating package lists..."
    apt-get update -qq

    log_info "Installing base dependencies..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${BASE_PACKAGES[@]}"
}

# =============================================================================
# ROS2 INSTALLATION
# =============================================================================
install_ros2() {
    local distro="${ROS_DISTRO:-humble}"
    
    # Check if already installed
    if [ -f "/opt/ros/${distro}/setup.bash" ]; then
        log_success "ROS2 ${distro} is already installed."
        return 0
    fi
    
    log_info "Installing ROS2 ${distro}..."
    
    # Add ROS2 apt repository
    curl -sSL "$ROS2_GPG_URL" | gpg --dearmor -o /usr/share/keyrings/ros-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] $ROS2_REPO_URL $(lsb_release -cs) main" \
        | tee /etc/apt/sources.list.d/ros2.list > /dev/null
    
    apt-get update -qq
    
    # Install ROS2 packages
    log_info "Installing ROS2 packages (this may take a while)..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${ROS2_PACKAGES[@]}"
    
    log_success "ROS2 ${distro} installed successfully."
}

# =============================================================================
# MESA PPA (GPU Acceleration)
# =============================================================================
install_mesa_latest() {
    log_info "Adding Mesa PPA for latest GPU drivers..."
    
    # Add oibaf PPA
    add-apt-repository -y "$MESA_PPA"
    apt-get update -qq
    
    log_info "Upgrading Mesa packages..."
    DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
    
    # Install GPU packages
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${GPU_PACKAGES[@]}"
    
    log_success "Mesa GPU drivers updated."
}

# =============================================================================
# DEVELOPMENT TOOLS
# =============================================================================
install_dev_tools() {
    log_info "Installing development tools..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${DEV_PACKAGES[@]}"
    log_success "Development tools installed."
}

# =============================================================================
# FONT INSTALLATION
# =============================================================================
install_d2coding_font() {
    local font_dir="/usr/share/fonts/truetype/d2coding"
    
    if [ -d "$font_dir" ] && [ -f "$font_dir/D2Coding-Ver1.3.2-20180524.ttf" ]; then
        log_success "D2Coding font is already installed."
        return 0
    fi

    log_info "Installing D2Coding font..."
    
    mkdir -p "$font_dir"
    
    # Download D2Coding font (ver 1.3.2)
    local download_url="https://github.com/naver/d2codingfont/releases/download/VER1.3.2/D2Coding-Ver1.3.2-20180524.zip"
    local temp_zip="/tmp/d2coding.zip"
    
    if curl -L -o "$temp_zip" "$download_url"; then
        unzip -q -o "$temp_zip" -d "$font_dir"
        rm "$temp_zip"
        
        # Update font cache
        fc-cache -f -v > /dev/null
        
        log_success "D2Coding font installed successfully."
    else
        log_warn "Failed to download D2Coding font."
        return 1
    fi
}

# =============================================================================
# UV INSTALLATION (Python Tool)
# =============================================================================
install_uv() {
    if command -v uv &>/dev/null; then
        log_success "uv is already installed."
        return 0
    fi

    # Install system-wide to /usr/local/bin
    log_info "Installing uv (Fast Python Installer) to /usr/local/bin..."
    
    export UV_INSTALL_DIR="/usr/local/bin"
    curl -LsSf https://astral.sh/uv/install.sh | sh
    
    log_success "uv installed system-wide."
}

# =============================================================================
# USER & WORKSPACE SETUP
# =============================================================================
setup_user() {
    local username=$1
    if id -u "$username" &>/dev/null; then
        log_info "User '$username' already exists."
    else
        log_info "Creating user '$username'..."
        useradd -m -s /bin/bash -G sudo,adm,dialout,plugdev "$username"
        echo "$username:$username" | chpasswd
        log_success "User '$username' created."
    fi
    
    usermod -aG sudo "$username"
    
    # Create workspace
    local ws_dir="/home/$username/ros_ws"
    mkdir -p "$ws_dir/src"
    chown -R "$username:$username" "/home/$username"
    log_success "Workspace created at $ws_dir"
}

setup_wsl_conf() {
    local target_user=$1
    local config_src="$CONFIG_DIR/wsl.conf"
    
    log_info "Configuring /etc/wsl.conf..."
    if [ -f "$config_src" ]; then
        cp "$config_src" /etc/wsl.conf
        
        if ! grep -q "\[user\]" /etc/wsl.conf; then
            echo -e "\n[user]\ndefault=$target_user" >> /etc/wsl.conf
        fi
        log_success "wsl.conf updated."
    else
        log_warn "wsl.conf source not found."
    fi
}

# =============================================================================
# ENVIRONMENT CONFIGURATION
# =============================================================================
configure_ros_environment() {
    local username=$1
    local bashrc="/home/$username/.bashrc"
    local ros_distro="${ROS_DISTRO:-humble}"
    
    log_info "Configuring ROS2 environment for $username..."
    
    # Backup bashrc
    cp "$bashrc" "${bashrc}.bak" 2>/dev/null || true
    
    # Add ROS2 source
    if ! grep -q "source /opt/ros/${ros_distro}/setup.bash" "$bashrc"; then
        cat >> "$bashrc" << 'EOF'

# =============================================================================
# ROS2 Environment
# =============================================================================
source /opt/ros/humble/setup.bash

# Workspace (if exists)
if [ -f ~/ros_ws/install/setup.bash ]; then
    source ~/ros_ws/install/setup.bash
fi

# Colcon autocomplete
if [ -f /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash ]; then
    source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash
fi

# RMW Implementation (Middleware)
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

# ROS2 Domain ID (change if needed)
export ROS_DOMAIN_ID=0

# ccache (compiler cache)
if [ -d "/usr/lib/ccache" ]; then
    export PATH="/usr/lib/ccache:$PATH"
fi
EOF
    fi
    
    # Add aliases
    local aliases_src="$CONFIG_DIR/aliases.sh"
    if [ -f "$aliases_src" ]; then
        if ! grep -q "aliases.sh" "$bashrc"; then
            echo "" >> "$bashrc"
            echo "# Custom aliases" >> "$bashrc"
            echo "source ~/env/config/aliases.sh" >> "$bashrc"
        fi
    fi
    
    # Setup terminator config
    local terminator_src="$CONFIG_DIR/terminator_config"
    local terminator_dir="/home/$username/.config/terminator"
    if [ -f "$terminator_src" ]; then
        mkdir -p "$terminator_dir"
        # Copy instead of symlink (user preference)
        cp "$terminator_src" "$terminator_dir/config"
        chown -R "$username:$username" "/home/$username/.config"
        log_info "Terminator config copied."
    fi
    
    # Set default shell and terminal
    if [ "$SHELL" != "/bin/bash" ]; then
        chsh -s /bin/bash "$username"
        log_info "Default shell set to bash."
    fi
    
    # Set Terminator as default x-terminal-emulator
    if command -v terminator &>/dev/null; then
        update-alternatives --set x-terminal-emulator /usr/bin/terminator 2>/dev/null || true
        log_info "Terminator set as default terminal emulator."
    fi
    
    # Fix ownership
    chown "$username:$username" "$bashrc"
    
    log_success "ROS2 environment configured."
}
# ─────────────────────────────────────────────────────────────────────────────
# Cache Configuration
# ─────────────────────────────────────────────────────────────────────────────

configure_system_cache() {
    local host_cache_dir=$1
    
    if [ -z "$host_cache_dir" ] || [ ! -d "$host_cache_dir" ]; then
        return
    fi
    
    log_info "Configuring persistent cache at $host_cache_dir..."
    
    # 1. APT Cache
    local apt_cache="$host_cache_dir/apt"
    mkdir -p "$apt_cache"
    
    # Check if already mounted (idempotency)
    if grep -q "/var/cache/apt/archives" /proc/mounts; then
        log_success "APT cache is already mounted."
    else
        # Clean existing only if NOT mounted
        if [ ! -L /var/cache/apt/archives ]; then
            rm -rf /var/cache/apt/archives
        fi
        mkdir -p /var/cache/apt/archives
        
        # Bind mount
        mount --bind "$apt_cache" /var/cache/apt/archives
        log_success "APT cache bound to persistent storage."
    fi
    
    # 2. UV/Pip Cache (Prepare Environment Variables)
    local uv_cache_dir="$host_cache_dir/uv"
    local pip_cache_dir="$host_cache_dir/pip"
    mkdir -p "$uv_cache_dir" "$pip_cache_dir"
    
    # Export for current script execution
    export UV_CACHE_DIR="$uv_cache_dir"
    export PIP_CACHE_DIR="$pip_cache_dir"
    
    log_success "Package caches configured (Apt, UV, Pip)."
}

configure_user_cache() {
    local target_user=$1
    local host_cache_dir=$2
    
    if [ -z "$host_cache_dir" ]; then
        return
    fi
    
    local user_home=$(eval echo "~$target_user")
    local bashrc="$user_home/.bashrc"
    local uv_cache_dir="$host_cache_dir/uv"
    local pip_cache_dir="$host_cache_dir/pip"
    
    log_info "Persisting cache configuration for $target_user..."
    
    if grep -q "UV_CACHE_DIR" "$bashrc"; then
        # Update existing
        sed -i "s|export UV_CACHE_DIR=.*|export UV_CACHE_DIR=\"$uv_cache_dir\"|" "$bashrc"
        sed -i "s|export PIP_CACHE_DIR=.*|export PIP_CACHE_DIR=\"$pip_cache_dir\"|" "$bashrc"
    else
        # Append new
        echo "" >> "$bashrc"
        echo "# [Persistent Cache]" >> "$bashrc"
        echo "export UV_CACHE_DIR=\"$uv_cache_dir\"" >> "$bashrc"
        echo "export PIP_CACHE_DIR=\"$pip_cache_dir\"" >> "$bashrc"
    fi
    chown "$target_user:$target_user" "$bashrc"
    log_success "User cache persisted in .bashrc"
}
