#!/bin/bash
# Security hardening script for Raspberry Pi

set -e

echo "=========================================="
echo "Security Hardening"
echo "=========================================="

# Install fail2ban
echo "Installing fail2ban..."
sudo apt-get install -y fail2ban

# Configure fail2ban
echo "Configuring fail2ban..."
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local 2>/dev/null || true

# Start and enable fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Install and configure UFW (Uncomplicated Firewall)
echo "Installing UFW..."
sudo apt-get install -y ufw

# Configure UFW rules
echo "Configuring UFW rules..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS

# Ask before enabling UFW
read -p "Enable firewall now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo ufw --force enable
    echo "UFW enabled"
else
    echo "UFW configured but not enabled. Run 'sudo ufw enable' when ready."
fi

# SSH hardening recommendations
echo ""
echo "SSH Hardening Recommendations:"
echo "1. Disable root login: PermitRootLogin no"
echo "2. Use SSH keys instead of passwords"
echo "3. Change default SSH port"
echo "4. Disable password authentication: PasswordAuthentication no"
echo ""
read -p "Open SSH config for editing? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo ${EDITOR:-nano} /etc/ssh/sshd_config
    read -p "Restart SSH service? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo systemctl restart ssh
    fi
fi

echo "=========================================="
echo "Security hardening complete!"
echo "fail2ban status:"
sudo systemctl status fail2ban --no-pager | head -5
echo ""
echo "UFW status:"
sudo ufw status
echo "=========================================="
