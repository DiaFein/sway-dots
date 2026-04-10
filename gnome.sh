#!/bin/bash
# =========================================================
# VOID LINUX GNOME (RUNIT-SAFE) — BULLETPROOF INSTALLER
# Author: ChatGPT (Optimized for stability)
# =========================================================

set -euo pipefail

# ---------- COLORS ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[*] $1${NC}"; }
ok()  { echo -e "${GREEN}[✔] $1${NC}"; }
err() { echo -e "${RED}[✖] $1${NC}"; }

# ---------- ROOT CHECK ----------
if [ "$EUID" -ne 0 ]; then
  err "Run as root (sudo ./install-gnome-void.sh)"
  exit 1
fi

log "Updating system..."
xbps-install -Syu

# ---------- CORE SERVICES ----------
log "Installing core services (elogind, dbus)..."
xbps-install -y elogind dbus

# Enable services (runit way)
enable_service() {
    local svc=$1
    if [ ! -d "/var/service/$svc" ]; then
        ln -s "/etc/sv/$svc" "/var/service/"
        ok "Enabled $svc"
    else
        ok "$svc already enabled"
    fi
}

enable_service elogind
enable_service dbus

sleep 2

# Start services (safe)
sv up elogind || true
sv up dbus || true

# ---------- VERIFY SERVICES ----------
log "Checking service status..."
sv status elogind || err "elogind not running!"
sv status dbus || err "dbus not running!"

# ---------- PAM FIX ----------
log "Ensuring PAM elogind integration..."
if ! grep -q pam_elogind /etc/pam.d/system-login 2>/dev/null; then
    echo "session   optional   pam_elogind.so" >> /etc/pam.d/system-login
    ok "Added pam_elogind"
else
    ok "pam_elogind already present"
fi

# ---------- INSTALL FULL GNOME ----------
log "Installing full GNOME stack (safe set)..."

xbps-install -y \
    gnome gnome-extra \
    gnome-session gnome-shell gnome-control-center \
    gnome-settings-daemon gnome-terminal nautilus \
    mutter gsettings-desktop-schemas \
    adwaita-icon-theme gdm xorg

# ---------- CLEAN BROKEN STATES ----------
log "Cleaning possible broken GNOME cache..."
rm -rf /var/lib/gdm/.config/dconf 2>/dev/null || true

# ---------- ENABLE GDM ----------
log "Enabling GDM (display manager)..."
enable_service gdm
sv up gdm || true

# ---------- XDG RUNTIME FIX ----------
log "Fixing XDG runtime dir permissions..."
mkdir -p /run/user/$(id -u)
chown $(logname):$(logname) /run/user/$(id -u)
chmod 700 /run/user/$(id -u)

# ---------- FINAL CHECK ----------
log "Running final checks..."

if ! command -v gnome-session >/dev/null; then
    err "GNOME install failed!"
    exit 1
fi

if ! loginctl >/dev/null 2>&1; then
    err "elogind not working properly!"
else
    ok "elogind working"
fi

ok "GNOME installation complete!"

echo
echo "==========================================="
echo "🚀 REBOOT NOW:"
echo "sudo reboot"
echo
echo "Login via GDM (GUI login screen)"
echo "==========================================="
