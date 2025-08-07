#!/bin/bash

# Enhanced Chromium Docker Setup Script
# Version: 2.0 - Fixed all syntax errors
# Description: User-friendly script to install and setup Chromium container

# Colors for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m'

# Exit on any error
set -e

# Enhanced log functions with colors
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ${WHITE}$1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

info() {
    echo -e "${CYAN}[INFO] $1${NC}"
}

# Print banner
print_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              Chromium Docker Setup Script v2.0              ║"
    echo "║                  Enhanced & User-Friendly                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        warning "Running as root. This is fine but not recommended for production."
        read -p "Do you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Check system compatibility
check_system() {
    info "Checking system compatibility..."
    
    if [ ! -f /etc/os-release ]; then
        error "Cannot detect OS. This script is designed for Ubuntu/Debian systems."
        exit 1
    fi
    
    . /etc/os-release
    if [ "$ID" != "ubuntu" ] && [ "$ID" != "debian" ]; then
        warning "This script is optimized for Ubuntu/Debian. Your OS: $ID"
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    ARCH=$(dpkg --print-architecture 2>/dev/null || echo "unknown")
    if [ "$ARCH" != "amd64" ] && [ "$ARCH" != "arm64" ]; then
        warning "Unsupported architecture: $ARCH. Supported: amd64, arm64"
    fi
    
    success "System check completed. OS: $PRETTY_NAME, Arch: $ARCH"
}

# Check available resources
check_resources() {
    info "Checking system resources..."
    
    TOTAL_RAM=$(free -m | awk 'NR==2{printf "%.0f", $2/1024}')
    if [ "$TOTAL_RAM" -lt 2 ]; then
        warning "Low RAM detected: ${TOTAL_RAM}GB. Recommended: 2GB+"
    fi
    
    AVAILABLE_SPACE=$(df -BG "$HOME" | awk 'NR==2{print $4}' | sed 's/G//')
    if [ "$AVAILABLE_SPACE" -lt 5 ]; then
        warning "Low disk space: ${AVAILABLE_SPACE}GB. Recommended: 5GB+"
    fi
    
    success "Resources check completed. RAM: ${TOTAL_RAM}GB, Available space: ${AVAILABLE_SPACE}GB"
}

