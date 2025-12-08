#!/bin/bash

# CyberITEX API Setup Script - Production Grade
# Version: 2.0.0
# Usage: ./cyberitex-setup.sh [username] [swap_size] [hostname]
# Example: ./cyberitex-setup.sh deploy 8G api-server-01

set -euo pipefail

########################################
# Configuration
########################################

readonly SCRIPT_NAME="CyberITEX API Setup"
readonly SCRIPT_VERSION="2.0.0"
readonly LOG_FILE="/var/log/cyberitex-setup.log"
readonly REPO_URL="https://github.com/CyberITEX/cyberitex-flask-api.git"
readonly REPO_BRANCH="main"

# Parse arguments with defaults
readonly CUSTOM_USER="${1:-root}"
readonly RAM_SIZE="${2:-8G}"
readonly HOSTNAME_OPTIONAL="${3:-}"

# Derived paths
if [[ "$CUSTOM_USER" == "root" ]]; then
    readonly APP_DIR="/opt/cyberitex-flask-api"
    readonly USER_HOME="/root"
else
    readonly APP_DIR="/home/$CUSTOM_USER/cyberitex-flask-api"
    readonly USER_HOME="/home/$CUSTOM_USER"
fi

# State tracking for cleanup
SETUP_PHASE="init"

########################################
# Logging & Error Handling
########################################

# Ensure log directory exists
sudo mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -ia "$LOG_FILE") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*"
}

log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $*" >&2
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2
}

error_exit() {
    log_error "$1"
    log_error "Setup failed during phase: $SETUP_PHASE"
    log_error "Check log file: $LOG_FILE"
    exit 1
}

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_warn "Script exited with code $exit_code during phase: $SETUP_PHASE"
        log_warn "System may be in a partially configured state"
    fi
}

trap cleanup EXIT

########################################
# Validation Functions
########################################

