#!/usr/bin/env bash
# Package the Qt-deployed install tree as an AppImage for the native build host.
# Tool versions are pinned to upstream releases to avoid silently changing CI tools.
set -Eeuo pipefail

readonly RESET='\033[0m'
readonly GREEN='\033[1;32m'
readonly RED='\033[1;31m'
log() { printf "${GREEN}[appimage]${RESET} %s\n" "$*"; }
die() { printf "${RED}[appimage] ERROR:${RESET} %s\n" "$*" >&2; exit 1; }

if (( $# != 5 )); then
    die "Usage: $0 STAGE_DIR OUTPUT.AppImage VERSION ARCH COMMIT"
fi
stage_dir="$(realpath "$1")"
output_file="$(realpath -m "$2")"
version="$3"
architecture="$4"
commit="$5"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(dirname -- "$script_dir")"

[[ -x "$stage_dir/bin/cueflow" ]] || die "Missing staged app: $stage_dir/bin/cueflow"
[[ -n "$version" && -n "$architecture" && -n "$commit" ]] || die 'Version, architecture, and commit are required.'

host_arch="$(uname -m)"
case "$host_arch:$architecture" in
    x86_64:x86_64|aarch64:aarch64) ;;
    *) die "Native AppImage builds only: host $host_arch does not match requested architecture $architecture." ;;
esac

# These are the current upstream tagged tool releases. AppImage generation and
# Qt/QML collection follow the official linuxdeploy + Qt plugin workflow.
readonly LINUXDEPLOY_VERSION='1-alpha-20251107-1'
readonly LINUXDEPLOY_QT_VERSION='1-alpha-20250213-1'
readonly APPIMAGETOOL_VERSION='1.9.1'
readonly APPIMAGE_RUNTIME_RELEASE='20251108'

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
appdir="$work_dir/CueFlow.AppDir"
tools_dir="$work_dir/tools"
mkdir -p "$appdir/usr" "$tools_dir"
cp -a "$stage_dir/." "$appdir/usr/"
mkdir -p "$appdir/usr/share/applications" "$appdir/usr/share/icons/hicolor/scalable/apps"
install -m 0644 "$repo_root/packaging/linux/cueflow.desktop" "$appdir/usr/share/applications/cueflow.desktop"
install -m 0644 "$repo_root/packaging/linux/cueflow.svg" "$appdir/usr/share/icons/hicolor/scalable/apps/cueflow.svg"
install -m 0644 "$repo_root/LICENSE" "$appdir/usr/LICENSE"
cat > "$appdir/usr/BUILD-INFO.txt" <<INFO
application=CueFlow
version=$version
architecture=$architecture
source_commit=$commit
package=AppImage
INFO

# AppRun is explicit instead of relying on generated shell defaults. Keep the
# app's private Qt deployment configuration but clear unrelated host Qt paths.
cat > "$appdir/AppRun" <<'APPRUN'
#!/usr/bin/env sh
set -eu
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
unset QT_PLUGIN_PATH QT_QPA_PLATFORM_PLUGIN_PATH QML2_IMPORT_PATH QT_QML_IMPORT_PATH
export APPDIR="$HERE"
exec "$HERE/usr/bin/cueflow" "$@"
APPRUN
chmod 0755 "$appdir/AppRun"

case "$architecture" in
    x86_64) asset_arch='x86_64' ;;
    aarch64) asset_arch='aarch64' ;;
    *) die "Unsupported architecture: $architecture" ;;
esac

fetch() {
    local url="$1" destination="$2"
    log "Downloading $(basename -- "$destination")"
    curl --fail --location --retry 3 --retry-delay 2 --silent --show-error \
        "$url" --output "$destination"
    [[ -s "$destination" ]] || die "Download was empty: $url"
    chmod 0755 "$destination"
}

linuxdeploy="$tools_dir/linuxdeploy-${asset_arch}.AppImage"
qt_plugin="$tools_dir/linuxdeploy-plugin-qt-${asset_arch}.AppImage"
appimagetool="$tools_dir/appimagetool-${asset_arch}.AppImage"
runtime_file="$tools_dir/runtime-${asset_arch}"
fetch "https://github.com/linuxdeploy/linuxdeploy/releases/download/${LINUXDEPLOY_VERSION}/linuxdeploy-${asset_arch}.AppImage" "$linuxdeploy"
fetch "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/${LINUXDEPLOY_QT_VERSION}/linuxdeploy-plugin-qt-${asset_arch}.AppImage" "$qt_plugin"
fetch "https://github.com/AppImage/appimagetool/releases/download/${APPIMAGETOOL_VERSION}/appimagetool-${asset_arch}.AppImage" "$appimagetool"
fetch "https://github.com/AppImage/type2-runtime/releases/download/${APPIMAGE_RUNTIME_RELEASE}/runtime-${asset_arch}" "$runtime_file"

# appimagetool 1.9.1 retrieves a Type 2 runtime unless one is provided. Pin the
# expected asset hash so the runtime cannot silently change beneath a fixed tool
# version. Update these hashes deliberately when the official runtime is refreshed.
case "$asset_arch" in
    x86_64) runtime_sha256='2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d' ;;
    aarch64) runtime_sha256='00cbdfcf917cc6c0ff6d3347d59e0ca1f7f45a6df1a428a0d6d8a78664d87444' ;;
