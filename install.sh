#!/bin/bash

echo "--- Starting Preflight Checks ---"

# 1. Prevent root execution
if [ "$EUID" -eq 0 ]; then 
  echo "ERROR: Do not run this script as root. It will ask for sudo when needed."
  exit 1
fi

# 2. Check for Void runit services
for service in dbus elogind; do
    if [ ! -L "/var/service/$service" ]; then
        echo "CRITICAL: Service '$service' is not enabled in /var/service/"
        echo "Fix this by running: sudo ln -s /etc/sv/$service /var/service/"
        exit 1
    fi
done

echo "Preflight passed! System services are ready."

echo "--- Installing Packages for AMD/Sway ---"
# Installing core Wayland/Sway packages and AMD drivers
sudo xbps-install -Sy \
    linux-firmware-amd mesa-dri mesa-vulkan-radeon mesa-vaapi mesa-vdpau \
    sway waybar foot mako wmenu \
    grim slurp wl-clipboard swaybg swaylock swayidle \
    brightnessctl playerctl \
    font-awesome6 nerd-fonts-symbols-ttf \
    git

echo "--- Fetching Dotfiles ---"
DOTS_DIR="$HOME/sway-dots"
# Using your SSH URL
REPO_URL="git@github.com:DiaFein/sway-dots.git"

if [ -d "$DOTS_DIR" ]; then
    echo "Directory exists. Pulling updates..."
    cd "$DOTS_DIR" && git pull
else
    echo "Cloning repository via SSH..."
    git clone "$REPO_URL" "$DOTS_DIR" || { echo "Git clone failed! Ensure your SSH keys are set up and added to GitHub."; exit 1; }
fi

echo "--- Deploying Configuration ---"
mkdir -p "$HOME/.config"

configs=("sway" "waybar" "foot" "mako")
TIMESTAMP=$(date +%s)

for folder in "${configs[@]}"; do
    TARGET_DIR="$HOME/.config/$folder"
    
    # Backup existing config safely with a timestamp to prevent overwrites
    if [ -d "$TARGET_DIR" ] && [ ! -L "$TARGET_DIR" ]; then
        echo "Backing up existing $folder to ${folder}.bak.$TIMESTAMP"
        mv "$TARGET_DIR" "${TARGET_DIR}.bak.$TIMESTAMP"
    elif [ -L "$TARGET_DIR" ]; then
        echo "Removing old symlink for $folder"
        rm "$TARGET_DIR"
    fi
    
    # Create the new symlink directly to the repo
    ln -s "$DOTS_DIR/$folder" "$TARGET_DIR"
    echo "Symlinked $folder"
done

echo "--- Finalizing Permissions ---"
# Ensure your user has permissions to access AMD hardware and session management
sudo usermod -aG video,render,input,_seatd $(whoami)

echo "--- INSTALLATION COMPLETE ---"
echo "Reboot your computer, then start your session from the TTY with:"
echo "dbus-run-session sway"
