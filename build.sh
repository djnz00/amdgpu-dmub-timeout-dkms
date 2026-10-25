#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
kernel_version=${1:?Usage: build.sh KERNEL_VERSION}
./fetch-source.sh
mkdir -p "$PWD/include/trace"
# In-tree trace headers use ../../drivers/... paths. This include anchor
# resolves those paths to our fetched source instead of the headers package.
make -C "/lib/modules/${kernel_version}/build" \
    M="$PWD/drivers/gpu/drm/amd/amdgpu" \
    CONFIG_DRM_AMDGPU=m CONFIG_DEBUG_INFO_BTF_MODULES= \
    KCFLAGS="-g0 -I$PWD/include/trace" \
    -j"${AMDGPU_BUILD_JOBS:-8}" modules
