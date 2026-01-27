#!/bin/bash
# .devcontainer/scripts/detect_devices.sh
# Pre-container device detection for cross-platform compatibility
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

echo ""
log_info "╔══════════════════════════════════════════════════════════════╗"
log_info "║          Pre-Container Hardware Detection                      ║"
log_info "╚══════════════════════════════════════════════════════════════╝"
echo ""

# --- Environment Detection ---
log_info "Checking environment..."
if grep -qi "microsoft" /proc/version 2>/dev/null; then
    log_ok "WSL2 environment detected"
    IS_WSL2=true
else
    log_info "Native Linux environment"
    IS_WSL2=false
fi

# --- GPU Device Detection ---
log_info "Scanning GPU devices..."

# WSL2 D3D12 Passthrough
if [ -e "/dev/dxg" ]; then
    log_ok "/dev/dxg (Windows GPU Passthrough - D3D12)"
else
    log_warn "/dev/dxg not found (non-WSL2 or driver issue)"
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
    log_warn "/dev/dri directory not found"
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

# --- WSL Driver Store ---
if [ -d "/usr/lib/wsl/lib" ]; then
    log_ok "WSL Driver Store: /usr/lib/wsl/lib"
else
    if [ "$IS_WSL2" = true ]; then
        log_warn "WSL Driver Store not found (GPU passthrough may fail)"
    fi
fi

# --- Summary ---
echo ""
log_info "═══════════════════════════════════════════════════════════════"
log_info "Device detection complete. Container will start with available hardware."
log_info "═══════════════════════════════════════════════════════════════"
echo ""

exit 0
