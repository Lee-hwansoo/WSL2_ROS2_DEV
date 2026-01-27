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
    "unzip"
    "can-utils"
    "net-tools"
    "linux-tools-generic"
    "hwdata"
    "usbutils"
    "sudo"
    "lsb-release"
    "gnupg"
    "software-properties-common"
)

# ROS2 packages
ROS2_PACKAGES=(
    "ros-${ROS_DISTRO}-desktop-full"
    "ros-${ROS_DISTRO}-gazebo-ros-pkgs"
    "ros-${ROS_DISTRO}-ros-core"
    "ros-${ROS_DISTRO}-geometry2"
    "python3-colcon-common-extensions"
    "python3-rosdep"
    "python3-vcstool"
)

# Development tools
DEV_PACKAGES=(
    "terminator"
    "htop"
    "nvtop"
    "ccache"
    "python3-pip"
)

# GPU/Graphics packages
GPU_PACKAGES=(
    "mesa-utils"
    "vulkan-tools"
    "libgl1-mesa-dri"
    "libgl1-mesa-glx"
    "libglx-mesa0"
    "mesa-vulkan-drivers"
    "intel-gpu-tools"
    "clinfo"
)

# =============================================================================
# REPOSITORY URLS
# =============================================================================
ROS2_GPG_URL="https://raw.githubusercontent.com/ros/rosdistro/master/ros.key"
ROS2_REPO_URL="http://packages.ros.org/ros2/ubuntu"
MESA_PPA="ppa:kisak/kisak-mesa"
