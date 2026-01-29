#!/bin/bash
# scripts/install_config.sh
# SSO Configuration - All versions and packages defined here

# =============================================================================
# VERSION CONFIGURATION
# =============================================================================
ROS_DISTRO="humble"
UBUNTU_CODENAME="jammy"  # Ubuntu 22.04

# =============================================================================
# PACKAGE LISTS
# =============================================================================

# Base system packages
BASE_PACKAGES=(
    "build-essential"
    "curl"
    "wget"
    "git"
    "jq"
    "unzip"
    "can-utils"
    "net-tools"
    "linux-tools-generic"
    "hwdata"
    "usbutils"
    "sudo"
    "lsb-release"
    "gnupg"
    "tree"
    "software-properties-common"
    "htop"
    "nvtop"
    "ccache"
)

# ROS2 packages
ROS2_PACKAGES=(
    "ros-${ROS_DISTRO}-desktop-full"
    "ros-${ROS_DISTRO}-rmw-cyclonedds-cpp"
    "ros-${ROS_DISTRO}-gazebo-ros-pkgs"
    "python3-colcon-common-extensions"
    "python3-rosdep"
    "python3-vcstool"
)

# Simulation packages
SIM_PACKAGES=(
    "gazebo"
)

# Development tools
DEV_PACKAGES=(
    "terminator"
    "python3-pip"
    "python3-venv"
    "python3-dev"
    "clang-format"
    "cmake"
    "gdb"
    "gcc"
    "g++"
    "clangd"
)

# CUDA/Nvidia packages
CUDA_PACKAGES=(
    "nvidia-cuda-toolkit"
)

# GPU/Graphics packages
GPU_PACKAGES_COMMON=(
    "mesa-utils"
    "libwayland-client0"
    "libgl1-mesa-dri"
    "libgl1-mesa-glx"
    "libglfw3-dev"
    "libglu1-mesa-dev"
    "libegl1-mesa-dev"
    "libglx-mesa0"
    "libxkbcommon0"
    "mesa-vulkan-drivers"
    "vulkan-tools"
    "libvulkan-dev"
    "vulkan-validationlayers"
    "clinfo"
)

GPU_PACKAGES_INTEL=(
    "intel-opencl-icd"
    "intel-gpu-tools"
    "intel-media-va-driver-non-free"
    "libmfx1"
)

GPU_PACKAGES_AMD=() # Mesa covers most AMD needs, can add specifics if needed

# =============================================================================
# REPOSITORY URLS
# =============================================================================
ROS2_GPG_URL="https://raw.githubusercontent.com/ros/rosdistro/master/ros.key"
ROS2_REPO_URL="http://packages.ros.org/ros2/ubuntu"
MESA_PPA="ppa:kisak/kisak-mesa"
