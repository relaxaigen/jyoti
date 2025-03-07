#!/bin/bash

# Predefine your credentials here:
WORKER_ID="QJHaeMXnkN4tf35tYQ9xd"
CODE="5f6487b8-5382-45d5-8170-7246f9a06c5b"

CONFIG_FILE="$HOME/.kuzco_config"
LOG_FILE="/var/log/kuzco_worker.log"
SCREEN_NAME="kuzco"  # Name of the screen session

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

load_kuzco_config() {
    if [[ -z "$WORKER_ID" || -z "$CODE" ]] && [[ -f "$CONFIG_FILE" ]]; then
         source "$CONFIG_FILE"
    fi
}

setup_timezone() {
    log_message "Detecting and setting local timezone..."
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update > /dev/null 2>&1
    sudo apt-get install -y tzdata > /dev/null 2>&1
    if command -v timedatectl &> /dev/null; then
        LOCAL_TIMEZONE=$(timedatectl show --property=Timezone --value)
        [[ -z "$LOCAL_TIMEZONE" ]] && LOCAL_TIMEZONE="UTC"
    else
        LOCAL_TIMEZONE=$(curl -s https://ipapi.co/timezone)
        [[ -z "$LOCAL_TIMEZONE" ]] && LOCAL_TIMEZONE="UTC"
    fi
    echo "$LOCAL_TIMEZONE" | sudo tee /etc/timezone > /dev/null
    sudo ln -fs "/usr/share/zoneinfo/$LOCAL_TIMEZONE" /etc/localtime
    sudo dpkg-reconfigure -f noninteractive tzdata > /dev/null 2>&1
    log_message "Timezone set to $(date)."
}

install_gpu_tools() {
    if ! command -v lspci &> /dev/null || ! command -v lshw &> /dev/null; then
        echo "Installing GPU detection tools..."
        sudo apt update
        sudo apt install -y pciutils lshw coreutils
    fi
}

check_nvidia_gpu() {
    if grep -qi microsoft /proc/version; then
        echo "WSL detected. Checking GPU with nvcc..."
        command -v nvcc &> /dev/null && { nvcc --version; return 0; } || { echo "No CUDA found in WSL!"; return 1; }
    else
        if command -v lspci &> /dev/null && lspci | grep -qi nvidia; then
            echo "NVIDIA GPU detected!"
            command -v nvcc &> /dev/null && nvcc --version
            return 0
        else
            echo "No NVIDIA GPU detected!"
            return 1
        fi
    fi
}

setup_cuda_env() {
    log_message "Setting up CUDA environment..."
    {
        echo 'export PATH=/usr/local/cuda-12.8/bin${PATH:+:${PATH}}'
        echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.8/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}'
    } | sudo tee /etc/profile.d/cuda.sh >/dev/null
    source /etc/profile.d/cuda.sh
    echo "$PATH" | grep -q "/usr/local/cuda-12.8/bin" && log_message "CUDA PATH updated!" || log_message "CUDA PATH error!" >&2
    echo "$LD_LIBRARY_PATH" | grep -q "/usr/local/cuda-12.8/lib64" && log_message "CUDA LD_LIBRARY_PATH updated!" || log_message "CUDA LD_LIBRARY_PATH error!" >&2
}

check_install_cuda() {
    setup_cuda_env
    command -v nvcc &> /dev/null && log_message "CUDA already installed!" || {
        log_message "Installing CUDA..."
        curl -fsSL https://raw.githubusercontent.com/abhiag/CUDA/main/Cuda.sh | bash
        [ $? -eq 0 ] && log_message "CUDA installed." || log_message "CUDA installation failed!" >&2
    }
}

install_kuzco() {
    log_message "Installing Kuzco..."
    curl -fsSL https://inference.supply/install.sh | sh
    [ $? -eq 0 ] && log_message "Kuzco installed." || log_message "Kuzco installation failed!" >&2
}

start_worker() {
    log_message "Starting Kuzco worker in screen session '$SCREEN_NAME'..."
    screen -S "$SCREEN_NAME" -dm bash -c "
    while true; do
        sudo nohup kuzco worker start --worker \"$WORKER_ID\" --code \"$CODE\" 2>&1 | tee -a \"$LOG_FILE\"
        log_message \"Kuzco worker crashed! Restarting in 5 seconds...\"
        sleep 5
    done
    "
    log_message "Kuzco worker running in background."
}

check_kuzco_logs() {
    if screen -list | grep -q "$SCREEN_NAME"; then
        log_message "Attaching to Kuzco worker logs..."
        screen -r "$SCREEN_NAME"
    else
        log_message "No active Kuzco worker session found!"
    fi
}

setup_worker_node() {
    load_kuzco_config
    if [[ -z "$WORKER_ID" || -z "$CODE" ]]; then
        log_message "Error: Credentials not set."
        exit 1
    fi
    setup_timezone
    setup_cuda_env
    check_nvidia_gpu || exit 1
    command -v kuzco &> /dev/null || install_kuzco
    start_worker
}

check_dependencies() {
    command -v curl &> /dev/null || { log_message "Error: curl not installed."; exit 1; }
    command -v screen &> /dev/null || { log_message "Error: screen not installed."; exit 1; }
}

# Main (non-interactive): Option 2 then Option 5
check_dependencies
install_gpu_tools
setup_worker_node
check_kuzco_logs
