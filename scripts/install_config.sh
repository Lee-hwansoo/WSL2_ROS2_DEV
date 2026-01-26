#!/bin/bash
# scripts/install_config.sh
# Shared configuration for Linux setup

# Packages to install
# Utilizing a simpler array structure for bash
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
    "dbus-user-session"
    "pkg-config"
)

# Docker Settings
DOCKER_GPG_URL="https://download.docker.com/linux/ubuntu/gpg"
DOCKER_REPO_URL="https://download.docker.com/linux/ubuntu"

# NVIDIA Settings
NVIDIA_GPG_URL="https://nvidia.github.io/libnvidia-container/gpgkey"
NVIDIA_REPO_URL="https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list"
