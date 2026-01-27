#!/bin/bash
# scripts/hardware_check.sh
# Comprehensive hardware diagnostics for ROS2 DevContainer
# Run inside container: hw_check

set -e

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          ROS2 Development Hardware Diagnostics               ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# --- [1] Environment ---
echo -e "${BLUE}[1/6] Environment${NC}"
if grep -qi "microsoft" /proc/version 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Running in WSL2"
    echo "    Kernel: $(uname -r)"
else
    echo "  ○ Running on Native Linux"
    echo "    Kernel: $(uname -r)"
fi

# --- [2] GPU Devices ---
echo -e "\n${BLUE}[2/6] GPU Devices${NC}"

# /dev/dxg (WSL2 D3D12)
if [ -e "/dev/dxg" ]; then
    echo -e "  ${GREEN}✓${NC} /dev/dxg (WSL2 GPU Passthrough)"
fi

# /dev/dri (DRI devices)
if [ -d "/dev/dri" ]; then
    for card in /dev/dri/card* /dev/dri/renderD*; do
        [ -e "$card" ] && echo -e "  ${GREEN}✓${NC} $card"
    done
fi

# NVIDIA
if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    GPU_MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1)
    echo -e "  ${GREEN}✓${NC} NVIDIA: $GPU_NAME ($GPU_MEM)"
fi

# No GPU found
if [ ! -e "/dev/dxg" ] && [ ! -d "/dev/dri" ] && ! command -v nvidia-smi &>/dev/null; then
    echo -e "  ${YELLOW}⚠${NC} No GPU devices detected (CPU rendering mode)"
fi

# --- [3] OpenGL Renderer ---
echo -e "\n${BLUE}[3/6] OpenGL Renderer${NC}"
if command -v glxinfo &>/dev/null; then
    RENDERER=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | cut -d: -f2 | xargs)
    VENDOR=$(glxinfo 2>/dev/null | grep "OpenGL vendor" | cut -d: -f2 | xargs)
    VERSION=$(glxinfo 2>/dev/null | grep "OpenGL version" | cut -d: -f2 | xargs)
    
    if [ -n "$RENDERER" ]; then
        if echo "$RENDERER" | grep -qi "llvmpipe"; then
            echo -e "  ${YELLOW}⚠${NC} Renderer: $RENDERER ${YELLOW}(Software)${NC}"
        else
            echo -e "  ${GREEN}✓${NC} Renderer: $RENDERER"
        fi
        echo "    Vendor: $VENDOR"
        echo "    Version: $VERSION"
    else
        echo -e "  ${RED}✗${NC} Unable to get renderer (X11 connection failed?)"
    fi
else
    echo -e "  ${RED}✗${NC} glxinfo not installed (install mesa-utils)"
fi

# --- [4] Vulkan ---
echo -e "\n${BLUE}[4/6] Vulkan Support${NC}"
if command -v vulkaninfo &>/dev/null; then
    VK_GPU=$(vulkaninfo --summary 2>/dev/null | grep "deviceName" | head -1 | cut -d= -f2 | xargs)
    if [ -n "$VK_GPU" ]; then
        echo -e "  ${GREEN}✓${NC} Vulkan GPU: $VK_GPU"
    else
        echo -e "  ${YELLOW}⚠${NC} Vulkan installed but no GPU detected"
    fi
else
    echo "  ○ vulkaninfo not installed"
fi

# --- [5] NPU/AI Accelerators ---
echo -e "\n${BLUE}[5/6] NPU/AI Accelerators${NC}"
if [ -d "/dev/accel" ]; then
    for accel in /dev/accel/*; do
        [ -e "$accel" ] && echo -e "  ${GREEN}✓${NC} $accel"
    done
else
    echo "  ○ No NPU detected (/dev/accel not found)"
fi

# OpenVINO Check
if command -v python3 &>/dev/null; then
    if python3 -c "import openvino" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} OpenVINO runtime available"
    fi
fi

# --- [6] Display Configuration ---
echo -e "\n${BLUE}[6/6] Display Configuration${NC}"
echo "  DISPLAY=${DISPLAY:-${RED}not set${NC}}"
echo "  WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-not set}"
echo "  XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-not set}"

if [ -S "/mnt/wslg/runtime-dir/wayland-0" ]; then
    echo -e "  ${GREEN}✓${NC} WSLg Wayland socket available"
fi

if [ -d "/tmp/.X11-unix" ] && [ -n "$(ls /tmp/.X11-unix 2>/dev/null)" ]; then
    echo -e "  ${GREEN}✓${NC} X11 socket available"
fi

# --- Summary ---
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Diagnostics complete.${NC}"
echo ""
echo "Quick commands:"
echo "  gpu_auto  - Auto-configure GPU settings"
echo "  gpu_test  - Run OpenGL performance test"
echo "  use_cpu   - Force CPU rendering (if GPU issues)"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
