# syntax=docker/dockerfile:1
# OpenZTNA evaluation image: installs the signed `openzta` package from the
# public OpenZTNA APT repository (no source in the image). See
# docs/install/containers.md for the required host kernel (BTF), capabilities
# (CAP_BPF/CAP_PERFMON/CAP_NET_ADMIN), devices (/dev/net/tun, /dev/tpmrm0), and
# why this is an eval/dev image rather than a typical production deployment.
ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

# Channel to install from: stable (default) or nightly.
ARG CHANNEL=stable

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg; \
    curl -fsSL https://openztna.github.io/OpenZTA-packages/deb/openztna-archive-keyring.gpg \
      -o /usr/share/keyrings/openztna-archive-keyring.gpg; \
    printf 'Types: deb\nURIs: https://openztna.github.io/OpenZTA-packages/deb\nSuites: %s\nComponents: main\nSigned-By: /usr/share/keyrings/openztna-archive-keyring.gpg\n' "$CHANNEL" \
      > /etc/apt/sources.list.d/openztna.sources; \
    apt-get update; \
    apt-get install -y --no-install-recommends openzta tpm2-pkcs11 tpm2-tools; \
    rm -rf /var/lib/apt/lists/*

# The daemon ships inert (owner-only control socket). Provide config, a TPM, the
# PIN env, and the required caps/devices at `docker run` time — see the docs.
ENTRYPOINT ["/usr/lib/openzta/openzta-daemon", "--config", "/etc/openzta/daemon.toml"]
