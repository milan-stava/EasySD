#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

die() {
    echo
    echo "*** $* ***" >&2
    exit 1
}

if [[ -x ./sjasmplus ]]; then
    SJASM=./sjasmplus
elif command -v sjasmplus >/dev/null 2>&1; then
    SJASM=sjasmplus
else
    die "sjasmplus not found"
fi

SOURCE="easyhdd_1_1_release_SD12.a80"

[[ -f "$SOURCE" ]] || die "$SOURCE not found"
[[ -x ./make_taps_1_1.sh ]] || die "make_taps_1_1.sh not found or not executable"

echo
echo "========================================"
echo "  EasySD 1.1 - clean release build"
echo "========================================"

# Remove current and obsolete build artefacts so old binaries
# cannot be mistaken for fresh output.
rm -f EasySD_1_1_INSTALL.{bin,lst,tap}
rm -f EasySD_1_1_EL.{bin,lst,tap}
rm -f EasySD_1_1_SLIM.{bin,lst,tap}
rm -f EasySD_MB.bin EasySD_MB.lst EasySD_MB_BIN.tap
rm -f EasySD_EL.bin EasySD_EL.lst EasySD_EL.tap
rm -f EasySD_SLIM.bin EasySD_SLIM.lst EasySD_SLIM.tap

# ------------------------------------------------------------
# MB03+
# ------------------------------------------------------------
echo
echo "[1/4] Building MB03+ installer..."

"$SJASM" \
    --define DUAL_GUI_TEST \
    --define DUAL_GUI_INSTALL_TEST \
    --lst=EasySD_1_1_INSTALL.lst \
    --raw=EasySD_1_1_INSTALL.bin \
    "$SOURCE" \
    || die "MB03+ BUILD FAILED"

[[ -s EasySD_1_1_INSTALL.bin ]] \
    || die "EasySD_1_1_INSTALL.bin WAS NOT CREATED"

[[ $(wc -c < EasySD_1_1_INSTALL.bin) -eq 13312 ]] \
    || die "WRONG MB03+ SIZE - EXPECTED 13312 BYTES"

# ------------------------------------------------------------
# eLeMeNt ZX
# ------------------------------------------------------------
echo
echo "[2/4] Building eLeMeNt ZX..."

"$SJASM" \
    --define DUAL_GUI_TEST \
    --define DUAL_GUI_INSTALL_TEST \
    --define ELEMENT \
    --define SD_ONLY_PAGE98 \
    --lst=EasySD_1_1_EL.lst \
    --raw=EasySD_1_1_EL.bin \
    "$SOURCE" \
    || die "eLeMeNt BUILD FAILED"

[[ -s EasySD_1_1_EL.bin ]] \
    || die "EasySD_1_1_EL.bin WAS NOT CREATED"

# ------------------------------------------------------------
# MB03+ Slim
# SLIM uses the SD-only one-page model:
# BSDOS page 97, EasySD page 98.
# SD1 and SD2 share the same resident driver page.
# ------------------------------------------------------------
echo
echo "[3/4] Building MB03+ Slim..."

"$SJASM" \
    --define DUAL_GUI_TEST \
    --define DUAL_GUI_INSTALL_TEST \
    --define SLIM \
    --define SD_ONLY_PAGE98 \
    --lst=EasySD_1_1_SLIM.lst \
    --raw=EasySD_1_1_SLIM.bin \
    "$SOURCE" \
    || die "MB03+ SLIM BUILD FAILED"

[[ -s EasySD_1_1_SLIM.bin ]] \
    || die "EasySD_1_1_SLIM.bin WAS NOT CREATED"

[[ $(wc -c < EasySD_1_1_SLIM.bin) -le 16384 ]] \
    || die "SLIM BINARY TOO LARGE - MUST FIT IN 16384 BYTES"

# ------------------------------------------------------------
# TAP files
# ------------------------------------------------------------
echo
echo "[4/4] Building TAP files..."

./make_taps_1_1.sh \
    || die "TAP BUILD FAILED"

[[ -s EasySD_1_1_INSTALL.tap ]] \
    || die "EasySD_1_1_INSTALL.tap WAS NOT CREATED"

[[ -s EasySD_1_1_EL.tap ]] \
    || die "EasySD_1_1_EL.tap WAS NOT CREATED"

[[ -s EasySD_1_1_SLIM.tap ]] \
    || die "EasySD_1_1_SLIM.tap WAS NOT CREATED"

echo
echo "========================================"
echo "  EASYSD 1.1 BUILD OK"
echo "========================================"
printf '  EasySD_1_1_INSTALL.bin  %s bytes\n' "$(wc -c < EasySD_1_1_INSTALL.bin)"
printf '  EasySD_1_1_EL.bin       %s bytes\n' "$(wc -c < EasySD_1_1_EL.bin)"
printf '  EasySD_1_1_SLIM.bin     %s bytes\n' "$(wc -c < EasySD_1_1_SLIM.bin)"
echo
echo "  EasySD_1_1_INSTALL.tap"
echo "  EasySD_1_1_EL.tap"
echo "  EasySD_1_1_SLIM.tap"
echo "========================================"