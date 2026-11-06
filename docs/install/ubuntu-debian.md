# Install on Ubuntu & Debian

This guide installs the `openzta` package from the OpenZTNA APT repository and gets you to a running,
enrolled client. The same repository serves Ubuntu, Debian, and [Kali](kali.md); the `.deb` is identical.

Before you start, skim [system requirements](../requirements.md) — in particular you need a working
**TPM 2.0** (`/dev/tpmrm0`), and a **kernel ≥ 6.1** if you intend to enable traffic interception.

Tested on Ubuntu 22.04/24.04 and Debian 12; `amd64` only.

## 1. Trust the OpenZTNA signing key

Every package and the repository metadata are signed with the OpenZTNA release GPG key. Install its
**public** key into a dedicated keyring (the modern `signed-by` approach — we do **not** use the
deprecated `apt-key`):

```bash
curl -fsSL https://openztna.github.io/OpenZTA-packages/deb/openztna-archive-keyring.gpg \
  | sudo tee /usr/share/keyrings/openztna-archive-keyring.gpg >/dev/null
```

Before trusting it, verify the fingerprint against the one published in
[verifying signatures](../verify-signatures.md):

```bash
gpg --show-keys --with-fingerprint /usr/share/keyrings/openztna-archive-keyring.gpg
```

## 2. Add a channel

Pick **one** channel (see [channels & versioning](../channels-and-versioning.md)). Stable is recommended.

**Stable:**

```bash
sudo tee /etc/apt/sources.list.d/openztna.sources >/dev/null <<'EOF'
Types: deb
URIs: https://openztna.github.io/OpenZTA-packages/deb
Suites: stable
Components: main
Signed-By: /usr/share/keyrings/openztna-archive-keyring.gpg
EOF
```

**Nightly** (evaluation/bug reports — change `Suites: stable` to `Suites: nightly`):

```bash
sudo sed -i 's/^Suites: stable$/Suites: nightly/' /etc/apt/sources.list.d/openztna.sources
```

> This uses the deb822 `.sources` format with an explicit `Signed-By`, so the key is trusted **only**
> for this repository — not system‑wide.

## 3. Install

```bash
sudo apt-get update
sudo apt-get install -y openzta
# Supporting tools for the TPM key store (tpm2-pkcs11 is normally pulled in as a Recommends):
sudo apt-get install -y tpm2-pkcs11 tpm2-tools ca-certificates
```

The daemon starts immediately but **inert** — only an owner‑only control socket, no effect on traffic.
Confirm it is alive:

```bash
systemctl status openzta-daemon     # should be active (running)
ztactl ping                         # should print: pong (protocol vN)
ztactl status                       # full status snapshot (JSON)
```

## 4. Provision the TPM token

The daemon stores its device key in a PKCS#11 token inside your TPM. Create that token **once**, owned
by the `openzta` service user. Choose a strong PIN and keep it somewhere safe — you will give it to the
daemon via an environment variable, never in a file.

```bash
# Where the tpm2-pkcs11 token database lives, owned by the service user:
sudo install -d -o openzta -g openzta -m 0700 /var/lib/openzta/tpm2_pkcs11

# Initialise the store and add a token labelled "openzta", talking to the TPM via the kernel RM device.
# Replace CHANGE-ME-USER-PIN with your chosen user PIN (and pick your own SO/admin PIN).
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

`--label openzta` must match `token_label` in the config (it is `openzta` by default).

## 5. Configure the key store and enrollment

Edit `/etc/openzta/daemon.toml` (`sudoedit /etc/openzta/daemon.toml`). At minimum, point the key store
at the Debian/Ubuntu module path and the token you just created, and fill in your head‑end's enrollment
details. A minimal interactive‑enrollment stanza:

```toml
[enrollment]
enabled = true
issuer = "https://issuer.example.net"          # your OIDC issuer
client_id = "openzta-device"
scopes = ["openid", "device_enrollment"]
state_dir = "/var/lib/openzta"

[enrollment.registration]
device_registration_url = "https://enroll.example.net/device"   # your head-end enrollInit URL

[enrollment.acme]
directory_url = "https://ca.example.net/acme/directory"

[enrollment.store]
kind = "pkcs11"
# Debian/Ubuntu module path (NOT the generic default):
module_path = "/usr/lib/x86_64-linux-gnu/pkcs11/libtpm2_pkcs11.so"
token_label = "openzta"
pin_source = "env:OPENZTA_PKCS11_PIN"
scope = "machine"
```

The daemon reads the token PIN and TPM store location from its environment. Provide them with a systemd
drop‑in (so they survive restarts and are not world‑readable in the unit):

```bash
sudo systemctl edit openzta-daemon
```

Add:

```ini
[Service]
Environment=OPENZTA_PKCS11_PIN=CHANGE-ME-USER-PIN
Environment=TPM2_PKCS11_STORE=/var/lib/openzta/tpm2_pkcs11
Environment=TPM2_PKCS11_TCTI=device:/dev/tpmrm0
```

Then apply:

```bash
sudo systemctl restart openzta-daemon
ztactl ping
```

See the full [configuration reference](../configuration.md) for every option, and the
[Cisco Secure Access guide](../cisco-secure-access.md) for Cisco‑specific values.

## 6. Enroll the device identity

Run the interactive browser enrollment (the daemon opens your system browser for SSO):

```bash
ztactl enroll
```

Watch it complete, then confirm:

```bash
ztactl identity        # enrolled device identity status
ztactl status
```

Full enrollment details, including bootstrap and SAML flows, are in [enrollment](../enrollment.md). For
connecting to Cisco Secure Access specifically, follow [that guide](../cisco-secure-access.md).

## 7. (Optional) Enable the data path

Only after you have enrolled, and only if your kernel meets the [requirements](../requirements.md), you
can enable interception/steering by editing `/etc/openzta/daemon.toml` and restarting. See
[configuration](../configuration.md) and [operations](../operations.md). Remember this is still
experimental pre‑1.0 — test in a lab first.

## Updating & removing

```bash
sudo apt-get update && sudo apt-get upgrade      # update (within your channel)
sudo apt-get remove openzta                      # remove, keep identity + config
sudo apt-get purge openzta                       # remove everything, incl. /var/lib/openzta and the user
```

More in [operations](../operations.md) and [troubleshooting](../troubleshooting.md).
