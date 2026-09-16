from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parent
BIN_PATH = ROOT / "SWITCH_ALL.bin"
TAP_PATH = ROOT / "SWITCH_MENU.tap"

TOK = {
    "USR": 0xC0,
    "INT": 0xBA,
    "THEN": 0xCB,
    "REM": 0xEA,
    "GO TO": 0xEC,
    "INPUT": 0xEE,
    "LOAD": 0xEF,
    "LET": 0xF1,
    "PAUSE": 0xF2,
    "PRINT": 0xF5,
    "RANDOMIZE": 0xF9,
    "IF": 0xFA,
    "CLS": 0xFB,
    "CLEAR": 0xFD,
    "CODE": 0xAF,
}


def checksum(data):
    value = 0
    for byte in data:
        value ^= byte
    return value


def tap_block(flag, payload):
    body = bytes([flag]) + payload
    body += bytes([checksum(body)])
    return struct.pack("<H", len(body)) + body


def header(type_byte, name, length, p1, p2):
    name = name.encode("ascii")[:10].ljust(10, b" ")
    payload = bytes([type_byte]) + name + struct.pack("<HHH", length, p1, p2)
    return tap_block(0, payload)


def zxnum(number):
    return str(number).encode("ascii") + bytes(
        [0x0E, 0, 0, number & 0xFF, (number >> 8) & 0xFF, 0]
    )


def token(name):
    return bytes([TOK[name]])


def line(number, content):
    content += b"\r"
    return struct.pack(">H", number) + struct.pack("<H", len(content)) + content


def string(value):
    return b'"' + value.encode("ascii") + b'"'


