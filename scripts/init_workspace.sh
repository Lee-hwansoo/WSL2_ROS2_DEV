#!/bin/bash
# scripts/init_workspace.sh
# Executed inside the container (or WSL) to initialize the workspace environment.
# Run as user (non-root)

set -e

# --- Config ---
WS_DIR=~/ros_ws
SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"

LOG_PREFIX="[Workspace-Init]"
log() { echo -e "\033[0;35m$LOG_PREFIX $1\033[0m"; }

# --- Functions ---

ensure_workspace_structure() {
    # If the bind mount is empty or missing, auto-create the src directory
    # so colcon build doesn't fail.
    if [ ! -d "$WS_DIR/src" ]; then
        log "Creating workspace source directory: $WS_DIR/src"
        mkdir -p "$WS_DIR/src"
    fi
}

setup_environment_file() {
    # robust approach: generate a dedicated env file and source it from .bashrc
    local env_file="$HOME/.ros_env"
    
    log "Regenerating $env_file..."
    
    cat <<EOF > "$env_file"
# Auto-generated environment config
export DOCKER_HOST=unix:///var/run/docker.sock

# Load Aliases
if [ -f "$CONFIG_DIR/aliases.sh" ]; then
    source "$CONFIG_DIR/aliases.sh"
fi

# Load ROS2 Workspace
if [ -f "$WS_DIR/install/setup.bash" ]; then
    source "$WS_DIR/install/setup.bash"
fi

# Default Dir
cd $WS_DIR
EOF

    # Ensure .bashrc sources this file
    if ! grep -q "source $env_file" ~/.bashrc; then
        echo -e "\nif [ -f \"$env_file\" ]; then source \"$env_file\"; fi" >> ~/.bashrc
        log "Added env file source to .bashrc"
    fi
}

setup_terminator() {
    local config_src="$CONFIG_DIR/terminator_config"
    local config_dest="$HOME/.config/terminator/config"
    
    if [ ! -f "$config_src" ]; then
        log "No terminator config found in config dir."
        return
    fi
    
    mkdir -p "$(dirname "$config_dest")"
    
    # Use Symlink for Hot-Reloading (Windows -> WSL -> Docker)
    ln -sf "$config_src" "$config_dest"
    log "Linked Terminator config (Symlink)."
}

init_rosdep() {
    if [ ! -d "/etc/ros/rosdep" ]; then
        log "Initializing rosdep (requires sudo)..."
        sudo rosdep init || true
    fi
    
    if [ ! -f "$HOME/.ros/rosdep/sources.cache/index" ] || [ "$1" == "--force" ]; then
        log "Updating rosdep database..."
        rosdep update
    fi
}

init_gpu() {
    # GPU Setup: Auto-detect and configure for optimal rendering
    local gpu_script="$CONFIG_DIR/../scripts/gpu_setup.sh"
    
    if [ -f "$gpu_script" ]; then
        log "Initializing GPU configuration..."
        # Source the script to set environment variables
        source "$gpu_script"
        # Run auto-detection
        setup_gpu auto 2>/dev/null || true
        
        # Log GPU status
        local renderer
        renderer=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | cut -d: -f2 | xargs || echo "unknown")
        if echo "$renderer" | grep -qi "llvmpipe\|software"; then
            log "GPU: Software rendering (CPU fallback)"
        else
            log "GPU: Hardware accelerated - $renderer"
        fi
    else
        log "GPU setup script not found, skipping GPU configuration."
    fi
}

# --- Main ---

ensure_workspace_structure
setup_environment_file
setup_terminator
init_rosdep
init_gpu

log "Workspace Ready!"

