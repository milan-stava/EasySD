#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

byte() {
    local file="$1" v=$(( $2 & 255 ))
    printf "\\$(printf '%03o' "$v")" >> "$file"
}

bytes() {
    local file="$1"; shift
    local v
    for v in "$@"; do byte "$file" "$v"; done
}

u16le() {
    local file="$1" v=$2
    byte "$file" $((v & 255)); byte "$file" $(((v >> 8) & 255))
}

u16be() {
    local file="$1" v=$2
    byte "$file" $(((v >> 8) & 255)); byte "$file" $((v & 255))
}

checksum_file() {
    local file="$1" x=0 line n
    while read -r line; do
        for n in $line; do x=$((x ^ n)); done
    done < <(od -An -v -tu1 "$file")
    printf '%d\n' "$x"
}

tap_block() {
    local out="$1" flag="$2" payload="$3"
    local body="$TMP/body.$$.$RANDOM" len sum
    : > "$body"
    byte "$body" "$flag"
    cat "$payload" >> "$body"
    sum="$(checksum_file "$body")"
    byte "$body" "$sum"
    len="$(wc -c < "$body")"
    u16le "$out" "$len"
    cat "$body" >> "$out"
    rm -f "$body"
}

header() {
    local out="$1" type="$2" name="$3" len="$4" p1="$5" p2="$6"
    local p="$TMP/header.$$.$RANDOM"
    : > "$p"
    byte "$p" "$type"
    printf '%-10.10s' "$name" >> "$p"
    u16le "$p" "$len"; u16le "$p" "$p1"; u16le "$p" "$p2"
    tap_block "$out" 0 "$p"
    rm -f "$p"
}

code_file() {
    local out="$1" name="$2" data="$3" addr="$4"
    local len
    len="$(wc -c < "$data")"
    header "$out" 3 "$name" "$len" "$addr" 32768
    tap_block "$out" 255 "$data"
}

zxnum() {
    local out="$1" n="$2"
    printf '%d' "$n" >> "$out"
    bytes "$out" 14 0 0 $((n & 255)) $(((n >> 8) & 255)) 0
}

basic_line() {
    local program="$1" line_no="$2" content="$3"
    local d="$TMP/line.$$.$RANDOM" len
    cp "$content" "$d"
    byte "$d" 13
    len="$(wc -c < "$d")"
    u16be "$program" "$line_no"
    u16le "$program" "$len"
    cat "$d" >> "$program"
    rm -f "$d"
}

make_simple_tap() {
    local bin="$ROOT/EasySD_1_1_INSTALL.bin" out="$ROOT/EasySD_1_1_INSTALL.tap"
    local content="$TMP/simple_content" program="$TMP/simple_program" len
    [[ -s "$bin" ]] || { echo "ERROR: Missing EasySD_1_1_INSTALL.bin" >&2; exit 1; }
    : > "$content"; : > "$program"; : > "$out"
    byte "$content" 253; printf ' ' >> "$content"; zxnum "$content" 32767
    printf ':' >> "$content"; byte "$content" 239; printf ' "" ' >> "$content"; byte "$content" 175
    printf ' ' >> "$content"; zxnum "$content" 32768; printf ':' >> "$content"
    byte "$content" 249; printf ' ' >> "$content"; byte "$content" 192; printf ' ' >> "$content"; zxnum "$content" 32768
    basic_line "$program" 10 "$content"
    len="$(wc -c < "$program")"
    header "$out" 0 EASYSD11 "$len" 10 "$len"
    tap_block "$out" 255 "$program"
    code_file "$out" EASYSD11 "$bin" 32768
    echo "EasySD_1_1_INSTALL.tap : OK ($(wc -c < "$out") bytes)"
}

build_loader_common() {
    local mode="$1" easy="$2" loader="$3"
    local easy_len
    easy_len="$(wc -c < "$easy")"
    : > "$loader"
    # PAGE0=#7000, PAGE1=#7004, PAGE3=#7008, SELECT_PAGE=#700C, START=#7012
    bytes "$loader" 62 16 24 8 62 17 24 4 62 19 24 0 1 253 127 237 121 201
    if [[ "$mode" == element ]]; then
        bytes "$loader" 1 59 120 62 1 237 121 1 59 121 62 2 237 121
    else
        bytes "$loader" 1 59 112 175 237 121 1 59 113 62 1 237 121
    fi
    # page 0 -> MB02+ bank 0
    bytes "$loader" 1 253 127 62 16 237 121 62 96 211 23 33 0 192 17 0 0 1 0 64 237 176
    # page 1 -> MB02+ bank 1
    bytes "$loader" 1 253 127 62 17 237 121 62 97 211 23 33 0 192 17 0 0 1 0 64 237 176
    # page 3 -> EasySD at #8000
    bytes "$loader" 1 253 127 62 19 237 121 33 0 192 17 0 128 1
    u16le "$loader" "$easy_len"
    bytes "$loader" 237 176
    # BSROM page 0 read-only + JP #8000
    bytes "$loader" 62 64 211 23 195 0 128
}

add_loader_basic_line() {
    local program="$1" line_no="$2" kind="$3" value="$4"
    local c="$TMP/content.$$.$RANDOM"
    : > "$c"
    case "$kind" in
        clear)
            byte "$c" 253; printf ' ' >> "$c"; zxnum "$c" "$value" ;;
        load)
            byte "$c" 239; printf ' "" ' >> "$c"; byte "$c" 175; printf ' ' >> "$c"; zxnum "$c" "$value" ;;
        usr)
            byte "$c" 249; printf ' ' >> "$c"; byte "$c" 192; printf ' ' >> "$c"; zxnum "$c" "$value" ;;
    esac
    basic_line "$program" "$line_no" "$c"
    rm -f "$c"
}

make_full_tap() {
    local mode="$1" easy_name="$2" out_name="$3" basic_name="$4" loader_name="$5" easy_tap_name="$6"
    local bsrom="$ROOT/BSROM140_EL.rom" bsdos="$ROOT/BSDOS.rom" easy="$ROOT/$easy_name" out="$ROOT/$out_name"
    local loader="$TMP/${mode}_loader" program="$TMP/${mode}_program" plen
    [[ $(wc -c < "$bsrom") -eq 16384 ]] || { echo "ERROR: BSROM140_EL.rom must be 16384 bytes" >&2; exit 1; }
    [[ $(wc -c < "$bsdos") -eq 16384 ]] || { echo "ERROR: BSDOS.rom must be 16384 bytes" >&2; exit 1; }
    [[ -s "$easy" ]] || { echo "ERROR: Missing $easy_name" >&2; exit 1; }
    [[ $(wc -c < "$easy") -le 16384 ]] || { echo "ERROR: $easy_name too large" >&2; exit 1; }

    build_loader_common "$mode" "$easy" "$loader"
    : > "$program"
    add_loader_basic_line "$program" 10 clear 28671
    add_loader_basic_line "$program" 20 load 28672
    add_loader_basic_line "$program" 30 usr 28672
    add_loader_basic_line "$program" 40 load 49152
    add_loader_basic_line "$program" 50 usr 28676
    add_loader_basic_line "$program" 60 load 49152
    add_loader_basic_line "$program" 70 usr 28680
    add_loader_basic_line "$program" 80 load 49152
    add_loader_basic_line "$program" 90 usr 28690

    : > "$out"
    plen="$(wc -c < "$program")"
    header "$out" 0 "$basic_name" "$plen" 10 "$plen"
    tap_block "$out" 255 "$program"
    code_file "$out" "$loader_name" "$loader" 28672
    code_file "$out" BSROM140 "$bsrom" 49152
    code_file "$out" BSDOS "$bsdos" 49152
    code_file "$out" "$easy_tap_name" "$easy" 49152
    echo "$out_name : OK ($(wc -c < "$out") bytes)"
}

make_simple_tap
make_full_tap element EasySD_1_1_EL.bin EasySD_1_1_EL.tap EASYSD_EL EL128DIR EasySD_EL
make_full_tap slim EasySD_1_1_SLIM.bin EasySD_1_1_SLIM.tap EASYSD_SLM SLIM128DIR EasySD_SLM
