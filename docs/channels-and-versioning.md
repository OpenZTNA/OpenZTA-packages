# Release channels & versioning

OpenZTNA is published in two channels. You subscribe to one by adding its line to your package manager;
updates then arrive with ordinary `apt upgrade` / `dnf upgrade`.

## Channels

| Channel | Who it's for | Source | Cadence |
|---|---|---|---|
| **stable** | Most users. | Tagged releases. | On each `v0.y.z` tag. |
| **nightly** | Testing the newest changes; reporting bugs. | The development branch. | Daily (when there are changes). |

- **Subscribe to one channel per source entry.** The channels are kept as separate suites/components so
  a `stable` subscriber never silently receives a nightly build. You can enable both and pin if you
  know what you are doing, but the default is to pick one.
- **stable** is the recommended channel. **nightly** can change or break at any time and is intended for
  evaluation and bug reports.

How to select a channel is in each install guide:
[Ubuntu/Debian](install/ubuntu-debian.md), [Kali](install/kali.md),
[Fedora/RHEL](install/fedora-rhel.md). For containers, use the `:stable`/`:nightly` image tags
([containers](install/containers.md)).

## Version numbers

OpenZTNA follows **Semantic Versioning**, and is intentionally **below `1.0`** while it is
alpha/beta:

- A version like `0.2.0` is a **stable** release.
- While pre‑1.0, the leading `0.` signals that **anything may change between minor versions** —
  configuration keys, on‑the‑wire behaviour, and defaults are not yet frozen. Read the changelog before
  upgrading across a minor bump.
- There will be **no `1.0`** until the project declares general availability. Until then every published
  version starts with `0.`.

### Nightly version strings

Nightly packages use a pre‑release form so they always sort **between** the last stable release and the
next one, and are clearly marked:

```
0.2.0~nightly20261106.gab12cd3
│      │        │        └── short git commit the build came from
│      │        └── build date (UTC)
│      └── pre-release marker (sorts BEFORE 0.2.0 in dpkg and rpm)
└── the upcoming stable version this nightly is working toward
```

Because `~` sorts before everything in both Debian and RPM version ordering, `0.2.0~nightly…` is older
than `0.2.0` but newer than `0.1.x` — exactly what you want for a pre‑release channel. You can confirm
ordering yourself:

```bash
dpkg --compare-versions '0.1.0' lt '0.2.0~nightly20261106.gab12cd3' && echo "nightly is newer than 0.1.0"
dpkg --compare-versions '0.2.0~nightly20261106.gab12cd3' lt '0.2.0' && echo "nightly is older than 0.2.0 stable"
```

Container images are tagged `:stable` / `:latest` and `:0.y.z` for releases, and `:nightly` plus an
immutable `:0.y.z-nightly.YYYYMMDD` for nightlies.

## Updating and downgrading

- **Update:** `sudo apt-get update && sudo apt-get upgrade` (or `sudo dnf upgrade openzta`).
- **Pin to a specific version:** `sudo apt-get install openzta=0.2.0` (deb) or
  `sudo dnf install openzta-0.2.0` (rpm).
- **Switch channels:** edit the sources entry (change the suite from `stable` to `nightly` or back) and
  re‑run update. Moving from nightly back to stable may require an explicit version pin or
  `--allow-downgrades` because the nightly you have may be numerically newer than the current stable.

Upgrades preserve your `/etc/openzta/daemon.toml` (it is a conffile) and your enrolled identity under
`/var/lib/openzta`. See [operations](operations.md) for the upgrade/restart details.
