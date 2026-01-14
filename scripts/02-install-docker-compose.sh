#!/bin/bash
# Install Docker Compose on Raspberry Pi

set -e

echo "=========================================="
echo "Docker Compose Installation"
echo "=========================================="

# Check if Docker Compose is already installed
if command -v docker-compose &> /dev/null; then
    echo "Docker Compose is already installed:"
    docker-compose --version
    read -p "Do you want to reinstall? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Install Docker Compose using pip
echo "Installing Docker Compose..."
sudo apt-get install -y python3-pip libffi-dev
sudo pip3 install docker-compose

# Verify installation
echo "=========================================="
echo "Docker Compose installation complete!"
echo "Docker Compose version:"
docker-compose --version
echo "=========================================="
