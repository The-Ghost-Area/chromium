#!/bin/bash

# Enhanced Chromium Docker Setup Script
# Version: 3.1 - Clean and Fixed
# Description: Minimal production-ready script for Chromium container

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

# Global variables
DOCKER_COMPOSE_CMD=""
REPO_URL=""
CODENAME=""
PUBLIC_IP=""
CHROMIUM_DIR=""
CONFIG_DIR=""
CUSTOM_USER=""
PASSWORD=""
HTTPS_PORT=""
TZ=""

# Enhanced log functions with colors
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ${WHITE}$1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
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
    echo "║              Chromium Docker Setup Script v3.1              ║"
    echo "║                  Clean & Production Ready                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        warning "Running as root. This is not recommended for production."
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
        error "Cannot detect OS. This script requires a Linux distribution with /etc/os-release."
        exit 1
    fi
    
    # Source OS release info
    . /etc/os-release
    
    # Set repository URL and codename based on OS
    case "$ID" in
        ubuntu)
            REPO_URL="https://download.docker.com/linux/ubuntu"
            CODENAME="${VERSION_CODENAME:-focal}"
            ;;
        debian)
            REPO_URL="https://download.docker.com/linux/debian"
            CODENAME="${VERSION_CODENAME:-bullseye}"
            ;;
        *)
            warning "Unsupported OS: $ID. Trying Ubuntu repository as fallback."
            REPO_URL="https://download.docker.com/linux/ubuntu"
            CODENAME="focal"
            ;;
    esac
    
    # Check architecture
    ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
    case "$ARCH" in
        amd64|x86_64)
            ARCH="amd64"
            ;;
        arm64|aarch64)
            ARCH="arm64"
            ;;
        *)
            error "Unsupported architecture: $ARCH. Supported: amd64, arm64"
            exit 1
            ;;
    esac
    
    success "System check completed. OS: $PRETTY_NAME, Arch: $ARCH"
}

