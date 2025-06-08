Chromium Docker Setup

This repository (https://github.com/The-Ghost-Area/chromium.git) provides scripts to set up and remove a Chromium browser container using Docker on Ubuntu. The setup script installs Docker, configures a Chromium container, prompts for a username and password, auto-detects the server's timezone, uses default ports (3010 for HTTP, 3011 for HTTPS), and opens https://google.com by default. The cleanup script removes the container, directories, and Docker entirely.

Files





setup_chromium.sh: Installs Docker, sets up a Chromium container, and provides login URLs with the server's public IP.



delete_chromium_docker.sh: Stops the Chromium container, deletes the chromium directory, uninstalls Docker, and cleans up residual files.



.gitignore: Ignores sensitive data like the config/ directory.

Prerequisites





Ubuntu system with internet access.



sudo privileges.



curl, git, and bash installed:

sudo apt update && sudo apt install -y curl git



Public IP address for accessing the Chromium browser.

Setup Instructions





Clone the repository:

git clone https://github.com/The-Ghost-Area/chromium.git
cd chromium



Make the setup script executable:

chmod +x setup_chromium.sh



Run the setup script:

sudo ./setup_chromium.sh



Follow prompts:





Enter a CUSTOM_USER (username for Chromium login).



Enter a PASSWORD (hidden for security).



Access Chromium:





The script outputs URLs like http://<public-ip>:3010/ and https://<public-ip>:3011/.



Login with your chosen username and password.



If the IP shows as your-vps-ip, find your server's public IP:

curl ifconfig.me
