#!/bin/bash

# Enhanced Chromium Docker Setup Script
# Version: 3.0 - All errors fixed and improved
# Description: Production-ready script to install and setup Chromium container

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
HTTP_PORT=""
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
    echo "║              Chromium Docker Setup Script v3.0              ║"
    echo "║                Fixed & Production Ready                      ║"
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

# Check system compatibility with better OS detection
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
        centos|rhel|fedora)
            error "CentOS/RHEL/Fedora not supported in this version. Please use Ubuntu/Debian."
            exit 1
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
    
    success "System check completed. OS: $PRETTY_NAME, Arch: $ARCH, Codename: $CODENAME"
}

# Check available resources with better calculations
check_resources() {
    info "Checking system resources..."
    
    # Check RAM (handle systems with <1GB RAM properly)
    TOTAL_RAM_MB=$(free -m | awk 'NR==2{printf "%d", $2}')
    TOTAL_RAM_GB=$((TOTAL_RAM_MB / 1024))
    
    if [ "$TOTAL_RAM_GB" -lt 2 ]; then
        if [ "$TOTAL_RAM_MB" -lt 1024 ]; then
            warning "Very low RAM detected: ${TOTAL_RAM_MB}MB. Minimum recommended: 2GB"
        else
            warning "Low RAM detected: ${TOTAL_RAM_GB}GB. Recommended: 2GB+"
        fi
    fi
    
    # Check disk space
    AVAILABLE_SPACE=$(df -BG "$HOME" 2>/dev/null | awk 'NR==2{print $4}' | sed 's/G//' || echo "0")
    if [ "$AVAILABLE_SPACE" -lt 5 ]; then
        warning "Low disk space: ${AVAILABLE_SPACE}GB available. Recommended: 5GB+"
    fi
    
    success "Resources check completed. RAM: ${TOTAL_RAM_MB}MB, Available space: ${AVAILABLE_SPACE}GB"
}

