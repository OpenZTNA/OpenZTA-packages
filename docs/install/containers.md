# Container images (evaluation / dev)

OpenZTNA publishes container images to the GitHub Container Registry (GHCR) under the OpenZTNA org:

```
ghcr.io/openztna/openztna:stable            # latest stable
ghcr.io/openztna/openztna:0.y.z             # a specific release
ghcr.io/openztna/openztna:nightly           # latest nightly
ghcr.io/openztna/openztna:0.y.z-nightly.YYYYMMDD
```

Images are built on top of a distro base (Ubuntu; Kali variants are tagged `…-kali`) by installing the
same signed `openzta` package you would install on a host — there is no source in the image.

> [!IMPORTANT]
> **Images are for evaluation, development, and CI — not a typical production deployment.** OpenZTNA is
> a host security agent: it loads an eBPF program against the **host kernel**, needs a **TUN device** and
> a **TPM 2.0**, and manages host networking. Running it in a container means granting it broad access to
> the host (capabilities, device nodes, and usually the host network namespace). For real use, prefer the
> [native package](ubuntu-debian.md) on the host.
>
> **Availability:** image publication is part of the OpenZTNA distribution rollout. If a tag 404s, that
> channel/arch may not be published yet — check the repository's *Packages* page.

## What the container needs from the host

- **Host kernel ≥ 6.1 with BTF** — the eBPF data path runs against the host kernel, not the image's
  userland, so BTF is a property of the *host*. (This is the one upside of the container route on
  otherwise‑unsupported userlands.)
- **Capabilities:** `CAP_BPF`, `CAP_PERFMON`, `CAP_NET_ADMIN`.
- **Devices:** `/dev/net/tun` and `/dev/tpmrm0` (a working TPM 2.0 on the host).
- **Networking:** typically `--network host` so steering affects real host flows.
- A **provisioned TPM token** and the **PIN** (as for a host install).

## Pull and verify

```bash
docker pull ghcr.io/openztna/openztna:stable
```

Images are signed with **cosign** (keyless, via the publishing workflow's OIDC identity). Verify before
running (install `cosign` first):

```bash
cosign verify ghcr.io/openztna/openztna:stable \
  --certificate-identity-regexp '^https://github.com/OpenZTNA/OpenZTA-packages/' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com'
```

An SBOM and build provenance are attached as referrers; inspect them with
`cosign download sbom …` / `cosign verify-attestation …`. See [verifying signatures](../verify-signatures.md).

## Run (evaluation)

A minimal run that gives the daemon what it needs. Mount your config and the TPM token store, pass the
PIN, and grant the devices/caps:

```bash
docker run -d --name openztna \
  --network host \
  --cap-add CAP_BPF --cap-add CAP_PERFMON --cap-add CAP_NET_ADMIN \
  --device /dev/net/tun --device /dev/tpmrm0 \
  -e OPENZTA_PKCS11_PIN="CHANGE-ME-USER-PIN" \
  -e TPM2_PKCS11_STORE=/var/lib/openzta/tpm2_pkcs11 \
  -e TPM2_PKCS11_TCTI=device:/dev/tpmrm0 \
  -v /etc/openzta:/etc/openzta:ro \
  -v /var/lib/openzta:/var/lib/openzta \
  ghcr.io/openztna/openztna:stable
```

> If capabilities/devices are not enough on your host, `--privileged` will work for a quick lab trial,
> but understand you are giving the container full host access — never do this outside a throwaway
> environment.

Provision the TPM token on the **host** (see the [host guide](ubuntu-debian.md#4-provision-the-tpm-token))
and bind‑mount `/var/lib/openzta` so the container's daemon finds the token.

## Use the CLI against the running container

```bash
docker exec -it openztna ztactl ping
docker exec -it openztna ztactl status
docker exec -it openztna ztactl enroll      # opens a browser via the host; see enrollment docs
```

Enrollment that needs a browser is awkward from a container; for evaluation, enrolling on the host and
bind‑mounting the resulting `/var/lib/openzta` identity is usually simpler.

## `compose.yaml` example

```yaml
services:
  openztna:
    image: ghcr.io/openztna/openztna:stable
    network_mode: host
    cap_add: [CAP_BPF, CAP_PERFMON, CAP_NET_ADMIN]
    devices:
      - /dev/net/tun
      - /dev/tpmrm0
    environment:
      OPENZTA_PKCS11_PIN: "CHANGE-ME-USER-PIN"
      TPM2_PKCS11_STORE: /var/lib/openzta/tpm2_pkcs11
      TPM2_PKCS11_TCTI: device:/dev/tpmrm0
    volumes:
      - /etc/openzta:/etc/openzta:ro
      - /var/lib/openzta:/var/lib/openzta
    restart: unless-stopped
```

See [troubleshooting](../troubleshooting.md) if the daemon fails closed on the TPM or kernel checks.
