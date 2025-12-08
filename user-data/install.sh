#!/bin/bash

# CyberITEX API Setup Script - Simplified Version
set -euo pipefail  # Exit on error, undefined vars, pipe failures

########################################
# Configuration
########################################

readonly SCRIPT_NAME="CyberITEX API Setup"
readonly LOG_FILE="/var/log/cyberitex-setup.log"
readonly REPO_URL="https://github.com/CyberITEX/cyberitex-flask-api.git"

# Parse arguments with defaults
readonly CUSTOM_USER="${1:-root}"
readonly RAM_SIZE="${2:-8G}"
readonly HOSTNAME_OPTIONAL="${3:-}"

# Application directory per user
if [[ "$CUSTOM_USER" == "root" ]]; then
    APP_DIR="/opt/cyberitex-flask-api"
    USER_HOME="/root"
else
    APP_DIR="/home/$CUSTOM_USER/cyberitex-flask-api"
    USER_HOME="/home/$CUSTOM_USER"
fi
readonly APP_DIR
readonly USER_HOME

# Logging setup
exec > >(tee -i "$LOG_FILE") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

check_root() {
    [[ $EUID -eq 0 ]] && error_exit "Do not run this script as root"
}

########################################
# Main Functions
########################################

setup_hostname() {
    if [[ -n "$HOSTNAME_OPTIONAL" ]]; then
        log "Setting hostname to '$HOSTNAME_OPTIONAL'"
        sudo hostnamectl set-hostname "$HOSTNAME_OPTIONAL"
    else
        log "No hostname provided, skipping"
    fi
}

update_system() {
    log "Updating system packages"

    # Set non-interactive mode
    sudo debconf-set-selections <<< 'debconf debconf/frontend select Noninteractive'
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a

    sudo apt-get update -y
    sudo apt-get full-upgrade -y -o Dpkg::Options::="--force-confnew" -o Dpkg::Options::="--force-confdef"
    sudo apt-get install -y \
        linux-headers-$(uname -r) \
        linux-image-$(uname -r) \
        python3 python3-pip python3-venv \
        redis-server curl git tree
}

setup_redis() {
    log "Configuring Redis"

    sudo systemctl enable redis-server
    sudo systemctl start redis-server

    # Enable Redis persistence
    sudo sed -i -e 's/^# save 900 1/save 900 1/' \
                -e 's/^# save 300 10/save 300 10/' \
                -e 's/^# save 60 10000/save 60 10000/' \
                /etc/redis/redis.conf

    sudo systemctl restart redis-server

    # Verify Redis is working
    redis-cli ping | grep -q "PONG" || error_exit "Redis failed to start"
}

setup_swap() {
    local swapfile="/swapfile"

    if [[ -f "$swapfile" ]]; then
        log "Swapfile already exists, skipping creation"
        return
    fi

    log "Creating ${RAM_SIZE} swapfile"
    sudo fallocate -l "$RAM_SIZE" "$swapfile"
    sudo chmod 600 "$swapfile"
    sudo mkswap "$swapfile"
    sudo swapon "$swapfile"

    # Add to fstab if not already present
    grep -q "$swapfile" /etc/fstab || echo "$swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
}

configure_system() {
    log "Configuring system parameters"

    # Set swappiness
    sudo sysctl vm.swappiness=10

    # Update sysctl.conf
    local config_lines=(
        "vm.swappiness=10"
        "vm.vfs_cache_pressure=754"
        "vm.max_map_count=262144"
        "vm.dirty_ratio=15"
        "vm.dirty_background_ratio=5"
        "fs.inotify.max_user_watches=524288"
    )

    for line in "${config_lines[@]}"; do
        grep -q "^$line" /etc/sysctl.conf || echo "$line" | sudo tee -a /etc/sysctl.conf > /dev/null
    done
}

configure_network() {
    log "Configuring network parameters"
    echo "net.core.rmem_default=262144" | sudo tee -a /etc/sysctl.conf
    echo "net.core.rmem_max=16777216" | sudo tee -a /etc/sysctl.conf
    echo "net.core.wmem_default=262144" | sudo tee -a /etc/sysctl.conf
    echo "net.core.wmem_max=16777216" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
}

setup_user() {
    if [[ "$CUSTOM_USER" == "root" ]]; then
        log "Using root account; no user creation required"
        return
    fi

    if id "$CUSTOM_USER" &>/dev/null; then
        log "User '$CUSTOM_USER' already exists"
        return
    fi

    log "Creating user '$CUSTOM_USER'"
    sudo useradd -m -s /bin/bash "$CUSTOM_USER"
    sudo usermod -aG sudo "$CUSTOM_USER"
}

