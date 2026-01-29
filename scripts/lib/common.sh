#!/bin/bash
# scripts/lib/common.sh
# Common helpers and logging

LOG_PREFIX="[Setup]"

log_info() { echo -e "\033[0;36m${LOG_PREFIX} [INFO] $1\033[0m"; }
log_success() { echo -e "\033[0;32m${LOG_PREFIX} [SUCCESS] $1\033[0m"; }
log_warn() { echo -e "\033[0;33m${LOG_PREFIX} [WARN] $1\033[0m"; }
log_error() { echo -e "\033[0;31m${LOG_PREFIX} [ERROR] $1\033[0m"; }

ensure_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root."
        exit 1
    fi
}

cmd_exists() {
    command -v "$1" &> /dev/null
}

# Retry command: retry <retries> <delay> <command...>
retry() {
    local retries=$1
    shift
    local delay=$1
    shift
    local count=0
    until "$@"; do
        exit=$?
        wait=$delay
        count=$((count + 1))
        if [ $count -lt $retries ]; then
            log_warn "Command failed. Retrying in $wait seconds... ($count/$retries)"
            sleep $wait
        else
            log_error "Command failed after $retries attempts."
            return $exit
        fi
    done
    return 0
}

# =============================================================================
# HARDWARE DETECTION
# =============================================================================
detect_gpu_vendor() {
    # Returns: nvidia, amd, intel, or none
    local vendor="none"
    
    if cmd_exists lspci; then
        local pci_info=$(lspci -vnn 2>/dev/null | grep -i "VGA\|3D\|Display")
        
        if echo "$pci_info" | grep -qi "nvidia"; then
            vendor="nvidia"
        elif echo "$pci_info" | grep -qi "amd"; then
            vendor="amd"
        elif echo "$pci_info" | grep -qi "intel"; then
            vendor="intel"
        fi
    elif cmd_exists lshw; then
        local lshw_info=$(lshw -C display 2>/dev/null)
        
        if echo "$lshw_info" | grep -qi "nvidia"; then
            vendor="nvidia"
        elif echo "$lshw_info" | grep -qi "amd"; then
            vendor="amd"
        elif echo "$lshw_info" | grep -qi "intel"; then
            vendor="intel"
        fi
    fi
    
    echo "$vendor"
}