esac
printf '%s  %s\n' "$runtime_sha256" "$runtime_file" | sha256sum --check --status \
    || die "AppImage runtime checksum mismatch for $asset_arch; review the pinned runtime hash before updating it."

# GitHub-hosted runners may not expose FUSE. AppImage's documented extract-and-run
# mode lets the official AppImage tools run without mounting via FUSE.
export APPIMAGE_EXTRACT_AND_RUN=1
export APPIMAGETOOL_RUNTIME_FILE="$runtime_file"
# linuxdeploy discovers plugins by their executable name through PATH.
export PATH="$tools_dir:$PATH"
export QML_SOURCES_PATHS="$repo_root/qml"
if [[ -n "${QT_ROOT_DIR:-}" ]]; then
    if [[ -x "$QT_ROOT_DIR/bin/qmake" ]]; then
        export QMAKE="$QT_ROOT_DIR/bin/qmake"
    elif [[ -x "$QT_ROOT_DIR/bin/qmake6" ]]; then
        export QMAKE="$QT_ROOT_DIR/bin/qmake6"
    fi
fi

# The install tree already contains Qt's CMake-generated deployment of Qt/QML.
# The pinned linuxdeploy-qt plugin runs its own ELF dependency scan; exclusions
# passed to linuxdeploy are not reliably propagated into that plugin (upstream
# issue: linuxdeploy/linuxdeploy-plugin-qt#205). Install the host runtime libraries
# in the AppImage job so the scan can resolve them, then explicitly remove these
# driver/window-system libraries from AppDir below. Keep this cleanup even with the
# main linuxdeploy exclusions: it is a postcondition, not an option-dependent hope.
log "Deploying Qt/QML and ELF dependencies for $architecture"
# Pass the original staged executable so linuxdeploy can enumerate its ELF
# dependencies. Remove the copied target first to avoid a same-file copy.
rm -f "$appdir/usr/bin/cueflow"
"$linuxdeploy" --appdir "$appdir" \
    --executable "$stage_dir/bin/cueflow" \
    --desktop-file "$repo_root/packaging/linux/cueflow.desktop" \
    --icon-file "$repo_root/packaging/linux/cueflow.svg" \
    --exclude-library 'libEGL*.so*' \
    --exclude-library 'libGL.so*' \
    --exclude-library 'libGLX*.so*' \
    --exclude-library 'libGLdispatch.so*' \
    --exclude-library 'libOpenGL.so*' \
    --exclude-library 'libgbm.so*' \
    --exclude-library 'libdrm.so*' \
    --exclude-library 'libwayland-*.so*' \
    --exclude-library 'libxcb-glx.so*' \
    --exclude-library 'libglapi.so*' \
    --exclude-library 'libgallium-*.so*' \
    --plugin qt

# The Qt plugin can copy driver-sensitive host libraries despite the exclusions
# above. They must be resolved on the target system so the EGL/GL loader matches
# the active Mesa/proprietary driver and window-system stack. Remove files and
# symlinks anywhere in the AppDir, then assert that none remain.
log "Removing host graphics/window-system libraries from AppDir"
removed_graphics_libs=0
while IFS= read -r -d '' library_path; do
    library_name="${library_path##*/}"
    case "$library_name" in
        libEGL*.so*|libGL.so*|libGLX*.so*|libGLdispatch.so*|libOpenGL.so*|\
        libgbm.so*|libdrm.so*|libwayland-*.so*|libxcb-glx.so*|libglapi.so*|libgallium-*.so*)
            rm -f -- "$library_path"
            removed_graphics_libs=$((removed_graphics_libs + 1))
            log "Left to host: $library_name"
            ;;
    esac
done < <(find "$appdir/usr" \( -type f -o -type l \) -print0)

while IFS= read -r -d '' library_path; do
    library_name="${library_path##*/}"
    case "$library_name" in
        libEGL*.so*|libGL.so*|libGLX*.so*|libGLdispatch.so*|libOpenGL.so*|\
        libgbm.so*|libdrm.so*|libwayland-*.so*|libxcb-glx.so*|libglapi.so*|libgallium-*.so*)
            die "Host graphics library leaked into AppDir: $library_path" ;;
    esac
done < <(find "$appdir/usr" \( -type f -o -type l \) -print0)
log "Removed $removed_graphics_libs host graphics/window-system library files"

# linuxdeploy may create its own AppRun wrapper. Reassert our known entry point
# after deployment so the final image always launches the bundled executable.
cat > "$appdir/AppRun" <<'APPRUN'
#!/usr/bin/env sh
set -eu
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
unset QT_PLUGIN_PATH QT_QPA_PLATFORM_PLUGIN_PATH QML2_IMPORT_PATH QT_QML_IMPORT_PATH
export APPDIR="$HERE"
exec "$HERE/usr/bin/cueflow" "$@"
APPRUN
chmod 0755 "$appdir/AppRun"

mkdir -p "$(dirname -- "$output_file")"
log "Generating $output_file"
ARCH="$architecture" APPIMAGETOOL_APP_NAME='CueFlow' VERSION="$version" \
    "$appimagetool" "$appdir" "$output_file"

[[ -s "$output_file" ]] || die 'AppImage output is empty.'
file_description="$(file -b "$output_file")"
[[ "$file_description" == *ELF* ]] || die "Output is not an ELF AppImage: $file_description"
chmod 0755 "$output_file"
log "Created $(du -h "$output_file" | cut -f1) AppImage for $architecture ($version, ${commit:0:12})."
