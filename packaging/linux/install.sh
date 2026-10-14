#!/usr/bin/env sh
# Install CueFlow into the current user's home directory; no sudo is needed.
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PREFIX="${CUEFLOW_INSTALL_DIR:-$HOME/.local/opt/CueFlow}"
APP_ID="org.mmbesar.CueFlow"

say() { printf '\033[1;36mCueFlow:\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mCueFlow error:\033[0m %s\n' "$*" >&2; exit 1; }

[ -x "$SCRIPT_DIR/AppRun" ] || die "AppRun is missing. Extract the complete Linux bundle before running install.sh."
[ -x "$SCRIPT_DIR/bin/cueflow" ] || die "The bundled bin/cueflow executable is missing."
[ -f "$SCRIPT_DIR/cueflow.svg" ] || die "The CueFlow icon is missing from this bundle."
[ -n "$HOME" ] || die 'HOME is not set.'
[ "$PREFIX" != / ] && [ "$PREFIX" != "$HOME" ] || die "Refusing unsafe installation path: $PREFIX"
[ "$SCRIPT_DIR" != "$PREFIX" ] || die 'Run install.sh from the extracted release bundle, not from the installed copy.'

PARENT="$(dirname -- "$PREFIX")"
TEMP="${PREFIX}.new.$$"
BACKUP="${PREFIX}.old.$$"
mkdir -p "$PARENT"
rm -rf "$TEMP" "$BACKUP"
mkdir -p "$TEMP"
if ! cp -a "$SCRIPT_DIR/." "$TEMP/"; then
    rm -rf "$TEMP"
    die 'Could not copy CueFlow into the temporary install directory.'
fi
chmod 755 "$TEMP/AppRun" "$TEMP/install.sh" "$TEMP/uninstall.sh"

# Replace an existing install only after the new tree has been copied fully.
if [ -e "$PREFIX" ]; then
    mv "$PREFIX" "$BACKUP" || { rm -rf "$TEMP"; die 'Could not move the previous install aside.'; }
fi
if mv "$TEMP" "$PREFIX"; then
    rm -rf "$BACKUP"
else
    [ ! -e "$BACKUP" ] || mv "$BACKUP" "$PREFIX"
    rm -rf "$TEMP"
    die 'Could not activate the new install; attempted to restore the previous version.'
fi

ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$ICON_DIR" "$DESKTOP_DIR"
install -m 644 "$PREFIX/cueflow.svg" "$ICON_DIR/cueflow.svg"

# Desktop Entry quoting uses backslash escapes inside a double-quoted Exec path.
EXEC_PATH=$(printf '%s' "$PREFIX/AppRun" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
cat > "$DESKTOP_DIR/cueflow.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=CueFlow
Comment=Native Markdown teleprompter with local remote control
Exec="$EXEC_PATH"
Icon=cueflow
Terminal=false
Categories=Utility;Office;
Keywords=teleprompter;presenter;markdown;script;
StartupNotify=true
DESKTOP
chmod 644 "$DESKTOP_DIR/cueflow.desktop"
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true

say "Installed to $PREFIX"
say 'A CueFlow launcher was added to your desktop application menu.'
say 'Run it now with: ~/.local/opt/CueFlow/AppRun'
say 'To remove it, run the installed uninstall.sh script.'
