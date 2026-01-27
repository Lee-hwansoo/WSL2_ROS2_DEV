#!/bin/bash
# .devcontainer/scripts/detect_devices.sh
# Pre-container device detection and dynamic configuration
# Runs via initializeCommand before container starts

set -e

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOG_PREFIX="[Device-Detect]"
log_info()  { echo -e "${BLUE}${LOG_PREFIX}${NC} $1"; }
log_ok()    { echo -e "${GREEN}${LOG_PREFIX}${NC} ✓ $1"; }
log_warn()  { echo -e "${YELLOW}${LOG_PREFIX}${NC} ⚠ $1"; }

# --- Get Script Directory ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVCONTAINER_JSON="$SCRIPT_DIR/../devcontainer.json"

echo ""
log_info "╔══════════════════════════════════════════════════════════════╗"
log_info "║          Pre-Container Hardware Detection                      ║"
log_info "╚══════════════════════════════════════════════════════════════╝"
echo ""

# --- Environment Detection ---
is_wsl2() {
    grep -qi "microsoft" /proc/version 2>/dev/null
}

log_info "Detecting environment..."
if is_wsl2; then
    log_ok "WSL2 environment detected"
    ENVIRONMENT="wsl2"
else
    log_ok "Native Linux environment detected"
    ENVIRONMENT="native"
fi

# --- Dynamic Device Configuration ---
configure_devices() {
    log_info "Configuring device mappings for $ENVIRONMENT..."
    
    if [ ! -f "$DEVCONTAINER_JSON" ]; then
        log_warn "devcontainer.json not found, skipping device configuration"
        return
    fi
    
    # Check write permissions
    if [ ! -w "$DEVCONTAINER_JSON" ] || [ ! -w "$(dirname "$DEVCONTAINER_JSON")" ]; then
        echo ""
        log_error "═══════════════════════════════════════════════════════════════"
        log_error "PERMISSION DENIED: Cannot modify devcontainer.json"
        log_error "The script needs write access to configure hardware settings."
        echo ""
        log_warn  "Please run this command in your WSL terminal to fix ownership:"
        echo -e   "${GREEN}    sudo chown -R \$USER:\$USER ~/env${NC}"
        echo ""
        log_error "═══════════════════════════════════════════════════════════════"
        exit 1
    fi

    # Create backup
    cp "$DEVCONTAINER_JSON" "$DEVCONTAINER_JSON.bak"
    
    if [ "$ENVIRONMENT" = "wsl2" ]; then
        # Enable WSL2 device, disable Native device
        # Uncomment /dev/dxg line (remove // prefix if commented)
        sed -i 's|// *"--device=/dev/dxg"|"--device=/dev/dxg"|g' "$DEVCONTAINER_JSON"
        # Comment out /dev/dri line
        sed -i 's|^\([[:space:]]*\)"--device=/dev/dri"|\1// "--device=/dev/dri"|g' "$DEVCONTAINER_JSON"
        log_ok "Enabled: /dev/dxg (WSL2 D3D12)"
        log_info "Disabled: /dev/dri (Native Linux only)"
    else
        # Enable Native device, disable WSL2 device
        # Uncomment /dev/dri line
        sed -i 's|// *"--device=/dev/dri"|"--device=/dev/dri"|g' "$DEVCONTAINER_JSON"
        # Comment out /dev/dxg line
        sed -i 's|^\([[:space:]]*\)"--device=/dev/dxg"|\1// "--device=/dev/dxg"|g' "$DEVCONTAINER_JSON"
        log_ok "Enabled: /dev/dri (Native Linux DRI)"
        log_info "Disabled: /dev/dxg (WSL2 only)"
    fi
}

# Run device configuration
configure_devices

# --- GPU Device Detection ---
log_info "Scanning GPU devices..."

# WSL2 D3D12 Passthrough
if [ -e "/dev/dxg" ]; then
    log_ok "/dev/dxg (Windows GPU Passthrough - D3D12)"
else
    if [ "$ENVIRONMENT" = "wsl2" ]; then
        log_warn "/dev/dxg not found (driver issue?)"
    fi
fi

# DRI Devices (Intel/AMD/Mesa)
if [ -d "/dev/dri" ]; then
    DRI_COUNT=$(ls /dev/dri/card* /dev/dri/renderD* 2>/dev/null | wc -l)
    if [ "$DRI_COUNT" -gt 0 ]; then
        log_ok "/dev/dri available ($DRI_COUNT devices)"
        for dev in /dev/dri/card* /dev/dri/renderD*; do
            [ -e "$dev" ] && log_info "  └─ $dev"
        done
    else
        log_warn "/dev/dri exists but no devices found"
    fi
else
    if [ "$ENVIRONMENT" = "native" ]; then
        log_warn "/dev/dri not found"
    fi
fi

# NVIDIA GPU
if command -v nvidia-smi &>/dev/null; then
    if nvidia-smi &>/dev/null; then
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
        log_ok "NVIDIA GPU: $GPU_NAME"
    else
        log_warn "nvidia-smi found but not working (driver issue?)"
    fi
else
    log_info "NVIDIA: Not detected (nvidia-smi not available)"
fi

# --- NPU/AI Accelerator Detection ---
log_info "Scanning NPU/AI accelerators..."
if [ -d "/dev/accel" ]; then
    NPU_COUNT=$(ls /dev/accel/* 2>/dev/null | wc -l)
    if [ "$NPU_COUNT" -gt 0 ]; then
        log_ok "NPU/AI Accelerator: $NPU_COUNT device(s)"
        for dev in /dev/accel/*; do
            [ -e "$dev" ] && log_info "  └─ $dev"
        done
    fi
else
    log_info "NPU: Not detected (/dev/accel not found)"
fi

# --- Display/GUI Detection ---
log_info "Checking display configuration..."

if [ -n "$DISPLAY" ]; then
    log_ok "DISPLAY=$DISPLAY"
else
    log_warn "DISPLAY not set (GUI may not work)"
fi

if [ -d "/mnt/wslg" ]; then
    log_ok "WSLg available (Wayland/X11 GUI support)"
    [ -S "/mnt/wslg/runtime-dir/wayland-0" ] && log_info "  └─ Wayland socket ready"
fi

if [ -d "/tmp/.X11-unix" ]; then
    log_ok "X11 socket directory available"
fi

# WSL Driver Store
if [ -d "/usr/lib/wsl/lib" ]; then
    log_ok "WSL Driver Store: /usr/lib/wsl/lib"
else
    if [ "$ENVIRONMENT" = "wsl2" ]; then
        log_warn "WSL Driver Store not found (GPU passthrough may fail)"
    fi
fi

# --- Summary ---
echo ""
log_info "═══════════════════════════════════════════════════════════════"
log_info "Device detection complete. Environment: $ENVIRONMENT"
log_info "═══════════════════════════════════════════════════════════════"
echo ""

exit 0
