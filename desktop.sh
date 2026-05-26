#!/bin/bash
set -e

echo "=========================================="
echo "   PHASE 3: PURE WAYLAND PLASMA DESKTOP   "
echo "=========================================="

echo "-> Installing core graphics drivers..."
# mesa provides the open-source 3D graphics drivers needed for modern Wayland rendering
sudo pacman -S --noconfirm mesa

echo "-> Installing minimalist KDE Plasma Desktop (Wayland Native)..."
# plasma-desktop: Just the core shell, panel, and system settings
# sddm: The login screen display manager (handles Wayland hand-off beautifully)
# alacritty: Terminal emulator
sudo pacman -S --noconfirm plasma-desktop sddm alacritty

echo "-> Installing XWayland compatibility layer..."
# xorg-xwayland: Essential for running legacy apps that don't support Wayland natively yet
sudo pacman -S --noconfirm xorg-xwayland

echo "-> Activating the login manager service..."
sudo systemctl enable sddm.service

# ==============================================================================
# YOUR CUSTOM PACKAGES SECTION
# ==============================================================================
echo "-> Installing core utility packages..."
MY_PACKAGES=(
    "brave-bin"       # Web browser (runs natively on Wayland)
    "fastfetch"     # Modern, faster alternative to the archived neofetch
    "ufw"           # Uncomplicated Firewall
)

sudo pacman -S --noconfirm "${MY_PACKAGES[@]}"

if pacman -Qi ufw > /dev/null 2>&1; then
    sudo systemctl enable ufw.service
fi

echo "=========================================="
echo "🥇 WAYLAND DESKTOP READY! REBOOTING...   "
echo "=========================================="
sleep 2
sudo reboot
