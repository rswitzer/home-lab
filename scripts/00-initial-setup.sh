#!/bin/bash
# Initial setup script for Raspberry Pi
# Updates system and installs essential packages

set -e

echo "=========================================="
echo "Raspberry Pi Initial Setup"
echo "=========================================="

# Update package lists
echo "Updating package lists..."
sudo apt-get update

# Upgrade existing packages
echo "Upgrading existing packages..."
sudo apt-get upgrade -y

# Install essential packages
echo "Installing essential packages..."
sudo apt-get install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    tmux \
    net-tools \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release

# Clean up
echo "Cleaning up..."
sudo apt-get autoremove -y
sudo apt-get autoclean

echo "=========================================="
echo "Initial setup complete!"
echo "=========================================="
