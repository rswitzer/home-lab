#!/bin/bash
# Backup script for Raspberry Pi

set -e

# Configuration
BACKUP_DIR="/backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="pi-backup-${TIMESTAMP}"

echo "=========================================="
echo "Raspberry Pi Backup"
echo "=========================================="

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Creating backup directory: $BACKUP_DIR"
    sudo mkdir -p "$BACKUP_DIR"
fi

# Create backup subdirectory
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"
sudo mkdir -p "$BACKUP_PATH"

echo "Backing up to: $BACKUP_PATH"

# Backup important directories
echo "Backing up home directory..."
sudo tar -czf "${BACKUP_PATH}/home.tar.gz" /home 2>/dev/null || true

echo "Backing up /etc..."
sudo tar -czf "${BACKUP_PATH}/etc.tar.gz" /etc 2>/dev/null || true

echo "Backing up Docker volumes (if exists)..."
if [ -d "/var/lib/docker/volumes" ]; then
    sudo tar -czf "${BACKUP_PATH}/docker-volumes.tar.gz" /var/lib/docker/volumes 2>/dev/null || true
fi

# Create a list of installed packages
echo "Creating list of installed packages..."
sudo dpkg --get-selections | sudo tee "${BACKUP_PATH}/installed-packages.txt" > /dev/null

# Save crontab
echo "Backing up crontab..."
crontab -l > "${BACKUP_PATH}/crontab.txt" 2>/dev/null || echo "No crontab found"

# Calculate backup size
BACKUP_SIZE=$(du -sh "$BACKUP_PATH" | cut -f1)

echo "=========================================="
echo "Backup complete!"
echo "Location: $BACKUP_PATH"
echo "Size: $BACKUP_SIZE"
echo ""
echo "To restore, extract the tar.gz files to their respective locations"
echo "=========================================="