# Enhanced user input with validation
get_user_input() {
    info "Please provide the following information:"
    echo
    
    # Username input
    while true; do
        read -p "Enter username for Chromium [3-20 characters]: " CUSTOM_USER
        if [ -n "$CUSTOM_USER" ] && [ ${#CUSTOM_USER} -ge 3 ] && [ ${#CUSTOM_USER} -le 20 ] && [[ "$CUSTOM_USER" =~ ^[a-zA-Z0-9]+$ ]]; then
            break
        else
            error "Invalid username. Must be 3-20 alphanumeric characters."
        fi
    done
    
    # Password input
    while true; do
        read -s -p "Enter password [minimum 6 characters]: " PASSWORD
        echo
        if [ -n "$PASSWORD" ] && [ ${#PASSWORD} -ge 6 ]; then
            read -s -p "Confirm password: " PASSWORD_CONFIRM
            echo
            if [ "$PASSWORD" = "$PASSWORD_CONFIRM" ]; then
                break
            else
                error "Passwords do not match."
            fi
        else
            error "Password must be at least 6 characters."
        fi
    done
    
    # Port selection
    while true; do
        read -p "Enter HTTPS port [default: 3011]: " HTTPS_PORT
        HTTPS_PORT=${HTTPS_PORT:-3011}
        if [[ "$HTTPS_PORT" =~ ^[0-9]+$ ]] && [ "$HTTPS_PORT" -ge 1024 ] && [ "$HTTPS_PORT" -le 65535 ]; then
            break
        else
            error "Invalid port. Must be between 1024-65535."
        fi
    done
    
    success "Configuration completed!"
}

# Detect timezone
detect_timezone() {
    if [ -f /etc/timezone ]; then
        TZ=$(cat /etc/timezone 2>/dev/null || echo "")
    elif [ -L /etc/localtime ]; then
        TZ=$(realpath --relative-to /usr/share/zoneinfo /etc/localtime 2>/dev/null || echo "")
    elif command -v timedatectl >/dev/null 2>&1; then
        TZ=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "")
    fi
    
    if [ -z "$TZ" ] || [ ! -f "/usr/share/zoneinfo/$TZ" ]; then
        TZ="UTC"
        warning "Could not detect timezone, using UTC"
    else
        info "Detected timezone: $TZ"
    fi
}

# Show configuration summary
show_summary() {
    echo
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║            Configuration Summary         ║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC} Username:     ${WHITE}$CUSTOM_USER${NC}"
    echo -e "${BLUE}║${NC} HTTPS Port:   ${WHITE}$HTTPS_PORT${NC}"
    echo -e "${BLUE}║${NC} Timezone:     ${WHITE}$TZ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo
    
    read -p "Proceed with installation? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        exit 0
    fi
}

# Check Docker Compose command
check_docker_compose_cmd() {
    if docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker-compose"
    else
        error "Docker Compose not found!"
        exit 1
    fi
}

# Install Docker
install_docker() {
    log "Starting Docker installation..."
    
    # Check if Docker exists
    if command -v docker >/dev/null 2>&1 && docker --version >/dev/null 2>&1; then
        info "Docker already installed"
        return 0
    fi
    
    # Update system
    sudo apt-get update -qq
    
    # Install prerequisites
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Remove old packages
    for pkg in docker docker.io docker-doc docker-compose podman-docker containerd runc; do
        sudo apt-get remove -y $pkg 2>/dev/null || true
    done
    
    # Add Docker repository
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL "$REPO_URL/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] $REPO_URL $CODENAME stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt-get update -qq
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add user to docker group
    if [ "$EUID" -ne 0 ]; then
        sudo usermod -aG docker $USER
        warning "Please logout/login for group changes to take effect"
    fi
    
    success "Docker installed successfully!"
}

# Create directories
create_directories() {
    log "Creating directories..."
    
    CHROMIUM_DIR="$HOME/chromium"
    CONFIG_DIR="$CHROMIUM_DIR/config"
    
    mkdir -p "$CONFIG_DIR"
    success "Directories created: $CHROMIUM_DIR"
}

# Create docker-compose file
create_compose_file() {
    log "Creating docker-compose.yaml..."
    
    cd "$CHROMIUM_DIR"
    
    # Create compose file with proper variable substitution
    cat > docker-compose.yaml << 'COMPOSE_EOF'
version: '3.8'

services:
  chromium:
    image: lscr.io/linuxserver/chromium:latest
    container_name: chromium
    security_opt:
      - seccomp:unconfined
    environment:
      - CUSTOM_USER=REPLACE_USER
      - PASSWORD=REPLACE_PASS
      - PUID=1000
      - PGID=1000
      - TZ=REPLACE_TZ
      - CHROME_CLI=about:blank
    volumes:
      - REPLACE_CONFIG:/config
    ports:
      - "REPLACE_PORT:3001"
    shm_size: "2gb"
    restart: unless-stopped
COMPOSE_EOF

    # Replace placeholders
    sed -i "s|REPLACE_USER|$CUSTOM_USER|g" docker-compose.yaml
    sed -i "s|REPLACE_PASS|$PASSWORD|g" docker-compose.yaml
    sed -i "s|REPLACE_TZ|$TZ|g" docker-compose.yaml
    sed -i "s|REPLACE_CONFIG|$CONFIG_DIR|g" docker-compose.yaml
    sed -i "s|REPLACE_PORT|$HTTPS_PORT|g" docker-compose.yaml
    
    success "docker-compose.yaml created!"
}

# Start container
start_container() {
    log "Starting Chromium container..."
    
    cd "$CHROMIUM_DIR"
    
    # Determine Docker command
    DOCKER_CMD="$DOCKER_COMPOSE_CMD"
    if [ "$EUID" -ne 0 ] && ! groups | grep -q docker; then
        DOCKER_CMD="sudo $DOCKER_COMPOSE_CMD"
    fi
    
    # Pull and start
    $DOCKER_CMD pull
    $DOCKER_CMD up -d
    
    # Wait for startup
    sleep 20
    
    success "Container started successfully!"
}

# Get public IP
get_public_ip() {
    log "Detecting IP address..."
    
    PUBLIC_IP=""
    local services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com")
    
    for service in "${services[@]}"; do
        if PUBLIC_IP=$(curl -s --connect-timeout 5 "$service" 2>/dev/null | tr -d '\n\r'); then
            if [[ "$PUBLIC_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                break
            fi
        fi
    done
    
    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
        warning "Using local IP: $PUBLIC_IP"
    fi
}

# Show results
show_results() {
    clear
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                    🎉 INSTALLATION COMPLETED! 🎉                     ║"
    echo "╠══════════════════════════════════════════════════════════════════════╣"
    echo -e "║ ${WHITE}HTTPS URL:${NC} ${CYAN}https://$PUBLIC_IP:$HTTPS_PORT${NC}"
    echo -e "║ ${WHITE}Username:${NC}  ${YELLOW}$CUSTOM_USER${NC}"
    echo -e "║ ${WHITE}Password:${NC}  ${YELLOW}[Your secure password]${NC}"
    echo "╠══════════════════════════════════════════════════════════════════════╣"
    echo "║                        Management Commands                           ║"
    echo "╠══════════════════════════════════════════════════════════════════════╣"
    
    if [[ "$DOCKER_COMPOSE_CMD" == *"sudo"* ]]; then
        echo "║ Start:   sudo $DOCKER_COMPOSE_CMD up -d                                    ║"
        echo "║ Stop:    sudo $DOCKER_COMPOSE_CMD down                                     ║"
        echo "║ Logs:    sudo $DOCKER_COMPOSE_CMD logs -f chromium                         ║"
    else
        echo "║ Start:   $DOCKER_COMPOSE_CMD up -d                                      ║"
        echo "║ Stop:    $DOCKER_COMPOSE_CMD down                                       ║"
        echo "║ Logs:    $DOCKER_COMPOSE_CMD logs -f chromium                           ║"
    fi
    
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${GREEN}🎯 Ready! Open: ${CYAN}https://$PUBLIC_IP:$HTTPS_PORT${NC}"
}

# Main function
main() {
    print_banner
    check_root
    check_system
    detect_timezone
    get_user_input
    show_summary
    install_docker
    check_docker_compose_cmd
    create_directories
    create_compose_file
    start_container
    get_public_ip
    show_results
}

# Error handling
trap 'error "Script failed at line $LINENO"' ERR

# Run main function
main "$@"
