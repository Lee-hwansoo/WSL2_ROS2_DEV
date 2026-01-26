#!/bin/bash
# scripts/gpu_setup.sh
# GPU Auto-Detection and Configuration Script for WSL2 ROS2 Development
# Follows SSO (Single Source of Truth) and KISS principles
#
# Usage:
#   source ~/env/scripts/gpu_setup.sh        # Auto-detect and configure
#   source ~/env/scripts/gpu_setup.sh intel  # Force Intel GPU
#   source ~/env/scripts/gpu_setup.sh nvidia # Force NVIDIA GPU
#   source ~/env/scripts/gpu_setup.sh cpu    # Force CPU software rendering

set -e

# --- Configuration ---
LOG_PREFIX="[GPU-Setup]"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Logging Functions ---
log_info()  { echo -e "${BLUE}${LOG_PREFIX}${NC} $1"; }
log_ok()    { echo -e "${GREEN}${LOG_PREFIX}${NC} ✓ $1"; }
log_warn()  { echo -e "${YELLOW}${LOG_PREFIX}${NC} ⚠ $1"; }
log_error() { echo -e "${RED}${LOG_PREFIX}${NC} ✗ $1"; }

# --- GPU Detection Functions ---

# Check if running in WSL2
is_wsl2() {
    grep -qi "microsoft" /proc/version 2>/dev/null
}

# Check if D3D12 driver is available (WSL2 GPU passthrough)
has_d3d12() {
    [ -f "/usr/lib/wsl/lib/libd3d12.so" ] || [ -f "/usr/lib/wsl/lib/libdxcore.so" ]
}

# Check if NVIDIA GPU/driver is present
has_nvidia() {
    command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null
}

# Check if Intel GPU is available
has_intel_gpu() {
    glxinfo 2>/dev/null | grep -qi "intel" || \
    [ -n "$(ls /dev/dri/render* 2>/dev/null)" ]
}

# Check if DRI devices are accessible
has_dri() {
    [ -d "/dev/dri" ] && [ -n "$(ls /dev/dri/card* 2>/dev/null)" ]
}

# --- GPU Configuration Functions ---

# Detect best available GPU configuration
detect_gpu() {
    local gpu_type="software"
    
    if is_wsl2 && has_d3d12; then
        gpu_type="d3d12"
    elif has_nvidia; then
        gpu_type="nvidia"
    elif has_dri; then
        gpu_type="mesa"
    fi
    
    echo "$gpu_type"
}

# Configure environment for D3D12 (WSL2 GPU)
setup_d3d12() {
    export MESA_LOADER_DRIVER_OVERRIDE="d3d12"
    export GALLIUM_DRIVER="d3d12"
    export LD_LIBRARY_PATH="/usr/lib/wsl/lib:${LD_LIBRARY_PATH:-}"
    unset LIBGL_ALWAYS_SOFTWARE
    unset __NV_PRIME_RENDER_OFFLOAD
    unset __GLX_VENDOR_LIBRARY_NAME
    log_ok "Configured for WSL2 D3D12 GPU passthrough"
}

# Configure environment for Intel GPU
setup_intel() {
    export MESA_D3D12_DEFAULT_ADAPTER_NAME="Intel"
    if is_wsl2; then
        setup_d3d12
    fi
    log_ok "Configured for Intel GPU"
}

# Configure environment for NVIDIA GPU
setup_nvidia() {
    if is_wsl2; then
        export MESA_D3D12_DEFAULT_ADAPTER_NAME="NVIDIA"
        setup_d3d12
    else
        export __NV_PRIME_RENDER_OFFLOAD=1
        export __GLX_VENDOR_LIBRARY_NAME="nvidia"
        unset LIBGL_ALWAYS_SOFTWARE
    fi
    log_ok "Configured for NVIDIA GPU"
}

# Configure environment for CPU software rendering (fallback)
setup_software() {
    export LIBGL_ALWAYS_SOFTWARE=1
    export GALLIUM_DRIVER="llvmpipe"
    unset MESA_LOADER_DRIVER_OVERRIDE
    unset __NV_PRIME_RENDER_OFFLOAD
    unset __GLX_VENDOR_LIBRARY_NAME
    log_warn "Configured for CPU software rendering (fallback mode)"
}

# --- Diagnostic Functions ---