def build_basic():
    lines = []
    lines.append(line(10, b"".join([
        token("CLEAR"), b" ", zxnum(32767), b":",
        token("LOAD"), b' "" ', token("CODE"), b" ", zxnum(32768),
    ])))
    lines.append(line(20, token("CLS")))
    lines.append(line(30, b"".join([
        token("LET"), b" s=", token("USR"), b" ", zxnum(32779),
    ])))
    lines.append(line(35, b"".join([
        token("LET"), b" m=", token("USR"), b" ", zxnum(32782),
    ])))
    lines.append(line(36, b"".join([
        token("LET"), b" c=m-", zxnum(2), b"*", token("INT"), b" (m/", zxnum(2), b")",
    ])))
    lines.append(line(37, b"".join([
        token("LET"), b" d=", token("INT"), b" (m/", zxnum(2), b")-", zxnum(2),
        b"*", token("INT"), b" (m/", zxnum(4), b")",
    ])))
    lines.append(line(38, b"".join([
        token("LET"), b" e=", token("INT"), b" (m/", zxnum(4), b")",
    ])))
    lines.append(line(40, token("PRINT") + b" " + string("EasySD/EasyCF switcher 1.1")))
    lines.append(line(50, token("PRINT")))
    lines.append(line(60, token("PRINT") + b" " + string("Current: ") + b";"))
    for number, value, label in ((70, 0, "CF"), (80, 1, "SD1"), (90, 2, "SD2")):
        lines.append(line(number, b"".join([
            token("IF"), b" s=", zxnum(value), b" ", token("THEN"), b" ",
            token("PRINT"), b" ", string(label),
        ])))
    for number, value, label in (
        (92, 3, "EasyHDD detected"),
        (93, 4, "EasySD 1.0 detected"),
        (94, 5, "EasyCF detected"),
    ):
        lines.append(line(number, b"".join([
            token("IF"), b" s=", zxnum(value), b" ", token("THEN"), b" ",
            token("PRINT"), b" ", string(label),
        ])))
    lines.append(line(95, b"".join([
        token("IF"), b" s=", zxnum(255), b" ", token("THEN"), b" ",
        token("PRINT"), b" ", string("NOT DETECTED"),
    ])))
    lines.append(line(96, b"".join([
        token("IF"), b" s>", zxnum(2), b" ", token("THEN"), b" ",
        token("GO TO"), b" ", zxnum(500),
    ])))
    lines.append(line(100, token("PRINT")))
    for number, flag, label in ((110, "c", "1 - CF"), (120, "d", "2 - SD1"), (130, "e", "3 - SD2")):
        lines.append(line(number, token("PRINT") + b" " + string(label) + b";"))
        lines.append(line(number + 1, b"".join([
            token("IF"), b" " + flag.encode("ascii") + b"=", zxnum(0), b" ", token("THEN"), b" ",
            token("PRINT"), b" ", string("  NOT DETECTED"),
        ])))
        lines.append(line(number + 2, b"".join([
            token("IF"), b" " + flag.encode("ascii") + b"=", zxnum(1), b" ", token("THEN"), b" ",
            token("PRINT"),
        ])))
    lines.append(line(140, token("PRINT") + b" " + string("0 - Exit")))
    lines.append(line(150, token("PRINT")))
    lines.append(line(160, token("INPUT") + b" " + string("Select: ") + b";a"))
    lines.append(line(170, b"".join([
        token("IF"), b" a=", zxnum(0), b" ", token("THEN"), b" ",
        token("GO TO"), b" ", zxnum(9999),
    ])))
    for number, value, address in (
        (180, 1, 32768), (190, 2, 32771), (200, 3, 32775)
    ):
        lines.append(line(number, b"".join([
            token("IF"), b" a=", zxnum(value), b" ", token("THEN"), b" ",
            token("LET"), b" r=", token("USR"), b" ", zxnum(address), b":",
            token("GO TO"), b" ", zxnum(300),
        ])))
    lines.append(line(210, token("GO TO") + b" " + zxnum(160)))
    lines.append(line(300, b"".join([
        token("IF"), b" r=", zxnum(0), b" ", token("THEN"), b" ", token("GO TO"), b" ", zxnum(20),
    ])))
    lines.append(line(310, token("PRINT")))
    lines.append(line(320, token("PRINT") + b" " + string("NOT DETECTED - SWITCH NOT POSSIBLE")))
    lines.append(line(330, token("PAUSE") + b" " + zxnum(0)))
    lines.append(line(340, token("GO TO") + b" " + zxnum(20)))
    lines.append(line(500, token("PRINT")))
    lines.append(line(510, token("PRINT") + b" " + string("EasySD/EasyCF 1.1 not installed")))
    lines.append(line(520, token("PRINT")))
    lines.append(line(530, token("PRINT") + b" " + string("Press any key")))
    lines.append(line(540, token("PAUSE") + b" " + zxnum(0)))
    lines.append(line(550, token("GO TO") + b" " + zxnum(9999)))
    lines.append(line(9999, token("REM") + b" End"))
    return b"".join(lines)


def validate_tap(tap):
    offset = 0
    blocks = 0
    while offset < len(tap):
        length = struct.unpack_from("<H", tap, offset)[0]
        offset += 2
        body = tap[offset:offset + length]
        if len(body) != length or checksum(body) != 0:
            raise ValueError("Invalid TAP block")
        offset += length
        blocks += 1
    if offset != len(tap):
        raise ValueError("Invalid TAP length")
    return blocks


def main():
    code = BIN_PATH.read_bytes()
    basic = build_basic()
    tap = b"".join([
        header(0, "SWITCH1.1", len(basic), 10, len(basic)),
        tap_block(0xFF, basic),
        header(3, "SWITCHCODE", len(code), 32768, 32768),
        tap_block(0xFF, code),
    ])
    blocks = validate_tap(tap)
    TAP_PATH.write_bytes(tap)
    print(f"{TAP_PATH.name}: {len(tap)} B, {blocks} valid blocks")
    print(f"BASIC: {len(basic)} B, CODE: {len(code)} B")


if __name__ == "__main__":
    main()
