# System requirements

OpenZTNA is a Linux client with a few hard requirements. The daemon **fails closed** (refuses to start,
or refuses to enable a feature) rather than running in a degraded, insecure state, so it is worth
checking these before installing.

## Operating system & architecture

- **Linux only.** macOS, Windows, and Android are fail‑closed stubs in the client — the published
  packages are Linux `.deb`/`.rpm`.
- **Architecture:** `amd64` / `x86_64`. (`arm64`/`aarch64` is planned but not yet published.)
- **Kernel:** **Linux 6.1 or newer** (an LTS floor). The daemon fails closed below this.
- **init:** systemd (the package ships and manages a systemd unit).

## TPM 2.0 — always required

The device identity key is generated and used **inside a TPM 2.0** and never leaves it. This is not
optional and there is no software‑key fallback in release builds.

Check your TPM:

```bash
# A resource-manager device must exist:
ls -l /dev/tpmrm0

# And it must report spec version 2:
cat /sys/class/tpm/tpm0/tpm_version_major    # must print: 2
```

- A **physical TPM 2.0** or a **virtual TPM 2.0** both work (e.g. a cloud NitroTPM, or a
  VirtualBox 7 / Hyper‑V Gen‑2 / QEMU `swtpm` VM with a vTPM enabled). What matters is a real
  `/dev/tpmrm0` reporting major version `2`.
- The device node is owned by the `tss` group; the installer adds the `openzta` service user to `tss`.

If `/dev/tpmrm0` is missing or reports a version other than `2`, enrollment and the daemon's key store
will fail closed.

## Kernel features — required only when interception is enabled

The eBPF data path is loaded **only** when you set `[intercept] enabled = true`. If you do, the kernel
must provide:

```bash
# BTF (CO-RE) — the eBPF program needs this:
ls -l /sys/kernel/btf/vmlinux

# cgroup v2 must be mounted:
stat -fc %T /sys/fs/cgroup     # must print: cgroup2fs
```

- **BTF** (`CONFIG_DEBUG_INFO_BTF=y`) — present on stock Ubuntu, Debian, Fedora, and RHEL‑family
  kernels. Some minimal distributions do not enable it.
- **cgroup v2** — the default on all current mainstream distributions.
- The daemon needs the capabilities `CAP_BPF`, `CAP_PERFMON`, and `CAP_NET_ADMIN`; the systemd unit
  grants exactly these as ambient capabilities (the daemon still runs as non‑root).

An install with interception left disabled (the default) needs none of these kernel features.

## Required and recommended packages

These are standard distro packages; install them before enrolling.

**Debian / Ubuntu / Kali:**

```bash
sudo apt-get install -y tpm2-pkcs11 tpm2-tools ca-certificates
```

**Fedora / RHEL / Rocky / Alma:**

```bash
sudo dnf install -y tpm2-pkcs11 tpm2-tools ca-certificates
```

Roles:

- **`tpm2-pkcs11`** (provides `libtpm2_pkcs11.so`) — the PKCS#11 module the daemon opens for the
  TPM‑backed key store. The package declares this as a *recommended* dependency, so it is normally
  pulled in automatically; install it explicitly if your package manager skips recommends.
- **`tpm2-tools`** (provides `tpm2_ptool`) — used **once** to provision the device‑key token before your
  first enrollment (see [enrollment](enrollment.md)). Not a hard package dependency.
- **`ca-certificates`** — the system TLS trust store, used to validate the head‑end.

> **Ubuntu/Debian module‑path note.** The config default `module_path` is the generic
> `/usr/lib/pkcs11/libtpm2_pkcs11.so`, but on Debian/Ubuntu the module is installed at
> `/usr/lib/x86_64-linux-gnu/pkcs11/libtpm2_pkcs11.so`. You will set the correct path in
> `/etc/openzta/daemon.toml`. See [configuration](configuration.md) and
> [troubleshooting](troubleshooting.md).

## Network

- Outbound HTTPS to your head‑end (enrollment, ACME, and config‑sync endpoints). Specific hosts depend
  on your deployment; for Cisco Secure Access see [that guide](cisco-secure-access.md).
- Outbound UDP (QUIC/HTTP‑3) to the zero‑trust gateway when you enable the MASQUE transport, with an
  automatic fallback to HTTP/2 over TCP.

## Quick preflight

A one‑shot check that mirrors what the daemon verifies at start:

```bash
echo "kernel: $(uname -r) (need >= 6.1)"
[ -e /dev/tpmrm0 ] && echo "TPM device: present" || echo "TPM device: MISSING"
echo "TPM major: $(cat /sys/class/tpm/tpm0/tpm_version_major 2>/dev/null) (need 2)"
# Only relevant if you will enable [intercept]:
[ -r /sys/kernel/btf/vmlinux ] && echo "BTF: present" || echo "BTF: MISSING"
echo "cgroup: $(stat -fc %T /sys/fs/cgroup 2>/dev/null) (need cgroup2fs)"
```
