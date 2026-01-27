#!/bin/bash
# scripts/gpu_setup.sh
# GPU Auto-Detection and Configuration Script for WSL2 ROS2 Development

set -e

# --- Configuration ---
GPU_LOG_PREFIX="[GPU-Setup]"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Logging ---
function log_info()  { echo -e "${BLUE}${GPU_LOG_PREFIX}${NC} $1"; }
function log_ok()    { echo -e "${GREEN}${GPU_LOG_PREFIX}${NC} ✓ $1"; }
function log_warn()  { echo -e "${YELLOW}${GPU_LOG_PREFIX}${NC} ⚠ $1"; }
function log_error() { echo -e "${RED}${GPU_LOG_PREFIX}${NC} ✗ $1"; }

# --- Detection Helpers ---

function is_wsl2() {
    grep -qi "microsoft" /proc/version 2>/dev/null
}

function has_d3d12() {
    [ -f "/usr/lib/wsl/lib/libd3d12.so" ] || [ -f "/usr/lib/wsl/lib/libdxcore.so" ]
}

function has_nvidia() {
    command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null
}

function has_intel_gpu() {
    glxinfo 2>/dev/null | grep -qi "intel" || [ -n "$(ls /dev/dri/render* 2>/dev/null)" ]
}

function has_dri() {
    [ -d "/dev/dri" ] && [ -n "$(ls /dev/dri/card* 2>/dev/null)" ]
}

function has_npu() {
    [ -d "/dev/accel" ] && [ -n "$(ls /dev/accel/* 2>/dev/null)" ]
}

function has_vulkan() {
    command -v vulkaninfo &>/dev/null && vulkaninfo --summary 2>/dev/null | grep -qi "deviceName"
}

# --- Core Logic ---

function detect_gpu() {
    if is_wsl2 && has_d3d12; then
        echo "d3d12"
    elif has_nvidia; then
        echo "nvidia"
    elif has_dri; then
        echo "mesa"
    else
        echo "software"
    fi
}

function setup_d3d12() {
    # Explicitly force D3D12 driver for WSL2 GPU passthrough
    # Auto-detection often fails and falls back to llvmpipe
    export MESA_LOADER_DRIVER_OVERRIDE="d3d12"
    export GALLIUM_DRIVER="d3d12"
    export LD_LIBRARY_PATH="/usr/lib/wsl/lib:${LD_LIBRARY_PATH:-}"
    unset LIBGL_ALWAYS_SOFTWARE
    unset __NV_PRIME_RENDER_OFFLOAD
    unset __GLX_VENDOR_LIBRARY_NAME
    log_ok "Configured for WSL2 D3D12 GPU passthrough"
}

function setup_intel() {
    export MESA_D3D12_DEFAULT_ADAPTER_NAME="Intel"
    if is_wsl2; then
        setup_d3d12
    fi
    log_ok "Configured for Intel GPU"
}

function setup_nvidia() {
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

function setup_software() {
    export LIBGL_ALWAYS_SOFTWARE=1
    export GALLIUM_DRIVER="llvmpipe"
    unset MESA_LOADER_DRIVER_OVERRIDE
    unset __NV_PRIME_RENDER_OFFLOAD
    unset __GLX_VENDOR_LIBRARY_NAME
    log_warn "Configured for CPU software rendering (fallback mode)"
}

# --- Status & Diagnostic ---

function check_renderer() {
    local renderer
    local renderer_raw
    
    renderer_raw=$(glxinfo 2>/dev/null | grep "OpenGL renderer" || true)

    if [ -n "$renderer_raw" ]; then
        renderer=$(echo "$renderer_raw" | cut -d: -f2 | xargs)
    else
        renderer="unknown"
    fi

    if [ "$renderer" != "unknown" ]; then
        # Use grep -e to avoid pipe escaping issues
        if echo "$renderer" | grep -qi -e "llvmpipe" -e "software"; then
            log_warn "OpenGL renderer: $renderer (SOFTWARE)"
        else
            log_ok "OpenGL renderer: $renderer"
        fi
    else
        log_error "OpenGL renderer: Unable to detect (glxinfo failed)"
    fi
}

function gpu_status() {
    log_info "=== GPU Status ==="
    
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
    
    if has_dri; then
        log_ok "DRI devices: $(ls /dev/dri/card* 2>/dev/null | tr '\n' ' ')"
    else
        log_warn "DRI devices: Not accessible"
    fi
    
    if has_nvidia; then
        log_ok "NVIDIA GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)"
    else
        log_info "NVIDIA GPU: Not detected"
    fi
    
    check_renderer
    
    # NPU Status
    if has_npu; then
        log_ok "NPU devices: $(ls /dev/accel/* 2>/dev/null | tr '\n' ' ')"
    else
        log_info "NPU: Not detected"
    fi
    
    # Vulkan Status
    if has_vulkan; then
        VK_GPU=$(vulkaninfo --summary 2>/dev/null | grep "deviceName" | head -1 | cut -d= -f2 | xargs)
        log_ok "Vulkan: $VK_GPU"
    else
        log_info "Vulkan: Not configured"
    fi
    
    log_info "=== Environment ==="
    log_info "DISPLAY=${DISPLAY:-not set}"
    log_info "MESA_LOADER_DRIVER_OVERRIDE=${MESA_LOADER_DRIVER_OVERRIDE:-not set}"
    log_info "GALLIUM_DRIVER=${GALLIUM_DRIVER:-not set}"
    log_info "LIBGL_ALWAYS_SOFTWARE=${LIBGL_ALWAYS_SOFTWARE:-not set}"
}

function gpu_test() {
    log_info "=== GPU Tests ==="
    
    if command -v glxgears &>/dev/null; then
        log_info "Running glxgears (3 seconds)..."
        timeout 3 glxgears -info 2>&1 | head -5 || log_warn "glxgears test failed"
    fi
    
    if command -v vkcube &>/dev/null; then
        log_info "Running vkcube (2 seconds)..."
        timeout 2 vkcube 2>&1 | head -3 || log_warn "vkcube test failed"
    fi
}

# --- Main Entry Point ---

function setup_gpu() {
    local force_mode="${1:-auto}"
    
    log_info "GPU setup starting (mode: $force_mode)..."
    
    case "$force_mode" in
        intel)    setup_intel ;;
        nvidia)   
            if has_nvidia || is_wsl2; then setup_nvidia; else setup_software; fi 
            ;;
        cpu|software) setup_software ;;
        auto|*)
            local detected=$(detect_gpu)
            log_info "Detected GPU type: $detected"
            case "$detected" in
                d3d12)  setup_d3d12 ;;
                nvidia) setup_nvidia ;;
                mesa)   if is_wsl2; then setup_d3d12; fi ;;
                *)      setup_software ;;
            esac
            ;;
    esac
    
    # Initialization check
    local glx_output
    if ! glx_output=$(glxinfo 2>&1); then
        local err_msg=$(echo "$glx_output" | head -n 1)
        log_warn "GPU verification skipped (X11 not ready): $err_msg"
        log_info "Note: This is normal during initialization. Please check 'gpu_check' in a new terminal."
        return
    fi
    
    check_renderer
}

# --- Export Aliases ---
alias gpu_status='gpu_status'
alias gpu_test='gpu_test'
alias use_intel='setup_intel'
alias use_nvidia='setup_nvidia'
alias use_cpu='setup_software'
alias gpu_auto='setup_gpu auto'

# --- Auto Run ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_gpu "${1:-auto}"
    gpu_status
fi
