# Operations: service, logs, diagnostics, upgrades

Day‑to‑day running of the OpenZTNA daemon.

## The service

OpenZTNA runs as a systemd unit, `openzta-daemon.service`, as the unprivileged **`openzta`** user (never
root), with a tight sandbox: `NoNewPrivileges=yes`, only the ambient capabilities `CAP_BPF`,
`CAP_PERFMON`, `CAP_NET_ADMIN`, a seccomp filter, `ProtectSystem=strict`, read‑only `/etc/openzta`, and
`DeviceAllow` limited to `/dev/net/tun` and `/dev/tpmrm0`.

```bash
sudo systemctl status openzta-daemon
sudo systemctl start openzta-daemon
sudo systemctl stop openzta-daemon
sudo systemctl restart openzta-daemon
sudo systemctl enable openzta-daemon     # start at boot (default after install)
sudo systemctl disable openzta-daemon
```

Health from the client side:

```bash
ztactl ping        # pong (protocol vN)
ztactl status      # full snapshot
ztactl health      # health report
```

The daemon starts **inert** (owner‑only control socket) until you enable features in
`/etc/openzta/daemon.toml`. See [configuration](configuration.md).

## Applying configuration changes

After editing `/etc/openzta/daemon.toml`:

```bash
sudo systemctl restart openzta-daemon     # always safe
# or, for a live reload where supported:
ztactl reload
```

Environment‑based settings (the PKCS#11 PIN and TPM store/TCTI) live in a systemd drop‑in; edit with
`sudo systemctl edit openzta-daemon`, then `sudo systemctl restart openzta-daemon`.

## Logs

- **Service logs:** `journalctl -u openzta-daemon` (add `-f` to follow, `-b` for this boot).
- **Audit / structured logs:** under `/var/log/openzta/` (e.g. `/var/log/openzta/audit`), rotated per the
  `[log.rotation]` settings (daily, 14 files, 16 MiB/file, 128 MiB total by default).
- **Change verbosity at runtime** without a restart:
  ```bash
  ztactl log-level "info,openzta_stream=debug"      # EnvFilter syntax
  ztactl log-level "warn"                            # back to quiet
  ```
  `RUST_LOG` in the service environment overrides the config `level` if set.

## Diagnostics & support bundles

```bash
# Redacted snapshot (versions, engine status, host, redacted config):
ztactl diagnostics --output /tmp/openzta-diag.json

# Owner-only redacted support bundle written by the daemon; prints its path (not sent over the socket):
ztactl collect-diagnostics
```

Both are redacted by design. Still review a bundle before sharing it.

## Steering control

Pause/resume user steering during maintenance or A/B testing (see the [CLI reference](cli.md)):

```bash
ztactl steering status
ztactl steering pause --for 900          # auto-resume after 15 min
ztactl steering pause --gateway gw.example.net:443
ztactl steering resume
```

## Upgrades

Upgrades come **only** through the signed repository you subscribed to (there is no in‑client updater):

```bash
sudo apt-get update && sudo apt-get upgrade        # Debian/Ubuntu/Kali
sudo dnf upgrade openzta                            # Fedora/RHEL
```

- Your `/etc/openzta/daemon.toml` is a conffile and is **preserved** (your package manager will prompt
  if a new default config diverges from your edited one).
- Your enrolled identity under `/var/lib/openzta` is **preserved** across upgrades and plain removes.
- The service is restarted by the package scripts as part of the upgrade.

Pin or downgrade a version: `apt-get install openzta=<version>` / `dnf install openzta-<version>`
(downgrades may need `--allow-downgrades` on apt). See [channels & versioning](channels-and-versioning.md).

## Uninstall

```bash
# Debian/Ubuntu/Kali
sudo apt-get remove openzta      # stop + remove binaries; KEEP /etc/openzta and /var/lib/openzta
sudo apt-get purge  openzta      # also remove config, state (/var/lib/openzta), and the openzta user

# Fedora/RHEL
sudo dnf remove openzta          # leaves /etc/openzta and /var/lib/openzta; remove by hand for a clean slate
```

Removing the package disables and stops the service first. **Purge** additionally deletes your enrolled
identity — only do that if you intend to fully decommission the device.

## Backups

The sensitive key material lives in your **TPM** and is non‑extractable — it cannot be backed up by
copying files, and it is bound to that TPM. If you reset/clear the TPM or move to new hardware, you must
**re‑enroll**. The public identity material and config under `/etc/openzta` and `/var/lib/openzta` can be
backed up normally (they contain no private keys).
