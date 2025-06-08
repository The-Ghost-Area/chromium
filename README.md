Setup Instructions
1. Clone the repository:
git clone <repository-url>
cd chromium-docker-repo

2. Make the setup script executable:
chmod +x setup_chromium.sh

3. Run the setup script:
sudo ./setup_chromium.sh

4. Follow prompts:
Enter a CUSTOM_USER (username for Chromium login).
Enter a PASSWORD (hidden for security).

5. Access Chromium:
The script outputs URLs like http://<public-ip>:3010/ and https://<public-ip>:3011/.
Login with your chosen username and password.
If the IP shows as your-vps-ip, replace it with your server's public IP (curl ifconfig.me).

