# home-lab

Ansible playbooks for managing a Raspberry Pi homelab cluster.

## Hardware

| Role          | Board            | Hostname             |
| ------------- | ---------------- | -------------------- |
| Control plane | Raspberry Pi 5   | `pi-control-plane`   |
| Worker 1      | Raspberry Pi 5   | `pi-node1`           |
| Worker 2      | Raspberry Pi 5   | `pi-node2`           |
| Database      | Raspberry Pi 4   | `pi-db`              |

All nodes run **Ubuntu Server 25.10 (64-bit)**. The cluster runs **k3s v1.34.6+k3s1**.

## Flashing the Pis

1. Download and open [Raspberry Pi Imager](https://www.raspberrypi.com/software/).
2. Choose **Ubuntu Server 25.10 (64-bit)** as the OS.
3. Click the gear icon (or **Edit Settings**) before writing and configure:
   - **Hostname** — set to the hostname from the table above (e.g. `pi-control-plane`).
   - **Username / password** — create user `rachel` with a password.
   - **Enable SSH** — check "Allow public-key authentication only" if you already have a key, otherwise use password auth for now.
4. Write to the SD card and boot the Pi.
5. Repeat for each node.

> **Important:** Before running any playbook with `become: true`, make sure passwordless sudo is configured for your user. See [ADR-005](docs/adr/ADR-005-passwordless-sudo-prerequisite.md) for details and the fix.

## Networking (mDNS)

The inventory uses `.local` hostnames (e.g. `pi-node1.local`) which rely on **mDNS / Avahi**. Ubuntu Server includes `avahi-daemon` by default, so this should work out of the box on your local network.

Verify each node is reachable before continuing:

```bash
ping pi-control-plane.local
ping pi-node1.local
ping pi-node2.local
ping pi-db.local
```

If a hostname doesn't resolve, make sure the Pi is booted and on the same network. As a fallback, replace the `.local` hostnames in `inventory.ini` with IP addresses.

> **Note:** mDNS works for Ansible and tools like `curl` and `ping`, but **not** for k3s itself. k3s is a statically-linked Go binary that bypasses the system DNS resolver and cannot resolve `.local` hostnames. This is why `k3s.yml` uses the control plane's real IP address for `K3S_URL`. See [ADR-003](docs/adr/ADR-003-k3s-url-ip-not-mdns.md) for the full story.

## Prerequisites

On your **controller machine** (the computer you run Ansible from):

1. **Ansible** — install via your package manager or pip. See the [Ansible install guide](https://docs.ansible.com/ansible/latest/installation_guide/index.html).
2. **SSH keypair** — generate an ed25519 key if you don't already have one:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
```

3. **`kubectl`** — the `k3s.yml` playbook copies the kubeconfig to `~/.kube/config` automatically. Install `kubectl` on your controller to use it:

```bash
# Ubuntu/Debian
sudo apt install kubectl
```

## Project Structure

```
.
├── ansible.cfg           # Ansible settings (inventory path, timeouts, etc.)
├── inventory.ini         # Host definitions and groups
├── site.yml              # Central entrypoint — sets up the whole cluster
├── common.yml            # Base OS setup (apt update & dist-upgrade)
├── k3s.yml               # Install k3s server + agents, copy kubeconfig
├── k3s-uninstall.yml     # Tear down k3s from all cluster nodes
├── wait-for-ssh.yml      # Preflight — polls until all hosts are reachable
├── bootstrap-key.yml     # One-shot: install your SSH public key on all Pis
└── docs/
    └── adr/              # Architectural Decision Records
```

- **`ansible.cfg`** — points Ansible at `inventory.ini`, disables host-key checking, sets a 20 s SSH timeout, and silences Python interpreter warnings.
- **`inventory.ini`** — four groups: `control_plane` (pi-control-plane), `workers` (pi-node1, pi-node2), `db` (pi-db), and `cluster` which combines control plane + workers. All hosts set `ansible_user=rachel`.
- **`site.yml`** — the main entrypoint. Chains `wait-for-ssh.yml` → `common.yml` → `k3s.yml` so a single command sets up the entire cluster.
- **`common.yml`** — base OS setup applied to all hosts: apt cache update + full dist-upgrade.
- **`k3s.yml`** — installs k3s server on `control_plane`, joins `workers` as agents using the server's real IP address, and copies the kubeconfig to `~/.kube/config` on your controller.
- **`k3s-uninstall.yml`** — cleanly removes k3s from workers then the server, and deletes the local kubeconfig. Use this to start fresh.
- **`wait-for-ssh.yml`** — preflight: polls SSH on every host until available (up to 180 s).
- **`bootstrap-key.yml`** — one-time setup: copies `~/.ssh/id_ed25519.pub` into `~/.ssh/authorized_keys` on every host so future runs don't need a password.

## Usage: Setup the Cluster

**Step 1** — ensure passwordless SSH and sudo are in place (see Bootstrap below), then run:

```bash
ansible-playbook site.yml
```

This will:
1. Wait for all hosts to be reachable via SSH
2. Run `apt update` + `dist-upgrade` on every node
3. Install k3s server on `pi-control-plane`
4. Join `pi-node1` and `pi-node2` as k3s agents
5. Copy the kubeconfig to `~/.kube/config` on your controller

> **Note:** `pi-db` is excluded from k3s. Until passwordless sudo is configured on `pi-db`, exclude it from all runs:
> ```bash
> ansible-playbook site.yml --limit 'all:!pi-db'
> ```

**Step 2** — verify the cluster:

```bash
kubectl get nodes
```

You should see all three nodes with status `Ready`:

```
NAME               STATUS   ROLES           AGE   VERSION
pi-control-plane   Ready    control-plane   ...   v1.34.6+k3s1
pi-node1           Ready    <none>          ...   v1.34.6+k3s1
pi-node2           Ready    <none>          ...   v1.34.6+k3s1
```

## Usage: Bootstrap SSH Keys

After booting all the Pis, check whether you already have passwordless access:

```bash
ansible all -m ping
```

**If all hosts return `SUCCESS`** — you set a public key in Pi Imager during flashing and don't need the bootstrap playbook.

**If you get connection errors or password prompts** — run the bootstrap playbook once. Pass `--ask-pass` so Ansible can connect with the password you set during imaging:

```bash
ansible-playbook bootstrap-key.yml --ask-pass
```

The playbook polls SSH (up to 180 s) before installing `~/.ssh/id_ed25519.pub` from your controller.

Then verify:

```bash
ansible all -m ping
```

All hosts should return `SUCCESS`. From this point, no password is needed:

```bash
ssh rachel@pi-node1.local
```

## Usage: Uninstall k3s

To tear down k3s from all cluster nodes and remove the local kubeconfig:

```bash
ansible-playbook k3s-uninstall.yml
```

This removes agents first (pi-node1, pi-node2), then the server (pi-control-plane), then deletes `~/.kube/config` on your controller. It's safe to run even if k3s was never installed — it checks for the uninstall scripts before running them.

## Usage: `--limit` Examples

```bash
# Exclude pi-db (e.g. while sudo isn't configured there)
ansible-playbook site.yml --limit 'all:!pi-db'

# Run only on workers
ansible-playbook site.yml --limit workers

# Run on two specific hosts
ansible-playbook site.yml --limit "pi-node1,pi-node2"

# Bootstrap a single host
ansible-playbook bootstrap-key.yml --limit pi-db --ask-pass
```

> You don't need `-i inventory.ini` — `ansible.cfg` already sets the inventory path.

## Architectural Decision Records

Key decisions and non-obvious design choices are documented in [`docs/adr/`](docs/adr/):

| ADR | Title |
|-----|-------|
| [ADR-001](docs/adr/ADR-001-central-site-entrypoint.md) | Central `site.yml` entrypoint with `import_playbook` chain |
| [ADR-002](docs/adr/ADR-002-k3s-install-script.md) | k3s installation via upstream install script |
| [ADR-003](docs/adr/ADR-003-k3s-url-ip-not-mdns.md) | Use static IP (not mDNS hostname) for `K3S_URL` |
| [ADR-004](docs/adr/ADR-004-pi-db-excluded-from-k3s.md) | `pi-db` excluded from the k3s cluster |
| [ADR-005](docs/adr/ADR-005-passwordless-sudo-prerequisite.md) | Passwordless sudo is a hard prerequisite |

## Troubleshooting

**Hostname doesn't resolve (`pi-node1.local`)**
- Confirm the Pi is powered on and connected to the same network.
- Check that `avahi-daemon` is running: `ssh rachel@<ip> 'systemctl status avahi-daemon'`.
- Fallback: replace `.local` hostnames in `inventory.ini` with IP addresses.

**k3s agents fail to join — `connection reset by peer` on `127.0.0.1:6444`**
- This is the mDNS / Go DNS issue. See [ADR-003](docs/adr/ADR-003-k3s-url-ip-not-mdns.md).
- The internal k3s load balancer proxy can't resolve `.local` hostnames because Go doesn't use the system's mDNS resolver.
- Fix: uninstall agents, ensure `k3s.yml` uses `ansible_default_ipv4.address` for `K3S_URL`, and reinstall.

**`sudo-rs: interactive authentication is required`**
- Passwordless sudo is not configured on that host. See [ADR-005](docs/adr/ADR-005-passwordless-sudo-prerequisite.md).
- Quick fix on the Pi: `echo "rachel ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-rachel`
- Workaround: `ansible-playbook site.yml --limit 'all:!pi-db'`

**`--ask-pass` prompts but the password is rejected**
- Make sure `sshpass` is installed on your controller (`sudo apt install sshpass`).
- Verify you're using the password you set in Raspberry Pi Imager, not the SSH key passphrase.

**Ansible still asks for a password after bootstrap**
- Confirm your public key is on the Pi: `ssh rachel@pi-node1.local 'cat ~/.ssh/authorized_keys'`.
- The playbook reads `~/.ssh/id_ed25519.pub` — make sure that file exists on your controller.
- Debug with verbose SSH: `ssh -vvv rachel@pi-node1.local`.

**`kubectl get nodes` shows workers as `NotReady`**
- Give it 30–60 seconds after install for the agents to fully initialize.
- Check agent status: `ansible workers -b -a "systemctl status k3s-agent --no-pager"`
- Check agent logs: `ansible workers -b -m shell -a "journalctl -u k3s-agent -n 20 --no-pager"`
