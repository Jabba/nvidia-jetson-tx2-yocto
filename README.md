# nvidia-jetson-tx2-yocto

A Yocto Project (BitBake) build setup that produces a minimal, flashable Linux image for the
NVIDIA Jetson TX2, using the [`meta-tegra`](https://github.com/OE4T/meta-tegra) BSP layer.

There is no application source code in this repo — it *is* the build configuration: layer
checkouts, `local.conf`/`bblayers.conf`, and the Docker environment needed to run BitBake at all.
For the full write-up of the boot chain, Yocto concepts, and the reasoning behind every decision
here, see [`index.html`](index.html) (and [`layers.html`](layers.html) for the layer stack in
detail) — this README only covers day-to-day commands.

## Why 2018-era software

This project builds against `meta-tegra`'s `thud-l4t-r28.3` branch (L4T R28.3 / JetPack 3.3),
which locks the rest of the stack to **Poky "thud" (Yocto 2.6, 2018)**. Because that BitBake
version can't run on a modern host, the whole build happens inside a pinned Ubuntu 18.04 Docker
container. Don't upgrade `poky`, `meta-openembedded`, or `meta-tegra` independently — they must
stay matched to `thud`. See `index.html` for why the TX2 (unlike the TX1) isn't actually stuck on
this branch, it's just what's currently checked out.

## Prerequisites

- Docker, with your user able to run it (`docker` group or equivalent)
- ~50 GB free disk for `sources/`, `downloads/`, `sstate-cache/`, and `build/tmp/`
- A physical Jetson TX2 in Force Recovery Mode over USB, only needed for the flashing step

## Setup

### 1. Clone the pinned layers

```
cd sources
git clone -b thud git://git.yoctoproject.org/poky.git
git clone -b thud git://git.openembedded.org/meta-openembedded
git clone -b thud-l4t-r28.3 https://github.com/OE4T/meta-tegra.git
```

`poky` and `meta-openembedded` both need Poky's `thud` branch, matching meta-tegra's
`LAYERSERIES_COMPAT_tegra = "thud"` declaration. `meta-tegra` needs `thud-l4t-r28.3` specifically —
the branch containing `conf/machine/jetson-tx2.conf`.

If the `git://` protocol is blocked on your network, use the `https://` mirrors instead:
`https://git.yoctoproject.org/poky` and `https://git.openembedded.org/meta-openembedded`.

`sources/` is gitignored — these checkouts are reproducible from the branches above and aren't
committed.

### 2. Build and enter the container

```
./docker/build.sh
```

This builds the Ubuntu 18.04 image (`docker/Dockerfile`) and drops you into a shell with
`sources/`, `build/`, `downloads/`, and `sstate-cache/` bind-mounted at `/work`. Everything from
here on runs *inside* that container — never run `bitbake` directly on the host.

### 3. Initialize the build directory

```
source sources/poky/oe-init-build-env build
```

The first run generates `build/conf/local.conf` and `build/conf/bblayers.conf` from Poky's
defaults. Replace them with this project's hand-verified versions:

```
cp build/conf-templates/local.conf build/conf/local.conf
cp build/conf-templates/bblayers.conf build/conf/bblayers.conf
```

These templates set `MACHINE = "jetson-tx2"` and add the `image_types_tegra` class /
`tegraflash` image type meta-tegra needs to produce a flashable image. `build/` itself is
gitignored except for `conf-templates/` — if you ever delete `build/` to start fresh, these
templates are what you copy back in.

### 4. Sanity-check the layer stack before building

```
bitbake-layers show-layers
bitbake -p
```

`bitbake -p` is parse-only — it validates all layers/recipes with no actual build, and should
report 0 parse errors.

## Building

```
bitbake core-image-minimal
```

Full image build, ~1500 recipes, hours on first run (later runs reuse `sstate-cache/`). Output
lands in `build/tmp/deploy/images/jetson-tx2/core-image-minimal-jetson-tx2.tegraflash.zip`.

Useful debugging commands:

```
bitbake -e core-image-minimal     # dump final variable values for a target
```

There's no conventional test suite or linter here — correctness is verified by `bitbake -p` (0
parse errors) and `bitbake -e` (expected variable values), as documented in `index.html` section 8.

## Flashing

Requires a physical TX2 in Force Recovery Mode connected over USB. Extract
`core-image-minimal-jetson-tx2.tegraflash.zip` and run `./doflash.sh` from inside it, inside the
container. See `index.html` section 10 for the full procedure — this step needs physical hardware
access and can't be done by an agent.

## What's tracked in git vs. regenerated

| Path                    | Tracked?                          | Notes                                        |
|--------------------------|------------------------------------|-----------------------------------------------|
| `sources/*`              | No (gitignored)                   | Layer checkouts, reproducible from pinned branches |
| `build/*`                | Only `build/conf-templates/`      | Hand-verified `local.conf`/`bblayers.conf` copies |
| `downloads/`, `sstate-cache/` | No (gitignored)              | `DL_DIR`/`SSTATE_DIR` caches, safe to delete (forces re-fetch/re-build) |
