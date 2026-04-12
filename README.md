# home-lab

Ansible playbooks for managing a Raspberry Pi homelab cluster running k3s.

## Hardware

| Role          | Board          | Hostname           |
| ------------- | -------------- | ------------------ |
| Control plane | Raspberry Pi 5 | `pi-control-plane` |
| Worker 1      | Raspberry Pi 5 | `pi-node1`         |
| Worker 2      | Raspberry Pi 5 | `pi-node2`         |
| Database      | Raspberry Pi 4 | `pi-db`            |

All nodes run **Ubuntu Server 25.10 (64-bit)**. The cluster runs **k3s v1.34.6+k3s1**.

## Prerequisites

On your **controller machine** (the computer you run Ansible from):

1. **Ansible** — install via your package manager or pip:

   ```bash
   # Ubuntu/Debian
   sudo apt install ansible

   # or via pip
   pip install ansible
   ```

2. **SSH keypair** — generate one if you don't have it:

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
   ```

3. **`kubectl`** — the k3s playbook copies the kubeconfig to `~/.kube/config` automatically:

   ```bash
   sudo apt install kubectl
   ```

## Project Structure

```
.
├── ansible.cfg                    # Ansible settings (inventory path, timeouts)
├── site.yml                       # Central entrypoint — sets up the whole cluster
├── inventory/
│   └── hosts.ini                  # Host definitions and groups
└── playbooks/
    ├── bootstrap/
    │   └── bootstrap-key.yml      # One-time: install SSH key + configure passwordless sudo
    ├── setup/
    │   ├── common.yml             # Base OS setup (apt, sudo, cgroup config + reboot)
    │   └── k3s.yml                # Install k3s server + agents, copy kubeconfig
    ├── teardown/
    │   └── k3s-uninstall.yml      # Tear down k3s from all cluster nodes
    └── ops/
        ├── shutdown.yml           # Graceful cluster shutdown (workers → control plane → db)
        └── wait-for-ssh.yml       # Preflight — polls until all hosts are SSH-reachable
```

---

## Setup After a Fresh Flash

Follow these steps **in order** after flashing all SD cards with Raspberry Pi Imager.

### Step 0: Flash the SD Cards

1. Download and open [Raspberry Pi Imager](https://www.raspberrypi.com/software/).
2. Choose **Ubuntu Server 25.10 (64-bit)** as the OS.
3. Click **Edit Settings** before writing and configure:
   - **Hostname** — set to the hostname from the table above (e.g. `pi-control-plane`).
   - **Username / password** — create user `admin` with a password you'll remember.
   - **Enable SSH** — use password authentication (the bootstrap playbook will install your key).
4. Write to the SD card and boot the Pi.
5. Repeat for each node.

### Step 1: Verify Network Connectivity

Make sure all Pis are booted and reachable on your local network via mDNS:

```bash
ping pi-control-plane.local
ping pi-node1.local
ping pi-node2.local
ping pi-db.local
```

> **Tip:** If a hostname doesn't resolve, make sure the Pi is booted and on the same network. As a fallback, replace `.local` hostnames in `inventory/hosts.ini` with IP addresses.

### Step 2: Clear Stale SSH Host Keys

If you previously had these Pis connected, your `known_hosts` file will have old keys that no longer match. Clear them:

```bash
ssh-keygen -f ~/.ssh/known_hosts -R pi-control-plane.local
ssh-keygen -f ~/.ssh/known_hosts -R pi-node1.local
ssh-keygen -f ~/.ssh/known_hosts -R pi-node2.local
ssh-keygen -f ~/.ssh/known_hosts -R pi-db.local
```

> Skip this step if this is your very first time setting up the Pis.

### Step 3: Bootstrap SSH Keys and Passwordless Sudo

This installs your SSH public key on every Pi and configures passwordless `sudo`. You'll be prompted for the password you set during imaging:

```bash
ansible-playbook playbooks/bootstrap/bootstrap-key.yml --ask-pass --ask-become-pass
```

Enter the same password for both prompts.

### Step 4: Verify Ansible Connectivity

Confirm all hosts are reachable over key-based SSH:

```bash
ansible all -m ping
```

You should see `SUCCESS` for all four hosts.

### Step 5: Run the Full Site Playbook

This runs the entire setup end-to-end — base OS configuration, cgroup enablement (with reboot if needed), and k3s cluster installation:

```bash
ansible-playbook site.yml
```

What `site.yml` does in order:

1. **Preflight** (`wait-for-ssh.yml`) — waits until all hosts are SSH-reachable.
2. **Common setup** (`common.yml`) — apt update + dist-upgrade, enforces passwordless sudo, enables cgroup memory (required by k3s), and reboots if the boot config changed.
3. **K3s install** (`k3s.yml`) — installs k3s server on the control plane, joins the workers as agents, and copies the kubeconfig to `~/.kube/config` on your machine.

### Step 6: Verify the Cluster

```bash
kubectl get nodes
```

You should see `pi-control-plane`, `pi-node1`, and `pi-node2` in `Ready` state. (`pi-db` is not part of the k3s cluster by design.)

---

## Operations & Management

Commands for day-to-day management after the initial setup.

### Check Host Connectivity

```bash
ansible all -m ping
```

### Run Individual Setup Playbooks

If you need to re-run a specific part of the setup:

```bash
# Base OS setup only (apt upgrade, sudo, cgroups)
ansible-playbook playbooks/setup/common.yml

