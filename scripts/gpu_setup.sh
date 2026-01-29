#!/bin/bash
# scripts/gpu_setup.sh
# GPU Configuration for ROS2 Development (WSL2 Native / Linux)

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOG_PREFIX="[GPU]"
log_info()  { echo -e "${BLUE}${LOG_PREFIX}${NC} $1"; }
log_ok()    { echo -e "${GREEN}${LOG_PREFIX}${NC} ✓ $1"; }
log_warn()  { echo -e "${YELLOW}${LOG_PREFIX}${NC} ⚠ $1"; }

# =============================================================================
# Detection Helpers
# =============================================================================
is_wsl2() { grep -qi "microsoft" /proc/version 2>/dev/null; }
has_nvidia() { command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null 2>&1; }

# =============================================================================
# GPU Setup Functions
# =============================================================================
reset_gpu_env() {
    # Clear all overrides to ensure a clean slate
    unset LD_LIBRARY_PATH
    unset MESA_LOADER_DRIVER_OVERRIDE
    unset GALLIUM_DRIVER
    unset LIBGL_ALWAYS_SOFTWARE
    unset MESA_D3D12_DEFAULT_ADAPTER_NAME
    unset __NV_PRIME_RENDER_OFFLOAD
    unset __GLX_VENDOR_LIBRARY_NAME
}

setup_d3d12() {
    export LD_LIBRARY_PATH="/usr/lib/wsl/lib:${LD_LIBRARY_PATH:-}"
    export MESA_LOADER_DRIVER_OVERRIDE="d3d12"
    export GALLIUM_DRIVER="d3d12"
    log_ok "D3D12 GPU passthrough configured"
}

setup_nvidia() {
    reset_gpu_env
    if is_wsl2; then
        export MESA_D3D12_DEFAULT_ADAPTER_NAME="NVIDIA"
        setup_d3d12
    else
        export __NV_PRIME_RENDER_OFFLOAD=1
        export __GLX_VENDOR_LIBRARY_NAME="nvidia"
    fi
    log_ok "NVIDIA GPU configured"
}

setup_intel() {
    reset_gpu_env
    if is_wsl2; then
        export MESA_D3D12_DEFAULT_ADAPTER_NAME="Intel"
        setup_d3d12
    fi
    # Native Linux Intel uses standard system drivers
    log_ok "Intel GPU configured"
}

setup_software() {
    reset_gpu_env
    export LIBGL_ALWAYS_SOFTWARE=1
    export GALLIUM_DRIVER="llvmpipe"
    log_warn "Software rendering (CPU) configured"
}

# =============================================================================
# Auto Detection
# =============================================================================
setup_auto() {
    if is_wsl2; then
        reset_gpu_env
        setup_d3d12
    elif has_nvidia; then
        setup_nvidia
    else
        setup_software
    fi
}

# =============================================================================
# Status
# =============================================================================
gpu_status() {
    log_info "=== GPU Status ==="

    if is_wsl2; then
        log_info "Environment: WSL2"
    else
        log_info "Environment: Native Linux"
    fi

    if has_nvidia; then
        log_ok "NVIDIA: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)"
    fi

    # OpenGL renderer
    local renderer=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | cut -d: -f2 | xargs)
    if [ -n "$renderer" ]; then
        if echo "$renderer" | grep -qi "llvmpipe"; then
            log_warn "Renderer: $renderer (Software)"
        else
            log_ok "Renderer: $renderer"
        fi
    else
        log_warn "Renderer: Unable to detect"
    fi

    log_info "=== Environment Variables ==="
    log_info "DISPLAY=${DISPLAY:-not set}"
    log_info "MESA_LOADER_DRIVER_OVERRIDE=${MESA_LOADER_DRIVER_OVERRIDE:-not set}"
    log_info "GALLIUM_DRIVER=${GALLIUM_DRIVER:-not set}"
}

# =============================================================================
# Main Entry
# =============================================================================
case "${1:-}" in
    intel)    setup_intel ;;
    nvidia)   setup_nvidia ;;
    cpu|software) setup_software ;;
    status)   gpu_status ;;
    auto|"")  setup_auto ;;
    *)        echo "Usage: $0 {auto|intel|nvidia|cpu|status}" ;;
esac