# Enhanced user input with validation
get_user_input() {
    info "Please provide the following information:"
    echo
    
    # Username input with validation
    while true; do
        read -p "Enter username for Chromium [3-20 characters, alphanumeric only]: " CUSTOM_USER
        if [ ${#CUSTOM_USER} -ge 3 ] && [ ${#CUSTOM_USER} -le 20 ] && [[ "$CUSTOM_USER" =~ ^[a-zA-Z0-9]+$ ]]; then
            break
        else
            error "Invalid username. Must be 3-20 characters, alphanumeric only."
        fi
    done
    
    # Password input with validation
    while true; do
        read -s -p "Enter password for Chromium [minimum 6 characters]: " PASSWORD
        echo
        if [ ${#PASSWORD} -ge 6 ]; then
            read -s -p "Confirm password: " PASSWORD_CONFIRM
            echo
            if [ "$PASSWORD" = "$PASSWORD_CONFIRM" ]; then
                break
            else
                error "Passwords do not match. Please try again."
            fi
        else
            error "Password must be at least 6 characters long."
        fi
    done
    
    # Port selection with defaults
    echo
    read -p "Enter HTTP port [default: 3010]: " HTTP_PORT
    HTTP_PORT=${HTTP_PORT:-3010}
    
    read -p "Enter HTTPS port [default: 3011]: " HTTPS_PORT
    HTTPS_PORT=${HTTPS_PORT:-3011}
    
    # Validate ports
    if ! [[ "$HTTP_PORT" =~ ^[0-9]+$ ]] || [ "$HTTP_PORT" -lt 1024 ] || [ "$HTTP_PORT" -gt 65535 ]; then
        warning "Invalid HTTP port. Using default: 3010"
        HTTP_PORT=3010
    fi
    
    if ! [[ "$HTTPS_PORT" =~ ^[0-9]+$ ]] || [ "$HTTPS_PORT" -lt 1024 ] || [ "$HTTPS_PORT" -gt 65535 ]; then
        warning "Invalid HTTPS port. Using default: 3011"
        HTTPS_PORT=3011
    fi
    
    success "Configuration completed!"
}

# Check if ports are available
check_ports() {
    info "Checking port availability..."
    
    if command -v netstat >/dev/null 2>&1; then
        if netstat -tuln | grep -q ":$HTTP_PORT "; then
            warning "Port $HTTP_PORT is already in use!"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
        
        if netstat -tuln | grep -q ":$HTTPS_PORT "; then
            warning "Port $HTTPS_PORT is already in use!"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        warning "netstat not available. Cannot check port availability."
    fi
}

# Show configuration summary
show_summary() {
    echo
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║            Configuration Summary         ║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC} Username:     ${WHITE}$CUSTOM_USER${NC}"
    echo -e "${BLUE}║${NC} HTTP Port:    ${WHITE}$HTTP_PORT${NC}"
    echo -e "${BLUE}║${NC} HTTPS Port:   ${WHITE}$HTTPS_PORT${NC}"
    echo -e "${BLUE}║${NC} Timezone:     ${WHITE}$TZ${NC}"
    echo -e "${BLUE}║${NC} Directory:    ${WHITE}$CHROMIUM_DIR${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo
    
    read -p "Proceed with installation? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        info "Installation cancelled by user."
        exit 0
    fi
}

# Enhanced Docker installation with better error handling
install_docker() {
    log "Starting Docker installation process..."
    
    # Check if Docker is already installed
    if command -v docker >/dev/null 2>&1; then
        DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        info "Docker is already installed - version: $DOCKER_VERSION"
        read -p "Reinstall Docker? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    # Update system
    log "Updating system packages..."
    if ! sudo apt update -y; then
        error "Failed to update package list"
        exit 1
    fi
    
    # Install prerequisites
    log "Installing prerequisites..."
    sudo apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common
    
    # Remove old Docker packages
    log "Removing old Docker packages..."
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
        sudo apt-get remove -y $pkg 2>/dev/null || true
    done
    
    # Add Docker GPG key and repository
    log "Adding Docker repository..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    log "Installing Docker..."
    sudo apt-get update
    if ! sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        error "Failed to install Docker"
        exit 1
    fi
    
    # Add current user to docker group if not root
    if [ "$EUID" -ne 0 ]; then
        log "Adding user to docker group..."
        sudo usermod -aG docker $USER
        warning "Please logout and login again, or run 'newgrp docker' to apply group changes."
        info "For now, using sudo for docker commands..."
    fi
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    success "Docker installation completed!"
}

# Create directory structure with proper error handling
create_directories() {
    log "Creating directory structure..."
    
    # Determine the best location for chromium directory
    if [ -w "$HOME" ]; then
        CHROMIUM_DIR="$HOME/chromium"
    elif [ -w "/opt" ]; then
        CHROMIUM_DIR="/opt/chromium"
        warning "Using /opt/chromium as $HOME is not writable"
    else
        CHROMIUM_DIR="/tmp/chromium"
        warning "Using /tmp/chromium as fallback location"
    fi
    
    # Create main directory
    if ! mkdir -p "$CHROMIUM_DIR"; then
        error "Failed to create directory $CHROMIUM_DIR"
        exit 1
    fi
    
    # Create config directory
    CONFIG_DIR="$CHROMIUM_DIR/config"
    if ! mkdir -p "$CONFIG_DIR"; then
        error "Failed to create config directory $CONFIG_DIR"
        exit 1
    fi
    
    # Set proper permissions
    if [ "$EUID" -ne 0 ]; then
        sudo chown -R $USER:$USER "$CHROMIUM_DIR" 2>/dev/null || true
    fi
    
    success "Directory structure created: $CHROMIUM_DIR"
}

# Create enhanced docker-compose.yaml
create_compose_file() {
    log "Creating docker-compose.yaml..."
    
    cd "$CHROMIUM_DIR"
    
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
      - $CONFIG_DIR:/config
    ports:
      - "$HTTP_PORT:3000"
      - "$HTTPS_PORT:3001"
    shm_size: "1gb"
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3000 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
EOF
    
    success "docker-compose.yaml created successfully!"
}

# Start container with better feedback
start_container() {
    log "Starting Chromium container..."
    
    cd "$CHROMIUM_DIR"
    
    # Pull the image first
    info "Pulling Chromium Docker image - this may take a while..."
    if [ "$EUID" -ne 0 ] && ! groups | grep -q docker; then
        sudo docker compose pull
    else
        docker compose pull
    fi
    
    # Start the container
    info "Starting container..."
    if [ "$EUID" -ne 0 ] && ! groups | grep -q docker; then
        if ! sudo docker compose up -d; then
            error "Failed to start Chromium container"
            exit 1
        fi
    else
        if ! docker compose up -d; then
            error "Failed to start Chromium container"
            exit 1
        fi
    fi
    
    # Wait for container to be ready
    info "Waiting for container to be ready..."
    sleep 10
    
    # Check if container is running
    if [ "$EUID" -ne 0 ] && ! groups | grep -q docker; then
        CONTAINER_STATUS=$(sudo docker compose ps --format "table {{.Status}}" | grep -v STATUS | head -1)
    else
        CONTAINER_STATUS=$(docker compose ps --format "table {{.Status}}" | grep -v STATUS | head -1)
    fi
    
    if [[ "$CONTAINER_STATUS" == *"Up"* ]]; then
        success "Chromium container started successfully!"
    else
        error "Container failed to start properly. Status: $CONTAINER_STATUS"
        exit 1
    fi
}

# Get public IP with multiple fallbacks
get_public_ip() {
    log "Detecting public IP address..."
    
    PUBLIC_IP=""
    
    for service in "curl -s ifconfig.me" "curl -s ipinfo.io/ip" "curl -s icanhazip.com" "curl -s ident.me"; do
        if PUBLIC_IP=$(eval $service 2>/dev/null) && [ -n "$PUBLIC_IP" ]; then
            break
        fi
    done
    
    # Fallback to local IP if public IP detection fails
    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
        warning "Could not detect public IP, using local IP: $PUBLIC_IP"
    fi
    
    info "Detected IP address: $PUBLIC_IP"
}

# Show final results with enhanced formatting
show_results() {
    clear
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                    🎉 INSTALLATION COMPLETED! 🎉                     ║"
    echo "╠══════════════════════════════════════════════════════════════════════╣"
    echo "║                         Access Information                           ║"
    echo "╠══════════════════════════════════════════════════════════════════════╣"
    echo -e "║ ${WHITE}HTTP URL:${NC}  ${CYAN}http://$PUBLIC_IP:$HTTP_PORT${NC}"
    echo -e "║ ${WHITE}HTTPS URL:${NC} ${CYAN}https://$PUBLIC_IP:$HTTPS_PORT${NC}"
    echo "║                                                                      ║"
    echo -e "║ ${WHITE}Username:${NC}  ${YELLOW}$CUSTOM_USER${NC}"
    echo -e "║ ${WHITE}Password:${NC}  ${YELLOW}[Your secure password]${NC}"
    echo "║                                                                      ║"
    echo -e "║ ${WHITE}Container Status:${NC} ${GREEN}Running${NC}"
    echo -e "║ ${WHITE}Config Directory:${NC} $CONFIG_DIR"
    echo "╠══════════════════════════════════════════════════════════════════════╣"
    echo "║                        Management Commands                           ║"
    echo "╠══════════════════════════════════════════════════════════════════════╣"
    echo "║ Start:   docker compose up -d                                       ║"
    echo "║ Stop:    docker compose down                                        ║"
    echo "║ Restart: docker compose restart                                     ║"
    echo "║ Logs:    docker compose logs -f                                     ║"
    echo "║ Status:  docker compose ps                                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo
    echo -e "${BLUE}📋 Quick Notes:${NC}"
    echo "• It may take 1-2 minutes for Chromium to fully load"
    echo "• If you can't connect, check your firewall settings"
    echo "• All management commands should be run from: $CHROMIUM_DIR"
    echo
    
    if [ "$PUBLIC_IP" = "localhost" ] || [[ "$PUBLIC_IP" =~ ^192\.168\. ]] || [[ "$PUBLIC_IP" =~ ^10\. ]] || [[ "$PUBLIC_IP" =~ ^172\. ]]; then
        echo -e "${YELLOW}⚠️  Note: Using local/private IP. For external access, use your server's public IP.${NC}"
        echo
    fi
    
    echo -e "${GREEN}🎯 Ready to browse! Open your web browser and navigate to the URLs above.${NC}"
}

# Main execution function
main() {
    print_banner
    
    # Pre-installation checks
    check_root
    check_system
    check_resources
    
    # Detect timezone
    if [ -f /etc/localtime ]; then
        TZ=$(realpath --relative-to /usr/share/zoneinfo /etc/localtime 2>/dev/null || echo "UTC")
    else
        TZ="UTC"
        warning "/etc/localtime not found, using UTC"
    fi
    
    # Get user configuration
    get_user_input
    check_ports
    
    # Create directories first
    create_directories
    
    # Show summary and get confirmation
    show_summary
    
    # Installation process
    install_docker
    create_compose_file
    start_container
    get_public_ip
    
    # Show final results
    show_results
}

# Trap errors and provide helpful information
trap 'error "Script failed at line $LINENO. Check the logs above for details."' ERR

# Run main function
main "$@"
