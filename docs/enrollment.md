# Device enrollment

Enrollment is how OpenZTNA obtains the device identity it uses for zero‑trust access: a key generated
**inside your TPM 2.0** and a client certificate issued by your head‑end's ACME endpoint after you
authenticate. This page covers the general flows. For Cisco Secure Access specifics, see
[that guide](cisco-secure-access.md).

## Before you enroll

1. **A provisioned TPM token.** Create it once with `tpm2_ptool` (label `openzta`) — see the
   [install guide, step 4](install/ubuntu-debian.md#4-provision-the-tpm-token).
2. **Key‑store config.** `[enrollment.store]` must point `module_path` at your distro's
   `libtpm2_pkcs11.so` and `token_label` at `openzta`, and the daemon must have `OPENZTA_PKCS11_PIN`,
   `TPM2_PKCS11_STORE`, and `TPM2_PKCS11_TCTI` in its environment. See [configuration](configuration.md).
3. **Enrollment config.** `[enrollment] enabled = true` with your `issuer`, `client_id`,
   `[enrollment.registration] device_registration_url`, and `[enrollment.acme] directory_url`.

## What stays where (privilege split)

The daemon holds all secrets and makes all network calls. `ztactl` runs in your user session, opens the
browser, hosts a loopback redirect listener, and relays back **only** the opaque OAuth `code` and
`state` — never the PKCE verifier, tokens, or any private key. The device private key is minted and used
**inside the TPM** and never touches disk; only public material (the issued certificate chain, pinned
anchors, non‑key metadata) is stored under `/var/lib/openzta/identity/`.

## Flow A — interactive browser SSO (default)

Standards: OAuth 2.0 / OIDC authorization‑code with **PKCE** (RFC 7636), loopback redirect (RFC 8252),
**DPoP** (RFC 9449), **ACME** (RFC 8555), JOSE/JWS ES256.

```bash
ztactl enroll
```

What happens:

1. `ztactl` binds an ephemeral `http://127.0.0.1:<port>/callback` listener and asks the daemon to begin.
2. The daemon mints an **EC P‑256 ephemeral enrollment key in the TPM** (it doubles as the DPoP key and
   the ACME account key), builds PKCE + `state`/`nonce`, and returns the authorization URL.
3. `ztactl` prints the URL and opens your browser:
   ```
   Opening your browser to sign in:
     https://issuer.example.net/authorize?...
   Waiting for authorization (timeout 300s)…
   ```
   (If a browser can't be opened it prints a warning and the URL to open manually.)
4. You authenticate; `ztactl` captures `code`+`state` and relays them. The daemon exchanges the code
   with a DPoP proof, **requires** an `id_token` (access‑token‑only is rejected), validates
   `iss`/`aud`/`exp`/`nonce`, the ES256 signature, and the DPoP thumbprint binding.
5. The daemon runs the ACME order and persists the issued identity, then schedules renewal. `ztactl`
   shows per‑step progress and ends with `Enrollment succeeded.`

Useful flags: `--timeout-secs`, and one‑off overrides `--enroll-url` / `--issuer` / `--client-id` (see
the [CLI reference](cli.md)). Check progress or cancel a long run from another shell with
`ztactl enroll-status <SESSION_ID>` / `ztactl enroll-cancel <SESSION_ID>`.

Verify afterwards:

```bash
ztactl identity
ztactl status
```

## Flow B — bootstrap (no browser)

If the device already has a provisioning certificate in the OS cert store, enroll without any
interactive step:

```bash
ztactl enroll --bootstrap
```

The daemon selects the pre‑provisioned mTLS client identity that matches your
`[enrollment.bootstrap]` policy (issuer/subject/EKU rules) and authenticates with it. Prints
`Starting bootstrap enrollment (using the OS cert store identity)…`.

There is also a **signed bootstrap seed** mechanism for zero‑touch fleets: an MDM drops a signed
descriptor (`*.ebs.json`, or a native Cisco choice file) into
`/var/lib/openzta/enroll-bootstrap/`, and the daemon loads and verifies it at startup (signature +
certificate chain to a configured anchor + time + URL policy). A present‑but‑invalid seed **aborts
startup**. A trusted seed can **seal** the enrollInit endpoint, after which `--enroll-url` is ignored.
You can verify a seed offline before deploying it:

```bash
ztactl bootstrap verify device.ebs.json --anchors /etc/openzta/ebs-signers.pem
```

Enable the seed loader with `[enrollment.bootstrap_seed] enabled = true` and a `signer_anchors_path`;
see [configuration](configuration.md).

## Flow C — SAML (requires the `ztaui` GUI)

SAML enrollment harvests an SSO cookie from an embedded browser (webview). The headless `ztactl` has no
webview, so it **fails closed by design**:

```bash
ztactl enroll --saml
# error: SAML enrollment requires an embedded webview to harvest the SSO cookie;
#        run it from the ztaui GUI app (ztactl is headless)
```

To complete SAML you need **`ztaui`**, the OpenZTNA GUI (built with the `saml-webview` feature). `ztaui`
is **not yet published in this packages repository**. Until it is, use interactive browser SSO (Flow A)
or bootstrap (Flow B) where your head‑end supports them. The same limitation applies to
`ztactl step-up --saml`.

## After enrollment

The daemon:

- Stores the key non‑extractably in the TPM; public material under `/var/lib/openzta/identity/` (`0700`).
- Schedules **automatic renewal** (starting at `renew_at_percent` of the certificate lifetime, with
  jitter and exponential backoff), rotating the leaf key each renewal — no restart needed.
- Begins admitting protected flows per‑connect once a valid identity exists (first enroll and each
  renewal take effect live).
- On a non‑recoverable renewal failure: in `interactive` mode it flags that attention is required (run
  `ztactl enroll` again); in `zero_touch` mode it silently re‑bootstraps against `renewal_bootstrap_url`.

## Troubleshooting

- `ztactl enroll` fails at the key store → check the TPM token exists, `module_path` is correct for your
  distro, and the PIN env var is set. See [troubleshooting](troubleshooting.md).
- Browser doesn't open → copy the printed URL manually; ensure you're in a graphical session, or enroll
  from a desktop.
- SAML → see Flow C above.
