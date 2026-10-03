#!/bin/sh
# Installs a standalone CPython on a jailbroken Kindle, into /mnt/us/py.
# Nothing is installed into the read-only rootfs, so no mntroot rw is needed.
#
#   curl -sL <this-url> | sh
#
# Needs: sh, curl or wget, tar, and ~120 MB free on /mnt/us.

DEST=/mnt/us/py
BUILD=20261003
PYVER=3.12.15
BASE="https://github.com/astral-sh/python-build-standalone/releases/download/$BUILD"

say() { echo "python: $1"; }
die() { say "$1"; exit 1; }

ARCH="$(uname -m 2>/dev/null)"
case "$ARCH" in
    aarch64*) TARGET="aarch64-unknown-linux-gnu" ;;
    armv7*|armv8l*) TARGET="armv7-unknown-linux-gnueabihf" ;;
    arm*) TARGET="armv7-unknown-linux-gnueabihf" ;;
    *) die "unsupported architecture '$ARCH' - this is for ARM Kindles only." ;;
esac

URL="$BASE/cpython-${PYVER}%2B${BUILD}-${TARGET}-install_only_stripped.tar.gz"
say "device architecture: $ARCH"
say "downloading CPython $PYVER for $TARGET (~28 MB)"

TGZ="$DEST.tgz"
rm -f "$TGZ"
if command -v curl >/dev/null 2>&1; then
    curl -fsL "$URL" -o "$TGZ" || die "download failed"
elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$TGZ" "$URL" || die "download failed"
else
    die "need curl or wget"
fi
[ -s "$TGZ" ] || die "download produced an empty file"

say "unpacking to $DEST"
rm -rf "$DEST"
mkdir -p "$DEST" || die "cannot create $DEST"
tar xzf "$TGZ" -C "$DEST" || die "unpack failed"
rm -f "$TGZ"

PY="$DEST/python/bin/python3"
[ -x "$PY" ] || PY="$DEST/python/bin/python"
[ -x "$PY" ] || die "python binary not found after unpacking"

if ! "$PY" -V 2>/dev/null; then
    die "found $PY but it will not run on this device (glibc/ABI mismatch?).
    This build needs glibc; Kindle firmware ships an older one, so try the
    KOReader 'Tools' or ask for a hard-float/soft-float variant."
fi

say "installed: $("$PY" -V 2>&1)"

# Make it usable without editing PATH: drop a wrapper into a directory that is
# already on PATH on most jailbreaks, and always tell the user the PATH line.
if mkdir -p /usr/local/bin 2>/dev/null && [ -w /usr/local/bin ]; then
    ln -sf "$PY" /usr/local/bin/python3 2>/dev/null && \
        say "linked /usr/local/bin/python3"
fi

cat <<EOF

Add this to your shell (or just use the full path):

    export PATH="/mnt/us/py/python/bin:\$PATH"

Then check it:

    python3 -V

EOF
exit 0