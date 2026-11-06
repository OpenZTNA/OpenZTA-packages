#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Build/refresh a signed DNF/YUM repository with createrepo_c. Signs the package
# (rpm --addsign) and the repository metadata (detached-sign repomd.xml), so a
# client with gpgcheck=1 + repo_gpgcheck=1 verifies both.
#
# Layout under <repo-root> (default: rpm/):
#   <suite>/<pkg>-<ver>.<arch>.rpm
#   <suite>/repodata/{repomd.xml,repomd.xml.asc,...}
#
#   build-dnf-repo.sh --suite stable --rpm openzta-0.2.0.x86_64.rpm --gpg-key <id>
set -euo pipefail

REPO_ROOT="rpm"
SUITE="stable"
RPM=""
GPG_KEY="${GPG_KEY:-}"

usage() { echo "usage: $0 --suite <stable|nightly> [--rpm <file>] [--repo-root rpm] [--gpg-key <id>]"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root) REPO_ROOT="$2"; shift 2;;
    --suite)     SUITE="$2";     shift 2;;
    --rpm)       RPM="$2";       shift 2;;
    --gpg-key)   GPG_KEY="$2";   shift 2;;
    -h|--help)   usage; exit 0;;
    *) echo "unknown arg: $1" >&2; usage; exit 2;;
  esac
done

[ "$SUITE" = stable ] || [ "$SUITE" = nightly ] || { echo "suite must be stable|nightly" >&2; exit 2; }

dir="$REPO_ROOT/$SUITE"
mkdir -p "$dir"

if [ -n "$RPM" ]; then
  [ -f "$RPM" ] || { echo "no such rpm: $RPM" >&2; exit 2; }
  pkgname="$(rpm -qp --queryformat '%{NAME}' "$RPM" 2>/dev/null || echo openzta)"
  find "$dir" -maxdepth 1 -name "${pkgname}-*.rpm" -delete
  cp "$RPM" "$dir/"
  echo "added $(basename "$RPM") to $dir"
  if [ -n "$GPG_KEY" ]; then
    # rpm drives gpg; loopback pinentry so a passphrase-less CI key signs non-interactively.
    cat > "$HOME/.rpmmacros" <<EOF
%_gpg_name $GPG_KEY
%__gpg_sign_cmd %{__gpg} gpg --batch --no-armor --pinentry-mode loopback --no-secmem-warning -u "%{_gpg_name}" -sbo %{__signature_filename} --digest-algo sha256 %{__plaintext_filename}
EOF
    rpm --addsign "$dir"/*.rpm && echo "rpm --addsign: ok" || echo "WARN: rpm --addsign failed (packages unsigned; repo metadata signature still applies)" >&2
  fi
fi

createrepo_c --update "$dir"

if [ -n "$GPG_KEY" ]; then
  rm -f "$dir/repodata/repomd.xml.asc"
  gpg --batch --yes --pinentry-mode loopback --local-user "$GPG_KEY" --detach-sign --armor "$dir/repodata/repomd.xml"
  echo "signed: $dir/repodata/repomd.xml.asc"
else
  echo "WARNING: no --gpg-key given; repository metadata is UNSIGNED." >&2
fi

echo "dnf repo updated: $dir"
