#!/bin/bash
# scripts/lib/installers.sh
# Core installation logic

install_base_packages() {
    log_info "Updating package lists..."
    apt-get update -qq

    log_info "Installing base dependencies..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${BASE_PACKAGES[@]}"
}

install_docker() {
    if cmd_exists docker; then
        log_success "Docker is already installed."
        return
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
}

install_nvidia_toolkit() {
    if cmd_exists nvidia-ctk; then
        log_success "NVIDIA Container Toolkit is already installed."
        return
    fi

    log_info "Installing NVIDIA Container Toolkit..."
    curl -fsSL "$NVIDIA_GPG_URL" | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L "$NVIDIA_REPO_URL" | \
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
      tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    apt-get update -qq
    apt-get install -y nvidia-container-toolkit
    
    # Configure runtime
    nvidia-ctk runtime configure --runtime=docker
}

setup_workspace_permissions() {
    local username=$1
    local workspace_dir="/home/$username/ros_ws"
    local env_dir="/home/$username/env"
    
    log_info "Ensuring workspace permissions for $username..."
    
    # Pre-create directories to ensure ownership
    mkdir -p "$workspace_dir/src" "$env_dir"
    
    # Recursively fix ownership
    chown -R "$username:$username" "/home/$username"
    log_success "Permissions fixed for /home/$username"
}

setup_user() {
    local username=$1
    if id -u "$username" &>/dev/null; then
        log_info "User '$username' already exists."
    else
        log_info "Creating user '$username'..."
        useradd -m -s /bin/bash -G sudo,docker,adm,dialout,plugdev "$username"
        echo "$username:$username" | chpasswd
        log_success "User '$username' created."
    fi
    
    # Ensure groups
    usermod -aG sudo,docker "$username"
    
    # Fix permissions
    setup_workspace_permissions "$username"
}

setup_wsl_conf() {
    local target_user=$1
    local config_src="$CONFIG_DIR/wsl.conf"
    
    log_info "Configuring /etc/wsl.conf..."
    if [ -f "$config_src" ]; then
        cp "$config_src" /etc/wsl.conf
        
        # Ensure default user
        if ! grep -q "\[user\]" /etc/wsl.conf; then
            echo -e "\n[user]\ndefault=$target_user" >> /etc/wsl.conf
        fi
        log_success "wsl.conf updated."
    else
        log_warn "wsl.conf source not found."
    fi
}

enable_docker_service() {
    # In WSL2, systemd might not be running immediately unless configured
    if pidof systemd > /dev/null; then
        systemctl enable docker
        systemctl start docker || true
        log_success "Docker service started."
    else
        log_info "Systemd not active. Enabling Docker for next boot."
        systemctl enable docker 2>/dev/null || true
    fi
}
