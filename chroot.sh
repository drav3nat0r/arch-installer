#!/bin/bash
set -e

# Safety check: Ensure the script is running inside the chroot environment as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: This script must be run as root inside the chroot environment."
    exit 1
fi

echo "=================================================="
echo "   CHROOT CONFIGURATION (Arch Wiki Section 4)    "
echo "=================================================="

# ==============================================================================
# 1. TIME ZONE (Arch Wiki Guideline 4.1)
# ==============================================================================
echo "-> Configuring regional timezone (Africa/Johannesburg)..."
ln -sf /usr/share/zoneinfo/Africa/Johannesburg /etc/localtime
hwclock --systohc

# ==============================================================================
# 2. LOCALIZATION (Arch Wiki Guideline 4.2)
# ==============================================================================
echo "-> Configuring system locales..."
# Explicitly append the English US UTF-8 character map configuration
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

# Set the primary system language variable
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# ==============================================================================
# 3. NETWORK CONFIGURATION (Arch Wiki Guideline 4.3)
# ==============================================================================
echo "-> Setting local network hostname..."
echo "arch-box" > /etc/hostname

# ==============================================================================
# 4. INITIAL RAMDISK (Arch Wiki Guideline 4.4)
# ==============================================================================
echo "-> Rebuilding initial ramdisk environment (initramfs)..."
# Explicitly triggers a full preset build to match virtual hardware hooks
mkinitcpio -p linux

# ==============================================================================
# 5. USER PROFILES & PASSWORDS (Arch Wiki Guideline 4.5)
# ==============================================================================
echo "-> Managing user access control and profiles..."
# Define administrative root password
echo "root:password123" | chpasswd

# Create your primary user profile with wheel, storage, and power group flags
useradd -m -g users -G wheel,storage,power -s /bin/bash mornay
echo "mornay:password123" | chpasswd

# Securely configure sudoers by dropping a custom rule into the .d staging path
mkdir -p /etc/sudoers.d
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# ==============================================================================
# 6. BOOTLOADER SETUP (Arch Wiki Guideline 4.6)
# ==============================================================================
echo "-> Installing system utilities and virtual target drivers..."
# Pull down GRUB, UEFI boot manager utilities, and QEMU-specific guest support
pacman -S --noconfirm grub efibootmgr xf86-video-qxl qemu-guest-agent

echo "-> Deploying GRUB payload to motherboard NVRAM..."
# Writes the binaries directly to the mounted EFI directory
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

echo "-> Compiling core bootloader runtime configuration menu..."
grub-mkconfig -o /boot/grub/grub.cfg

# ==============================================================================
# 7. ENVIRONMENT SERVICES
# ==============================================================================
echo "-> Activating underlying daemon infrastructure..."
systemctl enable NetworkManager
systemctl enable qemu-guest-agent

echo "=================================================="
echo "🎯 Chroot configuration complete! Exiting environment..."
echo "=================================================="
