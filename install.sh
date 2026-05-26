#!/bin/bash
set -e

# ==============================================================================
# PRE-FLIGHT SAFETY CHECKS (Arch Wiki Guideline 1.1 - 1.4)
# ==============================================================================

# 1. Root check
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: This script must be executed with root privileges."
    exit 1
fi

# 2. Verify Boot Mode (Arch Wiki: "Verify the boot mode")
# Check if the system has booted into UEFI mode. If missing, fail out safely.
if [ ! -d "/sys/firmware/efi/efivars" ]; then
    echo "❌ Error: System did not boot in UEFI mode! Clean EFI partitioning is impossible."
    exit 1
fi

echo "=========================================="
echo "   BLOCK 1: INITIALIZING SYSTEM TIME     "
echo "=========================================="
echo "-> Activating Network Time Synchronization (NTP)..."
# Arch Wiki: "Update the system clock"
timedatectl set-ntp true
echo "-> Verified System Time:"
date

echo "=========================================="
echo "   BLOCK 2: DISK IDENTIFICATION           "
echo "=========================================="
echo "Available storage block devices:"
echo "------------------------------------------"
lsblk -dno NAME,SIZE | grep -v 'loop\|airoot\|sr' | awk '{print "👉 /dev/" $1 " (" $2 ")"}'
echo "------------------------------------------"

while true; do
    read -p "Enter the device node name to partition (e.g., vda, sda, nvme0n1): " USER_DRIVE
    TARGET_DRIVE="/dev/$USER_DRIVE"
    if [ -b "$TARGET_DRIVE" ] && [ ! -z "$USER_DRIVE" ]; then
        break
    else
        echo "❌ Invalid block device selection. Try again."
    fi
done

echo "-> Target drive locked: $TARGET_DRIVE"
echo "⚠️ WARNING: Proceeding will irreversibly format $TARGET_DRIVE in 5 seconds..."
sleep 5

# Match exact partition naming conventions (e.g., nvme0n1p1 vs vda1)
if [[ "$TARGET_DRIVE" =~ "nvme" ]]; then
    BOOT_PART="${TARGET_DRIVE}p1"
    ROOT_PART="${TARGET_DRIVE}p2"
else
    BOOT_PART="${TARGET_DRIVE}1"
    ROOT_PART="${TARGET_DRIVE}2"
fi

# ==============================================================================
# PARTITIONING & FORMATTING (Arch Wiki Guideline 2.2 - 2.3)
# ==============================================================================
echo "-> Initializing new GPT scheme and creating partitions..."
(
echo g     # Create a clean GPT partition layout
echo n     # Partition 1 (EFI System Partition)
echo 1     # Partition ID
echo       # Sector default
echo +512M # 512MiB allocation as recommended by wiki
echo t     # Convert type
echo 1     # Type 1 = EFI System Partition (Hex: 0xEF00)
echo n     # Partition 2 (Root Partition)
echo 2     # Partition ID
echo       # Sector default
echo       # Grab remainder of block size
echo w     # Write table to layout disk
) | fdisk "$TARGET_DRIVE"

echo "-> Formatting EFI system file system ($BOOT_PART)..."
mkfs.vfat -F 32 "$BOOT_PART"

echo "-> Formatting Root system file system ($ROOT_PART)..."
mkfs.ext4 -F "$ROOT_PART"

# ==============================================================================
# MOUNTING & BOOTSTRAPPING (Arch Wiki Guideline 3.1 - 3.2)
# ==============================================================================
echo "=========================================="
echo "   BLOCK 3: MOUNTING & BOOTSTRAPPING      "
echo "=========================================="
echo "-> Mounting target filesystems..."
# Arch Wiki: "Mount the file systems"
mount "$ROOT_PART" /mnt
mount --mkdir "$BOOT_PART" /mnt/boot

# Arch Wiki CPU Microcode Detection (Arch Wiki: "Select the mirrors" & "Install essential packages")
# This automatically figures out if your host/VM is running on Intel or AMD architecture 
# and queues up the official vendor security microcode package.
MICROCODE=""
if grep -q "Intel" /proc/cpuinfo; then
    MICROCODE="intel-ucode"
elif grep -q "AMD" /proc/cpuinfo; then
    MICROCODE="amd-ucode"
fi

echo "-> Bootstrapping packages (Target Microcode: ${MICROCODE:-None detected/VM})..."
# Explicitly packages the base environment, kernel, firmware, microcode, and critical workspace tools
pacstrap -K /mnt base linux linux-firmware $MICROCODE nano networkmanager git

echo "-> Building filesystem translation tables (/etc/fstab)..."
# Arch Wiki: "Fstab" (-U forces strict UUID mappings)
genfstab -U /mnt >> /mnt/etc/fstab

echo "=========================================="
echo "   BLOCK 4: THE CHROOT HAND-OFF           "
echo "=========================================="
echo "-> Pulling internal staging script..."
curl -L "https://raw.githubusercontent.com/drav3nat0r/arch-installer/main/chroot.sh" -o /mnt/chroot.sh
chmod +x /mnt/chroot.sh

echo "-> Transitioning execution context into system chroot environment..."
arch-chroot /mnt ./chroot.sh

echo "=========================================="
echo "   BLOCK 5: SYSTEM CLEANUP                "
echo "=========================================="
echo "-> Unmounting runtime file systems cleanly..."
umount -R /mnt

echo "🎉 Script complete. Disconnect installation media and cycle power."
sleep 2
reboot
