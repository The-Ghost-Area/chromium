#!/bin/bash

# Exit on any error
set -e

# Log function for debugging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Step 1: Check home directory permissions
log "Checking home directory permissions..."
HOME_DIR="$HOME"
if [ ! -w "$HOME_DIR" ]; then
    log "Error: Home directory $HOME_DIR is not writable"
    exit 1
fi
log "Home directory $HOME_DIR is writable"

# Step 2: Update and upgrade the system
log "Updating and upgrading system packages..."
sudo apt update -y && sudo apt upgrade -y

# Step 3: Remove any existing Docker-related packages
log "Removing existing Docker packages..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    sudo apt-get remove -y $pkg || true
done

# Step 4: Install prerequisites and add Docker's official GPG key
log "Installing prerequisites and Docker GPG key..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Step 5: Add Docker repository to APT sources
log "Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Step 6: Update and install Docker
log "Installing Docker..."
sudo apt update -y && sudo apt upgrade -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Step 7: Verify Docker installation
log "Checking Docker version..."
if ! docker --version; then
    log "Error: Docker installation failed"
    exit 1
fi

# Step 8: Automatically fetch timezone
log "Detecting server timezone..."
if [ -f /etc/localtime ]; then
    TZ=$(realpath --relative-to /usr/share/zoneinfo /etc/localtime 2>/dev/null || echo "UTC")
else
    TZ="UTC"
    log "Warning: /etc/localtime not found, defaulting to UTC"
fi
log "Detected timezone: $TZ"

# Step 9: Prompt for username and password
log "Prompting for username and password..."
read -p "Enter CUSTOM_USER for Chromium: " CUSTOM_USER
read -s -p "Enter PASSWORD for Chromium: " PASSWORD
echo

# Step 10: Set default ports
HTTP_PORT=3010
HTTPS_PORT=3011
log "Using default ports: HTTP=$HTTP_PORT, HTTPS=$HTTPS_PORT"

# Step 11: Create chromium directory and verify
log "Creating Chromium directory..."
CHROMIUM_DIR="$HOME/chromium"
if ! mkdir -p "$CHROMIUM_DIR"; then
    log "Error: Failed to create directory $CHROMIUM_DIR, trying /root/chromium as fallback"
    CHROMIUM_DIR="/root/chromium"
    if ! sudo mkdir -p "$CHROMIUM_DIR"; then
        log "Error: Failed to create fallback directory $CHROMIUM_DIR"
        exit 1
    fi
fi
if [ -d "$CHROMIUM_DIR" ]; then
    log "Directory $CHROMIUM_DIR created or already exists"
else
    log "Error: Directory $CHROMIUM_DIR does not exist after creation attempt"
    exit 1
fi
if ! cd "$CHROMIUM_DIR"; then
    log "Error: Failed to change to $CHROMIUM_DIR"
    exit 1
fi
log "Changed to directory: $(pwd)"

# Step 12: Create docker-compose.yaml and verify
log "Creating docker-compose.yaml..."
cat > docker-compose.yaml <<EOF
services:
  chromium:
    image: lscr.io/linuxserver/chromium:latest
    container_name: chromium
    security_opt:
      - seccomp:unconfined
    environment:
      - CUSTOM_USER=$CUSTOM_USER
      - PASSWORD=$PASSWORD
      - PUID=1000
      - PGID=1000
      - TZ=$TZ
      - CHROME_CLI=https://google.com
    volumes:
      - $CHROMIUM_DIR/config:/config
    ports:
      - "$HTTP_PORT:3000"
      - "$HTTPS_PORT:3001"
    shm_size: "1gb"
    restart: unless-stopped
EOF

if [ -f "$CHROMIUM_DIR/docker-compose.yaml" ]; then
    log "docker-compose.yaml created successfully in $CHROMIUM_DIR"
else
    log "Error: Failed to create docker-compose.yaml in $CHROMIUM_DIR"
    exit 1
fi

# Step 13: Create config directory for volumes
log "Creating config directory for Chromium..."
CONFIG_DIR="$CHROMIUM_DIR/config"
if ! mkdir -p "$CONFIG_DIR"; then
    log "Error: Failed to create config directory $CONFIG_DIR, trying with sudo"
    if ! sudo mkdir -p "$CONFIG_DIR"; then
        log "Error: Failed to create config directory $CONFIG_DIR with sudo"
        exit 1
    fi
fi
if [ -d "$CONFIG_DIR" ]; then
    log "Config directory $CONFIG_DIR created or already exists"
else
    log "Error: Config directory $CONFIG_DIR does not exist after creation attempt"
    exit 1
fi

# Step 14: Start the Chromium container
log "Starting Chromium container..."
if ! docker compose up -d; then
    log "Error: Failed to start Chromium container"
    exit 1
fi

# Step 15: Fetch public IP address
log "Fetching public IP address..."
PUBLIC_IP=$(curl -s ifconfig.me || echo "your-vps-ip")
if [ "$PUBLIC_IP" = "your-vps-ip" ]; then
    log "Warning: Failed to fetch public IP, using 'your-vps-ip' as placeholder"
fi
log "Public IP address: $PUBLIC_IP"

# Step 16: Display access information
log "Chromium container started successfully!"
echo "You can access Chromium at:"
echo "http://$PUBLIC_IP:$HTTP_PORT/"
echo "https://$PUBLIC_IP:$HTTPS_PORT/"
echo "Login with username: $CUSTOM_USER, password: [hidden for security]"
if [ "$PUBLIC_IP" = "your-vps-ip" ]; then
    echo "Note: Replace 'your-vps-ip' with your server's actual public IP address."
fi
