Chromium Docker Setup
This repository (https://github.com/The-Ghost-Area/chromium.git) provides scripts to set up and remove a Chromium browser container using Docker on Ubuntu. The setup script installs Docker, configures a Chromium container, prompts for a username and password, auto-detects the server's timezone, uses default ports (3010 for HTTP, 3011 for HTTPS), and opens https://google.com by default. The cleanup script removes the container, directories, and Docker entirely.
Installation

Clone the Repository:
git clone https://github.com/The-Ghost-Area/chromium.git

cd chromium


Install Requirements:

Ensure you have curl, git, and Docker prerequisites installed:sudo apt update && sudo apt install -y curl git ca-certificates


The setup script will install Docker if not already present.



Configuration

Make the Setup Script Executable:
chmod +x setup_chromium.sh


Run the Setup Script:
sudo ./setup_chromium.sh


Enter a CUSTOM_USER (username for Chromium login).
Enter a PASSWORD (hidden for security).
The script will output URLs like http://<public-ip>:3010/ and https://<public-ip>:3011/.
Login with your chosen username and password.
If the IP shows as your-vps-ip, find your server's public IP:curl ifconfig.me





Cleanup

Make the Cleanup Script Executable:
chmod +x delete_chromium_docker.sh


Run the Cleanup Script:
sudo ./delete_chromium_docker.sh


This stops and removes the Chromium container, deletes the chromium directory (~/chromium or /root/chromium), uninstalls Docker, and cleans up residual files.



Troubleshooting

Chromium folder not created:
Check home directory permissions:ls -ld ~

Ensure it’s writable (e.g., drwxr-xr-x yuvraj).
Run the script with sudo.
Check if the folder is in /root/chromium:sudo ls -la /root/chromium




Docker errors:
Verify Docker installation:docker --version


Check container logs:cd ~/chromium && docker compose logs




Port conflicts:
Check ports 3010 or 3011:ss -tuln | grep -E ':3010|:3011'


Edit setup_chromium.sh to change ports (e.g., 3020, 3021).


Public IP not detected:
Check your IP:curl ifconfig.me





