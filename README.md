🚀 Chromium Docker Setup Guide

This guide will help you quickly set up and manage Chromium inside a Docker container.

Step : Update Package List and Install Git
-------------------------------------------
Before cloning the repository, make sure Git is installed on your system. Run:

    sudo apt update
    sudo apt install git

Step 1: Clone the Chromium Docker Repository
--------------------------------------------
Open your terminal and run:

    git clone https://github.com/The-Ghost-Area/chromium.git && cd chromium

This command clones the repository and navigates into the project directory.

Step 2: Make the Setup Script Executable and Run It
---------------------------------------------------
Give execute permission to the setup script by running:

    chmod +x setup_chromium.sh

Then execute the script with superuser privileges:

    sudo ./setup_chromium.sh

Note: You may be prompted for your password because admin rights are required to install dependencies and set up the Docker container.

The script will automatically pull necessary Docker images and configure the Chromium container.

Step 3: Manage the Chromium Docker Container
--------------------------------------------
Use the following commands to control the container:

    docker start chromium      # Start the container
    docker stop chromium       # Stop the container
    docker restart chromium    # Restart the container

Create Firewall Rule for Chromium
---------------
1. Go to Google Cloud Console
https://console.cloud.google.com
2. Navigate to:
VPC Network > Firewall rules
3. Click on “Create Firewall Rule”

 Fill in the form:
Name: allow-chromium

Network: default (or the network your VM is using) 

Targets: All instances in the network (or use “Specified target tags” if you're using instance tags) 

Source IP Ranges: 0.0.0.0/0 
(Allows access from anywhere — you can restrict this to your IP if needed for security) 

Protocols and Ports:
Select Specified protocols and ports 

Then check TCP and enter:
3010,3011
 Click “Create”

Troubleshooting
---------------
- Ensure Docker is installed and running.
- Use `sudo` to avoid permission issues when running the setup script.
- Check Docker service status and logs if you encounter errors.

Summary
-------
1. Update package list and install Git.
2. Clone the repository and enter the directory.
3. Make the setup script executable and run it with sudo.
4. Use Docker commands to start, stop, or restart the Chromium container.

For further assistance, feel free to ask.