# Print current GPU status
gpu_status() {
    log_info "=== GPU Status ==="
    
    # WSL2 check
    if is_wsl2; then
        log_info "Environment: WSL2"
        if has_d3d12; then
            log_ok "D3D12 driver: Available"
        else
            log_warn "D3D12 driver: Not found"
        fi
    else
        log_info "Environment: Native Linux"
    fi
    
    # DRI check
    if has_dri; then
        log_ok "DRI devices: $(ls /dev/dri/card* 2>/dev/null | tr '\n' ' ')"
    else
        log_warn "DRI devices: Not accessible"
    fi
    
    # NVIDIA check
    if has_nvidia; then
        log_ok "NVIDIA GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)"
    else
        log_info "NVIDIA GPU: Not detected"
    fi
    
    # OpenGL renderer
    local renderer
    renderer=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | cut -d: -f2 | xargs)
    if [ -n "$renderer" ]; then
        if echo "$renderer" | grep -qi "llvmpipe\|software"; then
            log_warn "OpenGL renderer: $renderer (SOFTWARE)"
        else
            log_ok "OpenGL renderer: $renderer"
        fi
    else
        log_error "OpenGL renderer: Unable to detect (glxinfo failed)"
    fi
    
    # Environment variables
    log_info "=== Environment ==="
    log_info "DISPLAY=${DISPLAY:-not set}"
    log_info "MESA_LOADER_DRIVER_OVERRIDE=${MESA_LOADER_DRIVER_OVERRIDE:-not set}"
    log_info "GALLIUM_DRIVER=${GALLIUM_DRIVER:-not set}"
    log_info "LIBGL_ALWAYS_SOFTWARE=${LIBGL_ALWAYS_SOFTWARE:-not set}"
}

# Run GPU tests
gpu_test() {
    log_info "=== GPU Tests ==="
    
    # glxgears test (quick)
    if command -v glxgears &>/dev/null; then
        log_info "Running glxgears (3 seconds)..."
        timeout 3 glxgears -info 2>&1 | head -5 || log_warn "glxgears test failed"
    fi
    
    # vkcube test (if available)
    if command -v vkcube &>/dev/null; then
        log_info "Running vkcube (2 seconds)..."
        timeout 2 vkcube 2>&1 | head -3 || log_warn "vkcube test failed"
    fi
}

# --- Main Setup Function ---

setup_gpu() {
    local force_mode="${1:-auto}"
    
    log_info "GPU setup starting (mode: $force_mode)..."
    
    case "$force_mode" in
        intel)
            setup_intel
            ;;
        nvidia)
            if has_nvidia || is_wsl2; then
                setup_nvidia
            else
                log_error "NVIDIA not available, falling back to software"
                setup_software
            fi
            ;;
        cpu|software)
            setup_software
            ;;
        auto|*)
            local detected
            detected=$(detect_gpu)
            log_info "Detected GPU type: $detected"
            
            case "$detected" in
                d3d12)
                    setup_d3d12
                    ;;
                nvidia)
                    setup_nvidia
                    ;;
                mesa)
                    # Try D3D12 first in WSL2, fallback to native mesa
                    if is_wsl2; then
                        setup_d3d12
                    fi
                    ;;
                *)
                    setup_software
                    ;;
            esac
            ;;
    esac
    
    # Verify setup
    # Note: During container initialization (postCreateCommand), X11 might not be ready yet.
    # This is often normal and will work in an interactive shell.
    
    local glx_output
    if ! glx_output=$(glxinfo 2>&1); then
        # Capture the first line of error (e.g., "Error: unable to open display :0")
        local err_msg=$(echo "$glx_output" | head -n 1)
        log_warn "GPU verification skipped (X11 not ready): $err_msg"
        log_info "Note: This is normal during initialization. Please check 'gpu_check' in a new terminal."
        return
    fi

    local renderer
    renderer=$(echo "$glx_output" | grep "OpenGL renderer" | cut -d: -f2 | xargs)
    
    if [ -z "$renderer" ]; then
        log_warn "GPU status unknown: glxinfo returned empty renderer string."
    elif echo "$renderer" | grep -qi "llvmpipe\|software"; then
        if [ "$force_mode" != "cpu" ] && [ "$force_mode" != "software" ]; then
            log_warn "GPU acceleration unavailable, using software rendering: $renderer"
        fi
    else
        log_ok "GPU rendering active: $renderer"
    fi
}

# --- Exported Aliases ---
# These will be available after sourcing this script

alias gpu_status='gpu_status'
alias gpu_test='gpu_test'
alias use_intel='setup_intel'
alias use_nvidia='setup_nvidia'
alias use_cpu='setup_software'
alias gpu_auto='setup_gpu auto'

# --- Auto-run if executed directly ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_gpu "${1:-auto}"
    gpu_status
fi
