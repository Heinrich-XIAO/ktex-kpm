#!/bin/sh
# KTEX installer. One command, nothing to upload to the Kindle:
#
#   curl -sL <this-url> | sh
#
# This script is permanent and never changes; it looks up the current version
# in latest.json (cache-busted, so CDN caches cannot serve a stale app), then
# downloads and installs it.

KTEX_ROOT="${KTEX_ROOT:-/mnt/us}"
APP_DIR="$KTEX_ROOT/ktex"
SCRIPTLET="$KTEX_ROOT/documents/KTEX.sh"
WORK="$KTEX_ROOT/ktex-install-tmp"
REPO_URLS="https://heinrich-xiao.github.io/ktex-kpm https://raw.githubusercontent.com/Heinrich-XIAO/ktex-kpm/main"

say() { echo "KTEX: $1"; }
die() { say "$1"; exit 1; }

get() {
    # get <url> <destination>
    if command -v curl >/dev/null 2>&1; then
        curl -fsL "$1" -o "$2" && return 0
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -q -O "$2" "$1" && return 0
    fi
    return 1
}

rm -rf "$WORK"
mkdir -p "$WORK" || die "cannot write to $KTEX_ROOT"

# ---- resolve the current version -------------------------------------------------
STAMP="$(date +%s 2>/dev/null || echo 0)"
LATEST=""
for base in $REPO_URLS; do
    if get "$base/latest.json?cb=$STAMP" "$WORK/latest.json"; then
        LATEST="$base"
        break
    fi
done
[ -n "$LATEST" ] || die "could not reach the download server (check WiFi)"

VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\\([^"]*\\)".*/\\1/p' "$WORK/latest.json" | head -1)"
PAYLOAD="$(sed -n 's/.*"payload"[[:space:]]*:[[:space:]]*"\\([^"]*\\)".*/\\1/p' "$WORK/latest.json" | head -1)"
[ -n "$VERSION" ] && [ -n "$PAYLOAD" ] || die "latest.json did not list a version/payload"
say "installing version $VERSION"

# ---- download -------------------------------------------------------------------
TGZ="$WORK/payload.tgz"
get "$LATEST/$PAYLOAD" "$TGZ" || die "download of $PAYLOAD failed"
[ -s "$TGZ" ] || die "downloaded file was empty"
say "downloaded $(wc -c < "$TGZ" | tr -d ' ') bytes"

# ---- unpack ---------------------------------------------------------------------
# /mnt/us is vfat: no symlinks, and some tars abort on them. Extract
# best-effort, then extract any missing files individually.
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR" || die "cannot create $APP_DIR"
( cd "$APP_DIR" && tar xzf "$TGZ" 2>/dev/null )

missing=""
for want in app/index.html app/ktex.js app/style.css server.py launch.sh; do
    [ -f "$APP_DIR/$want" ] || missing="$missing $want"
done
if [ -n "$missing" ]; then
    say "some files were missing ($missing ), extracting them individually"
    for want in $missing; do
        ( cd "$APP_DIR" && tar xzf "$TGZ" "$want" 2>/dev/null )
    done
fi

for want in app/index.html server.py launch.sh; do
    [ -f "$APP_DIR/$want" ] || die "payload is missing $want"
done
chmod +x "$APP_DIR/launch.sh" 2>/dev/null
chmod +x "$APP_DIR/server.py" 2>/dev/null

# ---- library scriptlet ----------------------------------------------------------
mkdir -p "$KTEX_ROOT/documents" || die "cannot create $KTEX_ROOT/documents"
cat > "$SCRIPTLET" <<'SCRIPTLET'
#!/bin/sh
# Name: KTEX LaTeX Pad
# Author: ktex
KTEX_ROOT="${KTEX_ROOT:-/mnt/us}"
exec sh "$KTEX_ROOT/ktex/launch.sh"
SCRIPTLET
chmod +x "$SCRIPTLET"

rm -rf "$WORK"
say "installed to $APP_DIR"
say "starting..."
sh "$APP_DIR/launch.sh"
