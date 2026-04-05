RUNBOOK — Pi cluster setup & common fixes
========================================

Purpose: beginner-friendly runbook to get the Raspberry Pi cluster reachable and configured for Ansible runs. Includes preflight playbooks and Wi‑Fi fixes for intermittent connectivity.

1) Quick preflight — verify reachability

```bash
# quick mDNS check
ping pi-control-plane.local
ansible all -m ping
```

2) If `ansible all -m ping` sometimes fails

Run the preflight wait playbook (it polls until Ansible SSH connection works):

```bash
ansible-playbook wait-for-ssh.yml
# then verify
ansible all -m ping
```

3) Bootstrap SSH keys (one-time)

```bash
ansible-playbook bootstrap-key.yml --ask-pass
```

Notes: `bootstrap-key.yml` now includes a `pre_tasks` step that waits up to 180s for SSH per host before installing your public key.

4) Wi‑Fi-specific fixes (common cause of intermittent connectivity)

- Temporarily disable Wi‑Fi power saving to test:

```bash
sudo iw dev wlan0 set power_save off
```

- Persist via NetworkManager on each Pi: create `/etc/NetworkManager/conf.d/wifi-powersave.conf` with:

```
[connection]
wifi.powersave = 2
```

then restart NetworkManager:

```bash
sudo systemctl restart NetworkManager
```

5) Ansible reliability tips

- Serialize connections for fragile networks: `ansible all -m ping -f 1` or run `ansible-playbook bootstrap-key.yml -f 1`.
- Increase `timeout` in `ansible.cfg` (e.g. `timeout = 60`) if hosts take longer to complete SSH handshakes.

6) Troubleshooting pointers

- Check Avahi / mDNS: `systemctl status avahi-daemon` on the Pi
- Check SSH logs: `journalctl -u ssh -n 200`
- If DHCP is slow, consider static IPs or DHCP reservations in your router

Next steps I can do for you:
- Add an Ansible role to disable Wi‑Fi power save after bootstrap (runs once keys are installed)
- Create a convenience script to run preflight + bootstrap in sequence