validate_inputs() {
    SETUP_PHASE="input_validation"
    log "Validating inputs"

    # Validate username (POSIX portable: lowercase, starts with letter/underscore)
    if [[ ! "$CUSTOM_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        error_exit "Invalid username '$CUSTOM_USER'. Must be lowercase alphanumeric, start with letter/underscore, max 32 chars"
    fi

    # Validate RAM size format (number followed by G or M)
    if [[ ! "$RAM_SIZE" =~ ^[0-9]+[GgMm]$ ]]; then
        error_exit "Invalid RAM size '$RAM_SIZE'. Expected format: 8G, 4G, 512M, etc."
    fi

    # Validate hostname if provided (RFC 1123 - supports both short names and FQDNs)
    if [[ -n "$HOSTNAME_OPTIONAL" ]]; then
        # Max 253 chars total, each label 1-63 chars, alphanumeric + hyphens, no leading/trailing hyphens
        local label_regex='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'
        local valid=true

        # Check total length
        if [[ ${#HOSTNAME_OPTIONAL} -gt 253 ]]; then
            valid=false
        fi

        # Check each label
        IFS='.' read -ra labels <<< "$HOSTNAME_OPTIONAL"
        for label in "${labels[@]}"; do
            if [[ ! "$label" =~ $label_regex ]]; then
                valid=false
                break
            fi
        done

        if [[ "$valid" != true ]]; then
            error_exit "Invalid hostname '$HOSTNAME_OPTIONAL'. Must be valid hostname or FQDN (e.g., 'server01' or 'api.example.com')"
        fi
    fi

    # Validate we can sudo
    if ! sudo -n true 2>/dev/null; then
        error_exit "This script requires sudo privileges. Run with a user that has passwordless sudo or enter password when prompted."
    fi

    log "Input validation passed"
}

validate_system_requirements() {
    SETUP_PHASE="system_requirements"
    log "Checking system requirements"

    # Check for Debian-based system
    if [[ ! -f /etc/debian_version ]]; then
        error_exit "This script requires a Debian-based system (Debian/Ubuntu)"
    fi

    # Check minimum disk space (2GB free)
    local free_space_kb
    free_space_kb=$(df / | awk 'NR==2 {print $4}')
    if [[ $free_space_kb -lt 2097152 ]]; then
        error_exit "Insufficient disk space. Need at least 2GB free, have $((free_space_kb / 1024))MB"
    fi

    # Check for required commands
    local required_cmds=("curl" "git")
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            log_warn "Required command '$cmd' not found, will be installed"
        fi
    done

    log "System requirements check passed"
}

########################################
# System Configuration Functions
########################################

setup_hostname() {
    SETUP_PHASE="hostname"

    if [[ -z "$HOSTNAME_OPTIONAL" ]]; then
        log "No hostname provided, skipping"
        return 0
    fi

    local current_hostname
    current_hostname=$(hostname)

    if [[ "$current_hostname" == "$HOSTNAME_OPTIONAL" ]]; then
        log "Hostname already set to '$HOSTNAME_OPTIONAL'"
        return 0
    fi

    log "Setting hostname to '$HOSTNAME_OPTIONAL'"
    sudo hostnamectl set-hostname "$HOSTNAME_OPTIONAL"

    # Extract short hostname (first label) for /etc/hosts
    local short_hostname="${HOSTNAME_OPTIONAL%%.*}"

    # Update /etc/hosts - remove old 127.0.1.1 entry and add new one
    sudo sed -i '/^127\.0\.1\.1/d' /etc/hosts

    # Add FQDN and short hostname (FQDN first per convention)
    if [[ "$HOSTNAME_OPTIONAL" == "$short_hostname" ]]; then
        # Short hostname only
        echo "127.0.1.1	$short_hostname" | sudo tee -a /etc/hosts > /dev/null
    else
        # FQDN with short hostname alias
        echo "127.0.1.1	$HOSTNAME_OPTIONAL $short_hostname" | sudo tee -a /etc/hosts > /dev/null
    fi

    log "Hostname configured: $HOSTNAME_OPTIONAL"
}

update_system() {
    SETUP_PHASE="system_update"
    log "Updating system packages"

    # Set non-interactive mode
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a

    # Preconfigure debconf
    echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections

    # Update package lists
    sudo apt-get update -y || error_exit "Failed to update package lists"

    # Upgrade packages
    sudo apt-get full-upgrade -y \
        -o Dpkg::Options::="--force-confnew" \
        -o Dpkg::Options::="--force-confdef" || error_exit "Failed to upgrade packages"

    # Install required packages
    local packages=(
        "linux-headers-$(uname -r)"
        "linux-image-$(uname -r)"
        python3
        python3-pip
        python3-venv
        redis-server
        curl
        git
        tree
        htop
    )

    sudo apt-get install -y "${packages[@]}" || error_exit "Failed to install required packages"

    # Clean up
    sudo apt-get autoremove -y
    sudo apt-get clean

    log "System update completed"
}

setup_swap() {
    SETUP_PHASE="swap"
    local swapfile="/swapfile"

    # Check if swap already exists and is active
    if swapon --show | grep -q "$swapfile"; then
        log "Swapfile already active, skipping"
        return 0
    fi

    # Check if swapfile exists but isn't active
    if [[ -f "$swapfile" ]]; then
        log "Swapfile exists, activating"
        sudo chmod 600 "$swapfile"
        sudo swapon "$swapfile" || log_warn "Failed to activate existing swapfile"
        return 0
    fi

    log "Creating ${RAM_SIZE} swapfile"

    # Create swapfile
    sudo fallocate -l "$RAM_SIZE" "$swapfile" || \
        sudo dd if=/dev/zero of="$swapfile" bs=1M count="${RAM_SIZE%[GgMm]}" status=progress

    sudo chmod 600 "$swapfile"
    sudo mkswap "$swapfile" || error_exit "Failed to create swap"
    sudo swapon "$swapfile" || error_exit "Failed to activate swap"

    # Add to fstab idempotently
    if ! grep -q "^$swapfile" /etc/fstab; then
        echo "$swapfile none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
    fi

    log "Swapfile created and activated"
}

configure_sysctl() {
    SETUP_PHASE="sysctl"
    log "Configuring kernel parameters"

    local sysctl_conf="/etc/sysctl.d/99-cyberitex.conf"

    # Create dedicated sysctl config (avoids polluting main sysctl.conf)
    sudo tee "$sysctl_conf" > /dev/null << 'EOF'
# CyberITEX API Server Tuning
# Generated by setup script

# Memory Management
vm.swappiness=10
vm.vfs_cache_pressure=75
vm.max_map_count=262144
vm.dirty_ratio=15
vm.dirty_background_ratio=5

# File System
fs.inotify.max_user_watches=524288
fs.file-max=2097152

# Network Buffers
net.core.rmem_default=262144
net.core.rmem_max=16777216
net.core.wmem_default=262144
net.core.wmem_max=16777216
net.core.somaxconn=65535
net.core.netdev_max_backlog=65535

# TCP Tuning
net.ipv4.tcp_rmem=4096 262144 16777216
net.ipv4.tcp_wmem=4096 262144 16777216
net.ipv4.tcp_max_syn_backlog=65535
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_tw_reuse=1
EOF

    # Apply settings
    sudo sysctl -p "$sysctl_conf" || log_warn "Some sysctl settings may not have applied"

    log "Kernel parameters configured"
}

########################################
# Service Setup Functions
########################################

setup_redis() {
    SETUP_PHASE="redis"
    log "Configuring Redis"

    # Enable and start Redis
    sudo systemctl enable redis-server
    sudo systemctl start redis-server

    # Configure Redis for persistence (idempotent using sed)
    local redis_conf="/etc/redis/redis.conf"

    if [[ -f "$redis_conf" ]]; then
        # Enable RDB persistence
        sudo sed -i \
            -e 's/^# save 900 1$/save 900 1/' \
            -e 's/^# save 300 10$/save 300 10/' \
            -e 's/^# save 60 10000$/save 60 10000/' \
            "$redis_conf"

        # Restart to apply changes
        sudo systemctl restart redis-server
    fi

    # Wait for Redis to be ready
    local retries=5
    while [[ $retries -gt 0 ]]; do
        if redis-cli ping 2>/dev/null | grep -q "PONG"; then
            log "Redis is running and responding"
            return 0
        fi
        retries=$((retries - 1))
        sleep 1
    done

    error_exit "Redis failed to start or respond"
}

########################################
# User & Application Setup
########################################

setup_user() {
    SETUP_PHASE="user"

    if [[ "$CUSTOM_USER" == "root" ]]; then
        log "Using root account, no user creation required"
        return 0
    fi

    if id "$CUSTOM_USER" &>/dev/null; then
        log "User '$CUSTOM_USER' already exists"
    else
        log "Creating user '$CUSTOM_USER'"
        sudo useradd -m -s /bin/bash "$CUSTOM_USER" || error_exit "Failed to create user"
        sudo usermod -aG sudo "$CUSTOM_USER"
    fi

    # Configure passwordless sudo (required for service account)
    local sudoers_file="/etc/sudoers.d/$CUSTOM_USER"
    if [[ ! -f "$sudoers_file" ]]; then
        log "Configuring passwordless sudo for '$CUSTOM_USER'"
        echo "$CUSTOM_USER ALL=(ALL) NOPASSWD: ALL" | sudo tee "$sudoers_file" > /dev/null
        sudo chmod 440 "$sudoers_file"
        
        # Validate sudoers syntax
        if ! sudo visudo -c -f "$sudoers_file" &>/dev/null; then
            sudo rm -f "$sudoers_file"
            error_exit "Failed to configure sudo - invalid syntax"
        fi
    fi

    # Ensure home directory exists and has correct permissions
    sudo mkdir -p "$USER_HOME"
    sudo chown "$CUSTOM_USER:$CUSTOM_USER" "$USER_HOME"
    sudo chmod 750 "$USER_HOME"
}

setup_application() {
    SETUP_PHASE="application"
    log "Setting up Flask application"

    # Create parent directory if needed
    sudo mkdir -p "$(dirname "$APP_DIR")"

    if [[ "$CUSTOM_USER" != "root" ]]; then
        sudo chown "$CUSTOM_USER:$CUSTOM_USER" "$(dirname "$APP_DIR")"
    fi

    # Clone or update repository (as target user, not root)
    if [[ ! -d "$APP_DIR/.git" ]]; then
        log "Cloning repository from $REPO_URL"

        if [[ "$CUSTOM_USER" == "root" ]]; then
            git clone --branch "$REPO_BRANCH" "$REPO_URL" "$APP_DIR" || \
                error_exit "Failed to clone repository"
        else
            sudo -u "$CUSTOM_USER" git clone --branch "$REPO_BRANCH" "$REPO_URL" "$APP_DIR" || \
                error_exit "Failed to clone repository"
        fi
    else
        log "Updating existing repository"

        if [[ "$CUSTOM_USER" == "root" ]]; then
            git -C "$APP_DIR" fetch origin
            git -C "$APP_DIR" reset --hard "origin/$REPO_BRANCH"
        else
            sudo -u "$CUSTOM_USER" git -C "$APP_DIR" fetch origin
            sudo -u "$CUSTOM_USER" git -C "$APP_DIR" reset --hard "origin/$REPO_BRANCH"
        fi
    fi

    # Setup environment file
    if [[ -f "$APP_DIR/example.env" && ! -f "$APP_DIR/.env" ]]; then
        log "Creating .env from example.env"
        if [[ "$CUSTOM_USER" == "root" ]]; then
            cp "$APP_DIR/example.env" "$APP_DIR/.env"
        else
            sudo -u "$CUSTOM_USER" cp "$APP_DIR/example.env" "$APP_DIR/.env"
        fi
        chmod 600 "$APP_DIR/.env"
    elif [[ -f "$APP_DIR/.env" ]]; then
        log ".env file already exists, preserving"
    else
        log_warn "No example.env found, .env must be created manually"
    fi

    log "Application setup completed"
}

setup_python_env() {
    SETUP_PHASE="python_env"
    log "Setting up Python virtual environment"

    local venv_path="$APP_DIR/venv"
    local pip_path="$venv_path/bin/pip"
    local requirements_file="$APP_DIR/requirements.txt"

    # Create virtual environment if it doesn't exist
    if [[ ! -d "$venv_path" ]]; then
        log "Creating virtual environment"

        if [[ "$CUSTOM_USER" == "root" ]]; then
            python3 -m venv "$venv_path" || error_exit "Failed to create virtual environment"
        else
            sudo -u "$CUSTOM_USER" python3 -m venv "$venv_path" || error_exit "Failed to create virtual environment"
        fi
    fi

    # Verify venv was created
    [[ ! -f "$pip_path" ]] && error_exit "Virtual environment creation failed - pip not found"

    # Upgrade pip and install requirements (using pip directly, no activation needed)
    log "Installing Python dependencies"

    if [[ "$CUSTOM_USER" == "root" ]]; then
        "$pip_path" install --upgrade pip setuptools wheel
        [[ -f "$requirements_file" ]] && "$pip_path" install -r "$requirements_file"
    else
        sudo -u "$CUSTOM_USER" "$pip_path" install --upgrade pip setuptools wheel
        [[ -f "$requirements_file" ]] && sudo -u "$CUSTOM_USER" "$pip_path" install -r "$requirements_file"
    fi

    log "Python environment setup completed"
}

setup_services() {
    SETUP_PHASE="services"
    log "Setting up systemd services"

    local services_dir="$APP_DIR/services"

    if [[ ! -d "$services_dir" ]]; then
        log_warn "Services directory not found at '$services_dir', skipping service setup"
        return 0
    fi

    local services=("api" "celery")

    for service in "${services[@]}"; do
        local src_file="$services_dir/${service}.service"
        local dest_file="/etc/systemd/system/${service}.service"

        if [[ ! -f "$src_file" ]]; then
            log_warn "Service file '$src_file' not found, skipping"
            continue
        fi

        log "Installing ${service}.service"

        # Copy and configure service file
        sudo cp "$src_file" "$dest_file"

        # Update User directive
        sudo sed -i "s/^User=.*/User=$CUSTOM_USER/" "$dest_file"

        # Update WorkingDirectory
        sudo sed -i "s|^WorkingDirectory=.*|WorkingDirectory=$APP_DIR|" "$dest_file"

        # Update ExecStart paths if they reference the app directory
        sudo sed -i "s|/opt/cyberitex-flask-api|$APP_DIR|g" "$dest_file"
        sudo sed -i "s|/home/[^/]*/cyberitex-flask-api|$APP_DIR|g" "$dest_file"

        sudo chmod 644 "$dest_file"
    done

    # Reload systemd
    sudo systemctl daemon-reload

    # Enable and start services
    for service in "${services[@]}"; do
        local dest_file="/etc/systemd/system/${service}.service"

        if [[ ! -f "$dest_file" ]]; then
            continue
        fi

        sudo systemctl enable "${service}.service"
        sudo systemctl restart "${service}.service"

        # Verify service started
        sleep 2
        if sudo systemctl is-active --quiet "${service}.service"; then
            log "${service}.service is running"
        else
            log_warn "${service}.service failed to start. Check: sudo journalctl -u ${service}.service"
        fi
    done

    log "Service setup completed"
}

########################################
# Shell Configuration
########################################

setup_shell_config() {
    SETUP_PHASE="shell_config"
    log "Setting up shell configuration for $CUSTOM_USER"

    local bashrc="$USER_HOME/.bashrc"
    local venv_activate="$APP_DIR/venv/bin/activate"

    # Ensure bashrc exists
    if [[ ! -f "$bashrc" ]]; then
        sudo touch "$bashrc"
        sudo chown "$CUSTOM_USER:$CUSTOM_USER" "$bashrc"
    fi

    # Add CyberITEX aliases block (idempotent)
    if ! grep -q "# CyberITEX Aliases" "$bashrc" 2>/dev/null; then
        sudo tee -a "$bashrc" > /dev/null << EOF

# CyberITEX Aliases
alias dfh='df -h | grep -E "^/dev/|^Filesystem" | grep -v docker | grep -v "/boot"'
alias sourcep='source $venv_activate'
alias cdapp='cd $APP_DIR'
alias logs-api='sudo journalctl -u api.service -f'
alias logs-celery='sudo journalctl -u celery.service -f'
alias restart-api='sudo systemctl restart api.service'
alias restart-celery='sudo systemctl restart celery.service'
alias status='sudo systemctl status api.service celery.service redis-server'
EOF
    fi

    sudo chown "$CUSTOM_USER:$CUSTOM_USER" "$bashrc"

    log "Shell configuration completed"
}

########################################
# Verification
########################################

verify_installation() {
    SETUP_PHASE="verification"
    log "Verifying installation"

    local errors=0

    # Check Redis
    if ! redis-cli ping 2>/dev/null | grep -q "PONG"; then
        log_error "Redis is not responding"
        ((errors++))
    fi

    # Check application directory
    if [[ ! -d "$APP_DIR" ]]; then
        log_error "Application directory not found: $APP_DIR"
        ((errors++))
    fi

    # Check virtual environment
    if [[ ! -f "$APP_DIR/venv/bin/python" ]]; then
        log_error "Python virtual environment not found"
        ((errors++))
    fi

    # Check .env file
    if [[ ! -f "$APP_DIR/.env" ]]; then
        log_warn ".env file not found - application may not start correctly"
    fi

    # Check services
    for service in api celery; do
        if [[ -f "/etc/systemd/system/${service}.service" ]]; then
            if ! sudo systemctl is-active --quiet "${service}.service"; then
                log_warn "${service}.service is not running"
            fi
        fi
    done

    if [[ $errors -gt 0 ]]; then
        log_error "Installation verification found $errors error(s)"
        return 1
    fi

    log "Installation verification passed"
    return 0
}

print_summary() {
    log ""
    log "=========================================="
    log "  $SCRIPT_NAME v$SCRIPT_VERSION"
    log "  Installation Complete"
    log "=========================================="
    log ""
    log "Configuration:"
    log "  User:        $CUSTOM_USER"
    log "  App Dir:     $APP_DIR"
    log "  Swap Size:   $RAM_SIZE"
    log "  Hostname:    ${HOSTNAME_OPTIONAL:-$(hostname)}"
    log ""
    log "Services:"
    sudo systemctl status api.service celery.service redis-server --no-pager -l 2>/dev/null | head -30 || true
    log ""
    log "Quick Commands:"
    log "  sourcep       - Activate Python venv"
    log "  cdapp         - Go to app directory"
    log "  status        - Check all services"
    log "  logs-api      - Follow API logs"
    log "  logs-celery   - Follow Celery logs"
    log ""
    log "Log file: $LOG_FILE"
    log "=========================================="
}

########################################
# Main Execution
########################################

main() {
    log "Starting $SCRIPT_NAME v$SCRIPT_VERSION"
    log "Parameters: USER=$CUSTOM_USER, RAM=$RAM_SIZE, HOSTNAME=${HOSTNAME_OPTIONAL:-<not set>}"
    log ""

    # Phase 1: Validation
    validate_inputs
    validate_system_requirements

    # Phase 2: System Configuration (before services)
    setup_hostname
    update_system
    setup_swap
    configure_sysctl

    # Phase 3: User Setup
    setup_user

    # Phase 4: Services & Application
    setup_redis
    setup_application
    setup_python_env
    setup_services

    # Phase 5: Finalization
    setup_shell_config
    verify_installation

    # Summary
    print_summary

    log "$SCRIPT_NAME completed successfully"
}

# Execute main
main "$@"