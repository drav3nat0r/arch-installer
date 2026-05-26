#!/bin/bash
set -e

# Safety check: Ensure the script is running as root/superuser
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: This script must be run as root to install system packages."
    exit 1
fi

echo "=========================================="
echo "   PHASE 3: PURE WAYLAND PLASMA DESKTOP   "
echo "=========================================="

echo "-> Installing core graphics drivers and sudo framework..."
# Added 'sudo' here so your 'mornay' user can use it after we reboot!
pacman -S --noconfirm mesa sudo

echo "-> Installing minimalist KDE Plasma Desktop (Wayland Native)..."
# plasma-desktop: Just the core shell, panel, and system settings
# sddm: The login screen display manager
# konsole: The native KDE terminal emulator
pacman -S --noconfirm plasma-desktop sddm konsole

echo "-> Installing XWayland compatibility layer..."
pacman -S --noconfirm xorg-xwayland

echo "-> Activating the login manager service..."
systemctl enable sddm.service

# ==============================================================================
# YOUR CUSTOM PACKAGES SECTION
# ==============================================================================
echo "-> Installing core utility packages..."
MY_PACKAGES=(
    "firefox"       # Web browser
    "fastfetch"     # Modern system info display tool
    "ufw"           # Uncomplicated Firewall
)

pacman -S --noconfirm "${MY_PACKAGES[@]}"

if pacman -Qi ufw > /dev/null 2>&1; then
    systemctl enable ufw.service
fi

echo "=========================================="
echo "🥇 WAYLAND DESKTOP READY! REBOOTING...   "
echo "=========================================="
sleep 2
reboot
