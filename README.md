# AMDGPU DMUB 200 ms timeout (DKMS)

A small patch and DKMS wrapper for Arch Linux's in-tree AMDGPU driver. It
changes `MAX_WAIT_US` in `display/dc/dc_dmub_srv.c` from `100000` to `200000`.
This shared DMUB service budget covers command completion and several other
DMUB waits. It is a nominal polling budget; actual wall-clock duration includes
register-access and loop overhead.

The motivation is an observed Cezanne/DCN 2.1 eDP panel-power-off command that
finishes after the driver reports a timeout during login. This is an experimental
workaround, not an upstream fix or a general remedy for all DMCUB errors.

## Source and compatibility

- Upstream: [archlinux/linux](https://github.com/archlinux/linux), tag `v7.2.11-arch1`.
- Pinned commit: `64a90897d3c539033f24105968e3513957e70819`.
- Source archive SHA-256 is pinned in [source.env](source.env).
- DKMS package: `amdgpu-dmub-timeout/7.2.11.1`; built module: `amdgpu`.
- Built and installed against `7.2.11-arch1-1`. Automatic builds are restricted
  to **7.2.x**; other 7.2 patch releases still require validation.
- Newer kernel series are deliberately skipped. Refresh the source pin and
  review compatibility before widening this restriction.

Only the patch, scripts, and configuration are tracked. Fetching downloads the
full compressed kernel archive (about 254 MiB), checks its SHA-256, extracts the
AMD driver and DRM headers, and applies the patch without fuzz. The generated
source occupies roughly 554 MiB and is ignored by Git. DKMS receives a local
copy, so ordinary automatic rebuilds do not need a network connection.

The only driver changes are the timeout and a `MODULE_VERSION("7.2.11.1")`
identifier. Runtime features follow the installed kernel configuration. Debug
information and module BTF are omitted to keep build disk usage modest.

## Install on Arch Linux

Install `base-devel`, `dkms`, matching `linux-headers`, `curl`, `patch`, `zstd`,
and `mkinitcpio`. Keep the installed kernel and headers in sync.

```sh
git clone https://github.com/djnz00/amdgpu-dmub-timeout-dkms.git
cd amdgpu-dmub-timeout-dkms
./install.sh
```

The installer fetches source as your user, backs up the original module and
initramfs under `/var/lib/amdgpu-dmub-timeout/backup/`, builds and installs through
DKMS, adds an `amdgpu` mkinitcpio module drop-in, and rebuilds the `linux` preset.
The explicit module entry is needed because Arch's `kms` hook filters by the
in-tree driver path and can miss `updates/dkms/amdgpu.ko.zst`.

Reboot to activate it. The installer does not unload a live display driver or
reboot the machine. Secure Boot systems must trust the DKMS signing certificate.

## Fetch or build separately

```sh
./fetch-source.sh
./build.sh "$(uname -r)"
```

Archives are cached in `$XDG_CACHE_HOME/amdgpu-dmub-timeout/`, defaulting to
`~/.cache/amdgpu-dmub-timeout/`. Set `AMDGPU_SOURCE_ARCHIVE` to use an existing
archive; its checksum is still verified. Set `AMDGPU_BUILD_JOBS` to change the
default eight parallel compiler jobs.

The source stamp avoids downloading and patching again. It identifies the pin
and patch, not arbitrary edits to generated source. Use a fresh checkout when
changing pins or patches. Do not edit generated `drivers/` to maintain a patch.

## Verify after reboot

```sh
cat /sys/module/amdgpu/version       # expected: 7.2.11.1 (loaded module)
modinfo -n amdgpu                    # expected: .../updates/dkms/amdgpu.ko.zst
dkms status amdgpu-dmub-timeout/7.2.11.1
sudo journalctl -k -b | grep -E 'DMUB|DMCUB|amdgpu.*ERROR'
```

For detailed diagnostic state, `drm.debug=0x02` can be added to the kernel
command line separately. This repository does not alter GRUB.

## Roll back

```sh
./uninstall.sh
```

DKMS restores the original module, the unmodified mkinitcpio drop-in is removed,
and the initramfs is regenerated. Reboot to activate the restored driver.

## Maintaining the pin

Update `source.env` to a reviewed Arch kernel commit and record the SHA-256 of
its codeload archive. Review/rebase the patch, increment the DKMS and module
versions, and adjust the kernel-series restriction only after a successful
build and boot test. Do not automatically follow a moving branch.

The driver remains part of the [Linux kernel](https://github.com/torvalds/linux/tree/master/drivers/gpu/drm/amd).
Report upstream AMD display issues at [drm/amd](https://gitlab.freedesktop.org/drm/amd/-/issues).

License: GPL-2.0-only; downloaded kernel files retain their original licenses.
