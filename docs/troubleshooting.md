# Troubleshooting

OpenZTNA **fails closed**: when a security precondition isn't met it refuses to proceed rather than
running insecurely. Most "it won't start / won't enroll" problems are one of a handful of preconditions.
Start by capturing state:

```bash
systemctl status openzta-daemon
journalctl -u openzta-daemon -b --no-pager | tail -n 100
ztactl ping ; ztactl status ; ztactl identity
```

## The daemon won't start or `ztactl ping` fails

- **No TPM 2.0.** The release daemon fails closed without a usable TPM. Check:
  ```bash
  ls -l /dev/tpmrm0
  cat /sys/class/tpm/tpm0/tpm_version_major    # must be 2
  ```
  In a VM, enable a virtual TPM 2.0 in the hypervisor. See [requirements](requirements.md).
- **Kernel too old.** Needs Linux ≥ 6.1. `uname -r`.
- **Socket mismatch.** If `ztactl` can't reach the daemon, confirm `--socket` / `OPENZTA_SOCKET` matches
  `[control] socket_path` (default `/run/openzta/daemon.sock`), and that the daemon is actually running.
- **Config error.** A malformed `daemon.toml`, or `config_sync` enabled without its prerequisites
  (`enrollment` + `intercept` + `intercept.steering` with `dns_forward = true`), makes the daemon fail
  closed. The journal names the offending section.

## Enrollment fails at the key store / PKCS#11

- **Wrong module path.** The config default `/usr/lib/pkcs11/libtpm2_pkcs11.so` is usually wrong on
  mainstream distros. Set `[enrollment.store] module_path` to:
  - Debian/Ubuntu/Kali: `/usr/lib/x86_64-linux-gnu/pkcs11/libtpm2_pkcs11.so`
  - Fedora/RHEL: `/usr/lib64/pkcs11/libtpm2_pkcs11.so` (confirm with `rpm -ql tpm2-pkcs11`).
- **Token not provisioned, or wrong label.** The token must exist and be labelled `openzta`
  (matching `token_label`). Re‑run the provisioning from the [install guide](install/ubuntu-debian.md#4-provision-the-tpm-token).
- **PIN not supplied.** The daemon reads the PIN only from the env var named in `pin_source`
  (default `OPENZTA_PKCS11_PIN`). Ensure it is set in the systemd drop‑in along with
  `TPM2_PKCS11_STORE` and `TPM2_PKCS11_TCTI=device:/dev/tpmrm0`:
  ```bash
  systemctl show openzta-daemon -p Environment
  ```
- **Store ownership.** `/var/lib/openzta/tpm2_pkcs11` must be readable/writable by the `openzta` user
  (provision it with `sudo -u openzta …`, and it should be `0700` owned by `openzta:openzta`).

## Browser doesn't open during `ztactl enroll`

`ztactl` prints the authorization URL even when it can't launch a browser — open it manually in a
graphical session, authenticate, and the loopback listener will catch the redirect. On a headless host,
prefer the bootstrap/certificate path (`ztactl enroll --bootstrap`) or run from a desktop.

## `ztactl enroll --saml` (or `step-up --saml`) errors immediately

Expected. SAML needs an embedded webview that `ztactl` doesn't have:

```
SAML enrollment requires an embedded webview to harvest the SSO cookie;
run it from the ztaui GUI app (ztactl is headless)
```

Use the `ztaui` GUI (not yet published here) for SAML, or use the certificate/bootstrap or interactive
browser flows. See [enrollment](enrollment.md) and [Cisco Secure Access](cisco-secure-access.md).

## Interception won't enable

Enabling `[intercept]` needs an eBPF‑capable build plus kernel features:

```bash
ls -l /sys/kernel/btf/vmlinux               # BTF must be present
stat -fc %T /sys/fs/cgroup                   # must be cgroup2fs
```

Minimal/custom kernels may lack BTF (`CONFIG_DEBUG_INFO_BTF`). The daemon logs which feature is missing
and keeps the data path off.

## Cisco config‑sync doesn't apply policy

- Against a **production Cisco proxy**, the config‑sync **POST body is not implemented yet**, so a full
  POST round‑trip won't succeed — this is a known pre‑1.0 limitation, not a misconfiguration. See
  [Cisco Secure Access](cisco-secure-access.md#config-sync-pulling-steering-policy-from-cisco).
- For a Cisco endpoint, you generally need `method = "post"` and `trust = "system"` (public CA). With
  `trust = "enrolled"` (default) the client validates against your enrolled anchors — correct for an
  OpenZTNA‑native head‑end serving the document over `GET`.
- Some `ztnaConfig` v2 features are parsed but not enforced yet (TND/roaming, user‑pause, local‑LAN
  exclusion, multiple proxies).

## Signature / repository errors

- `apt-get update` fails with a signature error → the keyring is missing or doesn't match. Re‑install the
  key and verify its fingerprint ([verifying signatures](verify-signatures.md)).
- `dnf` key‑import prompt → confirm the fingerprint before accepting.
- A nightly appears "older" than stable when switching channels → that's the `~nightly` ordering; pin the
  version or use `--allow-downgrades`. See [channels & versioning](channels-and-versioning.md).

## Gathering information for a bug report

```bash
ztactl diagnostics --output /tmp/openzta-diag.json
ztactl collect-diagnostics
journalctl -u openzta-daemon -b --no-pager > /tmp/openzta-journal.txt
```

Attach the redacted diagnostics (review them first) to an issue. For a suspected vulnerability, use
[SECURITY.md](https://github.com/OpenZTNA/OpenZTA-packages/blob/main/SECURITY.md) instead of a public issue.
