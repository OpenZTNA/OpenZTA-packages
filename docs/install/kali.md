# Install on Kali Linux

Kali is Debian‑based and uses APT, so it installs from the **same** OpenZTNA repository and the **same**
`.deb` as [Ubuntu/Debian](ubuntu-debian.md). This page only notes the Kali‑specific points; follow the
[Ubuntu & Debian guide](ubuntu-debian.md) for the full walkthrough.

## Kali notes

- **Rolling release.** Kali tracks Debian testing and updates frequently. The OpenZTNA `.deb` targets
  the Debian/Ubuntu ABI; on an up‑to‑date Kali it installs cleanly. If you run a heavily customized or
  older Kali, check the [requirements](../requirements.md) first.
- **TPM 2.0 is still required.** Bare‑metal Kali on hardware with a TPM 2.0 works. If you run Kali in a
  VM, enable a **virtual TPM 2.0** in your hypervisor (VirtualBox 7+, Hyper‑V Gen 2, QEMU `swtpm`), so
  `/dev/tpmrm0` reports version `2`. Kali live/forensic sessions without a TPM cannot enroll.
- **Kernel ≥ 6.1 with BTF** is needed only if you enable interception; Kali's stock kernel satisfies
  this, but custom/minimal kernels may not.
- Package names for the TPM tooling are the same as Debian: `tpm2-pkcs11 tpm2-tools ca-certificates`.
- The PKCS#11 module path is the Debian path:
  `/usr/lib/x86_64-linux-gnu/pkcs11/libtpm2_pkcs11.so`.

## Quick version

```bash
# 1. Key
curl -fsSL https://openztna.github.io/OpenZTA-packages/deb/openztna-archive-keyring.gpg \
  | sudo tee /usr/share/keyrings/openztna-archive-keyring.gpg >/dev/null

# 2. Channel (stable)
sudo tee /etc/apt/sources.list.d/openztna.sources >/dev/null <<'EOF'
Types: deb
URIs: https://openztna.github.io/OpenZTA-packages/deb
Suites: stable
Components: main
Signed-By: /usr/share/keyrings/openztna-archive-keyring.gpg
EOF

# 3. Install
sudo apt-get update
sudo apt-get install -y openzta tpm2-pkcs11 tpm2-tools ca-certificates
```

Then continue from [step 4 (provision the TPM token)](ubuntu-debian.md#4-provision-the-tpm-token) in the
Ubuntu/Debian guide, and enroll with [`ztactl enroll`](../enrollment.md). To connect to Cisco Secure
Access, see [that guide](../cisco-secure-access.md).
