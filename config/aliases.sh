#!/bin/bash
# config/aliases.sh
# Centralized aliases for ROS2 Development Environment (Native WSL2)

# =============================================================================
# ROS2 Build & Source
# =============================================================================
alias cb='colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release'
alias cbp='colcon build --symlink-install --packages-select'
alias cbt='colcon test'
alias s='source install/setup.bash'
alias sb='source ~/.bashrc'

# =============================================================================
# Navigation
# =============================================================================
alias cw='cd ~/ros_ws'
alias cs='cd ~/ros_ws/src'
alias ce='cd ~/env'

# =============================================================================
# Utils
# =============================================================================
alias k='killall -9'
alias t='terminator'
alias py='python3'
alias g='git'
alias ll='ls -alF'

# =============================================================================
# ROS2 Commands
# =============================================================================
alias rt='ros2 topic list'
alias rn='ros2 node list'
alias rs='ros2 service list'
alias rp='ros2 param list'
alias rr='ros2 run'
alias rl='ros2 launch'
alias rqt='rqt'

# =============================================================================
# Hardware Diagnostics
# =============================================================================
# Comprehensive hardware check
alias hw_check='bash ~/env/scripts/hardware_check.sh'

# Quick GPU status
alias gpu_check='glxinfo 2>&1 | grep -E "OpenGL (vendor|renderer|version)" || echo "Error: glxinfo failed"'

# GPU mode switching
alias gpu_info='source ~/env/scripts/gpu_setup.sh && gpu_status'
alias gpu_auto='source ~/env/scripts/gpu_setup.sh auto'
alias use_intel='source ~/env/scripts/gpu_setup.sh intel'
alias use_nvidia='source ~/env/scripts/gpu_setup.sh nvidia'
alias use_cpu='source ~/env/scripts/gpu_setup.sh cpu'

# GPU performance test
alias gpu_test='timeout 5 glxgears -info 2>&1 | head -10 || echo "GPU test failed"'

# Vulkan check
alias vulkan_check='vulkaninfo --summary 2>/dev/null | head -20 || echo "Vulkan not available"'

# =============================================================================
# Gazebo / Simulation
# =============================================================================
alias gz='gazebo'
alias gzs='ros2 launch gazebo_ros gazebo.launch.py'
alias gzw='export GAZEBO_MODEL_PATH=$GAZEBO_MODEL_PATH:~/ros_ws/src'

# =============================================================================
# WSL2 Specific
# =============================================================================
# Open Windows Explorer in current directory
alias explorer='explorer.exe .'
# Open VS Code
alias c='code .'
