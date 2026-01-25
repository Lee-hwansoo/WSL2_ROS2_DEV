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
    dbus-x11 \
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
    && rm -rf /var/lib/apt/lists/*

# 1.1 Configure Locales (Fix encoding issues)
RUN locale-gen en_US.UTF-8 ko_KR.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# 2. Configure ccache (Speed up builds)
ENV PATH="/usr/lib/ccache:$PATH"
ENV CCACHE_DIR="/home/$USERNAME/.ccache"

# 3. Install uv (Fast Python Package Installer)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# 4. Create User & Grant Sudo
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# 5. Pre-configure Terminator (Skeleton dir)
USER $USERNAME
RUN mkdir -p /home/$USERNAME/.config/terminator \
    && mkdir -p /home/$USERNAME/.ccache

# 6. Environment Setup
RUN echo "source /opt/ros/humble/setup.bash" >> /home/$USERNAME/.bashrc \
    && echo "export RCUTILS_COLORIZED_OUTPUT=1" >> /home/$USERNAME/.bashrc

# 7. Create Workspace Directory
WORKDIR /home/$USERNAME/ros_ws