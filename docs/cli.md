# `ztactl` command reference

`ztactl` is the control CLI. It talks to the running daemon over the owner‑only control socket and also
drives interactive enrollment. It performs no privileged work itself — keys, tokens, and network calls
stay in the daemon; `ztactl` only relays opaque values (such as an OAuth `code`).

> The binary is **`ztactl`** (installed at `/usr/bin/ztactl`). Some older prose calls it `openztactl`;
> that name does not exist on an installed system.

## Usage & global options

```
ztactl [--socket <PATH>] [--log-level <LEVEL>] <SUBCOMMAND> [args]
```

| Global option | Default | Env | Notes |
|---|---|---|---|
| `--socket <PATH>` | `/run/openzta/daemon.sock` | `OPENZTA_SOCKET` | Daemon control socket. |
| `--log-level <LEVEL>` | `warn` | `OPENZTA_LOG_LEVEL` (and `RUST_LOG`) | `ztactl`'s own stderr diagnostics. Command results print to stdout. |

Global options come **before** the subcommand. `ztactl --version` and `ztactl --help` are available.

## Status & inspection

| Command | What it does |
|---|---|
| `ztactl ping` | Check the daemon is alive. Prints `pong (protocol vN)`. |
| `ztactl status` | Full status snapshot (JSON). |
| `ztactl health` | Health report (JSON). |
| `ztactl identity` | Enrolled device‑identity status (JSON). |
| `ztactl posture` | Evaluate and print endpoint posture (JSON). |
| `ztactl context show` | Show the endpoint‑context header dialect and disclosure policy (`enabled`, `header_dialect`, `disclose_user/hardware/network`, `flow_provenance`). |
| `ztactl stats` | Cumulative metrics snapshot (flow‑policy counters). |
| `ztactl crypto fips status` | Crypto backend posture: `fips_capable`, `fips_active`, `fips_required`, `kx_groups`. (FIPS is a build‑time property; this only inspects.) |

> There is **no** `ztactl context set-header-dialect`. The dialect is set via `[context] header_dialect`
> in the config and applied on restart.

## Policy & control

| Command | What it does |
|---|---|
| `ztactl policy --dst-ip <IP> --dst-port <PORT> [--protocol tcp\|udp] [--pid <PID>]` | Ask the policy engine how it would dispose of a flow. `--protocol` defaults to `tcp`. |
| `ztactl reload` | Ask the daemon to reload its configuration. |
| `ztactl shutdown` | Ask the daemon to shut down gracefully. |
| `ztactl log-level <DIRECTIVES>` | Change the daemon's runtime log level, e.g. `ztactl log-level "info,openzta_stream=debug"`. |

Example:

```bash
ztactl policy --protocol tcp --dst-ip 10.0.0.5 --dst-port 443
```

## Steering control

Pause or resume operator (user) steering — useful during troubleshooting or maintenance.

| Command | What it does |
|---|---|
| `ztactl steering status` | Current steering state: enabled/suspended, reason, auto‑resume countdown, per‑gateway pauses. |
| `ztactl steering pause [--for <SECS>] [--gateway <AUTHORITY>]` | Pause steering. `--for` auto‑resumes after N seconds; `--gateway` pauses only that gateway. Omit both to pause everything until `resume`. |
| `ztactl steering resume [--gateway <AUTHORITY>]` | Clear a pause (whole‑policy, or a single `--gateway`), cancelling any pending auto‑resume. |

```bash
ztactl steering pause --for 600        # pause all steering for 10 minutes
ztactl steering status
ztactl steering resume
```

## Enrollment

Full walkthrough in [enrollment](enrollment.md) and [Cisco Secure Access](cisco-secure-access.md).

| Command | What it does |
|---|---|
| `ztactl enroll [flags]` | Enroll this device. Interactive browser SSO by default. |
| `ztactl enroll-status <SESSION_ID>` | Show the progress of an enrollment session. |
| `ztactl enroll-cancel <SESSION_ID>` | Cancel an enrollment session. |

`ztactl enroll` flags:

| Flag | Default | Notes |
|---|---|---|
| `--bootstrap` | off | Use a pre‑provisioned bootstrap mTLS identity from the OS cert store (no browser). |
| `--saml` | off | SAML flow. **Fails closed in `ztactl`** — SAML needs the `ztaui` GUI's embedded webview. Conflicts with `--bootstrap`. |
| `--timeout-secs <N>` | `300` | Seconds to wait for browser authorization. |
| `--enroll-url <URL>` | (config) | Override the enrollInit URL for this run. Ignored if a trusted bootstrap seed has sealed the endpoint. |
| `--issuer <URL>` | (config) | Override the OIDC issuer (ignored by the SAML flow). |
| `--client-id <ID>` | (config) | Override the OIDC client id (ignored by the SAML flow). |

```bash
ztactl enroll
ztactl enroll --bootstrap
ztactl enroll --enroll-url https://enroll.example.net/device --issuer https://issuer.example.net
```

## Step‑up authentication

Provision the credential a per‑flow CONNECT `407` step‑up challenge demands.

| Command | What it does |
|---|---|
| `ztactl step-up [--scope <SCOPE>] [--list] [--saml] [--timeout-secs <N>]` | Authenticate an interactive step‑up for a scope via browser SSO. `--list` shows pending/provisioned scopes instead. With no `--scope`, the single pending scope is used. `--saml` fails closed (use `ztaui`). `--timeout-secs` defaults to `300`. |

```bash
ztactl step-up --list
ztactl step-up --scope finance-app
```

## Diagnostics & support bundles

| Command | What it does |
|---|---|
| `ztactl diagnostics [--output <PATH>]` | Fetch a redacted diagnostics snapshot (versions, engine status, host info, redacted config). Prints JSON, or writes it to `--output`. |
| `ztactl collect-diagnostics` | Ask the daemon to write an owner‑only, redacted support bundle to its bundle directory and print the path. The bundle is never sent over the socket. |

```bash
ztactl diagnostics --output /tmp/openzta-diag.json
ztactl collect-diagnostics
```

## Offline: verify a bootstrap seed

Works without the daemon.

```
ztactl bootstrap verify <SEED> --anchors <PEM> [--dialect generic|cisco-secure-access]
```

- `<SEED>` — path to a `*.ebs.json` seed descriptor (or a native Cisco choice `*.json` with
  `--dialect cisco-secure-access`).
- `--anchors <PEM>` — **required** PEM bundle of trusted seed‑signer CA anchors to validate the signing
  chain.
- `--dialect` — `generic` (default) or `cisco-secure-access`.

It validates the signature, certificate chain, time claims, and enrollment‑URL policy, then prints the
normalized descriptor JSON (`verified`, `signer`, `content_sha256`, `descriptor`). See
[enrollment](enrollment.md).

```bash
ztactl bootstrap verify device.ebs.json --anchors /etc/openzta/ebs-signers.pem
ztactl bootstrap verify choice.json --anchors ca.pem --dialect cisco-secure-access
```
