#!/bin/bash
# Master setup script - runs all setup scripts in order

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Raspberry Pi Homelab Complete Setup"
echo "=========================================="
echo "This script will run all setup scripts in order."
echo "You can also run individual scripts separately."
echo ""

# Array of scripts to run
# Note: 06-backup.sh is intentionally excluded as it should be run separately after setup
SCRIPTS=(
    "00-initial-setup.sh"
    "01-install-docker.sh"
    "02-install-docker-compose.sh"
    "03-configure-network.sh"
    "04-security-hardening.sh"
    "05-setup-monitoring.sh"
)

echo "Scripts to be executed:"
for script in "${SCRIPTS[@]}"; do
    echo "  - $script"
done
echo ""

read -p "Continue with full setup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

# Run each script
for script in "${SCRIPTS[@]}"; do
    SCRIPT_PATH="${SCRIPT_DIR}/${script}"
    if [ -f "$SCRIPT_PATH" ]; then
        echo ""
        echo "=========================================="
        echo "Running: $script"
        echo "=========================================="
        bash "$SCRIPT_PATH"
    else
        echo "Warning: $SCRIPT_PATH not found, skipping..."
    fi
done

echo ""
echo "=========================================="
echo "Complete setup finished!"
echo ""
echo "Recommended next steps:"
echo "1. Reboot the system: sudo reboot"
echo "2. Log back in and verify Docker: docker ps"
echo "3. Set up your applications using Docker Compose"
echo "4. Configure regular backups using 06-backup.sh"
echo "=========================================="
