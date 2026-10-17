# Waynux

[![Build Waynux](https://github.com/mihakotik/waynux/actions/workflows/build.yml/badge.svg)](https://github.com/mihakotik/waynux/actions/workflows/build.yml)

**Waynux** is an independent, source-based GNU/Linux distribution built from source in an isolated [bubblewrap](https://github.com/containers/bubblewrap) (`bwrap`) sandbox.

## Features

- **Isolated Sandbox Builds**: Builds packages inside non-root `bwrap` sandboxes to prevent host contamination.
- **GNU Base System**: Modern GNU toolchain (`gcc`, `binutils`, `glibc`) with Linux kernel.
- **Package Metadata**: Standardized package manifests with versions, sources, sha256 checksums, licenses, and dependencies.
- **Bootable Live ISO**: Uses GRUB and custom minimal initramfs to generate bootable hybrid ISO images.
- **Continuous Integration**: Automated validation, bootstrap, and ISO artifact building via GitHub Actions.

## Requirements (Host)

- Linux host (x86_64)
- `bubblewrap` (`bwrap`)
- `build-essential`, `bison`, `flex`, `texinfo`, `gawk`, `bc`
- `libelf-dev`, `libssl-dev`, `libgmp-dev`, `libmpfr-dev`, `libmpc-dev`
- `grub-pc-bin`, `grub-efi-amd64-bin`, `xorriso`, `mtools`, `cpio`
- `wget` or `curl`

On Debian/Ubuntu:
```bash
sudo apt update && sudo apt install -y bubblewrap build-essential bison flex texinfo gawk bc \
  libelf-dev libssl-dev libgmp-dev libmpfr-dev libmpc-dev \
  grub-pc-bin grub-efi-amd64-bin xorriso mtools cpio wget curl
```

## Quick Start

```bash
# 1. Validate package manifests, licenses, and scripts
make validate

# 2. Bootstrap base system into /mnt/waynux
sudo mkdir -p /mnt/waynux /sources /logs
sudo chown -R $USER:$USER /mnt/waynux /sources /logs
make bootstrap

# 3. Build bootable Live ISO
make iso

# 4. (Optional) Enter isolated chroot environment
make chroot
```

## Available Make Targets

| Target | Description |
|---|---|
| `make validate` | Validate package metadata, license compliance, and shell scripts |
| `make bootstrap` | Compile and install base system packages inside `bwrap` |
| `make iso` | Build bootable Live ISO image (`waynux.iso`) |
| `make chroot` | Enter isolated Waynux environment |
| `make clean` | Clean temporary build directories |
| `make help` | Show available targets and environment variables |
