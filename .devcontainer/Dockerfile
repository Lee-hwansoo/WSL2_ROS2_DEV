FROM osrf/ros:humble-desktop-full

ARG USERNAME=ros
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# 1. Install Base Tools and Dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository universe \
    && apt-get update && apt-get install -y --no-install-recommends \
    ccache \
    curl \
    git \
    terminator \
    htop \
    psmisc \
    dbus-x11 \
    mesa-utils \
    libgl1-mesa-glx \
    libgl1-mesa-dri \
    can-utils \
    net-tools \
    python3-pip \
    python3-vcstool \
    ros-humble-gazebo-ros-pkgs \
    ros-humble-ros-core \
    ros-humble-geometry2 \
    locales \
    fonts-ubuntu \
    # Intel iGPU & Media Acceleration
    intel-media-va-driver-non-free \
    libmfx1 \
    # Intel NPU & GPU Compute (OpenCL / OneAPI)
    intel-opencl-icd \
    clinfo \
    # NVIDIA Compute Utilities
    libnvidia-compute-535 \
    # Hardware Monitoring Tools
    intel-gpu-tools \
    nvtop \
    mesa-utils \
    vulkan-tools \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# 1.1 Configure Locales
RUN locale-gen en_US.UTF-8 ko_KR.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# 1.1.5 Install D2Coding Font
RUN mkdir -p /usr/share/fonts/truetype/d2coding \
    && curl -L -o /tmp/d2coding.zip https://github.com/naver/d2codingfont/releases/download/VER1.3.2/D2Coding-Ver1.3.2-20180524.zip \
    && unzip /tmp/d2coding.zip -d /usr/share/fonts/truetype/d2coding \
    && rm /tmp/d2coding.zip \
    && fc-cache -f -v

# 1.2 Universal Hardware Environment
# Force libGL/OpenCL to look in /usr/lib/wsl/lib for host drivers
ENV LD_LIBRARY_PATH=/usr/lib/wsl/lib:$LD_LIBRARY_PATH

# 2. Configure ccache (Speed up builds)
ENV PATH="/usr/lib/ccache:$PATH"
ENV CCACHE_DIR="/home/$USERNAME/.ccache"

# 3. Install uv (Fast Python Package Installer)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# 4. Create User & Grant Sudo
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# 5. Pre-configure (Skeleton dir)
USER $USERNAME
RUN mkdir -p /home/$USERNAME/.config/terminator \
    && mkdir -p /home/$USERNAME/.ccache

# 6. Environment Setup
RUN echo "source /opt/ros/humble/setup.bash" >> /home/$USERNAME/.bashrc \
    && echo "export RCUTILS_COLORIZED_OUTPUT=1" >> /home/$USERNAME/.bashrc \
    # Hardware Switching Aliases
    && echo 'alias use_intel="export MESA_D3D12_DEFAULT_ADAPTER_NAME=Intel && echo \"Switched to Intel Iris Xe/NPU\""' >> /home/$USERNAME/.bashrc \
    && echo 'alias use_nvidia="export MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA && echo \"Switched to NVIDIA RTX\""' >> /home/$USERNAME/.bashrc \
    && echo 'alias use_cpu="export LIBGL_ALWAYS_SOFTWARE=1 && echo \"Switched to CPU Only Mode\""' >> /home/$USERNAME/.bashrc

# 7. Create Workspace Directory
WORKDIR /home/$USERNAME/ros_ws