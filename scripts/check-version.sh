#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Guard: OpenZTNA stays below 1.0 while it is alpha/beta. Fail any version that
# is not 0.x. Used by the publish pipeline and usable in the private build CI.
#
#   check-version.sh <version>     # e.g. 0.2.0  or  0.2.0~nightly20261106.gabc123  or  v0.2.0
set -euo pipefail

ver="${1:?usage: check-version.sh <version>}"
ver="${ver#v}"   # tolerate a leading v (tag form)

if [[ "$ver" =~ ^0\.[0-9] ]]; then
  echo "ok: '$ver' is a pre-1.0 (0.x) version"
  exit 0
fi

echo "ERROR: version '$ver' is not below 1.0 — OpenZTNA must stay 0.x while alpha/beta." >&2
echo "       (refusing to publish a >= 1.0 version)" >&2
exit 1
