#!/bin/bash

# Chromium Docker Setup Script
# Following the exact guide provided

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Functions
print_step() {
    echo -e "${BLUE}🔹 $1${NC}"
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Banner
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                  🌐 Chromium in Docker Guide 🌐                   ║"
echo "║        Browser accessible via HTTPS on custom port               ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo
print_warning "Make sure to open ports 3010 and 3011 in your VPS firewall!"
print_info "For Google Cloud: VPC Network > Firewall rules > Create rule"
echo

# Get user input
print_step "Getting Configuration"
read -p "Enter username for Chromium: " CUSTOM_USER
read -s -p "Enter password for Chromium: " PASSWORD
echo
echo

# Step 1: Install Docker (Official Method)
print_step "Step 1: Installing Docker (Official Method)"

print_info "Updating system..."
sudo apt update && sudo apt upgrade -y

print_info "Removing old Docker versions..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do 
    sudo apt-get remove -y $pkg 2>/dev/null || true
done

print_info "Installing dependencies..."
sudo apt-get install -y ca-certificates curl gnupg

print_info "Adding Docker GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

print_info "Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

print_info "Installing Docker Engine and plugins..."
sudo apt update -y && sudo apt install -y \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

print_success "Docker installation completed!"

# Step 2: Check timezone
print_step "Step 2: Checking Timezone"
TZ=$(realpath --relative-to /usr/share/zoneinfo /etc/localtime 2>/dev/null || echo "UTC")
print_info "Detected timezone: $TZ"

# Step 3: Fix Docker permissions
print_step "Step 3: Fixing Docker Permissions"
print_info "Adding user to docker group..."
sudo usermod -aG docker $USER
print_warning "You may need to restart your VPS or run 'newgrp docker'"

# Step 4: Set up Chromium folder
print_step "Step 4: Setting Up Chromium Folder"
print_info "Creating chromium directory..."
mkdir -p chromium
cd chromium
print_success "Created and entered chromium directory"

# Step 5: Create docker-compose.yaml
print_step "Step 5: Creating docker-compose.yaml"
print_info "Creating configuration file..."

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
      - CHROME_CLI=about:blank
    volumes:
      - /root/chromium/config:/config
    ports:
      - "3011:3001"  # HTTPS only
    shm_size: "2gb"
    restart: unless-stopped
EOF

print_success "docker-compose.yaml created successfully!"

# Step 6: Start Chromium
print_step "Step 6: Starting Chromium"
print_info "Starting Chromium container..."

# Try without sudo first, then with sudo if needed
if docker compose up -d 2>/dev/null; then
    print_success "Container started successfully!"
else
    print_info "Trying with sudo..."
    sudo docker compose up -d
    print_success "Container started with sudo!"
fi

# Get server IP
print_info "Getting server IP address..."
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}' 2>/dev/null || echo "your-vps-ip")

# Final results
echo
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                    🎉 SETUP COMPLETED! 🎉                         ║"
echo "╠═══════════════════════════════════════════════════════════════════╣"
echo "║                                                                   ║"
echo -e "║  🌐 Access URL: ${CYAN}https://$SERVER_IP:3011/${GREEN}                    ║"
echo "║                                                                   ║"
echo -e "║  👤 Username: ${YELLOW}$CUSTOM_USER${GREEN}                                        ║"
echo -e "║  🔒 Password: ${YELLOW}[Your Password]${GREEN}                                ║"
echo "║                                                                   ║"
echo "╠═══════════════════════════════════════════════════════════════════╣"
echo "║                    📋 Management Commands                         ║"
echo "╠═══════════════════════════════════════════════════════════════════╣"
echo "║  Start:    docker compose up -d                                  ║"
echo "║  Stop:     docker compose down                                   ║"
echo "║  Restart:  docker compose restart                               ║"
echo "║  Logs:     docker compose logs -f                               ║"
echo "║  Status:   docker compose ps                                     ║"
echo "║                                                                   ║"
echo "║  Directory: $(pwd)                                        ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo
print_info "🕐 Wait 1-2 minutes for Chromium to fully load"
print_warning "🔥 Make sure port 3011 is open in your firewall!"
echo
print_success "🚀 Ready! Open your browser and go to: https://$SERVER_IP:3011/"

echo
echo -e "${YELLOW}📝 Optional: To stop and remove Chromium:${NC}"
echo -e "${CYAN}   docker stop chromium${NC}"
echo -e "${CYAN}   docker rm chromium${NC}"
echo -e "${CYAN}   docker system prune${NC}"
