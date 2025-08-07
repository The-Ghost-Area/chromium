#!/bin/bash

# Simple Chromium Docker Setup Script (No Proxy)
# Easy installation without complications

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Banner
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           Simple Chromium Docker Setup Script               ║"
echo "║                   No Proxy Required                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Get user input
echo
read -p "Enter username for Chromium: " CUSTOM_USER
read -s -p "Enter password for Chromium: " PASSWORD
echo
read -p "Enter HTTP port [default: 3010]: " HTTP_PORT
HTTP_PORT=${HTTP_PORT:-3010}
read -p "Enter HTTPS port [default: 3011]: " HTTPS_PORT  
HTTPS_PORT=${HTTPS_PORT:-3011}

# Get timezone
print_info "Detecting timezone..."
if [ -f /etc/localtime ]; then
    TZ=$(realpath --relative-to /usr/share/zoneinfo /etc/localtime 2>/dev/null || echo "UTC")
else
    TZ="UTC"
fi
print_info "Using timezone: $TZ"

# Update system
print_info "Updating system..."
sudo apt update -y && sudo apt upgrade -y

# Remove old Docker packages
print_info "Removing old Docker packages..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do 
    sudo apt-get remove -y $pkg 2>/dev/null || true
done

# Install prerequisites
print_info "Installing prerequisites..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# Add Docker repository
print_info "Setting up Docker repository..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
print_info "Installing Docker..."
sudo apt update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start Docker service
print_info "Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group (if not root)
if [ "$EUID" -ne 0 ]; then
    print_info "Adding user to docker group..."
    sudo usermod -aG docker $USER
    print_warning "You may need to logout and login again for docker group to take effect"
fi

# Create chromium directory
print_info "Creating chromium directory..."
mkdir -p $HOME/chromium
cd $HOME/chromium

# Create docker-compose.yaml
print_info "Creating docker-compose.yaml..."
cat > docker-compose.yaml <<EOF
version: '3.8'

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
      - $HOME/chromium/config:/config
    ports:
      - "$HTTP_PORT:3000"
      - "$HTTPS_PORT:3001"
    shm_size: "1gb"
    restart: unless-stopped
EOF

# Start the container
print_info "Starting Chromium container..."
if [ "$EUID" -ne 0 ] && ! groups | grep -q docker; then
    print_info "Using sudo for docker commands..."
    sudo docker compose up -d
else
    docker compose up -d
fi

# Get server IP
print_info "Getting server IP..."
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')

# Show results
echo
print_success "Chromium installation completed!"
echo
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    🎉 INSTALLATION SUCCESSFUL! 🎉                    ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║                         Access URLs:                                ║${NC}"
echo -e "${GREEN}║                                                                      ║${NC}"
echo -e "${GREEN}║ HTTP:  ${NC}http://$SERVER_IP:$HTTP_PORT${GREEN}                                    ║${NC}"
echo -e "${GREEN}║ HTTPS: ${NC}https://$SERVER_IP:$HTTPS_PORT${GREEN}                                   ║${NC}"
echo -e "${GREEN}║                                                                      ║${NC}"
echo -e "${GREEN}║ Username: ${NC}$CUSTOM_USER${GREEN}                                              ║${NC}"
echo -e "${GREEN}║ Password: ${NC}[Your Password]${GREEN}                                         ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║                      Management Commands:                            ║${NC}"
echo -e "${GREEN}║                                                                      ║${NC}"
echo -e "${GREEN}║ Start:    docker compose up -d                                      ║${NC}"
echo -e "${GREEN}║ Stop:     docker compose down                                       ║${NC}"
echo -e "${GREEN}║ Restart:  docker compose restart                                    ║${NC}"
echo -e "${GREEN}║ Logs:     docker compose logs -f                                    ║${NC}"
echo -e "${GREEN}║                                                                      ║${NC}"
echo -e "${GREEN}║ Directory: $HOME/chromium                                    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo

print_info "Wait 1-2 minutes for Chromium to fully load, then access via browser!"
print_info "All commands should be run from: $HOME/chromium"

echo -e "${YELLOW}Note: If you can't access externally, check your firewall settings.${NC}"
