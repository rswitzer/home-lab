# home-lab

Ansible playbooks for managing a Raspberry Pi homelab cluster.

## Hardware

| Role          | Board            | Hostname             |
| ------------- | ---------------- | -------------------- |
| Control plane | Raspberry Pi 5   | `pi-control-plane`   |
| Worker 1      | Raspberry Pi 5   | `pi-node1`           |
| Worker 2      | Raspberry Pi 5   | `pi-node2`           |
| Database      | Raspberry Pi 4   | `pi-db`              |

All nodes run **Ubuntu Server 25.10 (64-bit)**.

## Flashing the Pis

1. Download and open [Raspberry Pi Imager](https://www.raspberrypi.com/software/).
2. Choose **Ubuntu Server 25.10 (64-bit)** as the OS.
3. Click the gear icon (or **Edit Settings**) before writing and configure:
   - **Hostname** — set to the hostname from the table above (e.g. `pi-control-plane`).
   - **Username / password** — create user `rachel` (or whatever you use) with a password.
   - **Enable SSH** — check "Allow public-key authentication only" if you already have a key, otherwise use password authentication for now.
4. Write to the SD card and boot the Pi.
5. Repeat for each node.

## Networking (mDNS)

The inventory uses `.local` hostnames (e.g. `pi-node1.local`) which rely on **mDNS / Avahi**. Ubuntu Server includes `avahi-daemon` by default, so this should work out of the box on your local network.

Verify each node is reachable before continuing:

```bash
ping pi-control-plane.local
ping pi-node1.local
ping pi-node2.local
ping pi-db.local
```

If a hostname doesn't resolve, make sure the Pi is booted and on the same network. As a fallback you can replace the `.local` hostnames in `inventory.ini` with IP addresses.

## Prerequisites

On your **controller machine** (the computer you run Ansible from):

1. **Ansible** — install via your package manager or pip. See the [Ansible install guide](https://docs.ansible.com/ansible/latest/installation_guide/index.html).
2. **SSH keypair** — generate an ed25519 key if you don't already have one:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
```

## Project Structure

```
.
├── ansible.cfg          # Ansible settings (inventory path, timeouts, etc.)
├── inventory.ini        # Host definitions and groups
├── site.yml             # Central entrypoint — sets up all Pis
├── common.yml           # Base OS setup (apt update & upgrade)
├── wait-for-ssh.yml     # Preflight — waits for all hosts to be reachable
└── bootstrap-key.yml    # One-shot playbook to install your SSH public key
```

- **`ansible.cfg`** — points Ansible at `inventory.ini` and disables host-key checking so first connections don't hang.
- **`inventory.ini`** — defines four groups: `control_plane`, `workers`, `db`, and a `cluster` group that combines control plane + workers. All hosts use `ansible_user=rachel`.
- **`site.yml`** — the main entrypoint. Imports `wait-for-ssh.yml` then `common.yml` so you can set up every Pi with one command.
- **`common.yml`** — base OS setup applied to all hosts: updates the apt cache and runs a full dist-upgrade.
- **`wait-for-ssh.yml`** — preflight playbook that polls until SSH is available on every host (up to 180 s).
- **`bootstrap-key.yml`** — copies `~/.ssh/id_ed25519.pub` from your controller into `~/.ssh/authorized_keys` on every host, so future Ansible runs (and SSH sessions) don't need a password. Run this manually before `site.yml`.

## Usage: Setup All Pis

Once SSH keys are in place (see Bootstrap section below), run the central playbook to set up every Pi:

```bash
ansible-playbook site.yml
```

This will wait for all hosts to be reachable, then update and upgrade packages on every node.

## Usage: Bootstrap SSH Keys

After booting all the Pis, check whether you already have passwordless access first:

```bash
ansible all -m ping
```

**If all hosts return `SUCCESS`** — you're done. You pasted your public key in Pi Imager during flashing and don't need to run the bootstrap playbook.

**If you get connection errors or password prompts** — you used password auth when flashing (or skipped the key step). Run the bootstrap playbook once. The playbook includes a small wait step and will poll until SSH is available (up to 180s) before installing your controller's `~/.ssh/id_ed25519.pub`. Pass `--ask-pass` so Ansible can connect with the password you set during imaging:

```bash
ansible-playbook bootstrap-key.yml --ask-pass
```

Tip: to run the bootstrap (or any playbook) against a single host or subset of hosts, add `--limit` followed by a host, group, or pattern. Examples:

```bash
# Run bootstrap only on pi-db
ansible-playbook bootstrap-key.yml --limit pi-db --ask-pass

# Run on two specific hosts
ansible-playbook site.yml --limit "pi-node1,pi-node2"

# Run on a group
ansible-playbook site.yml --limit workers

# Exclude a host
ansible-playbook site.yml --limit "all:!pi-db"
```

> You don't need `-i inventory.ini` — `ansible.cfg` already sets the inventory path.

Then verify:

```bash
ansible all -m ping
```

You should see `SUCCESS` for all four hosts. From here on, no password is needed for Ansible or SSH:

```bash
ssh rachel@pi-node1.local
```

## Troubleshooting

**Hostname doesn't resolve (`pi-node1.local`)**
- Confirm the Pi is powered on and connected to the same network.
- Check that `avahi-daemon` is running: `ssh rachel@<ip> 'systemctl status avahi-daemon'`.
- Fallback: use the Pi's IP address directly in `inventory.ini`.

**`--ask-pass` prompts but the password is rejected**
- Make sure `sshpass` is installed on your controller (`sudo apt install sshpass`).
- Verify you're using the password you set in Raspberry Pi Imager, not the SSH key passphrase.

**Ansible still asks for a password after bootstrap**
- Confirm your public key is on the Pi: `ssh rachel@pi-node1.local 'cat ~/.ssh/authorized_keys'`.
- Check the key path matches: the playbook reads `~/.ssh/id_ed25519.pub` by default.
- Debug with verbose SSH: `ssh -vvv rachel@pi-node1.local`.
