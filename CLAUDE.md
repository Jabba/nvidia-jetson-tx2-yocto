# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Yocto Project (BitBake) build setup that produces a minimal, flashable Linux image for the
NVIDIA Jetson TX2, using the `meta-tegra` BSP layer. There is no application source code here —
this repo *is* the build configuration: layer checkouts, `local.conf`/`bblayers.conf`, and the
Docker environment needed to run BitBake at all. `index.html` is a long-form written explanation
of the whole project (boot chains, Yocto concepts, why every decision was made) — read it before
making non-trivial changes; it documents the reasoning this CLAUDE.md only summarizes.

## Why everything is pinned to 2018-era software

This project builds against `meta-tegra`'s `thud-l4t-r28.3` branch (L4T R28.3 / JetPack 3.3),
which declares `LAYERSERIES_COMPAT_tegra = "thud"` and locks the rest of the stack to **Poky
"thud" (Yocto 2.6, 2018)**. Unlike the TX1 (whose L4T support ended at R28.3), NVIDIA kept
shipping L4T updates for the TX2 well past this point — `thud-l4t-r28.3` isn't the TX2's ceiling,
it's just the branch already checked out in `sources/meta-tegra`. Moving to a newer meta-tegra
branch (e.g. `kirkstone-l4t-r32.7.x`) is possible for this board if ever needed, but is a
significant re-pin (different Poky/BitBake version, different Docker base image, different
toolchain) — don't do it incidentally. As long as this project stays on `thud-l4t-r28.3`, don't
"upgrade" poky, meta-openembedded, or meta-tegra independently; they must stay matched to
`thud`.

Because Yocto 2.6/BitBake cannot run on a modern host (Python 3.12 / glibc 2.39 / gcc 13 are all
too new), the entire build must happen inside the pinned Ubuntu 18.04 Docker container — never
attempt to run `bitbake` directly on the host.

## Common commands

Build the container image and drop into it (mounts `sources/`, `build/`, `downloads/`,
`sstate-cache/` from the repo root):

```
./docker/build.sh
```

Everything below runs *inside* that container:

```
source sources/poky/oe-init-build-env build
bitbake core-image-minimal        # full image build (~1500 recipes, hours on first run)
bitbake -p                        # parse-only: validates all layers/recipes, no build
bitbake -e core-image-minimal     # dump final variable values for a target (debugging config)
bitbake-layers show-layers        # confirm layer stack and priorities resolve correctly
```

There is no test suite or linter in the conventional sense; correctness is verified by `bitbake -p`
(0 parse errors) and `bitbake -e` (expected variable values), as documented in `index.html` section 8.

## Layer stack and machine config

Layers, lowest to highest priority (see `build/conf/bblayers.conf` /
`build/conf-templates/bblayers.conf`):

- `poky/meta` — OpenEmbedded-Core (generic base)
- `poky/meta-poky` — default distro policy (`DISTRO = "poky"`, unchanged)
- `poky/meta-yocto-bsp` — reference/QEMU machines (unused for this board)
- `meta-openembedded/meta-oe` — extra common recipes
- `meta-tegra` — TX2 board support (highest priority; the point of this project)

Target machine is `MACHINE = "jetson-tx2"`, set in `build/conf/local.conf`, overriding Poky's
`qemux86` default. Machine specifics (bootloader defconfig, kernel device tree, eMMC partition
sizes) live in `sources/meta-tegra/conf/machine/jetson-tx2.conf`, which pulls in the shared
`conf/machine/include/tegra186.inc` (SoC family: `tegra186`, the TX2's Pascal-generation chip).

`local.conf` also explicitly adds `IMAGE_CLASSES += "image_types_tegra"` and
`IMAGE_FSTYPES += "tegraflash"` to get a flashable `tegraflash.zip` output — this is required
because meta-tegra does not inherit its own flashing class by default; omitting it breaks parsing
for every image recipe with `No IMAGE_CMD defined for IMAGE_FSTYPES entry 'tegraflash'`.

## What's tracked in git vs. regenerated

- `sources/*` — layer checkouts (poky, meta-openembedded, meta-tegra). Gitignored; reproducible
  from the pinned branches, not committed.
- `build/*` — BitBake's working directory, including multi-GB `tmp/`. Gitignored **except**
  `build/conf-templates/`, which holds hand-verified copies of `local.conf`/`bblayers.conf` so the
  disposable `build/` directory can be deleted and regenerated without losing configuration
  decisions. If you change build configuration, edit the templates in `build/conf-templates/`, not
  (only) the live `build/conf/` files.
- `downloads/`, `sstate-cache/` — gitignored caches (`DL_DIR`, `SSTATE_DIR`). Safe to keep
  indefinitely and share across builds; deleting them just forces re-fetch/re-build of everything.

## Flashing

Build output lands in `build/tmp/deploy/images/jetson-tx2/`, specifically
`core-image-minimal-jetson-tx2.tegraflash.zip`. Flashing requires a physical TX2 in Force Recovery
Mode connected over USB and running `./doflash.sh` from the extracted zip inside the container —
see `index.html` section 10 for the full procedure. This step cannot be performed by an agent
without physical hardware access.
