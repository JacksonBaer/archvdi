#!/bin/bash
# Thin Client Setup for Arch Linux with LXDE
# Author: Jackson Baer (Adapted for Arch by [Your Name])
# Date: 27 Nov 2024

# Define the username
USERNAME=vdiuser

# Establish log file
LOG_FILE="/var/log/thinclient_setup.log"

log_event() {
    echo "$(date) [$(hostname)] [User: $(whoami)]: $1" >> "$LOG_FILE"
}

# Ensure the log file exists
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    log_event "Log file created."
fi

log_event "Starting Thin Client Setup script"

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    log_event "User ID is $EUID. Exiting as not root."
    exit
fi

# Prompt for the Proxmox IP or DNS name
read -p "Enter the Proxmox IP or DNS name: " PROXMOX_IP

# Prompt for the Thin Client Title
read -p "Enter the Thin Client Title: " VDI_TITLE

# Prompt for authentication type
while true; do
    read -p "Enter authentication type (pve or pam): " VDI_AUTH
    if [ "$VDI_AUTH" == "pve" ] || [ "$VDI_AUTH" == "pam" ]; then
        echo "You selected $VDI_AUTH authentication."
        break
    else
        echo "Error: Invalid input. Please enter 'pve' or 'pam'."
    fi
done

# Prompt for the Network Adapter
read -p "Enter your Network Adapter: " INET_ADAPTER

log_event "Proxmox IP/DNS entered: $PROXMOX_IP"
log_event "Thin Client Title entered: $VDI_TITLE"
log_event "Authentication type selected: $VDI_AUTH"
log_event "Network adapter selected: $INET_ADAPTER"

# Update and upgrade system
echo "Updating system packages"
log_event "Updating system packages"
sudo pacman -Syu --noconfirm

# Install required packages
log_event "Installing required dependencies..."
echo "Installing required dependencies..."
sudo pacman -S --noconfirm lxde lightdm lightdm-gtk-greeter python-pip virt-viewer zenity python-tk

# Install Python dependencies
echo "Installing Python dependencies..."
pip3 install proxmoxer "PySimpleGUI<5.0.0"

# Clone the repository and navigate into it
echo "Cloning PVE-VDIClient repository..."
log_event "Cloning PVE-VDIClient repository..."

cd /home/$USERNAME
git clone https://github.com/joshpatten/PVE-VDIClient.git
cd ./PVE-VDIClient || { echo "Failed to change directory to PVE-VDIClient"; exit 1; }

# Make the script executable
echo "Making vdiclient.py executable..."
chmod +x vdiclient.py

# Create the configuration directory and file
echo "Setting up configuration..."
sudo mkdir -p /etc/vdiclient
sudo tee /etc/vdiclient/vdiclient.ini > /dev/null <<EOL
[General]
title = $VDI_TITLE
icon=vdiicon.ico
logo=vdilogo.png
kiosk=false
theme=BrightColors

[Authentication]
auth_backend=$VDI_AUTH
auth_totp=false
tls_verify=false

[Hosts]
$PROXMOX_IP=8006
EOL

# Copy vdiclient.py to /usr/local/bin
echo "Copying vdiclient.py to /usr/local/bin..."
log_event "Copying vdiclient.py to /usr/local/bin..."
sudo cp vdiclient.py /usr/local/bin/vdiclient

# Create thinclient script
echo "Creating thinclient script..."
touch /home/$USERNAME/thinclient

cat <<'EOL' > /home/$USERNAME/thinclient
#!/bin/bash
cd ~/PVE-VDIClient
while true; do
    /usr/bin/python3 ~/PVE-VDIClient/vdiclient.py
done
EOL

chmod +x /home/$USERNAME/thinclient

# Configure LightDM for autologin and LXDE
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"

echo "Configuring LightDM for autologin and LXDE session..."
log_event "Configuring LightDM autologin for $USERNAME with LXDE session."

{
  echo "[Seat:*]"
  echo "autologin-user=$USERNAME"
  echo "autologin-user-timeout=0"
  echo "xserver-command=X -s 0 -dpms"
  echo "user-session=lxde"  # Specifies LXDE as the session
} >"$LIGHTDM_CONF"

if [ $? -eq 0 ]; then
    echo "LightDM autologin configured successfully for $USERNAME with LXDE."
    log_event "LightDM autologin configured successfully for $USERNAME with LXDE."
else
    echo "Failed to configure LightDM autologin with LXDE."
    exit 1
fi

# Add the script to autostart
AUTOSTART_DIR="/home/$USERNAME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"
echo "[Desktop Entry]
Type=Application
Exec=/home/$USERNAME/thinclient
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_US]=Thin Client
Name=Thin Client
Comment[en_US]=Starts Thin Client
Comment=Starts Thin Client" > "$AUTOSTART_DIR/thinclient.desktop"

# Restart system for changes to take effect
log_event "Rebooting System to Apply Changes"
sudo reboot
