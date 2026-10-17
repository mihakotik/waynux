#!/bin/sh
set -e

WAYNUX_ROOT="${WAYNUX_ROOT:-/mnt/waynux}"

if [ ! -d "$WAYNUX_ROOT" ]; then
    echo "[!] WAYNUX_ROOT does not exist: $WAYNUX_ROOT"
    exit 1
fi

echo "==> Entering Waynux environment at $WAYNUX_ROOT..."

if command -v bwrap >/dev/null 2>&1; then
    LIB64_ARG=""
    if [ -d "$WAYNUX_ROOT/lib64" ]; then
        LIB64_ARG="--bind $WAYNUX_ROOT/lib64 /lib64"
    fi

    exec bwrap \
        --die-with-parent \
        --new-session \
        --bind "$WAYNUX_ROOT" / \
        --proc /proc \
        --dev /dev \
        --tmpfs /tmp \
        --tmpfs /run \
        --setenv PATH /usr/bin:/bin:/usr/sbin:/sbin \
        --setenv TERM "$TERM" \
        --setenv HOME /root \
        --chdir /root \
        /bin/sh
else
    if [ "$(id -u)" -ne 0 ]; then
        echo "[!] Standard chroot requires root privileges. Please run with sudo or install bwrap."
        exit 1
    fi

    mount --bind /dev "$WAYNUX_ROOT/dev"
    mount -t devpts devpts "$WAYNUX_ROOT/dev/pts" -o gid=5,mode=620
    mount -t proc proc "$WAYNUX_ROOT/proc"
    mount -t sysfs sysfs "$WAYNUX_ROOT/sys"
    mount -t tmpfs tmpfs "$WAYNUX_ROOT/run"

    chroot "$WAYNUX_ROOT" /bin/sh -c "export PATH=/usr/bin:/bin:/usr/sbin:/sbin; cd /root; exec /bin/sh"

    umount "$WAYNUX_ROOT/run" || true
    umount "$WAYNUX_ROOT/sys" || true
    umount "$WAYNUX_ROOT/proc" || true
    umount "$WAYNUX_ROOT/dev/pts" || true
    umount "$WAYNUX_ROOT/dev" || true
fi
