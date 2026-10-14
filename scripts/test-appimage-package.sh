#!/usr/bin/env bash
# Exercise the AppImage packaging control flow without downloading or executing
# upstream packaging tools. Real AppImages are still built in architecture CI.
set -Eeuo pipefail

readonly RESET='\033[0m'
readonly GREEN='\033[1;32m'
readonly RED='\033[1;31m'
log() { printf "${GREEN}[appimage-test]${RESET} %s\n" "$*"; }
die() { printf "${RED}[appimage-test] ERROR:${RESET} %s\n" "$*" >&2; exit 1; }

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(dirname -- "$script_dir")"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

case "$(uname -m)" in
    x86_64) arch=x86_64 ;;
    aarch64) arch=aarch64 ;;
    *) die "Test needs a native x86_64 or aarch64 runner; got $(uname -m)." ;;
esac
stage="$tmp_dir/stage"
stubs="$tmp_dir/stubs"
mkdir -p "$stage/bin" "$stage/lib" "$stage/plugins" "$stage/qml" "$stage/resources" "$stubs"
cat > "$stage/bin/cueflow" <<'APP'
#!/usr/bin/env sh
printf 'CueFlow fixture\n'
APP
chmod 0755 "$stage/bin/cueflow"
printf 'fixture\n' > "$stage/bin/qt.conf"

# Fake curl writes tiny, inspectable executables for the pinned upstream
# assets; it never accesses the network.
cat > "$stubs/curl" <<'CURL'
#!/usr/bin/env bash
set -Eeuo pipefail
out=''
url=''
while (( $# )); do
    case "$1" in
        --output) out="$2"; shift 2 ;;
        http://*|https://*) url="$1"; shift ;;
        *) shift ;;
    esac
done
[[ -n "$out" && -n "$url" ]] || { echo 'bad fake curl arguments' >&2; exit 2; }
asset="${url##*/}"
case "$asset" in
    linuxdeploy-plugin-qt-*.AppImage)
        cat > "$out" <<'PLUGIN'
#!/usr/bin/env sh
exit 0
PLUGIN
        ;;
    linuxdeploy-*.AppImage)
        cat > "$out" <<'DEPLOY'
#!/usr/bin/env bash
set -Eeuo pipefail
appdir=''; executable=''; desktop=''; icon=''
while (( $# )); do
    case "$1" in
        --appdir) appdir="$2"; shift 2 ;;
        --executable) executable="$2"; shift 2 ;;
        --desktop-file) desktop="$2"; shift 2 ;;
        --icon-file) icon="$2"; shift 2 ;;
        --plugin) shift 2 ;;
        *) echo "unexpected fake linuxdeploy argument: $1" >&2; exit 2 ;;
    esac
done
test -x "$executable"
test -x "$appdir/AppRun"
test -x "$(dirname -- "$0")/linuxdeploy-plugin-qt-$(uname -m).AppImage"
mkdir -p "$appdir/usr/bin" "$appdir/usr/share/applications" "$appdir/usr/share/icons/hicolor/scalable/apps"
cp "$executable" "$appdir/usr/bin/cueflow"
cp "$desktop" "$appdir/cueflow.desktop"
cp "$desktop" "$appdir/usr/share/applications/cueflow.desktop"
cp "$icon" "$appdir/cueflow.svg"
cp "$icon" "$appdir/usr/share/icons/hicolor/scalable/apps/cueflow.svg"
DEPLOY
        ;;
    runtime-*)
        printf 'mock pinned runtime for packaging test\n' > "$out"
        ;;
    appimagetool-*.AppImage)
        cat > "$out" <<'TOOL'
#!/usr/bin/env bash
set -Eeuo pipefail
appdir="$1"
out="$2"
test -x "$appdir/AppRun"
test -f "$appdir/cueflow.desktop"
test -f "$appdir/cueflow.svg"
test -x "$appdir/usr/bin/cueflow"
test -f "$appdir/usr/BUILD-INFO.txt"
test -x "${APPIMAGETOOL_RUNTIME_FILE:?runtime must be explicitly pinned}"
cp /bin/true "$out"
TOOL
        ;;
    *) echo "unexpected fake tool URL: $url" >&2; exit 2 ;;
esac
chmod 0755 "$out"
CURL
chmod 0755 "$stubs/curl"
# The fixture's runtime isn't the upstream binary, so stub only the checksum
# verification call. The real CI packaging script uses /usr/bin/sha256sum.
cat > "$stubs/sha256sum" <<'SHA'
#!/usr/bin/env bash
if [[ " $* " == *" --check "* ]]; then
    exit 0
fi
exec /usr/bin/sha256sum "$@"
SHA
chmod 0755 "$stubs/sha256sum"

output="$tmp_dir/CueFlow-Linux-${arch}-test.AppImage"
PATH="$stubs:$PATH" "$repo_root/scripts/package-appimage.sh" \
    "$stage" "$output" '0.1.0-test' "$arch" '0000000000000000000000000000000000000000'

test -s "$output" || die 'AppImage package script created no output.'
file_description="$(file -b "$output")"
[[ "$file_description" == *ELF* ]] || die "Test output isn't ELF-shaped: $file_description"
[[ -x "$output" ]] || die 'Output is not executable.'
log "Mocked AppImage packaging path passed for $arch."
