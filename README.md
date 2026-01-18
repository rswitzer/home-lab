# home-lab
Raspberry PI Home lab setup

## Hardware

- 3 × Raspberry Pi 5 — Ubuntu Server 25.10 (64-bit), 8 GB RAM each  
  - 1 × control plane node  
  - 2 × worker nodes
- 1 × Raspberry Pi 4 — Ubuntu Server 25.10 (64-bit), 8 GB RAM — designated as the database node

All SD/eMMC images were flashed using Raspberry Pi Imager: https://www.raspberrypi.com/software/

Quick Raspberry Pi Imager instructions
1. Open Raspberry Pi Imager.
2. Click "Choose OS" → "Other general-purpose OS" → "Ubuntu" → select "Ubuntu Server 25.10 (64-bit)".
3. Click the gear icon (settings) before writing:
   - Enable SSH.
   - Optionally set username/password or paste an SSH public key.
   - Configure Wi‑Fi/hostname if needed.
4. Select storage and click "Write".

Boot each Pi with the flashed image and confirm SSH access before joining them to your cluster.

## Ansible

Install Ansible using the distro-specific instructions: https://docs.ansible.com/projects/ansible/latest/installation_guide/installation_distros.html

## Ping/Pong

Quick ad-hoc ping using Ansible (uses inventory file `inventory` in project root):

    ansible all -i inventory -m ping --ask-pass

Notes:
- Use --ask-pass to prompt for an SSH password; omit if using SSH keys.
- For a specific host group, replace "all" with the group name from your inventory.
