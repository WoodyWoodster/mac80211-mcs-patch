#!/usr/bin/env bash
set -euo pipefail

# Rebuild patched mac80211 module for the current kernel.
# Called by pacman hook after kernel upgrades.

PATCH_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
PATCH_FILE="$PATCH_DIR/skip-basic-mcs-check.patch"
KVER="$(uname -r)"
BUILD_DIR="/usr/lib/modules/$KVER/build"
WORK_DIR=$(mktemp -d)
INSTALL_DIR="/usr/lib/modules/$KVER/updates"

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

if [[ ! -d "$BUILD_DIR" ]]; then
    echo "mac80211-patch: kernel headers not found for $KVER, skipping" >&2
    exit 0
fi

# Get kernel source version from headers
KVER_BASE="${KVER%%-*}"  # e.g. 6.19.8
KVER_BASE="${KVER_BASE%.0}"  # e.g. 6.17.0 -> 6.17
MAJOR="${KVER_BASE%%.*}" # e.g. 6

echo "mac80211-patch: downloading kernel $KVER_BASE source..."
TARBALL="linux-$KVER_BASE.tar.xz"
URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/$TARBALL"

curl -sL "$URL" -o "$WORK_DIR/$TARBALL"
echo "mac80211-patch: extracting mac80211 source..."
tar xf "$WORK_DIR/$TARBALL" -C "$WORK_DIR" "linux-$KVER_BASE/net/mac80211/"

echo "mac80211-patch: applying patch..."
cd "$WORK_DIR/linux-$KVER_BASE"
patch -p1 < "$PATCH_FILE"

echo "mac80211-patch: building module..."
make -C "$BUILD_DIR" M="$WORK_DIR/linux-$KVER_BASE/net/mac80211" modules

echo "mac80211-patch: installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cp "$WORK_DIR/linux-$KVER_BASE/net/mac80211/mac80211.ko" "$INSTALL_DIR/"
depmod "$KVER"

echo "mac80211-patch: done. Patched mac80211 installed for $KVER."
