#!/bin/sh
set -e

# Waynux ISO Builder Script
# Creates a bootable Live ISO using GRUB and linux-libre

WAYNUX_ROOT="${WAYNUX_ROOT:-/mnt/waynux}"
ISO_OUTPUT="${ISO_OUTPUT:-waynux.iso}"
WORK_DIR="${WORK_DIR:-/tmp/waynux-iso}"
ISODIR="$WORK_DIR/iso"

echo "==> Building Waynux Live ISO..."
echo "    Root:   $WAYNUX_ROOT"
echo "    Output: $ISO_OUTPUT"

if [ ! -d "$WAYNUX_ROOT" ]; then
    echo "[!] WAYNUX_ROOT does not exist: $WAYNUX_ROOT"
    exit 1
fi

if ! command -v grub-mkrescue >/dev/null 2>&1 && ! command -v xorriso >/dev/null 2>&1; then
    echo "[!] grub-mkrescue or xorriso is required to generate the ISO."
    echo "    Ubuntu/Debian: sudo apt install grub-pc-bin grub-efi-amd64-bin xorriso mtools"
    exit 1
fi

rm -rf "$WORK_DIR"
mkdir -p "$ISODIR/boot/grub"

KERNEL=$(find "$WAYNUX_ROOT/boot" -name "vmlinuz*" | head -n 1)
if [ -z "$KERNEL" ] || [ ! -f "$KERNEL" ]; then
    echo "[!] Kernel not found in $WAYNUX_ROOT/boot"
    exit 1
fi
echo "--> Using kernel: $KERNEL"
cp -v "$KERNEL" "$ISODIR/boot/vmlinuz"

INITRAMFS_TMP="$WORK_DIR/initramfs"
mkdir -p "$INITRAMFS_TMP/bin" "$INITRAMFS_TMP/sbin" "$INITRAMFS_TMP/dev" \
         "$INITRAMFS_TMP/proc" "$INITRAMFS_TMP/sys" "$INITRAMFS_TMP/mnt" \
         "$INITRAMFS_TMP/etc" "$INITRAMFS_TMP/usr/bin" "$INITRAMFS_TMP/usr/sbin"

for bin in sh echo mount umount mkdir switch_root; do
    if [ -f "$WAYNUX_ROOT/bin/$bin" ]; then
        cp -a "$WAYNUX_ROOT/bin/$bin" "$INITRAMFS_TMP/bin/"
    elif [ -f "$WAYNUX_ROOT/usr/bin/$bin" ]; then
        cp -a "$WAYNUX_ROOT/usr/bin/$bin" "$INITRAMFS_TMP/bin/"
    fi
done

if [ -d "$WAYNUX_ROOT/lib" ]; then
    cp -a "$WAYNUX_ROOT/lib" "$INITRAMFS_TMP/"
fi
if [ -d "$WAYNUX_ROOT/lib64" ]; then
    cp -a "$WAYNUX_ROOT/lib64" "$INITRAMFS_TMP/"
fi

cat << 'EOF' > "$INITRAMFS_TMP/init"
#!/bin/sh
mount -t devtmpfs devtmpfs /dev 2>/dev/null || mount -t tmpfs tmpfs /dev
mount -t proc proc /proc
mount -t sysfs sysfs /sys

echo "Welcome to Waynux!"

exec /bin/sh
EOF
chmod +x "$INITRAMFS_TMP/init"

echo "--> Generating initramfs..."
(
    cd "$INITRAMFS_TMP"
    find . | cpio -o -H newc | gzip -9 > "$ISODIR/boot/initrd.img"
)

cat << 'EOF' > "$ISODIR/boot/grub/grub.cfg"
set default=0
set timeout=5

menuentry "Waynux Live (GNU/Linux)" {
    linux /boot/vmlinuz quiet console=tty1
    initrd /boot/initrd.img
}

menuentry "Waynux Live (Debug mode)" {
    linux /boot/vmlinuz debug console=tty1
    initrd /boot/initrd.img
}
EOF

echo "--> Creating bootable ISO with grub-mkrescue..."
grub-mkrescue -o "$ISO_OUTPUT" "$ISODIR"

echo "==> ISO build complete: $ISO_OUTPUT"
rm -rf "$WORK_DIR"
