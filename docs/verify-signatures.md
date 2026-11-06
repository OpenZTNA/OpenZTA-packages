# Verifying signatures

Everything OpenZTNA publishes is signed. You should verify signatures before trusting packages or
images — especially for pre‑1.0 software you are evaluating.

## The OpenZTNA release signing key

Packages (`.deb`/`.rpm`) and the repository metadata (`InRelease`/`Release.gpg` for APT,
`repomd.xml.asc` for DNF) are signed with the OpenZTNA release GPG key.

- **Public keyring (APT, dearmored):**
  `https://openztna.github.io/OpenZTA-packages/deb/openztna-archive-keyring.gpg`
- **Public key (armored, for DNF/manual import):**
  `https://openztna.github.io/OpenZTA-packages/rpm/openztna-archive-keyring.asc`
- **Fingerprint:** `<PUBLISHED-KEY-FINGERPRINT>`

  > The fingerprint above is published here and on the repository's release notes. Always compare what
  > you download against it before trusting the key. (This placeholder is filled in once the signing key
  > is generated; until then, treat any key as untrusted.)

Check a downloaded key's fingerprint:

```bash
curl -fsSL https://openztna.github.io/OpenZTA-packages/rpm/openztna-archive-keyring.asc \
  | gpg --show-keys --with-fingerprint
```

The private key never leaves the signing environment and is not present in any repository. Only the
public key is published.

## APT

When you use the `Signed-By` entry from the [install guide](install/ubuntu-debian.md), APT verifies the
repository's `InRelease` signature on every `apt-get update` automatically — a bad or missing signature
makes the update fail rather than silently proceed. To check a downloaded `.deb` out of band:

```bash
# Package integrity is covered by the signed Packages index; to inspect a file's hashes:
sha256sum openzta_*.deb
```

## DNF / RPM

With `gpgcheck=1` and `repo_gpgcheck=1` (both set in the [Fedora/RHEL guide](install/fedora-rhel.md)),
DNF verifies the metadata signature and each package signature, prompting you to accept the key on first
use. To check a package manually:

```bash
sudo rpm --import https://openztna.github.io/OpenZTA-packages/rpm/openztna-archive-keyring.asc
rpm --checksig openzta-*.rpm        # expect: ... digests signatures OK
```

## Checksums on releases

Each GitHub Release attaches a `SHA256SUMS` file and a detached GPG signature `SHA256SUMS.asc`. Verify:

```bash
gpg --verify SHA256SUMS.asc SHA256SUMS      # signature must be good, by the key above
sha256sum --check SHA256SUMS                # file hashes must match
```

## Container images (cosign)

Images are signed **keyless** with [cosign](https://docs.sigstore.dev/) — the signature is bound to the
identity of the GitHub Actions workflow that built them, recorded in the public Rekor transparency log.
Verify the signer identity, not a static key:

```bash
cosign verify ghcr.io/openztna/openztna:stable \
  --certificate-identity-regexp '^https://github.com/OpenZTNA/OpenZTA-packages/' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com'
```

A software bill of materials (SBOM) and build provenance are attached as referrers:

```bash
cosign download sbom ghcr.io/openztna/openztna:stable
cosign verify-attestation ghcr.io/openztna/openztna:stable \
  --type slsaprovenance \
  --certificate-identity-regexp '^https://github.com/OpenZTNA/OpenZTA-packages/' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com'
```

## If verification fails

Do **not** install or run the artifact. A failed signature check can mean a corrupted download, a
man‑in‑the‑middle, or a key mismatch. Re‑download over a clean network; if it still fails, open an issue
(without disclosing anything sensitive) — and for a suspected compromise, follow [SECURITY.md](../SECURITY.md).
