#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BIN_ONLY=0
if [[ "${1:-}" == "--bin-only" ]]; then
    BIN_ONLY=1
elif [[ $# -ne 0 ]]; then
    echo "Usage: $0 [--bin-only]" >&2
    exit 2
fi

die() {
    echo
    echo "*** $* ***" >&2
    exit 1
}

command -v sjasmplus >/dev/null 2>&1 || die "sjasmplus not found in PATH"
[[ -f easyhdd.a80 ]] || die "easyhdd.a80 not found in $SCRIPT_DIR"

echo
echo "========================================"
echo "  Building EasySD for MB03+"
echo "========================================"

rm -f EasySD_MB.bin EasySD_MB.lst
sjasmplus --lst=EasySD_MB.lst --raw=EasySD_MB.bin easyhdd.a80 || die "MB03+ BUILD FAILED"
[[ -s EasySD_MB.bin ]] || die "MB03+ build did not create EasySD_MB.bin"

echo
echo "========================================"
echo "  Building EasySD for eLeMeNt"
echo "========================================"

rm -f EasySD_EL.bin EasySD_EL.lst
sjasmplus --lst=EasySD_EL.lst --define ELEMENT --raw=EasySD_EL.bin easyhdd.a80 || die "eLeMeNt BUILD FAILED"
[[ -s EasySD_EL.bin ]] || die "eLeMeNt build did not create EasySD_EL.bin"

echo
echo "========================================"
echo "  Building EasySD for MB03+ Slim"
echo "========================================"

rm -f EasySD_SLIM.bin EasySD_SLIM.lst
sjasmplus --lst=EasySD_SLIM.lst --define SLIM --raw=EasySD_SLIM.bin easyhdd.a80 || die "MB03+ SLIM BUILD FAILED"
[[ -s EasySD_SLIM.bin ]] || die "MB03+ Slim build did not create EasySD_SLIM.bin"


if (( BIN_ONLY == 0 )); then
    echo
    echo "========================================"
    echo "  Building TAP files"
    echo "========================================"

    command -v python3 >/dev/null 2>&1 || die "python3 not found in PATH"

    if [[ -f make_bin_taps.py && -f make_el_tap.py && -f make_slim_tap.py ]]; then
        python3 make_bin_taps.py || die "SIMPLE BIN TAP BUILD FAILED"
        python3 make_el_tap.py || die "FULL eLeMeNt TAP BUILD FAILED"
        python3 make_slim_tap.py || die "FULL MB03+ SLIM TAP BUILD FAILED"
    elif command -v pwsh >/dev/null 2>&1 && [[ -f make_taps.ps1 ]]; then
        echo "Python TAP helpers not found; using make_taps.ps1 via pwsh."
        pwsh -NoProfile -File ./make_taps.ps1 || die "TAP BUILD FAILED"
    else
        die "TAP helpers not found. Expected make_bin_taps.py + make_el_tap.py + make_slim_tap.py, or pwsh + make_taps.ps1. BIN files were built successfully."
    fi

    [[ -s EasySD_MB_BIN.tap ]] || die "EasySD_MB_BIN.tap was not created"
    [[ -s EasySD_EL.tap ]] || die "EasySD_EL.tap was not created"
    [[ -s EasySD_SLIM.tap ]] || die "EasySD_SLIM.tap was not created"
fi

echo
echo "========================================"
echo "  BUILD OK"
echo "========================================"
echo "  EasySD_MB.bin      - MB03+"
echo "  EasySD_EL.bin      - eLeMeNt"
echo "  EasySD_SLIM.bin    - MB03+ Slim"
echo "  EasySD_MB.lst"
echo "  EasySD_EL.lst"
echo "  EasySD_SLIM.lst"

if (( BIN_ONLY == 0 )); then
    echo "  EasySD_MB_BIN.tap  - simple MB03+ TAP"
    echo "  EasySD_EL.tap      - full eLeMeNt startup TAP"
    echo "  EasySD_SLIM.tap    - full MB03+ Slim startup TAP"
fi

echo "========================================"
