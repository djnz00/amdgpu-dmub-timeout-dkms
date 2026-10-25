#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
source ./source.env

patch_hash=$(sha256sum patches/0001-dmub-200ms.patch | cut -d ' ' -f1)
stamp="${SOURCE_COMMIT} ${SOURCE_SHA256} ${patch_hash}"
if [[ -f .source-stamp && $(<.source-stamp) == "$stamp" &&
      -f drivers/gpu/drm/amd/amdgpu/Makefile ]]; then
    echo "Pinned, patched AMDGPU source is ready."
    exit 0
fi
if [[ -e drivers ]]; then
    echo "Existing drivers/ does not match the source stamp; use a fresh checkout." >&2
    exit 1
fi

archive=${AMDGPU_SOURCE_ARCHIVE:-${XDG_CACHE_HOME:-$HOME/.cache}/amdgpu-dmub-timeout/linux-${SOURCE_COMMIT}.tar.gz}
verify_archive() {
    printf '%s  %s\n' "$SOURCE_SHA256" "$1" | sha256sum --check --status
}
download=
stage=
cleanup() {
    [[ -z $download ]] || rm -f -- "$download"
    [[ -z $stage ]] || rm -rf -- "$stage"
    return 0
}
trap cleanup EXIT

if [[ ! -f $archive ]]; then
    mkdir -p -- "$(dirname -- "$archive")"
    download=$(mktemp "${archive}.download.XXXXXX")
    curl --fail --location --retry 3 \
        "https://codeload.github.com/${SOURCE_REPO}/tar.gz/${SOURCE_COMMIT}" \
        --output "$download"
    verify_archive "$download" || { echo "Source checksum mismatch." >&2; exit 1; }
    mv -- "$download" "$archive"
    download=
fi
verify_archive "$archive" || { echo "Cached source checksum mismatch: $archive" >&2; exit 1; }

stage=$(mktemp -d "$PWD/.source.XXXXXX")
tar --extract --gzip --file="$archive" --directory="$stage" \
    --strip-components=1 --wildcards \
    'linux-*/drivers/gpu/drm/amd/*' 'linux-*/drivers/gpu/drm/*.h'
patch --batch --fuzz=0 --directory="$stage" -p1 < patches/0001-dmub-200ms.patch
mv -- "$stage/drivers" ./drivers
printf '%s\n' "$stamp" > .source-stamp
echo "Prepared ${SOURCE_TAG} (${SOURCE_COMMIT}) with the 200 ms patch."
