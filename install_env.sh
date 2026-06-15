#!/usr/bin/env bash
#
# install_env.sh — Installs pkgdiff dependencies on AlmaLinux 9.
#
# Usage: sudo ./install_env.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (or via sudo)." >&2
    exit 1
fi

if ! grep -qi "almalinux" /etc/os-release 2>/dev/null; then
    echo "Warning: this script is intended for AlmaLinux 9." >&2
fi

echo "==> Refreshing repository metadata"
dnf -y makecache

echo "==> Enabling the EPEL repository (required for wdiff)"
dnf -y install epel-release

echo "==> Installing required dependencies"
dnf -y install \
    perl \
    perl-File-LibMagic \
    diffutils \
    wdiff \
    gawk \
    binutils \
    make \
    rpm-build \
    cpio

echo "==> Installing dependencies for suggested tools"
dnf -y install \
    curl \
    tar \
    gzip \
    gcc \
    gcc-c++ \
    elfutils \
    elfutils-libelf-devel

BUILD_DIR="${BUILD_DIR:-/tmp/pkgdiff-suggests}"
mkdir -p "$BUILD_DIR"

fetch_and_build() {
    local name="$1" version="$2"
    local tarball="$BUILD_DIR/${name}-${version}.tar.gz"
    local srcdir="$BUILD_DIR/${name}-${version}"

    echo "==> Installing ${name} ${version}"
    curl -fsSL -o "$tarball" "https://github.com/lvc/${name}/archive/refs/tags/${version}.tar.gz"
    tar -xzf "$tarball" -C "$BUILD_DIR"
    make -C "$srcdir" install prefix=/usr/local
}

if ! command -v vtable-dumper >/dev/null 2>&1; then
    fetch_and_build vtable-dumper 1.2
fi

if ! command -v abi-dumper >/dev/null 2>&1; then
    fetch_and_build abi-dumper 1.2
fi

if ! command -v abi-compliance-checker >/dev/null 2>&1; then
    fetch_and_build abi-compliance-checker 2.3
fi

echo "==> Verifying installed tools"
for cmd in perl diff wdiff gawk readelf make abi-dumper abi-compliance-checker vtable-dumper; do
    if command -v "$cmd" >/dev/null 2>&1; then
        printf "  [OK]  %s -> %s\n" "$cmd" "$(command -v "$cmd")"
    else
        printf "  [KO]  %s not found\n" "$cmd" >&2
    fi
done

echo
echo "Dependencies installed. You can now run:"
echo "    sudo make install prefix=/usr"
