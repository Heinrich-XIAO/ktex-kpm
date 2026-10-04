#!/bin/sh
# Installs a standalone CPython on a jailbroken Kindle, into /mnt/us/py.
# Nothing is installed into the read-only rootfs, so no mntroot rw is needed.
#
#   curl -sL <this-url> | sh
#
# Needs: sh, curl or wget, tar, and ~120 MB free on /mnt/us.

DEST="${KTEX_PY_DEST:-/mnt/us/py}"
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

# /mnt/us is vfat and cannot store symlinks. The archive ships python3 and
# python as symlinks to python3.X, so a plain extract can fail outright and
# leave nothing usable. Extract best-effort, then extract the real interpreter
# explicitly by name if it is missing.
tar xzf "$TGZ" -C "$DEST" 2>/dev/null || true
rm -f "$TGZ"

BINDIR="$DEST/python/bin"
if [ ! -f "$BINDIR/python3.12" ]; then
    REAL="$(tar tzf "$TGZ" 2>/dev/null | grep -E 'python/bin/python3\.[0-9]+$' | head -1)"
    [ -n "$REAL" ] || die "archive contains no python interpreter"
    say "extracting $REAL explicitly"
    tar xzf "$TGZ" -C "$DEST" "$REAL" 2>/dev/null || tar xzf "$TGZ" -C "$DEST" --strip-components=0 "$REAL"
fi

# Find the real interpreter, whatever minor version it is.
PY=""
for c in "$BINDIR"/python3.[0-9]* "$BINDIR"/python3 "$BINDIR"/python; do
    if [ -f "$c" ] && [ ! -L "$c" ]; then
        PY="$c"
        break
    fi
done
[ -n "$PY" ] || die "python interpreter not found after unpacking"

# Recreate python3/python as tiny wrapper scripts, which vfat can store.
# Remove any existing symlink FIRST: writing through a symlink that points at
# the interpreter would overwrite the interpreter itself.
for name in python3 python; do
    rm -f "$BINDIR/$name"
    printf '#!/bin/sh\nexec "%s" "$@"\n' "$PY" > "$BINDIR/$name"
    chmod +x "$BINDIR/$name" 2>/dev/null
done
say "interpreter: $PY"
say "wrappers created: python3, python"

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