#!/bin/bash
# Install Docker Compose on Raspberry Pi

set -e

echo "=========================================="
echo "Docker Compose Installation"
echo "=========================================="

# Check if Docker Compose is already installed
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    echo "Docker Compose is already installed:"
    docker compose version
    read -p "Do you want to reinstall? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Install Docker Compose plugin (recommended method)
echo "Installing Docker Compose plugin..."
sudo apt-get update
sudo apt-get install -y docker-compose-plugin

# Verify installation
echo "=========================================="
echo "Docker Compose installation complete!"
echo "Docker Compose version:"
docker compose version
echo ""
echo "Note: Use 'docker compose' (not 'docker-compose') with the plugin"
echo "=========================================="
