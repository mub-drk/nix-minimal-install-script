#!/usr/bin/env bash

set -e  # Exit on errors

### Helper Functions ###

# Prompt user with a default value
prompt() {
    local message=$1
    local default=$2
    read -p "$message [$default]: " input
    echo "${input:-$default}"
}

# Display an error message and exit
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Partition and format disk
partition_disk() {
    echo "Partitioning and formatting $DISK..."
    parted $DISK -- mklabel gpt
    parted $DISK -- mkpart ESP fat32 1MiB 512MiB
    parted $DISK -- set 1 boot on
    parted $DISK -- mkpart primary ext4 512MiB 100%

    mkfs.fat -F 32 "${DISK}1"
    mkfs.ext4 "${DISK}2"

    mount "${DISK}2" /mnt
    mkdir -p /mnt/boot
    mount "${DISK}1" /mnt/boot
    echo "Disk partitioned and mounted."
}

# Clone GitHub repository
clone_repository() {
    echo "Cloning NixOS configuration repository..."
    git clone "$REPO_URL" /mnt/etc/nixos || error_exit "Failed to clone repository."
    echo "Repository cloned to /mnt/etc/nixos."
}

# Install NixOS
install_nixos() {
    echo "Installing NixOS..."
    nixos-install
    echo "Installation complete! You may now reboot."
}

# Validate disk
validate_disk() {
    if [[ ! -b $DISK ]]; then
        error_exit "Invalid disk: $DISK"
    fi
}

### Main Script ###

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    error_exit "This script must be run as root!"
fi

echo "Welcome to the NixOS Interactive Installer (Arch Install Script Replica)"
echo "------------------------------------------------------------------------"

# Select the installation disk
lsblk
DISK=$(prompt "Enter the disk to install NixOS (e.g., /dev/sda)" "/dev/sda")
validate_disk

# Partition the disk
partition_disk

# Ask for the hostname
HOSTNAME=$(prompt "Enter a hostname for your system" "nixos")

# Ask for a GitHub repository link
REPO_URL=$(prompt "Enter the GitHub repository link containing your NixOS configuration" "")

if [[ -z $REPO_URL ]]; then
    error_exit "You must provide a valid GitHub repository URL."
fi

# Clone the GitHub repository
clone_repository

# Modify the configuration with the hostname
echo "Adding hostname to configuration.nix..."
echo "networking.hostName = \"$HOSTNAME\";" >> /mnt/etc/nixos/configuration.nix

# Install the system
install_nixos
