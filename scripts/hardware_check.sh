#!/bin/bash
# scripts/hardware_check.sh
# Hardware diagnostics for ROS2 development (WSL2 Native / Linux)

# Colors
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

# =============================================================================
# [1] Environment
# =============================================================================
echo -e "${BLUE}[1/5] Environment${NC}"
if grep -qi "microsoft" /proc/version 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Running in WSL2"
else
    echo -e "  ○ Running on Native Linux"
fi
echo "    Kernel: $(uname -r)"
echo "    Ubuntu: $(lsb_release -ds 2>/dev/null || echo 'Unknown')"

# =============================================================================
# [2] GPU Devices
# =============================================================================
echo -e "\n${BLUE}[2/5] GPU Devices${NC}"

# WSL2 D3D12 passthrough
if [ -e "/dev/dxg" ]; then
    echo -e "  ${GREEN}✓${NC} /dev/dxg (WSL2 GPU Passthrough)"
fi

# DRI devices
if [ -d "/dev/dri" ]; then
    for card in /dev/dri/card* /dev/dri/renderD*; do
        [ -e "$card" ] && echo -e "  ${GREEN}✓${NC} $card"
    done
fi

# NVIDIA (native Linux only)
if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    echo -e "  ${GREEN}✓${NC} NVIDIA: $GPU_NAME"
fi

# =============================================================================
# [3] OpenGL Renderer
# =============================================================================
echo -e "\n${BLUE}[3/5] OpenGL Renderer${NC}"
if command -v glxinfo &>/dev/null; then
    RENDERER=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | cut -d: -f2 | xargs)
    VENDOR=$(glxinfo 2>/dev/null | grep "OpenGL vendor" | cut -d: -f2 | xargs)
    VERSION=$(glxinfo 2>/dev/null | grep "OpenGL version" | cut -d: -f2 | xargs)
    
    if [ -n "$RENDERER" ]; then
        if echo "$RENDERER" | grep -qi "llvmpipe"; then
            echo -e "  ${YELLOW}⚠${NC} Renderer: $RENDERER ${YELLOW}(Software)${NC}"
        elif echo "$RENDERER" | grep -qi "d3d12"; then
            echo -e "  ${GREEN}✓${NC} Renderer: $RENDERER ${GREEN}(GPU Accelerated)${NC}"
        else
            echo -e "  ${GREEN}✓${NC} Renderer: $RENDERER"
        fi
        echo "    Vendor: $VENDOR"
        echo "    Version: $VERSION"
    else
        echo -e "  ${RED}✗${NC} Unable to get renderer"
    fi
else
    echo -e "  ${RED}✗${NC} glxinfo not found (install mesa-utils)"
fi

# =============================================================================
# [4] Vulkan
# =============================================================================
echo -e "\n${BLUE}[4/5] Vulkan Support${NC}"
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

# =============================================================================
# [5] Display
# =============================================================================
echo -e "\n${BLUE}[5/5] Display Configuration${NC}"
echo "  DISPLAY=${DISPLAY:-not set}"

if [ -S "/mnt/wslg/runtime-dir/wayland-0" ]; then
    echo -e "  ${GREEN}✓${NC} WSLg Wayland available"
fi

if [ -d "/tmp/.X11-unix" ] && [ -n "$(ls /tmp/.X11-unix 2>/dev/null)" ]; then
    echo -e "  ${GREEN}✓${NC} X11 available"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Diagnostics complete.${NC}"
echo ""
echo "Commands:"
echo "  gpu_auto   - Auto-configure GPU"
echo "  gpu_test   - OpenGL performance test"
echo "  use_cpu    - Force software rendering"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
