#!/usr/bin/env bash
# Regression test for Linux archive validation with large file listings.
set -Eeuo pipefail

readonly RESET='\033[0m'
readonly GREEN='\033[1;32m'
readonly RED='\033[1;31m'
log() { printf "${GREEN}[package-test]${RESET} %s\n" "$*"; }
die() { printf "${RED}[package-test] ERROR:${RESET} %s\n" "$*" >&2; exit 1; }

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(dirname -- "$script_dir")"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

stage="$tmp_dir/stage"
mkdir -p "$stage/bin"
cat > "$stage/bin/cueflow" <<'APP'
#!/usr/bin/env sh
printf 'CueFlow packaging fixture\n'
APP
chmod 0755 "$stage/bin/cueflow"

# Ensure the archive listing is large enough that an early `grep -q` can close
# its pipe before tar finishes writing, reproducing the original pipefail bug.
mkdir -p "$stage/resources"
for i in $(seq -w 1 7000); do
    printf 'fixture %s\n' "$i" > "$stage/resources/resource-$i.txt"
done

output="$tmp_dir/cueflow-test.tar.gz"
commit='0000000000000000000000000000000000000000'
"$repo_root/scripts/package-linux-bundle.sh" \
    "$stage" "$output" '0.1.0-test' 'x86_64' "$commit"

listing="$tmp_dir/archive-list.txt"
tar -tzf "$output" > "$listing" || die 'Cannot inspect test archive.'
grep -Eq '^(\./)?bin/cueflow$' "$listing" || die 'App binary missing from archive.'
grep -Eq '^(\./)?install\.sh$' "$listing" || die 'Installer missing from archive.'
log 'Large archive validated successfully.'
