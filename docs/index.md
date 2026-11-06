# OpenZTNA packages

Official prebuilt **Linux packages and container images** for the OpenZTNA zero‑trust network access
client, with the documentation for installing and using it.

!!! warning "Pre‑1.0 — alpha/beta"
    OpenZTNA is early software published for evaluation and convenience. Version numbers stay below
    `1.0`, interfaces and on‑the‑wire behaviour may change between releases, and the software is provided
    **with no warranty of any kind**. The client loads an eBPF program into your kernel and manages a
    device identity in your TPM — read the [overview](overview.md) before enabling any data‑path feature.

This site is served from a repository that contains **no source code** — only the public distribution
surface (a signed APT/DNF repository, container images on GHCR, and these docs). The client itself is
developed in a separate, private repository.

## What is OpenZTNA?

OpenZTNA (`openzta`) is a Linux zero‑trust access client: a hardened system daemon that enrolls a
non‑extractable **device identity in your TPM 2.0**, evaluates **endpoint posture**, and — when you
enable it — transparently **steers selected traffic** through a zero‑trust gateway over MASQUE/HTTP‑3,
driven by a small control CLI (`ztactl`). It interoperates with **Cisco Secure Access** and with
OpenZTNA‑native head‑ends. See the [overview & security model](overview.md).

It installs **inert by default**: every data‑path feature ships disabled, so a fresh install runs only
an owner‑only control socket until you deliberately enroll and enable features.

## Get started

1. [Check system requirements](requirements.md) (Linux ≥ 6.1, TPM 2.0).
2. Install for your distribution:
   [Ubuntu/Debian](install/ubuntu-debian.md) ·
   [Kali](install/kali.md) ·
   [Fedora/RHEL](install/fedora-rhel.md) ·
   [Containers](install/containers.md).
3. [Verify signatures](verify-signatures.md), then
   [enroll a device identity](enrollment.md) — or follow
   [**How to connect with Cisco Secure Access**](cisco-secure-access.md).

## Quick start (Ubuntu/Debian)

```bash
# 1. Trust the OpenZTNA signing key
curl -fsSL https://openztna.github.io/OpenZTA-packages/deb/openztna-archive-keyring.gpg \
  | sudo tee /usr/share/keyrings/openztna-archive-keyring.gpg >/dev/null

# 2. Add the stable channel
sudo tee /etc/apt/sources.list.d/openztna.sources >/dev/null <<'EOF'
Types: deb
URIs: https://openztna.github.io/OpenZTA-packages/deb
Suites: stable
Components: main
Signed-By: /usr/share/keyrings/openztna-archive-keyring.gpg
EOF

# 3. Install
sudo apt-get update
sudo apt-get install -y openzta
```

Then provision the TPM token and enroll — see [device enrollment](enrollment.md).

## Documentation map

| Topic | Page |
|---|---|
| What it is & the security model | [Overview](overview.md) |
| Hardware/kernel/TPM prerequisites | [Requirements](requirements.md) |
| stable vs nightly, the `<1.0` scheme | [Channels & versioning](channels-and-versioning.md) |
| `/etc/openzta/daemon.toml` | [Configuration reference](configuration.md) |
| Every `ztactl` command | [CLI reference](cli.md) |
| Interactive / bootstrap / SAML | [Device enrollment](enrollment.md) |
| Cisco tenant, choice file, config‑sync, ACIDEx | [Cisco Secure Access](cisco-secure-access.md) |
| Service, logs, diagnostics, upgrade/uninstall | [Operations](operations.md) |
| When something fails closed | [Troubleshooting](troubleshooting.md) |

## Supported today

- **OS:** Linux only. **Arch:** `amd64`/`x86_64` (`arm64` planned).
- **Formats:** `.deb` (Debian/Ubuntu/Kali), `.rpm` (Fedora/RHEL family). Alpine/`musl` is not yet available.
- **Channels:** `stable` and opt‑in `nightly`.

## License

GPL‑2.0‑only with an OpenSSL linking exception (covering AWS‑LC / `aws-lc-rs`); the full text ships in
every package under `/usr/share/doc/openzta/`, and the software comes with **no warranty**.
`OpenZTA`/`OpenZTNA` and the `openzta-` prefix are trademarks of the project author.
