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

> **Tip:** Leave SSH set to password authentication for now — the bootstrap playbook will install your key and configure passwordless sudo in one command.

## Networking (mDNS)

The inventory uses `.local` hostnames (e.g. `pi-node1.local`) which rely on **mDNS / Avahi**. Ubuntu Server includes `avahi-daemon` by default, so this should work out of the box on your local network.

Verify each node is reachable before continuing:

```bash
ping pi-control-plane.local
ping pi-node1.local
ping pi-node2.local
ping pi-db.local
```

If a hostname doesn't resolve, make sure the Pi is booted and on the same network. As a fallback, replace the `.local` hostnames in `inventory/hosts.ini` with IP addresses.

> **Note:** mDNS works for Ansible and tools like `curl` and `ping`, but **not** for k3s itself. k3s is a statically-linked Go binary that bypasses the system DNS resolver and cannot resolve `.local` hostnames. This is why `playbooks/k3s.yml` uses the control plane's real IP address for `K3S_URL`.

## Prerequisites

On your **controller machine** (the computer you run Ansible from):

1. **Ansible** — install via your package manager or pip. See the [Ansible install guide](https://docs.ansible.com/ansible/latest/installation_guide/index.html).
2. **SSH keypair** — generate an ed25519 key if you don't already have one:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
```

3. **`kubectl`** — the `playbooks/k3s.yml` playbook copies the kubeconfig to `~/.kube/config` automatically. Install `kubectl` on your controller to use it:

```bash
# Ubuntu/Debian
sudo apt install kubectl
```

## Project Structure

```
.
├── ansible.cfg                    # Ansible settings (inventory path, timeouts, etc.)
├── site.yml                       # Central entrypoint — sets up the whole cluster
├── inventory/
│   └── hosts.ini                  # Host definitions and groups
└── playbooks/
    ├── bootstrap/
    │   └── bootstrap-key.yml      # One-time: install SSH key + configure passwordless sudo
    ├── setup/
    │   ├── common.yml             # Base OS setup (apt update, dist-upgrade, sudo config)
    │   └── k3s.yml                # Install k3s server + agents, copy kubeconfig
    ├── teardown/
    │   └── k3s-uninstall.yml      # Tear down k3s from all cluster nodes
    └── ops/
        ├── shutdown.yml           # Graceful cluster shutdown (workers → control plane → db)
        └── wait-for-ssh.yml       # Preflight — polls until all hosts are reachable
```

- **`ansible.cfg`** — points Ansible at `inventory/hosts.ini`, disables host-key checking, sets a 20 s SSH timeout, and silences Python interpreter warnings.
- **`inventory/hosts.ini`** — four groups: `control_plane` (pi-control-plane), `workers` (pi-node1, pi-node2), `db` (pi-db), and `cluster` which combines control plane + workers. All hosts set `ansible_user=rachel`.
- **`site.yml`** — the main entrypoint. Chains `wait-for-ssh.yml` → `common.yml` → `k3s.yml` so a single command sets up the entire cluster.
- **`playbooks/bootstrap/bootstrap-key.yml`** — one-time setup: installs `~/.ssh/id_ed25519.pub` on every host and configures passwordless sudo, using SSH password auth on a fresh Pi.
- **`playbooks/setup/common.yml`** — base OS setup applied to all hosts: apt cache update + full dist-upgrade + enforce passwordless sudo.
- **`playbooks/setup/k3s.yml`** — installs k3s server on `control_plane`, joins `workers` as agents using the server's real IP address, and copies the kubeconfig to `~/.kube/config` on your controller.
- **`playbooks/teardown/k3s-uninstall.yml`** — cleanly removes k3s from workers then the server, and deletes the local kubeconfig. Use this to start fresh.
- **`playbooks/ops/shutdown.yml`** — graceful shutdown: stops workers first (so k3s agents drain before the server), then control plane, then `pi-db`.
- **`playbooks/ops/wait-for-ssh.yml`** — preflight: polls SSH on every host until available (up to 180 s).

## Usage: Setup the Cluster

Full flow from a fresh Pi Imager flash to a running cluster:

**Step 1** — bootstrap SSH keys and passwordless sudo (one-time, uses the password you set in Pi Imager):

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
