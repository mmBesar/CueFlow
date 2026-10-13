#!/usr/bin/env bash
# Build and run the dependency-free playback tests; Qt is not required.
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/cueflow-scroll-model-test"

CXX="${CXX:-c++}"
if ! command -v "$CXX" >/dev/null 2>&1; then
    printf '%bC++ compiler not found: %s%b\n' "$RED" "$CXX" "$RESET" >&2
    printf 'Install a C++20 compiler or set CXX to its command name.\n' >&2
    exit 127
fi

printf '\n%b==> Compiling scroll model tests with %s%b\n' "$GREEN" "$CXX" "$RESET"
if ! "$CXX" -std=c++20 -Wall -Wextra -Wpedantic -Werror \
    "$ROOT/tests/scroll_model_test.cpp" -o "$OUT"; then
    printf '%bCompilation failed%b\n' "$RED" "$RESET" >&2
    exit 1
fi

printf '\n%b==> Running scroll model tests%b\n' "$GREEN" "$RESET"
"$OUT"
printf '%bAll checks passed.%b\n' "$GREEN" "$RESET"