# K3s install only
ansible-playbook playbooks/setup/k3s.yml
```

### Uninstall k3s

Cleanly removes k3s from all workers, then the server, and deletes the local kubeconfig:

```bash
ansible-playbook playbooks/teardown/k3s-uninstall.yml
```

### Graceful Cluster Shutdown

Shuts down nodes in a safe order — workers first (so k3s agents drain), then control plane, then database:

```bash
ansible-playbook playbooks/ops/shutdown.yml
```

### Reinstall k3s From Scratch

```bash
ansible-playbook playbooks/teardown/k3s-uninstall.yml
ansible-playbook playbooks/setup/k3s.yml
```

### Ad-hoc Commands

Run a command on all hosts:

```bash
ansible all -m shell -a "uptime"
```

Run a command on a specific group:

```bash
ansible workers -m shell -a "systemctl status k3s-agent"
ansible control_plane -m shell -a "kubectl get nodes"
```

---

## Networking Notes

- The inventory uses `.local` hostnames via **mDNS / Avahi**, which works out of the box on Ubuntu Server.
- **k3s** is a statically-linked Go binary that bypasses the system DNS resolver and **cannot** resolve `.local` hostnames. That's why `playbooks/setup/k3s.yml` uses the control plane's real IP address for `K3S_URL`.
- The fresh Pi OS images ship with **`sudo-rs`** (Rust sudo). The bootstrap playbook uses `ansible.builtin.raw` with `sudo -S` to configure passwordless sudo, which avoids Ansible's become prompt detection issues with `sudo-rs`.

```bash
ansible-playbook playbooks/bootstrap/bootstrap-key.yml --ask-pass --ask-become-pass
```

This installs your SSH public key and writes `/etc/sudoers.d/90-rachel` on every host. All subsequent commands run without any password prompts.

**Step 2** — verify all hosts are reachable:

```bash
ansible all -m ping
```

**Step 3** — bring up the full cluster:

```bash
ansible-playbook site.yml
```

This will:
1. Wait for all hosts to be reachable via SSH
2. Run `apt update` + `dist-upgrade` on every node (including `pi-db`)
3. Enforce passwordless sudo on every node
4. Install k3s server on `pi-control-plane`
5. Join `pi-node1` and `pi-node2` as k3s agents
6. Copy the kubeconfig to `~/.kube/config` on your controller

> **Note:** `pi-db` is intentionally excluded from k3s — it's in the `db` group, not the `cluster` group, so k3s playbooks never target it. It is fully included in `common.yml` runs (OS updates, sudo config) alongside all other nodes.

> **Tip:** `ansible.cfg` sets `inventory = inventory/hosts.ini` automatically. You never need to pass `-i` on the command line.

**Step 4** — verify the cluster is up and all nodes are ready.

`site.yml` takes a few minutes to run. When it finishes, open a **new terminal on your controller machine** (your laptop or desktop — the same machine you've been running `ansible-playbook` commands from, not one of the Pis) and run:

```bash
kubectl get nodes
```

This works because `site.yml` automatically copied the k3s connection config to `~/.kube/config` on your controller — `kubectl` reads that file to know how to talk to your cluster.

You should see output like this:

```
NAME               STATUS   ROLES           AGE   VERSION
pi-control-plane   Ready    control-plane   2m    v1.34.6+k3s1
pi-node1           Ready    <none>          90s   v1.34.6+k3s1
pi-node2           Ready    <none>          80s   v1.34.6+k3s1
```

**What to look for:**
- All three nodes appear in the list
- `STATUS` says `Ready` for each one (not `NotReady`)
- `pi-db` is not listed here — that's expected, it's not part of the k3s cluster

> **If a node shows `NotReady`:** wait 30–60 seconds and run `kubectl get nodes` again. Agents take a little time to fully initialize after install. If it stays `NotReady` after a couple of minutes, check the Troubleshooting section below.

> **If `kubectl: command not found`:** you need to install `kubectl` on your controller machine (see Prerequisites above). The kubeconfig is already in place — once `kubectl` is installed, the command will work immediately without any extra setup.

> **If you want to check `pi-db` too**, Ansible can verify it is reachable and healthy independently of k3s:
> ```bash
> ansible pi-db -m ping
> ```
> You should see `SUCCESS`.

## Usage: Bootstrap SSH Keys

The bootstrap playbook is the **first thing you run** after flashing. It handles SSH key installation and passwordless sudo in one shot:

```bash
ansible-playbook playbooks/bootstrap-key.yml --ask-pass --ask-become-pass
```

- `--ask-pass` — uses the password you set in Pi Imager to connect
- `--ask-become-pass` — uses the same password to gain sudo for writing `/etc/sudoers.d/90-rachel`

After this, all hosts accept your SSH key and all playbooks run without any password prompts:

```bash
ansible all -m ping   # should show SUCCESS for all hosts
ssh rachel@pi-node1.local   # no password needed
```

## Usage: Uninstall k3s

To tear down k3s from all cluster nodes and remove the local kubeconfig:

```bash
ansible-playbook playbooks/teardown/k3s-uninstall.yml
```

This removes agents first (pi-node1, pi-node2), then the server (pi-control-plane), then deletes `~/.kube/config` on your controller. It's safe to run even if k3s was never installed — it checks for the uninstall scripts before running them.

## Usage: `--limit` Examples

```bash
# Run only on workers
ansible-playbook site.yml --limit workers

