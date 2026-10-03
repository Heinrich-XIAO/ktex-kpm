#!/bin/sh
# KTEX installer. Runs itself: fetches the payload, unpacks it to
# /mnt/us/ktex, drops a library scriptlet in /mnt/us/documents, and starts it.
#
#   curl -sL <this-url> | sh
#
# Needs: sh, python3 (to run the app), a writable /mnt/us, and curl or wget.

KTEX_ROOT="${KTEX_ROOT:-/mnt/us}"
APP_DIR="$KTEX_ROOT/ktex"
PAYLOAD_URLS="https://heinrich-xiao.github.io/ktex-kpm https://raw.githubusercontent.com/Heinrich-XIAO/ktex-kpm/main"
PAYLOAD_NAME="__PAYLOAD_NAME__"
PAYLOAD_TGZ="$KTEX_ROOT/ktex-payload.tgz"

say() { echo "KTEX: $1"; }
die() { say "$1"; exit 1; }

command -v python3 >/dev/null 2>&1 || die "python3 not found. KTEX needs it to run."

fetch() {
    url="$1"
    out="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsL "$url" -o "$out" && return 0
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -q -O "$out" "$url" && return 0
    fi
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import sys,urllib.request; urllib.request.urlretrieve(sys.argv[1], sys.argv[2])' \
            "$url" "$out" && return 0
    fi
    return 1
}

echo "KTEX: downloading..."
rm -f "$PAYLOAD_TGZ"
for base in $PAYLOAD_URLS; do
    fetch "$base/$PAYLOAD_NAME" "$PAYLOAD_TGZ" 2>/dev/null && [ -s "$PAYLOAD_TGZ" ] && break
    rm -f "$PAYLOAD_TGZ"
done
[ -s "$PAYLOAD_TGZ" ] || die "download failed. Check the Kindle's WiFi connection."
say "downloaded $(wc -c < "$PAYLOAD_TGZ" | tr -d ' ') bytes"

# Replace any previous install, then unpack.
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR" || die "cannot create $APP_DIR"
python3 - "$PAYLOAD_TGZ" "$APP_DIR" <<'PYEOF' || die "could not unpack the payload"
import sys, tarfile
with tarfile.open(sys.argv[1]) as tf:
    for member in tf.getmembers():
        parts = member.name.split("/")
        if member.name.startswith("/") or ".." in parts:
            raise SystemExit("unsafe path in payload: %s" % member.name)
    tf.extractall(sys.argv[2])
PYEOF

chmod +x "$APP_DIR/launch.sh" 2>/dev/null
chmod +x "$APP_DIR/server.py" 2>/dev/null
[ -d "$APP_DIR/app" ] || die "payload is missing the app/ directory"

# Library scriptlet, so KTEX can be started by tapping it in the library.
mkdir -p "$KTEX_ROOT/documents" || die "cannot create $KTEX_ROOT/documents"
cat > "$KTEX_ROOT/documents/KTEX.sh" <<'SCRIPTLET'
#!/bin/sh
# Name: KTEX LaTeX Pad
# Author: ktex
KTEX_ROOT="${KTEX_ROOT:-/mnt/us}"
exec sh "$KTEX_ROOT/ktex/launch.sh"
SCRIPTLET
chmod +x "$KTEX_ROOT/documents/KTEX.sh"
rm -f "$PAYLOAD_TGZ"

say "installed to $APP_DIR"
say "starting..."
sh "$APP_DIR/launch.sh"
