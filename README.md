🚀 Chromium Docker Setup Guide

This guide will help you quickly set up and manage Chromium inside a Docker container.

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

Troubleshooting
---------------
- Ensure Docker is installed and running.
- Use `sudo` to avoid permission issues when running the setup script.
- Check Docker service status and logs if you encounter errors.

Summary
-------
1. Clone the repository and enter the directory.
2. Make the setup script executable and run it with sudo.
3. Use Docker commands to start, stop, or restart the Chromium container.

For further assistance, feel free to ask.
