#!/bin/sh
set -e

# Waynux Package & Script Validator

EXIT_CODE=0

echo "==> [1/3] Checking shell script syntax..."
for script in scripts/*.sh packages/base/*/build; do
    if [ -f "$script" ]; then
        if ! sh -n "$script"; then
            echo "[!] Syntax error in $script"
            EXIT_CODE=1
        fi
    fi
done

echo "==> [2/3] Checking configuration files..."
if [ ! -f "config/licenses.allow" ]; then
    echo "[!] Missing config/licenses.allow"
    EXIT_CODE=1
fi

if [ ! -f "config/sources.lock" ]; then
    echo "[!] Missing config/sources.lock"
    EXIT_CODE=1
fi

echo "==> [3/3] Checking package metadata and license compliance..."
for pkg_dir in packages/base/*; do
    [ -d "$pkg_dir" ] || continue
    pkg=$(basename "$pkg_dir")

    # Check required files
    for req in build checksums depends license sources version; do
        if [ ! -f "$pkg_dir/$req" ]; then
            echo "[!] Package '$pkg' is missing required file: $req"
            EXIT_CODE=1
        fi
    done

    # Check license against allowed list
    if [ -f "$pkg_dir/license" ]; then
        lic=$(head -n 1 "$pkg_dir/license" | tr -d '\r\n')
        if [ -n "$lic" ] && ! grep -q "^$lic$" config/licenses.allow; then
            echo "[!] Package '$pkg' has unallowed or unknown license: '$lic'"
            EXIT_CODE=1
        fi
    fi

    # Check version against sources.lock
    if [ -f "$pkg_dir/version" ]; then
        ver=$(head -n 1 "$pkg_dir/version" | tr -d '\r\n')
        if [ -n "$ver" ] && ! grep -q "^$pkg $ver$" config/sources.lock; then
            echo "[*] Warning: Package '$pkg' version ($ver) does not match entry in config/sources.lock"
        fi
    fi
done

if [ "$EXIT_CODE" -eq 0 ]; then
    echo "==> Validation successful! All checks passed."
else
    echo "[!] Validation failed with errors."
    exit 1
fi
