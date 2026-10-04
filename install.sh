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
REPO_URLS="https://heinrich-xiao.github.io/ktex-kpm https://cdn.jsdelivr.net/gh/Heinrich-XIAO/ktex-kpm@main https://raw.githubusercontent.com/Heinrich-XIAO/ktex-kpm/main"

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

# Parse without sed regex escaping headaches: split on commas, then fields.
json_field() {
    tr ',' '\n' < "$1" | grep "\"$2\"" | head -1 | cut -d '"' -f4
}
VERSION="$(json_field "$WORK/latest.json" version)"
PAYLOAD="$(json_field "$WORK/latest.json" payload)"

# Fall back to these if the index is unreadable or names something unavailable.
# Payload names contain a version, so each URL is immutable and never stale.
CANDIDATES="$PAYLOAD payload-0.1.8.tgz payload-0.1.7.tgz payload-0.1.6.tgz payload-0.1.5.tgz payload-0.1.4.tgz"

TGZ="$WORK/payload.tgz"
rm -f "$TGZ"
CHOSEN=""
for p in $CANDIDATES; do
    [ -n "$p" ] || continue
    if get "$LATEST/$p" "$TGZ" && [ -s "$TGZ" ]; then
        CHOSEN="$p"
        break
    fi
    rm -f "$TGZ"
done
[ -n "$CHOSEN" ] || die "could not download any payload (check WiFi)"
VERSION="$(echo "$CHOSEN" | sed "s/[^0-9.]//g; s/\\.$//")"
say "installing $CHOSEN (version ${VERSION:-unknown})"
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
