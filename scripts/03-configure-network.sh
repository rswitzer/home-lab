#!/bin/bash
# Configure network settings for Raspberry Pi

set -e

echo "=========================================="
echo "Network Configuration"
echo "=========================================="

# Get current hostname
CURRENT_HOSTNAME=$(hostname)
echo "Current hostname: $CURRENT_HOSTNAME"

# Ask for new hostname
read -p "Enter new hostname (or press Enter to keep current): " NEW_HOSTNAME
if [ ! -z "$NEW_HOSTNAME" ] && [ "$NEW_HOSTNAME" != "$CURRENT_HOSTNAME" ]; then
    echo "Setting hostname to: $NEW_HOSTNAME"
    sudo hostnamectl set-hostname $NEW_HOSTNAME
    echo "Hostname updated. Changes will take effect after reboot."
fi

# Display current IP
echo ""
echo "Current network configuration:"
ip -4 addr show | grep inet

# Ask if user wants to set static IP
echo ""
read -p "Do you want to configure a static IP? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "To set a static IP, you'll need to edit /etc/dhcpcd.conf"
    echo "Example configuration:"
    echo ""
    echo "interface eth0"
    echo "static ip_address=192.168.1.100/24"
    echo "static routers=192.168.1.1"
    echo "static domain_name_servers=192.168.1.1 8.8.8.8"
    echo ""
    read -p "Open /etc/dhcpcd.conf in editor? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo ${EDITOR:-nano} /etc/dhcpcd.conf
        echo "Network configuration updated. Reboot required for changes to take effect."
    fi
fi

echo "=========================================="
echo "Network configuration complete!"
echo "=========================================="
