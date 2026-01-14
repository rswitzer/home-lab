#!/bin/bash
# Setup monitoring tools for Raspberry Pi

set -e

echo "=========================================="
echo "Monitoring Setup"
echo "=========================================="

# Install monitoring tools
echo "Installing monitoring tools..."
sudo apt-get install -y \
    htop \
    iotop \
    iftop \
    nmon \
    sysstat

# Enable sysstat
echo "Enabling sysstat..."
sudo systemctl enable sysstat
sudo systemctl start sysstat

# Install Prometheus Node Exporter (optional)
read -p "Install Prometheus Node Exporter? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Installing Node Exporter..."
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        armv7l)
            NODE_ARCH="linux-armv7"
            ;;
        aarch64|arm64)
            NODE_ARCH="linux-arm64"
            ;;
        x86_64)
            NODE_ARCH="linux-amd64"
            ;;
        *)
            echo "Warning: Unsupported architecture: $ARCH"
            echo "Skipping Node Exporter installation"
            NODE_ARCH=""
            ;;
    esac
    
    if [ -n "$NODE_ARCH" ]; then
        # Download latest node exporter
        NODE_EXPORTER_VERSION="1.7.0"
        echo "Downloading Node Exporter for $NODE_ARCH..."
        wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.${NODE_ARCH}.tar.gz -O /tmp/node_exporter.tar.gz
        
        tar -xzf /tmp/node_exporter.tar.gz -C /tmp/
        sudo cp /tmp/node_exporter-${NODE_EXPORTER_VERSION}.${NODE_ARCH}/node_exporter /usr/local/bin/
        sudo chmod +x /usr/local/bin/node_exporter
    
    # Create systemd service
    sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=nobody
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF
        
        # Enable and start service
        sudo systemctl daemon-reload
        sudo systemctl enable node_exporter
        sudo systemctl start node_exporter
        
        echo "Node Exporter installed and running on port 9100"
        rm -rf /tmp/node_exporter*
    fi
fi

echo "=========================================="
echo "Monitoring setup complete!"
echo "Available commands:"
echo "  htop    - Interactive process viewer"
echo "  iotop   - Monitor disk I/O"
echo "  iftop   - Monitor network bandwidth"
echo "  nmon    - System performance monitor"
echo "=========================================="
