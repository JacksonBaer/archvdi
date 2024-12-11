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
log_event() {
    if command -v hostname &> /dev/null; then
        echo "$(date) [$(hostname)] [User: $(whoami)]: $1" >> "$LOG_FILE"
    else
        echo "$(date) [Unknown Host] [User: $(whoami)]: $1" >> "$LOG_FILE"
    fi
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
    exit 1
fi

# Ensure required packages for hostname and Python
sudo pacman -S --noconfirm inetutils python python-pip
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
sudo pacman -S --noconfirm gnome gdm python-pip virt-viewer zenity tk

# Install Python dependencies
echo "Installing Python dependencies..."
pip3 install proxmoxer "PySimpleGUI<5.0.0" --break-system-packages

# Clone the repository and navigate into it
echo "Cloning PVE-VDIClient repository..."
log_event "Cloning PVE-VDIClient repository..."

cd /home/vdiuser
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
touch /home/vdiuser/thinclient

cat <<'EOL' > /home/vdiuser/thinclient
#!/bin/bash
cd ~/PVE-VDIClient
while true; do
    /usr/bin/python3 ~/PVE-VDIClient/vdiclient.py
done
EOL

chmod +x /home/vdiuser/thinclient

# Configure LightDM for autologin and LXDE
GDM_CONF="/etc/gdm/custom.conf"

# Configure GDM for autologin and GNOME session
echo "Configuring GDM for autologin and GNOME session..."
log_event "Configuring GDM autologin for vdiuser with GNOME session."

{
  echo "[daemon]"
  echo "AutomaticLoginEnable=true"
  echo "AutomaticLogin=vdiuser"
} > "$GDM_CONF"

if [ $? -eq 0 ]; then
    echo "GDM autologin configured successfully for vdiuser with GNOME."
    log_event "GDM autologin configured successfully for vdiuser with GNOME."
else
    echo "Failed to configure GDM autologin with GNOME."
    exit 1
fi
