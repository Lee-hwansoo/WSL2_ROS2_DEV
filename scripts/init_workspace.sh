#!/bin/bash
# scripts/init_workspace.sh
# Running as non-root user (ros)

set -e

WS_DIR=~/ros_ws
SRC_DIR=$WS_DIR/src

LOG_PREFIX="[init_workspace]"
log() { echo -e "\033[0;32m$LOG_PREFIX $1\033[0m"; }

# Resolve Config Directory relative to this script
# Repo structure:
# root/
#   scripts/init_workspace.sh
#   config/
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CONFIG_DIR="$SCRIPT_DIR/../config"

log "Script Dir: $SCRIPT_DIR"
log "Config Dir: $CONFIG_DIR"

# 1. Inject Aliases
if [ -f "$CONFIG_DIR/aliases.sh" ]; then
    grep -qF "source $CONFIG_DIR/aliases.sh" ~/.bashrc || echo "source $CONFIG_DIR/aliases.sh" >> ~/.bashrc
    log "Aliases injected."
else
    log "Warning: aliases.sh not found in $CONFIG_DIR"
fi

# 2. Setup Terminator Config
# Remove existing file/link if exists to ensure we use the mounted one
mkdir -p ~/.config/terminator
if [ -f "$CONFIG_DIR/terminator_config" ]; then
    rm -f ~/.config/terminator/config
    ln -s "$CONFIG_DIR/terminator_config" ~/.config/terminator/config
    log "Terminator config linked (terminator_config)."
else
    log "Warning: terminator_config not found in $CONFIG_DIR."
fi

# 3. Setup Workspace Source only if built
if ! grep -qF "source $WS_DIR/install/setup.bash" ~/.bashrc; then
    echo "if [ -f $WS_DIR/install/setup.bash ]; then source $WS_DIR/install/setup.bash; fi" >> ~/.bashrc
    log "Workspace source added to .bashrc."
fi

# 4. Optional: Rosdep (Check for marker to avoid re-running)
if [ ! -f ~/.ros/rosdep/sources.cache/index ]; then
    if [ ! -f /tmp/apt_updated ]; then
        log "Updating apt cache for rosdep..."
        sudo apt-get update
        touch /tmp/apt_updated
    fi
    sudo rosdep init 2>/dev/null || true
    rosdep update
    log "Rosdep initialized."
fi

log "Workspace Initialization Complete."
