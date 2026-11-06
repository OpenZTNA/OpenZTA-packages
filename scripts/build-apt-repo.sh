#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Build/refresh a signed APT repository with apt-ftparchive (stateless: scans a
# per-suite pool, regenerates Packages + Release, then GPG-signs Release into
# InRelease + Release.gpg). The resulting tree is served verbatim over GitHub
# Pages and consumed by apt via a deb822 `.sources` entry with Signed-By.
#
# Layout under <repo-root> (default: deb/):
#   pool/<suite>/main/<pkg>_<ver>_<arch>.deb
#   dists/<suite>/main/binary-<arch>/Packages{,.gz}
#   dists/<suite>/{Release,InRelease,Release.gpg}
#
# Channels (suites) are independent pools so stable and nightly never mix and
# "latest-only per channel" is a simple wipe-and-add.
#
#   build-apt-repo.sh --suite stable --deb openzta_0.2.0_amd64.deb --gpg-key <id>
#   GPG_KEY=<id> build-apt-repo.sh --suite nightly --deb <file>
set -euo pipefail

REPO_ROOT="deb"
SUITE="stable"
ARCH="amd64"
DEB=""
GPG_KEY="${GPG_KEY:-}"
ORIGIN="OpenZTNA"
LABEL="OpenZTNA"

usage() { echo "usage: $0 --suite <stable|nightly> [--deb <file>] [--repo-root deb] [--arch amd64] [--gpg-key <id>]"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root) REPO_ROOT="$2"; shift 2;;
    --suite)     SUITE="$2";     shift 2;;
    --arch)      ARCH="$2";      shift 2;;
    --deb)       DEB="$2";       shift 2;;
    --gpg-key)   GPG_KEY="$2";   shift 2;;
    -h|--help)   usage; exit 0;;
    *) echo "unknown arg: $1" >&2; usage; exit 2;;
  esac
done

[ "$SUITE" = stable ] || [ "$SUITE" = nightly ] || { echo "suite must be stable|nightly" >&2; exit 2; }

pool="$REPO_ROOT/pool/$SUITE/main"
dist="$REPO_ROOT/dists/$SUITE"
bindir="$dist/main/binary-$ARCH"
mkdir -p "$pool" "$bindir"

if [ -n "$DEB" ]; then
  [ -f "$DEB" ] || { echo "no such deb: $DEB" >&2; exit 2; }
  pkgname="$(dpkg-deb -f "$DEB" Package)"
  # latest-only per channel: drop older copies of this package in this suite
  find "$pool" -maxdepth 1 -name "${pkgname}_*.deb" -delete
  cp "$DEB" "$pool/"
  echo "added $(basename "$DEB") to $pool"
fi

# Packages index (Filename: is relative to the repo root, where the dist is served)
( cd "$REPO_ROOT" && apt-ftparchive --arch "$ARCH" packages "pool/$SUITE/main" ) > "$bindir/Packages"
gzip -9c "$bindir/Packages" > "$bindir/Packages.gz"

# Release
conf="$(mktemp)"
cat > "$conf" <<EOF
APT::FTPArchive::Release::Origin "$ORIGIN";
APT::FTPArchive::Release::Label "$LABEL";
APT::FTPArchive::Release::Suite "$SUITE";
APT::FTPArchive::Release::Codename "$SUITE";
APT::FTPArchive::Release::Architectures "$ARCH";
APT::FTPArchive::Release::Components "main";
APT::FTPArchive::Release::Description "OpenZTNA $SUITE channel";
EOF
( cd "$dist" && apt-ftparchive -c "$conf" release . ) > "$dist/Release"
rm -f "$conf"

# Sign
if [ -n "$GPG_KEY" ]; then
  rm -f "$dist/InRelease" "$dist/Release.gpg"
  gpg --batch --yes --pinentry-mode loopback --local-user "$GPG_KEY" --clearsign -o "$dist/InRelease" "$dist/Release"
  gpg --batch --yes --pinentry-mode loopback --local-user "$GPG_KEY" -abs -o "$dist/Release.gpg" "$dist/Release"
  echo "signed: $dist/InRelease + $dist/Release.gpg"
else
  echo "WARNING: no --gpg-key given; repository is UNSIGNED and apt will refuse it." >&2
fi

echo "apt repo updated: $dist"
