# Overview & security model

OpenZTNA is a Linux **zero‑trust network access (ZTNA) client**. Instead of a classic always‑on VPN
tunnel, it gives each device a strong, hardware‑anchored identity and then — per connection — decides
whether a flow should go direct, be steered through a zero‑trust gateway, or be denied, based on policy
and endpoint posture.

This page explains what the software is, what gets installed, and the security model you are opting
into. Read it before enabling any data‑path feature.

## Components

A single package, `openzta`, installs:

| Component | Path | Role |
|---|---|---|
| **Daemon** | `/usr/lib/openzta/openzta-daemon` | Long‑running system service. Holds the device identity, talks to the head‑end, evaluates policy/posture, and (when enabled) programs the kernel data path. Runs as the unprivileged `openzta` user. |
| **Control CLI** | `/usr/bin/ztactl` | Thin client you run from your shell to inspect and control the daemon over a local socket, and to drive interactive enrollment. See the [CLI reference](cli.md). |
| **eBPF object** | `/usr/lib/openzta/openzta-ebpf.o` | The kernel data‑path program the daemon loads **only** when traffic interception is enabled. |
| **systemd unit** | `/usr/lib/systemd/system/openzta-daemon.service` | Hardened service definition (non‑root, tightly sandboxed). |
| **Config** | `/etc/openzta/daemon.toml` | Your configuration. Preserved across upgrades. See the [configuration reference](configuration.md). |

Runtime state lives under `/var/lib/openzta` (enrolled identity, `0700`), the control socket under
`/run/openzta/daemon.sock`, and logs under `/var/log/openzta`.

## How it works, briefly

1. **Enrollment.** The daemon mints a device key **inside your TPM 2.0** (it never leaves the chip) and
   obtains a client certificate from your head‑end's ACME endpoint after you authenticate — interactive
   browser SSO (OAuth 2.0 / OIDC with PKCE and DPoP), a pre‑provisioned bootstrap identity, or SAML.
   See [enrollment](enrollment.md).
2. **Posture & context.** The daemon can evaluate endpoint posture and attach endpoint‑context metadata
   to its requests (in OpenZTNA‑native form or Cisco `x‑acidex‑*` form).
3. **Policy & steering.** When you enable interception, a small eBPF program classifies outbound flows.
   Selected flows are redirected to the local proxy and carried to the configured gateway over
   **MASQUE** (HTTP/3 / QUIC, with an HTTP/2 fallback); everything else goes direct. Policy decisions
   are made per flow.
4. **Config‑sync.** Optionally, the daemon periodically pulls a steering configuration from the
   head‑end (e.g. Cisco Secure Access `ztnaConfig` v2) and applies it to the kernel steering tables.

## Inert by default (important)

A fresh install **does nothing to your traffic**. In the shipped `/etc/openzta/daemon.toml`:

- `[intercept] enabled = false` — no eBPF program is loaded, no packets are touched.
- `[proxy] enabled = false`, `[stream] enabled = false` — no local proxy, no gateway tunnel.
- `[enrollment] enabled = false`, `[config_sync] enabled = false` — no network calls to a head‑end.
- `[security]` sandboxing toggles are `off` in the shipped config (the systemd unit still applies a
  strong sandbox regardless).

So after `apt install openzta`, the daemon starts, exposes only an **owner‑only local control socket**,
and waits. You turn features on deliberately, by editing the config and enrolling. This is a safety
property: the package can be installed and inspected with zero effect on the host until you opt in.

## Security model & trust anchors

- **Device key is hardware‑bound and non‑extractable.** Keys are generated and used inside a **TPM 2.0**
  via the `tpm2-pkcs11` PKCS#11 module and the kernel resource‑manager device `/dev/tpmrm0`. There is
  **no software or exportable key path** in release builds — the daemon **fails closed** if a usable
  TPM 2.0 is not present. The PIN is supplied only via an environment variable, never stored in config.
- **Least privilege.** The daemon runs as `User=openzta` (never root) with only the ambient capabilities
  it needs for the data path (`CAP_BPF`, `CAP_PERFMON`, `CAP_NET_ADMIN`), `NoNewPrivileges=yes`, a
  seccomp filter, `ProtectSystem=strict`, and read‑only access to its config. See
  [`operations.md`](operations.md) and the systemd unit for the full sandbox.
- **Control socket is owner‑only.** `ztactl` talks to the daemon over a Unix socket in `/run/openzta`
  that is not world‑accessible. The CLI relays only opaque values during enrollment (e.g. an OAuth
  `code`) — never private keys, token material, or the PKCS#11 PIN.
- **Updates come only through this signed repository.** There is **no in‑client auto‑updater** by
  design. You patch OpenZTNA the same way you patch the rest of the OS: `apt upgrade` / `dnf upgrade`
  against the signed channel you subscribed to. All packages and repository metadata are GPG‑signed; see
  [verifying signatures](verify-signatures.md).

## Maturity & limitations (pre‑1.0)

OpenZTNA is published below `1.0` for evaluation. Be aware:

- **Linux‑only, `amd64`‑only** today.
- **Device enrollment** (including against Cisco Secure Access via interactive browser SSO) and the
  **control/inspection surface** (`ztactl status`/`identity`/`posture`/`health`/`context`) are the most
  exercised paths.
- The **eBPF steering data path**, the **MASQUE transport**, and **Cisco config‑sync** are present but
  still maturing. Treat **end‑to‑end traffic tunneling as experimental** and validate in a lab before
  relying on it.
- **SAML enrollment and step‑up require the `ztaui` GUI app**, which is not yet published here; the
  headless `ztactl --saml` path fails closed by design (see [enrollment](enrollment.md)).
- Some Cisco `ztnaConfig` v2 fields (network‑change/TND, roaming, user‑pause, local‑LAN exclusion, and
  multiple simultaneous proxies) are parsed but **not yet enforced**; the Cisco config‑sync **POST**
  request body is not implemented. See [Cisco Secure Access](cisco-secure-access.md).

See [release channels & versioning](channels-and-versioning.md) for what the version numbers mean.
