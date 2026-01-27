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
# DOCKER (Optional)
# =============================================================================
install_docker() {
    if cmd_exists docker; then
        log_success "Docker is already installed."
        return 0
    fi
    
    log_info "Installing Docker Engine..."
    
    # Clean previous
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
        apt-get remove -y $pkg 2>/dev/null || true
    done

    # Add Key
    install -m 0755 -d /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/docker.asc ]; then
        curl -fsSL "$DOCKER_GPG_URL" -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
    fi

    # Add Repo
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] $DOCKER_REPO_URL \
      $(lsb_release -cs) stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    log_success "Docker installed."
}

enable_docker_service() {
    if pidof systemd > /dev/null; then
        systemctl enable docker
        systemctl start docker || true
        log_success "Docker service started."
    else
        log_info "Systemd not active. Enabling Docker for next boot."
        systemctl enable docker 2>/dev/null || true
    fi
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

# ROS2 Domain ID (change if needed)
export ROS_DOMAIN_ID=0
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
    
    # Fix ownership
    chown "$username:$username" "$bashrc"
    
    log_success "ROS2 environment configured."
}
