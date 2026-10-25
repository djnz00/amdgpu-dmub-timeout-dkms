#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
kernelver=${1:-$(uname -r)}
source ./dkms.conf
[[ $kernelver =~ $BUILD_EXCLUSIVE_KERNEL ]] || {
    echo "This source supports 7.2.x only; refresh the source pin for another series." >&2
    exit 1
}
[[ -f /lib/modules/$kernelver/build/Module.symvers ]] || {
    echo "Install the matching kernel headers first." >&2; exit 1;
}
[[ -f /etc/mkinitcpio.d/linux.preset ]] || {
    echo "This installer targets Arch's linux/mkinitcpio preset." >&2; exit 1;
}
./fetch-source.sh
package="$PACKAGE_NAME/$PACKAGE_VERSION"
if [[ -n $(sudo dkms status "$package") ]]; then
    for file in drivers/gpu/drm/amd/display/dc/dc_dmub_srv.c drivers/gpu/drm/amd/amdgpu/amdgpu_drv.c; do
        cmp -- "$file" "/usr/src/${PACKAGE_NAME}-${PACKAGE_VERSION}/$file" || {
            echo "Registered source differs; use a new package version." >&2; exit 1;
        }
    done
else
    backup="/var/lib/$PACKAGE_NAME/backup/$kernelver"
    sudo install -d -m 0755 "$backup"
    original=$(modinfo -k "$kernelver" -n amdgpu)
    sudo cp -a --no-clobber "$original" "$backup/"
    sudo cp -a --no-clobber /boot/initramfs-linux.img "$backup/"
    sudo dkms add "$PWD"
fi
sudo dkms build "$package" -k "$kernelver"
sudo dkms install "$package" -k "$kernelver"
dropin=/etc/mkinitcpio.conf.d/amdgpu-dmub-timeout.conf
if [[ -e $dropin ]] && ! cmp -s amdgpu-dmub-timeout.conf "$dropin"; then
    echo "Existing $dropin differs; merge MODULES+=(amdgpu), then run mkinitcpio -p linux." >&2
    exit 1
fi
sudo install -D -m 0644 amdgpu-dmub-timeout.conf "$dropin"
sudo mkinitcpio -p linux
modinfo -k "$kernelver" -F filename amdgpu
modinfo -k "$kernelver" -F version amdgpu
echo "Installed. Reboot to load the patched driver."
