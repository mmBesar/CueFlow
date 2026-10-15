#!/usr/bin/env bash
# Turn a Qt-deployed CMake install tree into a per-user installable Linux archive.
set -Eeuo pipefail

readonly RESET='\033[0m'
readonly GREEN='\033[1;32m'
readonly RED='\033[1;31m'
log() { printf "${GREEN}[package]${RESET} %s\n" "$*"; }
die() { printf "${RED}[package] ERROR:${RESET} %s\n" "$*" >&2; exit 1; }

if (( $# != 5 )); then
    die "Usage: $0 STAGE_DIR OUTPUT.tar.gz VERSION ARCH COMMIT"
fi
stage_dir="$(realpath "$1")"
output_file="$(realpath -m "$2")"
version="$3"
architecture="$4"
commit="$5"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(dirname -- "$script_dir")"

[[ -x "$stage_dir/bin/cueflow" ]] || die "Missing installed app: $stage_dir/bin/cueflow"
[[ -n "$version" && -n "$architecture" && -n "$commit" ]] || die 'Version, architecture, and commit are required.'

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
package_root="$work_dir/package"
mkdir -p "$package_root"
cp -a "$stage_dir/." "$package_root/"
install -m 0755 "$repo_root/packaging/linux/AppRun" "$package_root/AppRun"
install -m 0755 "$repo_root/packaging/linux/install.sh" "$package_root/install.sh"
install -m 0755 "$repo_root/packaging/linux/uninstall.sh" "$package_root/uninstall.sh"
install -m 0644 "$repo_root/icon/CueFlow-icon.svg" "$package_root/cueflow.svg"
install -m 0644 "$repo_root/LICENSE" "$package_root/LICENSE"
cat > "$package_root/INSTALL.txt" <<INSTALL
CueFlow $version — Linux $architecture

Install for the current user (no sudo required):
  1. Extract this archive into a directory.
  2. Run: ./install.sh
  3. Launch CueFlow from the application menu, or ~/.local/opt/CueFlow/AppRun

To uninstall, launch ~/.local/opt/CueFlow/uninstall.sh and confirm the prompt.
Your local CueFlow settings/scripts are stored separately and are not removed by the uninstaller.

This is a native Linux bundle for $architecture. It includes the Qt/QML runtime deployed by Qt,
but still uses host graphics/display drivers and some host system libraries. See README.md for
requirements and the dedicated NixOS artifact if you use NixOS.
INSTALL
cat > "$package_root/BUILD-INFO.txt" <<INFO
application=CueFlow
version=$version
architecture=$architecture
source_commit=$commit
INFO

mkdir -p "$(dirname -- "$output_file")"
log "Creating $output_file"
tar -czf "$output_file" -C "$package_root" .
[[ -s "$output_file" ]] || die 'Output archive is empty.'

# Do not pipe tar directly into grep -q here. With `set -o pipefail`, grep can
# exit immediately after finding a match, closing the pipe while tar is still
# writing its listing. Tar then gets SIGPIPE / a broken pipe and the successful
# match is incorrectly reported as a failed validation (especially on bundles
# containing many Qt files). Materialize the small listing first, then inspect it.
archive_listing="$work_dir/archive-list.txt"
if ! tar -tzf "$output_file" > "$archive_listing"; then
    die 'Archive validation failed: cannot read the generated archive.'
fi
grep -Eq '^(\./)?bin/cueflow$' "$archive_listing" || die 'Archive validation failed: bin/cueflow is not present.'
grep -Eq '^(\./)?install\.sh$' "$archive_listing" || die 'Archive validation failed: installer is not present.'
log "Created $(du -h "$output_file" | cut -f1) archive for $architecture ($version, ${commit:0:12})."
