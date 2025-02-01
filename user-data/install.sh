#!/bin/bash

exec > >(tee -i /var/log/cyberitex-setup.log) 2>&1
echo "Starting CyberITEX API Setup Script..."

########################################
# Parse Script Arguments
########################################
CUSTOM_USER=${1:-ubuntu}   # First argument, defaults to 'ubuntu' if not provided
RAM_SIZE=${2:-8G}          # Second argument, defaults to '8G' if not provided
HOSTNAME_OPTIONAL=$3       # Third argument, optional

########################################
# (Optional) Set System Hostname
########################################
if [ -n "$HOSTNAME_OPTIONAL" ]; then
    echo "Setting hostname to '$HOSTNAME_OPTIONAL'..."
    sudo hostnamectl set-hostname "$HOSTNAME_OPTIONAL"
else
    echo "No hostname provided. Skipping hostname configuration."
fi

echo "Using CUSTOM_USER=${CUSTOM_USER}, RAM_SIZE=${RAM_SIZE}, HOSTNAME=${HOSTNAME_OPTIONAL}"

########################################
# Update and Upgrade System Packages
########################################
sudo debconf-set-selections <<< 'debconf debconf/frontend select Noninteractive'
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

sudo apt-get update -y
sudo apt-get full-upgrade -y -o Dpkg::Options::="--force-confnew" -o Dpkg::Options::="--force-confdef"
sudo apt-get install -y linux-headers-$(uname -r) linux-image-$(uname -r)

########################################
# Install Required System Packages
########################################
sudo apt-get install -y python3 python3-pip python3-venv redis-server curl git tree

########################################
# Enable and Configure Redis
########################################
sudo systemctl enable redis-server
sudo systemctl start redis-server
sudo systemctl is-enabled redis-server

# Enable Redis persistence
sudo sed -i 's/^# save 900 1/save 900 1/' /etc/redis/redis.conf
sudo sed -i 's/^# save 300 10/save 300 10/' /etc/redis/redis.conf
sudo sed -i 's/^# save 60 10000/save 60 10000/' /etc/redis/redis.conf
sudo systemctl restart redis-server

########################################
# Set Up Swapfile with Optional RAM Size
########################################
SWAPFILE="/swapfile"

if [ ! -f "$SWAPFILE" ]; then
    echo "Creating swapfile of size $RAM_SIZE..."
    sudo fallocate -l $RAM_SIZE $SWAPFILE
    sudo chmod 600 $SWAPFILE
    sudo mkswap $SWAPFILE
    sudo swapon $SWAPFILE
    echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab
else
    echo "Swapfile already exists. Skipping creation."
fi

# Make swap permanent
sudo cp /etc/fstab /etc/fstab.bak
grep -q "$SWAPFILE" /etc/fstab || echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab

# Adjust swappiness and system configurations
sudo sysctl vm.swappiness=10
CONFIG_FILE="/etc/sysctl.conf"
CONFIG_LINES=(
    "vm.swappiness=10"
    "vm.vfs_cache_pressure=754"
    "vm.max_map_count=262144"
    "fs.inotify.max_user_watches=524288"
)

for line in "${CONFIG_LINES[@]}"; do
    if ! grep -q "^$line" "$CONFIG_FILE"; then
        echo "$line" | sudo tee -a "$CONFIG_FILE" > /dev/null
    fi
done

########################################
# Check or Create the Custom User
########################################
if ! id "$CUSTOM_USER" &>/dev/null; then
    echo "Creating user '$CUSTOM_USER'..."
    sudo useradd -m -s /bin/bash "$CUSTOM_USER"
    echo "User '$CUSTOM_USER' created successfully."

    # Add user to sudo group
    sudo usermod -aG sudo "$CUSTOM_USER"
    echo "User '$CUSTOM_USER' has been added to the sudo group."
else
    echo "User '$CUSTOM_USER' already exists."
fi

########################################
# Configure Git for First-Time Use
########################################
git config --global user.name "CyberITEX"
git config --global user.email "support@cyberitex.com"

########################################
# Set Up the Flask App
########################################
APP_DIR="/opt/cyberitex-flask-api"
REPO_URL="https://github.com/CyberITEX/cyberitex-flask-api.git"

# Clone the Flask app repository if it doesn't exist
if [ ! -d "$APP_DIR/.git" ]; then
    echo "Cloning repository from $REPO_URL..."
    sudo git clone "$REPO_URL" "$APP_DIR"
    sudo chown -R "$CUSTOM_USER":"$CUSTOM_USER" "$APP_DIR"
else
    echo "Repository already exists. Pulling latest changes..."
    cd "$APP_DIR"
    sudo git pull origin main
fi

# Rename example.env to .env if it exists
if [ -f "$APP_DIR/example.env" ]; then
    echo "Renaming example.env to .env..."
    sudo mv "$APP_DIR/example.env" "$APP_DIR/.env"
    sudo chown "$CUSTOM_USER":"$CUSTOM_USER" "$APP_DIR/.env"
else
    echo "Warning: example.env not found. Skipping rename."
fi

# Change to the application directory
cd "$APP_DIR"

########################################
# Set Up Python Virtual Environment
########################################
python3 -m venv venv
source venv/bin/activate

if [[ -z "$VIRTUAL_ENV" ]]; then
    echo "Error: Virtual environment activation failed!"
    exit 1
fi

sudo chown -R "$CUSTOM_USER":"$CUSTOM_USER" "$APP_DIR/venv"
pip install --upgrade pip
pip install -r requirements.txt
deactivate

########################################
# Configure and Enable Systemd Services
########################################
SERVICES_DIR="$APP_DIR/services"
TARGET_DIR="/etc/systemd/system"

if [ ! -d "$SERVICES_DIR" ]; then
    echo "Error: Services directory '$SERVICES_DIR' not found!"
    exit 1
fi

# Copy service files to systemd directory
echo "Copying service files to $TARGET_DIR..."
sudo cp "$SERVICES_DIR/api.service" "$TARGET_DIR/api.service"
sudo cp "$SERVICES_DIR/celery.service" "$TARGET_DIR/celery.service"

# Update the 'User' field to the custom username
echo "Updating service files to use user '$CUSTOM_USER'..."
sudo sed -i "s/User=root/User=$CUSTOM_USER/" "$TARGET_DIR/api.service"
sudo sed -i "s/User=root/User=$CUSTOM_USER/" "$TARGET_DIR/celery.service"

# Set appropriate permissions
sudo chmod 644 "$TARGET_DIR/api.service"
sudo chmod 644 "$TARGET_DIR/celery.service"

# Reload systemd, enable, and start services
sudo systemctl daemon-reload
sudo systemctl enable api.service
sudo systemctl enable celery.service

########################################
# Validate Redis and Start Services
########################################
if redis-cli ping | grep -q "PONG"; then
    echo "Redis is running."
else
    echo "Error: Redis failed to start!"
    exit 1
fi

sudo systemctl start api.service
sudo systemctl start celery.service

# Verify services are active
if sudo systemctl is-active --quiet api.service; then
    echo "API service is running."
else
    echo "API service failed to start."
fi

if sudo systemctl is-active --quiet celery.service; then
    echo "Celery service is running."
else
    echo "Celery service failed to start."
fi

echo "CyberITEX API Setup Script completed!"