# Enhanced user input with better validation
get_user_input() {
    info "Please provide the following information:"
    echo
    
    # Username input with validation
    while true; do
        read -p "Enter username for Chromium [3-20 characters, alphanumeric only]: " CUSTOM_USER
        if [ -n "$CUSTOM_USER" ] && [ ${#CUSTOM_USER} -ge 3 ] && [ ${#CUSTOM_USER} -le 20 ] && [[ "$CUSTOM_USER" =~ ^[a-zA-Z0-9]+$ ]]; then
            break
        else
            error "Invalid username. Must be 3-20 characters, alphanumeric only, and not empty."
        fi
    done
    
    # Password input with validation
    while true; do
        read -s -p "Enter password for Chromium [minimum 6 characters]: " PASSWORD
        echo
        if [ -n "$PASSWORD" ] && [ ${#PASSWORD} -ge 6 ]; then
            read -s -p "Confirm password: " PASSWORD_CONFIRM
            echo
            if [ "$PASSWORD" = "$PASSWORD_CONFIRM" ]; then
                break
            else
                error "Passwords do not match. Please try again."
            fi
        else
            error "Password must be at least 6 characters long and not empty."
        fi
    done
    
    # Port selection - HTTPS only
    echo
    while true; do
        read -p "Enter HTTPS port [default: 3011, range: 1024-65535]: " HTTPS_PORT
        HTTPS_PORT=${HTTPS_PORT:-3011}
        if [[ "$HTTPS_PORT" =~ ^[0-9]+$ ]] && [ "$HTTPS_PORT" -ge 1024 ] && [ "$HTTPS_PORT" -le 65535 ]; then
            break
        else
            error "Invalid HTTPS port. Must be between 1024-65535."
        fi
    done
    
    success "Configuration input completed!"
}

# Check if port is available
check_ports() {
    info "Checking port availability..."
    
    if command -v netstat >/dev/null 2>&1; then
        if netstat -tuln 2>/dev/null | grep -q ":$HTTPS_PORT "; then
            warning "Port $HTTPS_PORT is already in use!"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    elif command -v ss >/dev/null 2>&1; then
        if ss -tuln 2>/dev/null | grep -q ":$HTTPS_PORT "; then
            warning "Port $HTTPS_PORT is already in use!"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        warning "Cannot check port availability (netstat/ss not found). Continuing..."
    fi
}

# Detect timezone with better fallbacks
detect_timezone() {
    info "Detecting timezone..."
    
    # Try multiple methods to detect timezone
    if [ -f /etc/timezone ]; then
        TZ=$(cat /etc/timezone 2>/dev/null || echo "")
    elif [ -L /etc/localtime ]; then
        TZ=$(realpath --relative-to /usr/share/zoneinfo /etc/localtime 2>/dev/null || echo "")
    elif command -v timedatectl >/dev/null 2>&1; then
        TZ=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "")
    fi
    
    # Validate timezone
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
    echo -e "${BLUE}║${NC} Directory:    ${WHITE}$CHROMIUM_DIR${NC}"
    echo -e "${BLUE}║${NC} OS/Arch:      ${WHITE}$ID/$ARCH${NC}"
    echo -e "${BLUE}║${NC} Repository:   ${WHITE}$REPO_URL${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo
    
    read -p "Proceed with installation? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        info "Installation cancelled by user."
        exit 0
    fi
}

# Check Docker Compose command availability
check_docker_compose_cmd() {
    info "Checking Docker Compose availability..."
    
    # First try docker compose (newer plugin)
    if docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
        info "Using Docker Compose plugin: docker compose"
    # Fallback to docker-compose (standalone)
    elif command -v docker-compose >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker-compose"
        info "Using Docker Compose standalone: docker-compose"
    else
        error "Neither 'docker compose' nor 'docker-compose' found!"
        error "Please install Docker Compose."
        exit 1
    fi
}

# Fixed Docker installation with proper error handling
install_docker() {
    log "Starting Docker installation process..."
    
    # Check if Docker is already installed and working
    if command -v docker >/dev/null 2>&1; then
        if docker --version >/dev/null 2>&1; then
            DOCKER_VERSION=$(docker --version 2>/dev/null | cut -d' ' -f3 | cut -d',' -f1 || echo "unknown")
            info "Docker is already installed - version: $DOCKER_VERSION"
            
            # Check if user can run docker without sudo
            if docker ps >/dev/null 2>&1; then
                info "Docker is working properly."
                return 0
            elif [ "$EUID" -ne 0 ]; then
                warning "Docker requires sudo. This will be handled automatically."
            fi
            return 0
        fi
    fi
    
    # Update system packages
    log "Updating system packages..."
    sudo apt-get update -qq
    
    # Install prerequisites
    log "Installing prerequisites..."
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        apt-transport-https \
        software-properties-common \
        wget \
        unzip
    
    # Remove conflicting packages
    log "Removing conflicting packages..."
    for pkg in docker docker.io docker-doc docker-compose podman-docker containerd runc; do
        sudo apt-get remove -y $pkg 2>/dev/null || true
    done
    
    # Create keyrings directory
    sudo mkdir -p /etc/apt/keyrings
    
    # Add Docker GPG key (fixed)
    log "Adding Docker GPG key..."
    if ! curl -fsSL "$REPO_URL/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
        error "Failed to add Docker GPG key"
        exit 1
    fi
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository (fixed)
    log "Adding Docker repository..."
    echo \
      "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] $REPO_URL \
      $CODENAME stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package list
    log "Updating package list with Docker repository..."
    if ! sudo apt-get update -qq; then
        error "Failed to update package list after adding Docker repository"
        exit 1
    fi
    
    # Install Docker
    log "Installing Docker..."
    if ! sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        error "Failed to install Docker"
        exit 1
    fi
    
    # Start and enable Docker
    log "Starting Docker service..."
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add current user to docker group if not root
    if [ "$EUID" -ne 0 ]; then
        log "Adding user to docker group..."
        sudo usermod -aG docker $USER
        warning "Group changes will take effect after logout/login or running 'newgrp docker'"
        info "For now, docker commands will use sudo"
    fi
    
    # Verify Docker installation
    if sudo docker --version >/dev/null 2>&1; then
        success "Docker installation completed successfully!"
    else
        error "Docker installation verification failed"
        exit 1
    fi
}

# Create directory structure with better error handling
create_directories() {
    log "Creating directory structure..."
    
    # Determine the best location for chromium directory
    if [ -w "$HOME" ] && [ -n "$HOME" ]; then
        CHROMIUM_DIR="$HOME/chromium"
    elif [ -w "/opt" ]; then
        CHROMIUM_DIR="/opt/chromium"
        warning "Using /opt/chromium (HOME directory not writable)"
    else
        CHROMIUM_DIR="/tmp/chromium"
        warning "Using /tmp/chromium as fallback (data will be lost on reboot)"
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
        sudo chown -R $USER:$USER "$CHROMIUM_DIR" 2>/dev/null || {
            warning "Could not set ownership of $CHROMIUM_DIR"
        }
    fi
    
    success "Directory structure created: $CHROMIUM_DIR"
}

# Create simple and clean docker-compose.yaml
create_compose_file() {
    log "Creating docker-compose.yaml..."
    
    cd "$CHROMIUM_DIR" || {
        error "Failed to change to directory $CHROMIUM_DIR"
        exit 1
    }
    
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
      - CHROME_CLI=about:blank
    volumes:
      - $CONFIG_DIR:/config
    ports:
      - "$HTTPS_PORT:3001"
    shm_size: "2gb"
    restart: unless-stopped
EOF
    
    success "docker-compose.yaml created successfully!"
}

# Start container with better feedback and error handling
start_container() {
    log "Starting Chromium container..."
    
    cd "$CHROMIUM_DIR" || {
        error "Failed to change to directory $CHROMIUM_DIR"
        exit 1
    }
    
    # Determine if we need sudo for docker
    DOCKER_CMD="$DOCKER_COMPOSE_CMD"
    if [ "$EUID" -ne 0 ] && ! groups | grep -q docker; then
        DOCKER_CMD="sudo $DOCKER_COMPOSE_CMD"
    fi
    
    # Pull the image first
    info "Pulling Chromium Docker image (this may take a while)..."
    if ! $DOCKER_CMD pull; then
        error "Failed to pull Docker image"
        exit 1
    fi
    
    # Start the container
    info "Starting container..."
    if ! $DOCKER_CMD up -d; then
        error "Failed to start Chromium container"
        error "Check logs with: $DOCKER_CMD logs chromium"
        exit 1
    fi
    
    # Wait for container to be ready
    info "Waiting for container to initialize (60 seconds)..."
    sleep 15
    
    # Check container status multiple times
    for i in {1..9}; do
        CONTAINER_STATUS=$($DOCKER_CMD ps --format "table {{.Status}}" | grep -v STATUS | head -1 2>/dev/null || echo "Not found")
        
        if [[ "$CONTAINER_STATUS" == *"Up"* ]]; then
            success "Chromium container started successfully!"
            return 0
        elif [[ "$CONTAINER_STATUS" == *"Exited"* ]]; then
            error "Container exited unexpectedly. Check logs:"
            $DOCKER_CMD logs chromium | tail -10
            exit 1
        fi
        
        info "Waiting... (attempt $i/9)"
        sleep 5
    done
    
    warning "Container status unclear. Check manually with: $DOCKER_CMD ps"
}

# Get public IP with multiple fallbacks and better error handling
get_public_ip() {
    log "Detecting IP address..."
    
    PUBLIC_IP=""
    
    # Try multiple services for public IP
    local ip_services=(
        "curl -s --connect-timeout 5 ifconfig.me"
        "curl -s --connect-timeout 5 ipinfo.io/ip"
        "curl -s --connect-timeout 5 icanhazip.com"
        "curl -s --connect-timeout 5 ident.me"
        "wget -qO- --timeout=5 ifconfig.me"
    )
    
    for service in "${ip_services[@]}"; do
        if PUBLIC_IP=$(eval $service 2>/dev/null | tr -d '\n\r' | head -1) && \
           [ -n "$PUBLIC_IP" ] && \
           [[ "$PUBLIC_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            info "Detected public IP: $PUBLIC_IP"
            return 0
        fi
    done
    
    # Fallback to local IP
    if PUBLIC_IP=$(hostname -I 2>/dev/null | awk '{print $1}'); then
        if [ -n "$PUBLIC_IP" ]; then
            warning "Could not detect public IP, using local IP: $PUBLIC_IP"
            return 0
        fi
    fi
    
    # Ultimate fallback
    PUBLIC_IP="localhost"
    warning "Could not detect any IP address, using localhost"
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
    
    # Show commands based on available docker compose
    if [[ "$DOCKER_COMPOSE_CMD" == *"sudo"* ]]; then
        echo "║ Start:   sudo $DOCKER_COMPOSE_CMD up -d                                    ║"
        echo "║ Stop:    sudo $DOCKER_COMPOSE_CMD down                                     ║"
        echo "║ Restart: sudo $DOCKER_COMPOSE_CMD restart                                  ║"
        echo "║ Logs:    sudo $DOCKER_COMPOSE_CMD logs -f chromium                         ║"
        echo "║ Status:  sudo $DOCKER_COMPOSE_CMD ps                                       ║"
    else
        echo "║ Start:   $DOCKER_COMPOSE_CMD up -d                                      ║"
        echo "║ Stop:    $DOCKER_COMPOSE_CMD down                                       ║"
        echo "║ Restart: $DOCKER_COMPOSE_CMD restart                                    ║"
        echo "║ Logs:    $DOCKER_COMPOSE_CMD logs -f chromium                           ║"
        echo "║ Status:  $DOCKER_COMPOSE_CMD ps                                         ║"
    fi
    
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo
    echo -e "${BLUE}📋 Important Notes:${NC}"
    echo "• Wait 2-3 minutes for Chromium to fully initialize"
    echo "• If HTTPS doesn't work, try HTTP first: http://$PUBLIC_IP:$HTTP_PORT"
    echo "• For HTTPS certificate warnings, click 'Advanced' → 'Proceed'"
    echo "• Check firewall settings if you can't connect externally"
    echo "• All management commands should be run from: $CHROMIUM_DIR"
    echo
    
    # IP address specific notes
    if [ "$PUBLIC_IP" = "localhost" ]; then
        echo -e "${YELLOW}⚠️  Note: Using localhost - only accessible from this machine${NC}"
    elif [[ "$PUBLIC_IP" =~ ^192\.168\. ]] || [[ "$PUBLIC_IP" =~ ^10\. ]] || [[ "$PUBLIC_IP" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
        echo -e "${YELLOW}⚠️  Note: Using private IP - accessible within local network only${NC}"
    fi
    
    echo
    echo -e "${GREEN}🎯 Installation complete! Open your web browser and navigate to:${NC}"
    echo -e "${WHITE}   Primary: ${CYAN}http://$PUBLIC_IP:$HTTP_PORT${NC}"
    echo -e "${WHITE}   Secure:  ${CYAN}https://$PUBLIC_IP:$HTTPS_PORT${NC}"
}

# Main execution function
main() {
    print_banner
    
    # Pre-installation checks
    check_root
    check_system
    check_resources
    detect_timezone
    
    # Get user configuration
    get_user_input
    check_ports
    
    # Create directories first
    create_directories
    
    # Show summary and get confirmation
    show_summary
    
    # Installation process
    install_docker
    check_docker_compose_cmd
    create_compose_file
    start_container
    get_public_ip
    
    # Show final results
    show_results
}

# Improved error trap with cleanup
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        error "Script failed at line $1. Exit code: $exit_code"
        
        # Show some helpful debugging info
        if [ -n "$CHROMIUM_DIR" ] && [ -d "$CHROMIUM_DIR" ]; then
            echo -e "${YELLOW}Debug information:${NC}"
            echo "• Installation directory: $CHROMIUM_DIR"
            
            if [ -f "$CHROMIUM_DIR/docker-compose.yaml" ]; then
                echo "• Docker compose file exists"
                if [ -n "$DOCKER_COMPOSE_CMD" ]; then
                    echo "• Container logs (last 10 lines):"
                    cd "$CHROMIUM_DIR" && $DOCKER_COMPOSE_CMD logs --tail=10 chromium 2>/dev/null || echo "  Could not retrieve logs"
                fi
            fi
        fi
        
        echo -e "${CYAN}For help, check:${NC}"
        echo "• Script logs above"
        echo "• Docker installation: systemctl status docker"
        echo "• Container status: docker ps -a"
    fi
}

trap 'cleanup $LINENO' ERR

# Run main function
main "$@"
