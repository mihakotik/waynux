#!/bin/sh
set -e

# Waynux Bootstrap Script
# Builds the base system inside an isolated bubblewrap (bwrap) sandbox

WAYNUX_ROOT="${WAYNUX_ROOT:-/mnt/waynux}"
WAYNUX_SOURCES="${WAYNUX_SOURCES:-/sources}"
WAYNUX_LOGS="${WAYNUX_LOGS:-/logs}"
WAYNUX_BUILD_TMP="${WAYNUX_BUILD_TMP:-/tmp/waynux-build}"

mkdir -p "$WAYNUX_ROOT" "$WAYNUX_SOURCES" "$WAYNUX_LOGS" "$WAYNUX_BUILD_TMP"

echo "         Waynux System Bootstrap          "
echo " Root directory:    $WAYNUX_ROOT"
echo " Sources directory: $WAYNUX_SOURCES"
echo " Logs directory:    $WAYNUX_LOGS"
echo " Temp directory:    $WAYNUX_BUILD_TMP"

if ! command -v bwrap >/dev/null 2>&1; then
    echo "[!] bubblewrap (bwrap) not found. Please install it:"
    echo "    Ubuntu/Debian: sudo apt install bubblewrap"
    echo "    Arch Linux:    sudo pacman -S bubblewrap"
    echo "    Fedora:        sudo dnf install bubblewrap"
    exit 1
fi

if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
    echo "[!] Neither wget nor curl found. Please install one of them."
    exit 1
fi

# Build order as required by LFS:
# 1. binutils
# 2. gcc (pass 1 - C only)
# 3. glibc (requires linux-headers)
# 4. gcc (pass 2 - C and C++)
# 5. base utilities and kernel
BUILD_STEPS="
binutils:1
gcc:1
glibc:1
gcc:2
linux:1
make:1
diffutils:1
findutils:1
gawk:1
grep:1
sed:1
tar:1
sysvinit:1
grub:1
"

download_source() {
    url="$1"
    dest_dir="$2"
    filename=$(basename "$url")
    target="$dest_dir/$filename"

    if [ ! -f "$target" ]; then
        echo "--> Downloading $filename..."
        if command -v wget >/dev/null 2>&1; then
            wget -q --show-progress -c -O "$target" "$url"
        else
            curl -fL -o "$target" "$url"
        fi
    fi
}

for step in $BUILD_STEPS; do
    [ -z "$step" ] && continue

    pkg=$(echo "$step" | cut -d: -f1)
    pass=$(echo "$step" | cut -d: -f2)

    if [ "$pkg" = "gcc" ]; then
        step_name="gcc (Pass $pass)"
        log_name="gcc-pass$pass"
    else
        step_name="$pkg"
        log_name="$pkg"
    fi

    echo ""
    echo "==> Building: $step_name"

    PKG_DIR="$(pwd)/packages/base/$pkg"
    if [ ! -d "$PKG_DIR" ]; then
        echo "[!] Package directory not found: $PKG_DIR"
        exit 1
    fi

    if [ -f "$PKG_DIR/sources" ]; then
        while read -r url; do
            [ -z "$url" ] && continue
            case "$url" in \#*) continue ;; esac
            download_source "$url" "$WAYNUX_SOURCES"
        done < "$PKG_DIR/sources"
    fi

    if [ "$pkg" = "glibc" ]; then
        download_source "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.8.tar.xz" "$WAYNUX_SOURCES"
    fi

    if [ -f "$PKG_DIR/checksums" ]; then
        echo "--> Verifying SHA256 checksums..."
        (
            cd "$WAYNUX_SOURCES"
            sha256sum -c "$PKG_DIR/checksums"
        ) || {
            echo "[!] Checksum verification failed for $pkg"
            exit 1
        }
    fi

    DESTDIR_TMP="$WAYNUX_BUILD_TMP/destdir-$pkg-pass$pass"
    rm -rf "$DESTDIR_TMP"
    mkdir -p "$DESTDIR_TMP"
    BUILD_SCRIPT="$WAYNUX_BUILD_TMP/build-$pkg.sh"
    cp "$PKG_DIR/build" "$BUILD_SCRIPT"
    chmod +x "$BUILD_SCRIPT"

    # Build optional mount arguments for /lib64
    LIB64_MOUNT=""
    if [ -d "/lib64" ]; then
        LIB64_MOUNT="--ro-bind /lib64 /lib64"
    fi

    echo "--> Running build in isolated sandbox (bwrap)..."
    bwrap \
        --unshare-all \
        --die-with-parent \
        --new-session \
        --ro-bind /usr /usr \
        --ro-bind /bin /bin \
        --ro-bind /lib /lib \
        $LIB64_MOUNT \
        --ro-bind /etc /etc \
        --bind "$WAYNUX_SOURCES" /sources \
        --bind "$DESTDIR_TMP" /destdir \
        --bind "$WAYNUX_BUILD_TMP" /build-tmp \
        --proc /proc \
        --dev /dev \
        --tmpfs /tmp \
        --tmpfs /home \
        --tmpfs /root \
        --tmpfs /var \
        --chdir /tmp \
        --setenv DESTDIR /destdir \
        --setenv PASS "$pass" \
        --setenv PATH /usr/bin:/bin:/usr/sbin:/sbin \
        --setenv HOME /tmp \
        /bin/sh "/build-tmp/build-$pkg.sh" \
        2>&1 | tee "$WAYNUX_LOGS/$log_name.log"

    if [ ! -d "$DESTDIR_TMP/usr" ] && [ ! -d "$DESTDIR_TMP/bin" ] && [ ! -d "$DESTDIR_TMP/boot" ] && [ ! -d "$DESTDIR_TMP/sbin" ]; then
        echo "[!] Build failed for $step_name: DESTDIR is empty!"
        exit 1
    fi

    mkdir -p "$WAYNUX_ROOT/var/lib/pm"
    find "$DESTDIR_TMP" -mindepth 1 | sed "s|^$DESTDIR_TMP||" > "$WAYNUX_ROOT/var/lib/pm/$log_name.files"

    echo "--> Merging $step_name into $WAYNUX_ROOT..."
    cp -a "$DESTDIR_TMP"/* "$WAYNUX_ROOT/" 2>/dev/null || true

    rm -rf "$DESTDIR_TMP" "$BUILD_SCRIPT"

    echo "==> $step_name completed successfully!"
done

echo ""
echo "==> Waynux Bootstrap Complete!"
echo "    Base system installed to: $WAYNUX_ROOT"