#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

command -v sjasmplus >/dev/null 2>&1 || {
    echo "*** sjasmplus not found in PATH ***" >&2
    exit 1
}

sjasmplus \
    --lst=FULL_SWITCHER_1_1.lst \
    --raw=FULL_SWITCHER_1_1.bin \
    FULL_SWITCHER_1_1.a80

size="$(wc -c < FULL_SWITCHER_1_1.bin)"
[[ "$size" == "2924" ]] || {
    echo "*** WRONG FULL_SWITCHER_1_1.bin SIZE: $size, EXPECTED 2924 BYTES ***" >&2
    exit 1
}

echo "FULL_SWITCHER_1_1.bin OK - 2924 bytes"
