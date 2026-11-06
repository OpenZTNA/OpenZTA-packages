# Install on Fedora, RHEL, Rocky & Alma

OpenZTNA publishes a GPG‑signed DNF/YUM repository with the same client as the Debian packages, built as
an `.rpm`. This covers Fedora and the RHEL family (RHEL, Rocky, Alma); `amd64`/`x86_64` only.

Skim [system requirements](../requirements.md) first — you need a working **TPM 2.0** and, for
interception, a **kernel ≥ 6.1 with BTF** (stock Fedora/RHEL kernels have it).

## 1. Add the repository

Pick **one** channel (see [channels & versioning](../channels-and-versioning.md)). Stable is recommended.

**Stable:**

```bash
sudo tee /etc/yum.repos.d/openztna.repo >/dev/null <<'EOF'
[openztna-stable]
name=OpenZTNA (stable)
baseurl=https://openztna.github.io/OpenZTA-packages/rpm/stable
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://openztna.github.io/OpenZTA-packages/rpm/openztna-archive-keyring.asc
EOF
```

**Nightly** (evaluation/bug reports): use the same block but `name=OpenZTNA (nightly)`,
`[openztna-nightly]`, and `baseurl=…/rpm/nightly`.

- `gpgcheck=1` verifies each package signature; `repo_gpgcheck=1` additionally verifies the repository
  metadata signature. Both are enabled — keep them on.
- Verify the key fingerprint against [verifying signatures](../verify-signatures.md) before trusting it:
  ```bash
  curl -fsSL https://openztna.github.io/OpenZTA-packages/rpm/openztna-archive-keyring.asc \
    | gpg --show-keys --with-fingerprint
  ```

## 2. Install

```bash
sudo dnf install -y openzta tpm2-pkcs11 tpm2-tools ca-certificates
```

Accept the key import when prompted (confirm the fingerprint matches). The daemon starts **inert**:

```bash
systemctl status openzta-daemon
ztactl ping
```

## 3. Provision the TPM token

As on Debian, create the PKCS#11 token once, owned by the `openzta` user. Pick your own PINs.

```bash
sudo install -d -o openzta -g openzta -m 0700 /var/lib/openzta/tpm2_pkcs11

sudo -u openzta env \
  TPM2_PKCS11_STORE=/var/lib/openzta/tpm2_pkcs11 \
  TPM2_PKCS11_TCTI=device:/dev/tpmrm0 \
  tpm2_ptool init --path /var/lib/openzta/tpm2_pkcs11

sudo -u openzta env \
  TPM2_PKCS11_STORE=/var/lib/openzta/tpm2_pkcs11 \
  TPM2_PKCS11_TCTI=device:/dev/tpmrm0 \
  tpm2_ptool addtoken --pid 1 --path /var/lib/openzta/tpm2_pkcs11 \
    --label openzta --sopin "CHANGE-ME-SO-PIN" --userpin "CHANGE-ME-USER-PIN"
```

## 4. Configure

Edit `/etc/openzta/daemon.toml`. The key difference from Debian is the **PKCS#11 module path**, which on
Fedora/RHEL is typically:

```toml
[enrollment.store]
kind = "pkcs11"
module_path = "/usr/lib64/pkcs11/libtpm2_pkcs11.so"   # Fedora/RHEL path (confirm on your system)
token_label = "openzta"
pin_source = "env:OPENZTA_PKCS11_PIN"
scope = "machine"
```

Confirm the real path on your system:

```bash
rpm -ql tpm2-pkcs11 | grep -E 'libtpm2_pkcs11\.so$'
```

Then supply the PIN and TPM store via a systemd drop‑in and restart, exactly as in the
[Ubuntu/Debian guide, step 5](ubuntu-debian.md#5-configure-the-key-store-and-enrollment):

```bash
sudo systemctl edit openzta-daemon
# [Service]
# Environment=OPENZTA_PKCS11_PIN=CHANGE-ME-USER-PIN
# Environment=TPM2_PKCS11_STORE=/var/lib/openzta/tpm2_pkcs11
# Environment=TPM2_PKCS11_TCTI=device:/dev/tpmrm0
sudo systemctl restart openzta-daemon
```

Fill in `[enrollment]`, `[enrollment.registration]`, and `[enrollment.acme]` for your head‑end — see the
[configuration reference](../configuration.md) and, for Cisco, the
[Cisco Secure Access guide](../cisco-secure-access.md).

## 5. Enroll

```bash
ztactl enroll
ztactl identity
```

## Updating & removing

```bash
sudo dnf upgrade openzta
sudo dnf remove openzta
```

`dnf remove` leaves `/etc/openzta` and `/var/lib/openzta` in place. Remove them manually if you want a
clean slate. See [operations](../operations.md).
