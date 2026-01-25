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
