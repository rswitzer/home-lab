#!/bin/bash
# Install Docker on Raspberry Pi

set -e

echo "=========================================="
echo "Docker Installation"
echo "=========================================="

# Check if Docker is already installed
if command -v docker &> /dev/null; then
    echo "Docker is already installed:"
    docker --version
    read -p "Do you want to reinstall? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Install Docker using convenience script
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sudo sh /tmp/get-docker.sh
rm /tmp/get-docker.sh

# Add current user to docker group
echo "Adding user to docker group..."
sudo usermod -aG docker $USER

# Enable Docker service
echo "Enabling Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

echo "=========================================="
echo "Docker installation complete!"
echo "Docker version:"
docker --version
echo ""
echo "NOTE: You may need to log out and back in for group changes to take effect"
echo "=========================================="