# Run on two specific hosts
ansible-playbook site.yml --limit "pi-node1,pi-node2"

# Bootstrap a single host
ansible-playbook playbooks/bootstrap/bootstrap-key.yml --limit pi-db --ask-pass --ask-become-pass

# Shut down the whole cluster gracefully
ansible-playbook playbooks/ops/shutdown.yml
```

> You don't need `-i inventory/hosts.ini` — `ansible.cfg` already sets the inventory path.

## Troubleshooting

**Hostname doesn't resolve (`pi-node1.local`)**
- Confirm the Pi is powered on and connected to the same network.
- Check that `avahi-daemon` is running: `ssh rachel@<ip> 'systemctl status avahi-daemon'`.
- Fallback: replace `.local` hostnames in `inventory/hosts.ini` with IP addresses.

**k3s agents fail to join — `connection reset by peer` on `127.0.0.1:6444`**
- This is the mDNS / Go DNS issue — k3s is a statically-linked Go binary that can't resolve `.local` hostnames.
- The internal k3s load balancer proxy can't resolve `.local` hostnames because Go doesn't use the system's mDNS resolver.
- Fix: uninstall agents, ensure `playbooks/setup/k3s.yml` uses `ansible_default_ipv4.address` for `K3S_URL`, and reinstall.

**`sudo-rs: interactive authentication is required`**
- The bootstrap playbook was not run with `--ask-become-pass`, so passwordless sudo was never written.
- Re-run bootstrap: `ansible-playbook playbooks/bootstrap/bootstrap-key.yml --ask-pass --ask-become-pass`
- Or fix a single host directly: `echo "rachel ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-rachel`

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

**Wi-Fi is intermittent / hosts drop off the network**
- Disable Wi-Fi power saving temporarily to test: `sudo iw dev wlan0 set power_save off`
- Persist via NetworkManager — create `/etc/NetworkManager/conf.d/wifi-powersave.conf` on each Pi:
  ```
  [connection]
  wifi.powersave = 2
  ```
  Then restart: `sudo systemctl restart NetworkManager`

**Ansible connections time out on a flaky network**
- Serialize connections to reduce simultaneous SSH load: `ansible all -m ping -f 1`
- Increase `timeout` in `ansible.cfg` (e.g. `timeout = 60`) if SSH handshakes are slow.
- Check SSH logs on the Pi: `journalctl -u ssh -n 200`
- If DHCP assignment is slow at boot, consider static IPs or DHCP reservations in your router.
