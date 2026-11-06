# Security policy

OpenZTNA is pre‑1.0 security software. We take vulnerability reports seriously and welcome them.

## Reporting a vulnerability

**Do not open a public issue for a suspected vulnerability.**

Instead, report privately using **GitHub Security Advisories** on this repository:
*Security → Report a vulnerability* (private disclosure to the maintainers).

Please include, where possible:

- The OpenZTNA version (`ztactl --version` or the installed package version) and channel (stable/nightly).
- OS, distribution, kernel (`uname -a`), and whether a physical or virtual TPM is in use.
- A description of the issue, its impact, and the steps or proof‑of‑concept to reproduce it.
- Any relevant redacted logs (`journalctl -u openzta-daemon`, `ztactl diagnostics`). Review redacted
  output before sharing; do not include PINs, private keys, or tokens.

We will acknowledge your report, investigate, and coordinate a fix and disclosure timeline with you.

## Scope

This repository is the **distribution surface** (packages, container images, repository metadata, and
documentation). Reports may concern:

- **Packaging / distribution:** signing, repository metadata, install/maintainer scripts, the systemd
  unit's hardening, container image contents, or anything that could let a bad artifact be installed or
  trusted.
- **The client itself:** vulnerabilities in the daemon or `ztactl` behaviour. These are triaged with the
  (private) development project; report them here and they will be routed appropriately.

## What not to report here

- General bugs, install problems, and documentation errors → open a normal issue.
- Vulnerabilities in third‑party dependencies (the kernel, `tpm2-pkcs11`, OpenSSL/AWS‑LC, etc.) → report
  upstream; if OpenZTNA's use of them is the problem, report that here.

## Hardening notes (for reviewers)

OpenZTNA is designed to fail closed and run with least privilege:

- Device keys are generated and used **inside a TPM 2.0** (`tpm2-pkcs11`, `/dev/tpmrm0`); there is **no
  software or exportable key path** in release builds, and the daemon refuses to run without a usable TPM.
- The daemon runs as the unprivileged `openzta` user with `NoNewPrivileges=yes`, a minimal ambient
  capability set (`CAP_BPF`, `CAP_PERFMON`, `CAP_NET_ADMIN`), a seccomp filter, `ProtectSystem=strict`,
  and read‑only config.
- The control socket is owner‑only; the PKCS#11 PIN is supplied only via environment variable and never
  written to config or logs.
- A fresh install is **inert** — no data‑path feature is active until explicitly enabled.
- All published packages, repository metadata, and container images are signed; see
  [verifying signatures](docs/verify-signatures.md).

## No warranty

OpenZTNA is provided under GPL‑2.0‑only (with an OpenSSL linking exception) **with no warranty**. It is
pre‑1.0 software; evaluate it accordingly.
