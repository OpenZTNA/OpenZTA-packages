# OpenZTNA packages

Official prebuilt **Linux packages and container images** for the OpenZTNA zero‑trust network access
client, plus the documentation for installing and using it.

> [!IMPORTANT]
> **Pre‑1.0 — alpha/beta.** OpenZTNA is early software published for evaluation and convenience. Version
> numbers stay below `1.0`, interfaces and on‑the‑wire behaviour may change between releases, and the
> software is provided **with no warranty of any kind** (see [LICENSE](#license)). Do not place it on a
> production path you cannot afford to lose. The client loads an eBPF program into your kernel and
> manages a device identity in your TPM — understand [what it does](docs/overview.md) before enabling
> any data‑path feature.

This repository contains **no source code**. It is the public distribution surface: a signed APT/DNF
package repository served over GitHub Pages, container images on GHCR, and the user documentation. The
client itself is developed in a separate, private repository.

## What is OpenZTNA?

OpenZTNA (`openzta`) is a Linux zero‑trust access client: a hardened system daemon that enrolls a
non‑extractable **device identity in your TPM 2.0**, evaluates **endpoint posture**, and (when you
enable it) transparently **steers selected traffic** through a zero‑trust gateway over MASQUE/HTTP‑3,
with a small control CLI (`ztactl`). It is designed to interoperate with **Cisco Secure Access** as
well as OpenZTNA‑native head‑ends. See the [overview](docs/overview.md).

It installs **inert by default** — every data‑path feature ships disabled, so a fresh install runs only
an owner‑only control socket until you deliberately enroll and enable features.

## Install

| Platform | Guide |
|---|---|
| Ubuntu / Debian | [docs/install/ubuntu-debian.md](docs/install/ubuntu-debian.md) |
| Kali Linux | [docs/install/kali.md](docs/install/kali.md) |
| Fedora / RHEL / Rocky / Alma | [docs/install/fedora-rhel.md](docs/install/fedora-rhel.md) |
| Container image (eval/dev) | [docs/install/containers.md](docs/install/containers.md) |
| Verifying signatures | [docs/verify-signatures.md](docs/verify-signatures.md) |

Quick start (Ubuntu/Debian):

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

Then provision the TPM token and enroll — see [docs/enrollment.md](docs/enrollment.md), or
[**How to connect with Cisco Secure Access**](docs/cisco-secure-access.md).

## Documentation

- [Overview & security model](docs/overview.md)
- [System requirements](docs/requirements.md)
- [Release channels & versioning](docs/channels-and-versioning.md)
- [Configuration reference (`/etc/openzta/daemon.toml`)](docs/configuration.md)
- [`ztactl` command reference](docs/cli.md)
- [Device enrollment](docs/enrollment.md)
- [**How to connect with Cisco Secure Access**](docs/cisco-secure-access.md)
- [Operations: service, logs, diagnostics, upgrade/uninstall](docs/operations.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Security policy](SECURITY.md)

## Supported today

- **OS:** Linux only. (Other platforms are fail‑closed stubs in the client.)
- **Architecture:** `amd64` / `x86_64`. (`arm64` is planned.)
- **Package formats:** `.deb` (Debian/Ubuntu/Kali) and `.rpm` (Fedora/RHEL family).
- **Channels:** `stable` (tagged releases) and `nightly` (opt‑in, daily from the development branch).

Alpine/`musl` packaging is not yet available.

## License

OpenZTNA is distributed under the **GNU General Public License, version 2 only**, with an **OpenSSL
linking exception** (covering AWS‑LC / `aws-lc-rs`). The full text ships inside every package under
`/usr/share/doc/openzta/` (`LICENSE`, `LICENSE-EXCEPTION.md`) and the software comes with **absolutely
no warranty**. `OpenZTA`/`OpenZTNA` and the `openzta-` prefix are trademarks of the project author;
redistributing modified builds requires dropping that branding.

## Reporting problems

Open an issue in this repository for packaging, repository‑metadata, install, or documentation problems.
For a suspected security vulnerability, follow [SECURITY.md](SECURITY.md) — please do not open a public
issue for vulnerabilities.
