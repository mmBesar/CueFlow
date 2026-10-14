#!/usr/bin/env sh
# Remove only CueFlow's per-user program files, desktop entry, and icon.
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
if [ -x "$SCRIPT_DIR/bin/cueflow" ] && [ -x "$SCRIPT_DIR/AppRun" ]; then
    PREFIX="$SCRIPT_DIR"
else
    PREFIX="${CUEFLOW_INSTALL_DIR:-$HOME/.local/opt/CueFlow}"
fi
[ -n "$HOME" ] || { echo 'HOME is not set.' >&2; exit 1; }
[ "$PREFIX" != / ] && [ "$PREFIX" != "$HOME" ] || { echo "Refusing unsafe path: $PREFIX" >&2; exit 1; }

printf 'Remove CueFlow from %s? [y/N] ' "$PREFIX"
IFS= read -r answer || answer=
case "$answer" in
    y|Y|yes|YES)
        rm -rf "$PREFIX"
        rm -f "$HOME/.local/share/applications/cueflow.desktop"
        rm -f "$HOME/.local/share/icons/hicolor/scalable/apps/cueflow.svg"
        command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
        printf 'CueFlow removed. Your CueFlow settings and scripts were not intentionally touched.\n'
        ;;
    *) printf 'Cancelled.\n' ;;
esac
