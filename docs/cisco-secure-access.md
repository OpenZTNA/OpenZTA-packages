# How to connect with Cisco Secure Access

OpenZTNA can act as a zero‑trust client for **Cisco Secure Access** (the ZTNA service in Cisco's
Security Service Edge). This guide covers enrolling a device against a Secure Access tenant, configuring
the client for Cisco, and driving everyday tasks with the `ztactl` control CLI.

> [!IMPORTANT]
> **Status (pre‑1.0).** Enrolling a device identity against Cisco Secure Access and inspecting
> client/posture/context state are the most exercised paths. Cisco **config‑sync** and the **MASQUE data
> plane** are present but still maturing, and some pieces are not implemented yet (noted inline and in
> [Limitations](#limitations-with-cisco-today)). Treat full end‑to‑end traffic tunneling through Secure
> Access as **experimental** and validate in a lab before relying on it.

OpenZTNA is an independent implementation and is **not affiliated with or endorsed by Cisco**. "Cisco"
and "Cisco Secure Access" are trademarks of Cisco Systems, Inc., used here only to describe
interoperability.

## What you need from Cisco

From your Cisco Secure Access administrator / dashboard:

1. **ZTNA enabled** for your organization, with device enrollment configured.
2. Your organization's **enrollment URL** (the "enrollInit" endpoint). It is organization‑specific and
   commonly looks like `https://<org-id>.enroll.ztna.sse.cisco.com/enrollInit`.

   > OpenZTNA does **not** hard‑code or infer this host — get the authoritative value from your Secure
   > Access dashboard, your admin, or your enrollment choice file. (Internally, the client derives your
   > org id from the signed SSO token at enrollment time, not from the hostname.)
3. An **enrollment method** and its material:
   - **Certificate / bootstrap** — a signed **enrollment choice file** your admin exports. This is the
     headless‑friendly path and works with `ztactl` today.
   - **SAML** — browser‑based SSO. This requires the `ztaui` GUI (see [SAML](#saml-enrollment), not yet
     available in this packages repo).
4. The **trust anchors** for validating the choice‑file signer (a PEM bundle), if you use the certificate
   path.

You also need the standard OpenZTNA prerequisites: a working **TPM 2.0** and a provisioned token. Install
the package and provision the token first — see [Install on Ubuntu/Debian](install/ubuntu-debian.md)
steps 1–4 (Fedora/RHEL and Kali are equivalent).

## The Cisco enrollment choice file

Cisco Secure Access exports a signed **enrollment choice file** — JSON shaped like
`{ "version": 1, "comment": "...", "signed_payload": "<JWS>" }`. It carries the enrollInit URL, the
authentication type (`certificate` or `saml`), certificate‑renewal URL, and certificate‑match rules.
OpenZTNA consumes it natively as a *bootstrap seed* in the Cisco dialect.

**Verify a choice file offline before trusting it** (no daemon required):

```bash
ztactl bootstrap verify /path/to/choice.json \
  --anchors /etc/openzta/cisco-signers.pem \
  --dialect cisco-secure-access
```

This checks the signature, certificate chain, time claims, and enrollInit‑URL policy, then prints the
normalized descriptor (`verified`, `signer`, `content_sha256`, `descriptor`). Inspect it and confirm the
`enroll_url` matches your org before installing the file.

**Install the choice file** so the daemon loads it at startup:

```bash
sudo install -d -o openzta -g openzta -m 0700 /var/lib/openzta/enroll-bootstrap
sudo install -o openzta -g openzta -m 0600 choice.json /var/lib/openzta/enroll-bootstrap/choice.json
```

A trusted choice file **seals** the enrollInit endpoint — once loaded, `--enroll-url` and the
config value are ignored in favour of the signed URL, which is the safe behaviour.

## Configure the client for Cisco

Edit `/etc/openzta/daemon.toml`. A Cisco‑oriented configuration (certificate/bootstrap enrollment,
Cisco endpoint‑context headers, and Cisco config‑sync) looks like this:

```toml
[enrollment]
enabled = true
enrollment_mode = "zero_touch"          # certificate/bootstrap path; use "interactive" for browser SSO
state_dir = "/var/lib/openzta"

[enrollment.registration]
# Usually sealed by the signed choice file below; set it if you are not using a seed:
device_registration_url = "https://<org-id>.enroll.ztna.sse.cisco.com/enrollInit"
renewal_bootstrap_url  = "https://<org-id>.enroll.ztna.sse.cisco.com/enrollInit"   # cert re-enroll

[enrollment.store]
kind = "pkcs11"
module_path = "/usr/lib/x86_64-linux-gnu/pkcs11/libtpm2_pkcs11.so"   # Debian/Ubuntu; Fedora: /usr/lib64/...
token_label = "openzta"
pin_source = "env:OPENZTA_PKCS11_PIN"
scope = "machine"

# Consume the Cisco enrollment choice file as a signed bootstrap seed:
[enrollment.bootstrap_seed]
enabled = true
dir = "/var/lib/openzta/enroll-bootstrap"
dialect = "cisco_secure_access"
signer_anchors_path = "/etc/openzta/cisco-signers.pem"
# allowed_enroll_hosts = ["<org-id>.enroll.ztna.sse.cisco.com"]
max_clock_skew_secs = 60

# Send endpoint context in Cisco's ACIDEx (x-acidex-*) dialect:
[context]
enabled = true
header_dialect = "cisco_secure_access"
# Disclose only what your policy requires:
disclose_user = false
disclose_hardware = false
disclose_network = false
flow_provenance = true
```

Provide the PIN/TPM environment via a systemd drop‑in and restart (as in the
[install guide](install/ubuntu-debian.md#5-configure-the-key-store-and-enrollment)):

```bash
sudo systemctl edit openzta-daemon     # add OPENZTA_PKCS11_PIN / TPM2_PKCS11_STORE / TPM2_PKCS11_TCTI
sudo systemctl restart openzta-daemon
ztactl ping
```

## Enroll against Cisco Secure Access

### Certificate / bootstrap (headless)

With the choice file installed and `[enrollment.bootstrap_seed]` enabled, the daemon loads and verifies
the seed at startup and uses it to drive device registration and ACME certificate issuance. Confirm:

```bash
ztactl identity        # should show an enrolled identity
ztactl status
```

If your choice file's auth type is `certificate` and a provisioning cert is present in the OS store, you
can also trigger bootstrap enrollment explicitly:

```bash
ztactl enroll --bootstrap
```

### Interactive browser SSO

If your tenant offers OIDC‑style interactive device enrollment, use:

```bash
ztactl enroll --enroll-url "https://<org-id>.enroll.ztna.sse.cisco.com/enrollInit"
```

(The daemon opens your browser for SSO; see [enrollment, Flow A](enrollment.md#flow-a--interactive-browser-sso-default).)

### SAML enrollment

Cisco SAML enrollment harvests an SSO cookie from an embedded webview. `ztactl` is headless and
**fails closed**:

```bash
ztactl enroll --saml
# error: SAML enrollment requires an embedded webview to harvest the SSO cookie;
#        run it from the ztaui GUI app (ztactl is headless)
```

SAML therefore needs the **`ztaui`** GUI, which is **not yet published** in this repository. Until it is,
use the certificate/bootstrap path (above) for headless hosts. The same applies to per‑flow
[step‑up](#step-up-authentication) SAML.

## Config‑sync (pulling steering policy from Cisco)

OpenZTNA can periodically pull a steering configuration (Cisco `ztnaConfig` v2) from the head‑end and
apply it to the kernel steering tables. Enable it with:

```toml
[config_sync]
enabled = true
source = "cisco_secure_access"
method = "post"           # a real Cisco proxy expects POST
trust  = "system"         # validate the Cisco endpoint against the public CA set
interval_secs = 600
# endpoint_url is derived from the gateway when unset

# config_sync requires these to be enabled as well (daemon fails closed otherwise):
[intercept]
enabled = true
[intercept.steering]
enabled = true
dns_forward = true
[stream]
enabled = true
```

What it maps: resource FQDN/IP include/exclude lists → kernel steering include/exclude (IPv4 **and**
IPv6); proxy/gateway entries → the tunnel authority; org metadata → a display label.

> **Limitations with config‑sync against a real Cisco tenant (today):**
> - The Cisco config‑sync **POST request body** (the device‑state schema) is **not implemented**, so a
>   full POST round‑trip against a production Cisco proxy will not succeed yet. An OpenZTNA‑native
>   head‑end that serves the same document over `GET` with your enrolled anchors (`method = "get"`,
>   `trust = "enrolled"`, the defaults) does work.
> - Several `ztnaConfig` v2 fields are **parsed but not yet enforced**: network‑change/Trusted‑Network
>   Detection and roaming disconnect, user‑pause windows, local‑LAN exclusion, and multiple simultaneous
>   proxies (these are unioned into a single tunnel for now).

## Endpoint context (ACIDEx)

Setting `[context] header_dialect = "cisco_secure_access"` makes OpenZTNA attach its endpoint‑context
metadata using Cisco's `x-acidex-*` header names on both its CONNECT requests and the config‑sync
request (client/OS/host/network/flow attributes). Disclosure is governed by the
`disclose_user/hardware/network` toggles — disclose only what your deployment requires. Inspect the
effective policy:

```bash
ztactl context show
```

## Step‑up authentication

Cisco can demand a per‑flow step‑up (an in‑band `407` challenge) for sensitive resources. Provision the
credential it asks for:

```bash
ztactl step-up --list              # see which scopes are pending / provisioned
ztactl step-up --scope <SCOPE>     # interactive browser step-up for a scope
```

SAML‑based step‑up (`--saml`) has the same webview limitation as SAML enrollment and needs `ztaui`.

## Driving Cisco operations with `ztactl`

Common tasks mapped to commands (full list in the [CLI reference](cli.md)):

| Goal | Command |
|---|---|
| Confirm the daemon is up | `ztactl ping` |
| See overall state (identity, steering, engines) | `ztactl status` |
| Check the enrolled Cisco device identity / renewal | `ztactl identity` |
| Evaluate endpoint posture | `ztactl posture` |
| See what endpoint context is being sent, and the dialect | `ztactl context show` |
| Predict how a flow to a resource will be handled | `ztactl policy --dst-ip <IP> --dst-port 443` |
| Temporarily stop steering (e.g. to compare direct vs. tunneled) | `ztactl steering pause --for 600` → `ztactl steering status` → `ztactl steering resume` |
| Turn up logging while reproducing an issue | `ztactl log-level "info,openzta_stream=debug,openzta_configsync=debug"` |
| Reapply config after editing `daemon.toml` | `ztactl reload` (or `systemctl restart openzta-daemon`) |
| Gather a redacted bundle for a support case | `ztactl collect-diagnostics` |
| Grab a redacted snapshot (versions/host/redacted config) | `ztactl diagnostics --output /tmp/openzta-diag.json` |

Example: verify a resource behind Secure Access will be steered, then watch it:

```bash
ztactl policy --protocol tcp --dst-ip 10.20.30.40 --dst-port 443
ztactl log-level "info,openzta_stream=debug"
ztactl status            # inspect the steering / stream sections
```

## Limitations with Cisco today

- **SAML enrollment / step‑up** require `ztaui` (not yet published here); headless `ztactl` fails closed.
- **Config‑sync POST body** against a production Cisco proxy is not implemented; some `ztnaConfig` v2
  features are parsed but not enforced (see above).
- The **MASQUE data plane** is still maturing — end‑to‑end tunneling is experimental pre‑1.0.
- **`amd64` Linux only.**

For anything that fails closed, [troubleshooting](troubleshooting.md) maps the common errors (TPM,
module path, kernel features, SAML) to fixes.
