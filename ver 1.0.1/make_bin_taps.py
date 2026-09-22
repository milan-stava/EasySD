from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parent
LOAD_ADDR = 32768
CLEAR_ADDR = 32767

TOK_CLEAR = 0xFD
TOK_LOAD = 0xEF
TOK_CODE = 0xAF
TOK_RANDOMIZE = 0xF9
TOK_USR = 0xC0


def checksum(data):
    x = 0
    for b in data:
        x ^= b
    return x


def tap_block(flag, payload):
    body = bytes([flag]) + payload
    body += bytes([checksum(body)])
    return struct.pack("<H", len(body)) + body


def header(type_byte, name, length, p1, p2):
    nm = name.encode("ascii")[:10].ljust(10, b" ")
    payload = bytes([type_byte]) + nm + struct.pack("<HHH", length, p1, p2)
    return tap_block(0x00, payload)


def code_file(name, data, addr):
    return header(3, name, len(data), addr, 0x8000) + tap_block(0xFF, data)


def zxnum(n):
    return str(n).encode("ascii") + bytes([0x0E, 0, 0, n & 0xFF, (n >> 8) & 0xFF, 0])


def basic_line(number, content):
    content += b"\r"
    return struct.pack(">H", number) + struct.pack("<H", len(content)) + content


def make_loader_program():
    # 10 CLEAR 32767: LOAD "" CODE 32768:RANDOMIZE USR 32768
    content = b"".join([
        bytes([TOK_CLEAR]), b" ", zxnum(CLEAR_ADDR),
        b":",
        bytes([TOK_LOAD]), b' "" ', bytes([TOK_CODE]), b" ", zxnum(LOAD_ADDR),
        b":",
        bytes([TOK_RANDOMIZE]), b" ", bytes([TOK_USR]), b" ", zxnum(LOAD_ADDR),
    ])
    return basic_line(10, content)


def validate_tap(tap):
    i = 0
    blocks = 0
    while i < len(tap):
        if i + 2 > len(tap):
            raise ValueError("truncated TAP length")
        ln = struct.unpack_from("<H", tap, i)[0]
        i += 2
        body = tap[i:i + ln]
        if len(body) != ln:
            raise ValueError("truncated TAP block")
        if checksum(body) != 0:
            raise ValueError("bad TAP checksum")
        i += ln
        blocks += 1
    if i != len(tap):
        raise ValueError("invalid TAP length")
    return blocks


def build(bin_name, tap_name, spectrum_name):
    bin_path = ROOT / bin_name
    tap_path = ROOT / tap_name

    if not bin_path.exists():
        raise FileNotFoundError(f"{bin_name} not found")

    binary = bin_path.read_bytes()
    if not binary:
        raise ValueError(f"{bin_name} is empty")

    if LOAD_ADDR + len(binary) > 65536:
        raise ValueError(
            f"{bin_name} is too large for LOAD address {LOAD_ADDR}: {len(binary)} bytes"
        )

    program = make_loader_program()
    tap = (
        header(0, spectrum_name, len(program), 10, len(program))
        + tap_block(0xFF, program)
        + code_file(spectrum_name, binary, LOAD_ADDR)
    )

    blocks = validate_tap(tap)
    tap_path.write_bytes(tap)

    print(f"{tap_name}: OK")
    print(f"  source: {bin_name} ({len(binary)} bytes)")
    print(f"  LOAD address: {LOAD_ADDR}")
    print('  BASIC: 10 CLEAR 32767: LOAD "" CODE 32768:RANDOMIZE USR 32768')
    print(f"  TAP size: {len(tap)} bytes, blocks: {blocks}")


def main():
    targets = [
        ("EasySD_MB.bin", "EasySD_MB_BIN.tap", "EASYSD_MB"),
    ]

    try:
        for target in targets:
            build(*target)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
