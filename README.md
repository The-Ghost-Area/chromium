# Chromium Docker Setup

This repository (`https://github.com/The-Ghost-Area/chromium.git`) provides scripts to set up and remove a Chromium browser container using Docker on Ubuntu. The setup script installs Docker, configures a Chromium container, prompts for a username and password, auto-detects the server's timezone, uses default ports (3010 for HTTP, 3011 for HTTPS), and opens `https://google.com` by default. The cleanup script removes the container, directories, and Docker entirely.

## Installation

1. **Clone the Repository**:
