#!/usr/bin/env bash
set -Eeuo pipefail

TEMP_COUNT=2500

SCRIPT_PATH="$(readlink -f -- "$0")"
ROOT="$(dirname -- "$SCRIPT_PATH")"
ROOT_REAL="$(readlink -f -- "$ROOT")"

die() {
    echo
    echo "ERROR: $*" >&2
    echo
    exit 1
}

command -v findmnt >/dev/null 2>&1 || die "findmnt not found."
command -v find >/dev/null 2>&1 || die "find not found."
command -v sync >/dev/null 2>&1 || die "sync not found."

MOUNT_POINT="$(findmnt -rn -o TARGET -T "$ROOT_REAL" | head -n 1 || true)"
SOURCE="$(findmnt -rn -o SOURCE -T "$ROOT_REAL" | head -n 1 || true)"
FSTYPE="$(findmnt -rn -o FSTYPE -T "$ROOT_REAL" | head -n 1 || true)"

[[ -n "$MOUNT_POINT" ]] || die "Cannot determine mounted filesystem for: $ROOT_REAL"

MOUNT_REAL="$(readlink -f -- "$MOUNT_POINT")"

if [[ "$ROOT_REAL" != "$MOUNT_REAL" ]]; then
    echo
    echo "ERROR: This script must be stored directly in the ROOT of the"
    echo "       mounted BSDOS FAT32 partition."
    echo
    echo "Script directory : $ROOT_REAL"
    echo "Mount point      : $MOUNT_REAL"
    echo
    exit 1
fi

if [[ "$FSTYPE" != "vfat" && "$FSTYPE" != "msdos" ]]; then
    echo
    echo "ERROR: Target filesystem is '$FSTYPE', not FAT/VFAT."
    echo "Target: $ROOT_REAL"
    echo
    exit 1
fi

[[ -w "$ROOT_REAL" ]] || die "Target partition is not writable: $ROOT_REAL"

VOL_LABEL="(unknown)"
if command -v lsblk >/dev/null 2>&1 && [[ "$SOURCE" == /dev/* ]]; then
    LABEL_FOUND="$(lsblk -no LABEL "$SOURCE" 2>/dev/null | head -n 1 || true)"
    if [[ -n "${LABEL_FOUND//[[:space:]]/}" ]]; then
        VOL_LABEL="$LABEL_FOUND"
    fi
fi

echo "=========================================="
echo "  EasySD / EasyCF FAT32 preparation - Linux"
echo "=========================================="
echo
echo "Target mount : $ROOT_REAL"
echo "Device       : ${SOURCE:-"(unknown)"}"
echo "Filesystem   : $FSTYPE"
echo "Volume label : $VOL_LABEL"
echo
echo "IMPORTANT:"
echo "- Use this on a freshly formatted FAT32 BSDOS partition."
echo "- Run it BEFORE copying any MBD/MBH images."
echo "- Do not copy other files while preparation is running."
echo "- Linux does not need the Windows System Volume Information checks."
echo

FOUND_IMAGE="$(find "$ROOT_REAL" -maxdepth 1 -type f \( -iname '*.mbd' -o -iname '*.mbh' \) -print -quit)"
if [[ -n "$FOUND_IMAGE" ]]; then
    die "MBD or MBH files already exist on the target partition:
$FOUND_IMAGE

Preparation must be performed BEFORE the images are copied."
fi

FOUND_TMP="$(find "$ROOT_REAL" -maxdepth 1 -type f -iname 'ESD*.TMP' -print -quit)"
if [[ -n "$FOUND_TMP" ]]; then
    die "A file matching ESD*.TMP already exists:
$FOUND_TMP

Remove or rename it and run the script again."
fi

echo "The script will create and then remove $TEMP_COUNT temporary"
echo "8.3 directory entries in the FAT32 root directory."
echo
read -r -p "Press ENTER to continue, or Ctrl+C to abort... "

created=0
cleanup_done=0

cleanup_temp() {
    local i name failed=0
    (( cleanup_done == 0 )) || return 0
    cleanup_done=1

    if (( created == 0 )); then
        return 0
    fi

    echo
    echo "Removing temporary files..."

    for ((i = 1; i <= created; i++)); do
        printf -v name 'ESD%04d.TMP' "$i"
        if ! rm -f -- "$ROOT_REAL/$name"; then
            failed=1
        fi
    done

    sync

    if (( failed != 0 )); then
        echo "ERROR: Some temporary files could not be removed." >&2
        return 1
    fi
}

on_abort() {
    echo
    echo "Preparation interrupted."
    cleanup_temp || true
    echo "Preparation did NOT complete. Do not copy MBD/MBH files yet."
    exit 130
}

trap on_abort INT TERM

echo
echo "Step 1/2: Pre-allocating FAT32 root-directory space..."
echo "Creating $TEMP_COUNT temporary 8.3 directory entries..."
echo

for ((i = 1; i <= TEMP_COUNT; i++)); do
    printf -v name 'ESD%04d.TMP' "$i"

    if ! : > "$ROOT_REAL/$name"; then
        echo
        echo "ERROR: Could not create $name." >&2
        cleanup_temp || true
        echo "Preparation FAILED. Do not copy MBD/MBH images yet."
        exit 1
    fi

    created=$i

    if (( i % 250 == 0 )); then
        printf '  %4d / %d\n' "$i" "$TEMP_COUNT"
    fi
done

sync

echo
echo "Step 2/2: Removing temporary entries..."
cleanup_temp || die "Cleanup failed. Check the card before continuing."

LEFTOVER="$(find "$ROOT_REAL" -maxdepth 1 -type f -iname 'ESD*.TMP' -print -quit)"
if [[ -n "$LEFTOVER" ]]; then
    die "A temporary file still remains after cleanup:
$LEFTOVER

Preparation FAILED. Do not copy MBD/MBH images yet."
fi

sync
trap - INT TERM

echo
echo "=========================================="
echo "  Preparation complete"
echo "=========================================="
echo
echo "Target mount : $ROOT_REAL"
echo "Device       : ${SOURCE:-"(unknown)"}"
echo "Volume label : $VOL_LABEL"
echo
echo "The FAT32 root directory was pre-allocated using"
echo "$TEMP_COUNT temporary 8.3 directory entries."
echo
echo "NOW copy the MBD/MBH images to this partition."
echo "IMPORTANT: Do not format the partition again after this step."
echo
