#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
kernelver=$(uname -r)
source ./dkms.conf
sudo dkms remove "$PACKAGE_NAME/$PACKAGE_VERSION" --all
dropin=/etc/mkinitcpio.conf.d/amdgpu-dmub-timeout.conf
if cmp -s amdgpu-dmub-timeout.conf "$dropin"; then
    sudo rm -- "$dropin"
elif [[ -e $dropin ]]; then
    echo "Leaving modified $dropin in place."
fi
sudo depmod -a
sudo mkinitcpio -p linux
echo "Original driver restored for the next boot."
