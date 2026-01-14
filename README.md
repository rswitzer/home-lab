# home-lab
Raspberry Pi Home Lab Setup Scripts

A collection of bash scripts to quickly set up and configure a Raspberry Pi for homelab use.

## Features

- **Initial Setup**: System updates and essential packages
- **Docker & Docker Compose**: Container platform installation
- **Network Configuration**: Static IP and hostname setup
- **Security Hardening**: Firewall, fail2ban, and SSH configuration
- **Monitoring Tools**: System monitoring and optional Prometheus exporter
- **Backup Script**: Simple backup solution for important data
- **Example Configurations**: Docker Compose examples for common homelab services

## Quick Start

### Prerequisites
- Raspberry Pi (3/4/5 or Zero 2 W recommended)
- Fresh Raspberry Pi OS installation
- SSH access to your Pi
- Internet connection

### Installation

1. Clone this repository:
```bash
git clone https://github.com/rswitzer/home-lab.git
cd home-lab
```

2. Make scripts executable (if not already):
```bash
chmod +x scripts/*.sh
```

3. Run the complete setup:
```bash
./scripts/setup-all.sh
```

Or run individual scripts as needed:
```bash
./scripts/00-initial-setup.sh
./scripts/01-install-docker.sh
./scripts/02-install-docker-compose.sh
# ... etc
```

## Scripts

### 00-initial-setup.sh
Updates system packages and installs essential tools:
- curl, wget, git
- vim, htop, tmux
- net-tools, ca-certificates
- And more...

### 01-install-docker.sh
Installs Docker CE using the official convenience script and configures the service.

### 02-install-docker-compose.sh
Installs Docker Compose plugin via the official apt package for ARM compatibility.

### 03-configure-network.sh
Interactive script to:
- Set hostname
- Configure static IP address
- Update network settings

### 04-security-hardening.sh
Enhances security with:
- fail2ban installation and configuration
- UFW firewall setup with sensible defaults
- SSH hardening recommendations

### 05-setup-monitoring.sh
Installs monitoring tools:
- htop, iotop, iftop, nmon
- sysstat for system statistics
- Optional: Prometheus Node Exporter

### 06-backup.sh
Creates backups of:
- Home directories
- /etc configuration
- Docker volumes
- Installed packages list
- Crontab

### setup-all.sh
Master script that runs all setup scripts in sequence.

## Example Configurations

The `configs/` directory contains example configuration files:

- **docker-compose.example.yml**: Sample Docker Compose setup with:
  - Portainer (Docker management UI)
  - Pi-hole (Network-wide ad blocking)
  - Heimdall (Application dashboard)
  - Watchtower (Automatic container updates)

- **network.example**: Static IP configuration
- **ufw.example**: Firewall rules
- **ssh.example**: SSH hardening settings

## Usage Examples

### Deploy Example Docker Services
```bash
cd home-lab
cp configs/docker-compose.example.yml docker-compose.yml
# Edit docker-compose.yml with your settings
docker-compose up -d
```

### Run Regular Backups
```bash
# Create a cron job for weekly backups
crontab -e
# Add: 0 2 * * 0 /path/to/home-lab/scripts/06-backup.sh
```

### Check System Status
```bash
# After running monitoring setup
htop           # Interactive process viewer
sudo iftop     # Network bandwidth monitor
nmon           # System performance monitor
```

## Security Notes

1. **Change default passwords** in docker-compose.yml before deploying
2. **Set up SSH keys** before disabling password authentication
3. **Review firewall rules** in 04-security-hardening.sh before enabling
4. **Keep your system updated**: `sudo apt update && sudo apt upgrade`

## Common Services for Homelab

Consider deploying these services using Docker Compose:
- **Portainer**: Docker management UI
- **Pi-hole**: Network-wide ad blocker
- **Heimdall**: Application dashboard
- **Nextcloud**: Personal cloud storage
- **Home Assistant**: Home automation
- **Grafana + Prometheus**: Monitoring and metrics
- **Jellyfin/Plex**: Media server
- **Nginx Proxy Manager**: Reverse proxy

## Troubleshooting

### Docker permission denied
If you get permission errors with Docker, log out and back in after running the Docker installation script.

### Scripts won't run
Make sure scripts are executable:
```bash
chmod +x scripts/*.sh
```

### Network configuration not applying
After changing network settings, reboot the Pi:
```bash
sudo reboot
```

## Contributing

Feel free to open issues or submit pull requests with improvements!

## License

MIT License - feel free to use and modify for your homelab.
