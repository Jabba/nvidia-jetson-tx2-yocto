#!/usr/bin/env bash
# Build (if needed) and enter the Ubuntu 18.04 container used for all Yocto
# work in this project. Run this instead of using bitbake/oe-init-build-env
# directly on the host — see index.html section 9 for why.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="yocto-tx2-builder"

docker build \
    --build-arg USER_UID="$(id -u)" \
    --build-arg USER_GID="$(id -g)" \
    -t "${IMAGE_NAME}" \
    "${PROJECT_ROOT}/docker"

mkdir -p "${PROJECT_ROOT}/downloads" "${PROJECT_ROOT}/sstate-cache"

exec docker run --rm -i \
    -v "${PROJECT_ROOT}/sources:/work/sources" \
    -v "${PROJECT_ROOT}/build:/work/build" \
    -v "${PROJECT_ROOT}/downloads:/work/downloads" \
    -v "${PROJECT_ROOT}/sstate-cache:/work/sstate-cache" \
    -w /work \
    "${IMAGE_NAME}" \
    "$@"
