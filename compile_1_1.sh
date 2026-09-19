#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

die() {
    echo "*** $* ***" >&2
    exit 1
}

command -v sjasmplus >/dev/null 2>&1 || die "sjasmplus not found in PATH"
command -v python3 >/dev/null 2>&1 || die "python3 not found in PATH"

sjasmplus \
    --define DUAL_GUI_TEST \
    --define DUAL_GUI_INSTALL_TEST \
    --lst=EasySD_1_1_INSTALL.lst \
    --raw=EasySD_1_1_INSTALL.bin \
    easyhdd.a80 || die "EasySD 1.1 INSTALL BUILD FAILED"

sjasmplus \
    --lst=SWITCH_ALL.lst \
    --raw=SWITCH_ALL.bin \
    switch_device_unified.a80 || die "SWITCHER BUILD FAILED"

sjasmplus \
    --lst=FULL_SWITCHER_1_1/FULL_SWITCHER_1_1.lst \
    --raw=FULL_SWITCHER_1_1/FULL_SWITCHER_1_1.bin \
    FULL_SWITCHER_1_1/FULL_SWITCHER_1_1.a80 || die "FULL SWITCHER 1.1 BUILD FAILED"

python3 make_1_1_tap.py || die "INSTALL TAP BUILD FAILED"
python3 make_switch_menu.py || die "SWITCH MENU BUILD FAILED"

[[ -s EasySD_1_1_INSTALL.tap ]] || die "EasySD_1_1_INSTALL.tap was not created"
[[ -s SWITCH_MENU.tap ]] || die "SWITCH_MENU.tap was not created"
[[ -s FULL_SWITCHER_1_1/FULL_SWITCHER_1_1.bin ]] || die "FULL_SWITCHER_1_1.bin was not created"

echo "BUILD 1.1 OK"
echo "  EasySD_1_1_INSTALL.tap"
echo "  SWITCH_MENU.tap"
echo "  FULL_SWITCHER_1_1/FULL_SWITCHER_1_1.bin"
