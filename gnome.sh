#!/bin/bash
# =========================================================
# VOID LINUX — GNOME WAYLAND ONLY (RUNIT SAFE)
# =========================================================

set -euo pipefail

echo "[*] Updating system..."
sudo xbps-install -Syu

echo "[*] Installing core services..."
sudo xbps-install -y elogind dbus

enable_service() {
    [ -d "/var/service/$1" ] || sudo ln -s /etc/sv/$1 /var/service/
}

enable_service elogind
enable_service dbus

sudo sv up elogind || true
sudo sv up dbus || true

# PAM fix
if ! grep -q pam_elogind /etc/pam.d/system-login; then
    echo "session optional pam_elogind.so" | sudo tee -a /etc/pam.d/system-login
fi

echo "[*] Installing GNOME (Wayland components)..."

sudo xbps-install -y \
    gnome-shell \
    gnome-session \
    gnome-settings-daemon \
    gnome-control-center \
    gnome-terminal \
    nautilus \
    mutter \
    gsettings-desktop-schemas \
    adwaita-icon-theme \
    gdm \
    NetworkManager \
    network-manager-applet \
    polkit \
    polkit-gnome \
    xdg-user-dirs \
    xdg-utils \
    mesa-dri \
    mesa-vulkan-radeon

# Enable services
enable_service NetworkManager
enable_service gdm

sudo sv up NetworkManager || true
sudo sv up gdm || true

# Force Wayland (disable Xorg fallback)
echo "[*] Forcing Wayland session..."
sudo mkdir -p /etc/gdm
echo -e "[daemon]\nWaylandEnable=true\nDefaultSession=gnome-wayland.desktop" | sudo tee /etc/gdm/custom.conf

# Remove Xorg fallback session if exists
sudo rm -f /usr/share/xsessions/gnome.desktop 2>/dev/null || true

# Clean broken configs
echo "[*] Cleaning GNOME cache..."
sudo rm -rf /var/lib/gdm/.config/dconf 2>/dev/null || true

# Fix runtime dir
echo "[*] Fixing runtime..."
sudo mkdir -p /run/user/$(id -u)
sudo chown $(whoami):$(whoami) /run/user/$(id -u)
sudo chmod 700 /run/user/$(id -u)

echo
echo "======================================"
echo "✅ WAYLAND GNOME READY"
echo "Reboot: sudo reboot"
echo "======================================"
