#!/bin/bash
# =========================================================
# VOID LINUX GNOME (REAL FIX - NO META PKG)
# =========================================================

set -euo pipefail

echo "[*] Updating system..."
sudo xbps-install -Syu

echo "[*] Installing core services..."
sudo xbps-install -y elogind dbus

# Enable runit services
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

echo "[*] Installing FULL GNOME stack (Void-safe)..."

sudo xbps-install -y \
    gnome-shell \
    gnome-session \
    gnome-settings-daemon \
    gnome-control-center \
    gnome-terminal \
    nautilus \
    gdm \
    mutter \
    gsettings-desktop-schemas \
    adwaita-icon-theme \
    network-manager-applet \
    NetworkManager \
    dg-user-dirs \
    xdg-utils \
    polkit \
    polkit-gnome

echo "[*] Enabling essential services..."

enable_service NetworkManager
enable_service gdm

sudo sv up NetworkManager || true
sudo sv up gdm || true

echo "[*] Cleaning broken configs..."
sudo rm -rf /var/lib/gdm/.config/dconf 2>/dev/null || true

echo "[*] Fixing runtime dir..."
sudo mkdir -p /run/user/$(id -u)
sudo chown $(whoami):$(whoami) /run/user/$(id -u)
sudo chmod 700 /run/user/$(id -u)

echo
echo "=================================="
echo "✅ DONE — Reboot now"
echo "sudo reboot"
echo "=================================="
