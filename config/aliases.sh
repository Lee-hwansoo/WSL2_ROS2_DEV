# aliases.sh
# Centralized aliases for ROS2 Development Environment

# --- ROS2 Build & Source ---
alias cb='colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release'
alias cbp='colcon build --symlink-install --packages-select'
alias s='source install/setup.bash'
alias sb='source ~/.bashrc'

# --- Navigation ---
alias cw='cd ~/ros_ws'
alias cs='cd ~/ros_ws/src'

# --- Utils ---
alias k='killall -9'
alias py='python3'
alias g='git'
alias d='docker'

# --- ROS2 Utils ---
alias rt='ros2 topic list'
alias rn='ros2 node list'
alias rqt='rqt'

# --- GPU Management ---
# Quick GPU status check (Updated for better error reporting)
alias gpu_check='if ! command -v glxinfo &>/dev/null; then echo "Error: glxinfo not found (install mesa-utils)"; else glxinfo 2>&1 | grep -E "OpenGL (vendor|renderer|version)" || echo "Error: glxinfo failed (Check X11/Display connection)"; fi'
# Full GPU diagnostics (requires gpu_setup.sh)
alias gpu_info='source ~/env/scripts/gpu_setup.sh && gpu_status'
# GPU switching commands (wrappers for gpu_setup.sh)
alias use_intel='source ~/env/scripts/gpu_setup.sh intel'
alias use_nvidia='source ~/env/scripts/gpu_setup.sh nvidia'
alias use_cpu='source ~/env/scripts/gpu_setup.sh cpu'
alias gpu_auto='source ~/env/scripts/gpu_setup.sh auto'
# GPU test (runs glxgears briefly)
alias gpu_test='timeout 5 glxgears -info 2>&1 | head -10 || echo "GPU test failed"'