setup_git() {
    log "Configuring Git"
    git config --global user.name "CyberITEX"
    git config --global user.email "support@cyberitex.com"
}

setup_application() {
    log "Setting up Flask application"

    # Ensure application directory exists and is owned by CUSTOM_USER/root
    sudo mkdir -p "$APP_DIR"
    sudo chown -R "$CUSTOM_USER:$CUSTOM_USER" "$APP_DIR"

    # Clone or update repository
    if [[ ! -d "$APP_DIR/.git" ]]; then
        log "Cloning repository from $REPO_URL"
        sudo git clone "$REPO_URL" "$APP_DIR"
    else
        log "Updating existing repository"
        cd "$APP_DIR"
        sudo git pull origin main
    fi

    sudo chown -R "$CUSTOM_USER:$CUSTOM_USER" "$APP_DIR"

    # Handle environment file
    if [[ -f "$APP_DIR/example.env" ]]; then
        log "Setting up environment file"
        sudo mv "$APP_DIR/example.env" "$APP_DIR/.env"
        sudo chown "$CUSTOM_USER:$CUSTOM_USER" "$APP_DIR/.env"
    fi
}

setup_python_env() {
    log "Setting up Python virtual environment"

    cd "$APP_DIR"
    python3 -m venv venv
    # shellcheck disable=SC1091
    source venv/bin/activate

    [[ -z "${VIRTUAL_ENV:-}" ]] && error_exit "Virtual environment activation failed"

    pip install --upgrade pip
    pip install -r requirements.txt
    deactivate

    sudo chown -R "$CUSTOM_USER:$CUSTOM_USER" "$APP_DIR/venv"
}

setup_services() {
    log "Setting up systemd services"

    local services_dir="$APP_DIR/services"
    [[ ! -d "$services_dir" ]] && error_exit "Services directory '$services_dir' not found"

    # Copy and configure service files
    for service in api celery; do
        sudo cp "$services_dir/${service}.service" "/etc/systemd/system/"
        sudo sed -i "s/User=root/User=$CUSTOM_USER/" "/etc/systemd/system/${service}.service"
        sudo sed -i "s|WorkingDirectory=.*|WorkingDirectory=$APP_DIR|" "/etc/systemd/system/${service}.service" || true
        sudo chmod 644 "/etc/systemd/system/${service}.service"
    done

    # Enable and start services
    sudo systemctl daemon-reload
    sudo systemctl enable api.service celery.service
    sudo systemctl start api.service celery.service

    # Verify services
    for service in api celery; do
        if sudo systemctl is-active --quiet "${service}.service"; then
            log "$service service is running"
        else
            log "WARNING: $service service failed to start"
        fi
    done
}

setup_aliases() {
    log "Setting up shell aliases for $CUSTOM_USER"

    local bashrc="$USER_HOME/.bashrc"
    local venv_path="$APP_DIR/venv/bin/activate"

    # Ensure bashrc exists
    if [[ ! -f "$bashrc" ]]; then
        sudo touch "$bashrc"
        sudo chown "$CUSTOM_USER:$CUSTOM_USER" "$bashrc"
    fi

    # Add dfh alias (simplified version)
    if ! grep -q "^alias dfh=" "$bashrc" 2>/dev/null; then
        sudo bash -c "cat << 'EOF' >> '$bashrc'
# Show disk usage for main filesystems (exclude boot partitions)
alias dfh='df -h | grep -E \"^/dev/|^Filesystem\" | grep -v docker | grep -v \"/boot\"'
EOF"
    fi

    # Add sourcep alias
    if ! grep -q "alias sourcep=" "$bashrc" 2>/dev/null; then
        sudo bash -c "echo \"alias sourcep='source $venv_path'\" >> '$bashrc'"
    fi

    sudo chown "$CUSTOM_USER:$CUSTOM_USER" "$bashrc"
}

########################################
# Main Execution
########################################

main() {
    log "Starting $SCRIPT_NAME"
    log "Parameters: USER=$CUSTOM_USER, RAM=$RAM_SIZE, HOSTNAME=${HOSTNAME_OPTIONAL:-none}"

    # check_root  # intentionally not used to allow running as root with sudo inside

    setup_hostname
    update_system
    setup_redis
    setup_swap
    configure_system
    setup_user
    setup_git
    setup_application
    setup_python_env
    setup_services
    setup_aliases
    configure_network

    log "$SCRIPT_NAME completed successfully!"
    log "Services status:"
    sudo systemctl status api.service celery.service --no-pager -l || true
}

# Run main function
main "$@"
