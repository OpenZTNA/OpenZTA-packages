# Configuration reference

OpenZTNA is configured by a single TOML file, installed at **`/etc/openzta/daemon.toml`**. It is a
package *conffile*: your edits survive upgrades. After changing it, apply with
`sudo systemctl restart openzta-daemon` (or `ztactl reload` for a live reload where supported).

**Everything data‑path related ships disabled.** A fresh config leaves the daemon inert (owner‑only
control socket, no network calls, no packet handling). You enable features deliberately. Secrets (the
PKCS#11 PIN, step‑up tokens) are **never** written in this file — they come from environment variables.

This page documents the sections you are most likely to touch. Keys show their shipped defaults.

---

## `[control]` — the control socket

```toml
[control]
socket_path = "/run/openzta/daemon.sock"   # owner-only Unix socket that ztactl talks to
```

Under systemd this lives in `RuntimeDirectory=/run/openzta`. The matching `ztactl --socket` /
`OPENZTA_SOCKET` must point at the same path.

## `[log]` — logging

```toml
[log]
level = "info"        # tracing EnvFilter directive; RUST_LOG (if set) overrides this

[log.rotation]
period = "daily"
max_files = 14
max_file_bytes = 16777216      # 16 MiB; 0 disables this cap
max_total_bytes = 134217728    # 128 MiB; 0 disables; if non-zero must be >= max_file_bytes
```

Change the level at runtime without a restart via [`ztactl log-level`](cli.md). Audit records are
written under `/var/log/openzta/audit`.

## `[intercept]` — kernel traffic interception (disabled by default)

```toml
[intercept]
enabled = false                        # requires an eBPF-capable build + CAP_BPF/CAP_NET_ADMIN + kernel BTF
cgroup_path = "/sys/fs/cgroup"
# ebpf_object = "/usr/lib/openzta/openzta-ebpf.o"
# suppress_egress_pin = true           # default on
# self_exclude = true                  # don't intercept the daemon's own traffic; default on
# bypass_pids = [12345]                # PIDs to never intercept
```

### `[intercept.steering]` — kernel FQDN/CIDR steering (disabled by default)

```toml
[intercept.steering]
enabled = true
include = ["10.0.0.0/8", "app.example.com", "*.internal.example"]
exclude = ["10.1.2.0/24"]
dns_interface = "lo"
# dns_resolver_interface = "eth0"
dns_forward = false
dns_forward_port = 15353
synth_gc_interval_secs = 60
synth_idle_ttl_secs = 300
```

`include`/`exclude` mix CIDRs, hostnames, and FQDN globs (`*` matches all). This is the set of
destinations OpenZTNA steers; everything else goes direct.

## `[proxy]` — local redirect proxy (disabled by default)

```toml
[proxy]
enabled = false
listen_addr = "127.0.0.1"
listen_port = 18000
udp_listen_port = 18000
udp_origin_slot_limit = 128
udp_flow_idle_secs = 30
```

## `[policy]` — per‑flow policy

```toml
[policy]
default_action = "deny"     # allow | deny | redirect ; shipped config defaults to deny
# [[policy.rules]]          # first match wins
# protocol = "tcp"
# cidr = "10.0.0.0/8"
# port = 443
# action = "redirect"
```

## `[context]` — endpoint‑context headers (disabled by default)

```toml
[context]
enabled = false
header_dialect = "openzta"   # "openzta" (native openzta-* headers) | "cisco_secure_access" (x-acidex-*)
disclose_user = false
disclose_hardware = false
disclose_network = false
flow_provenance = true
```

Controls what endpoint context the client attaches to its requests and in which dialect. For Cisco
Secure Access set `header_dialect = "cisco_secure_access"`. Inspect the effective policy with
[`ztactl context show`](cli.md).

## `[enrollment]` — device enrollment (disabled by default)

```toml
[enrollment]
enabled = false
enrollment_mode = "interactive"      # interactive | zero_touch
state_dir = "/var/lib/openzta"
issuer = "https://issuer.example.net"
client_id = "openzta-device"
scopes = ["openid", "device_enrollment"]
pinned_anchors = "issued_chain"      # issued_chain | file
# pinned_anchors_path = "/etc/openzta/headend-anchors.pem"   # required when pinned_anchors = "file"
```

### `[enrollment.registration]`

```toml
[enrollment.registration]
device_registration_url = "https://enroll.example.net/device"   # the enrollInit URL
attestation_url = ""                                            # optional posture/health leg; empty = skip
renewal_bootstrap_url = "https://enroll.example.net/renew"      # required for zero_touch; unused by interactive
```

### `[enrollment.acme]`

```toml
[enrollment.acme]
directory_url = "https://ca.example.net/acme/directory"
identifier_type = "uri-list"
challenge_type = "token-bound"
identifier_urns = ["urn:example:org", "urn:example:device", "urn:example:user"]
```

These are deployment‑specific — match them to your head‑end's ACME profile.

### `[enrollment.store]` — the TPM key store (required)

```toml
[enrollment.store]
kind = "pkcs11"                       # the only supported store; hardware TPM 2.0, non-extractable keys
module_path = "/usr/lib/x86_64-linux-gnu/pkcs11/libtpm2_pkcs11.so"   # Debian/Ubuntu path
token_label = "openzta"               # must match the tpm2_ptool token label
pin_source = "env:OPENZTA_PKCS11_PIN" # env var ONLY — never a file, never inline
scope = "machine"
```

> **Module path differs by distro.** Debian/Ubuntu/Kali:
> `/usr/lib/x86_64-linux-gnu/pkcs11/libtpm2_pkcs11.so`. Fedora/RHEL: typically
> `/usr/lib64/pkcs11/libtpm2_pkcs11.so` (confirm with `rpm -ql tpm2-pkcs11`). The built‑in default
> `/usr/lib/pkcs11/libtpm2_pkcs11.so` is generic and usually wrong on these distros.

The daemon also needs these in its **environment** (set them in a systemd drop‑in, see
[install](install/ubuntu-debian.md#5-configure-the-key-store-and-enrollment)):
`OPENZTA_PKCS11_PIN`, `TPM2_PKCS11_STORE`, `TPM2_PKCS11_TCTI=device:/dev/tpmrm0`.

### `[enrollment.renewal]`, `[enrollment.dpop]`

```toml
[enrollment.renewal]
renew_at_percent = 60       # renew when this % of cert lifetime has elapsed
jitter_percent = 10
backoff_initial_secs = 60
backoff_max_secs = 3600

[enrollment.dpop]
include_body_hash = false
```

### `[enrollment.bootstrap]` / `[enrollment.bootstrap_seed]`

For zero‑touch / pre‑provisioned enrollment. `[enrollment.bootstrap]` matches a pre‑provisioned mTLS
identity in the OS cert store by issuer/subject/EKU rules; `[enrollment.bootstrap_seed]` consumes a
signed seed descriptor (generic `*.ebs.json`, or a native Cisco choice file when
`dialect = "cisco_secure_access"`). Both are disabled by default. See [enrollment](enrollment.md) and,
for Cisco, [that guide](cisco-secure-access.md).

## `[config_sync]` — pull steering config from the head‑end (disabled by default)

```toml
[config_sync]
enabled = false
source = "cisco_secure_access"
# endpoint_url = "..."        # derived from [stream].headend when unset
interval_secs = 600
fetch_timeout_secs = 30
method = "get"                # get | post
trust = "enrolled"            # enrolled | system | file
# ca_cert_path = "..."        # required when trust = "file"
# max_staleness_secs = 1800   # optional freshness SLA
```

Enabling `config_sync` requires `[enrollment]`, `[intercept]`, and `[intercept.steering]` enabled with
`dns_forward = true`; the daemon fails closed otherwise. See
[Cisco Secure Access](cisco-secure-access.md) for the Cisco‑specific `method`/`trust` values.

## `[stream]` — MASQUE transport to the gateway (disabled by default)

```toml
[stream]
enabled = false
# [[stream.gateway]]          # static gateways; replaced by a config-sync refresh
# authority = "gw.example.net:443"
# include = ["..."]
# exclude = ["..."]

[stream.quic]
broken_ttl_secs = 300         # 0 = always try HTTP/3 first

[stream.redirect]
allowed_authorities = []
max_redirects = 3
cache_ttl_secs = 300
max_reauth = 1
max_reposture = 1

[stream.step_up]
interactive = false
issuer = "https://issuer.example.net"   # required when interactive
client_id = "openzta-step-up"           # required when interactive
default_ttl_secs = 300
interactive_wait_secs = 120             # 0 = fail closed immediately

[stream.step_up.tokens]
# "<scope>" = "env:<VAR>"     # headless bearer tokens; only env: sources accepted
```

> The MASQUE `[stream]` engine is still maturing (pre‑1.0). Treat gateway tunneling as experimental.

## `[security]` — runtime hardening (off in shipped config)

```toml
[security]
landlock = "off"             # off | best_effort | enforce
seccomp = "off"              # off | log | enforce
drop_capabilities = false
privilege_separation = false
```

These are in addition to the sandbox the systemd unit already applies. Release builds may also force a
stricter baseline regardless of these toggles.

## `[crypto]`

```toml
[crypto]
fips = false                 # only effective with a FIPS-enabled build; a non-FIPS binary refuses fips=true
```

Inspect the active crypto posture with [`ztactl crypto fips status`](cli.md).

---

See the [`ztactl` reference](cli.md) to inspect the effective configuration
(`ztactl status`, `ztactl context show`, `ztactl diagnostics`).
