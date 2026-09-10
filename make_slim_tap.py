#!/usr/bin/env python3
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parent

BSROM = ROOT / "BSROM140_EL.rom"
BSDOS = ROOT / "BSDOS.rom"
EASY  = ROOT / "EasySD_SLIM.bin"
OUT   = ROOT / "EasySD_SLIM.tap"

BASE = 0x7000
PORT_7FFD = 0x7FFD

def die(msg):
    print(f"ERROR: {msg}")
    sys.exit(1)

def read_exact(path, size=None):
    if not path.exists():
        die(f"Missing file: {path.name}")
    data = path.read_bytes()
    if size is not None and len(data) != size:
        die(f"{path.name}: expected {size} bytes, got {len(data)}")
    return data

bsrom = read_exact(BSROM, 16384)
bsdos = read_exact(BSDOS, 16384)
easy  = read_exact(EASY)

if len(easy) > 0x4000:
    die(f"EasySD_SLIM.bin is too large for 16K staging page: {len(easy)} bytes")

# ------------------------------------------------------------
# MB03+ Slim bootstrap based on the proven eLeMeNt bootstrap:
# 48K environment + enabled 128K paging
# #10 -> page 0: BSROM
# #11 -> page 1: BSDOS
# #13 -> page 3: EasySD
# then m_zxi_000=#01 and MB02+ bank copy.
# ------------------------------------------------------------
code = bytearray()

def e(*xs):
    code.extend(xs)

def ew(v):
    code.extend((v & 0xFF, (v >> 8) & 0xFF))

PAGE0 = BASE + len(code)
e(0x3E, 0x10)              # ld a,#10
p0jr = len(code)
e(0x18, 0x00)              # jr SELECT_PAGE

PAGE1 = BASE + len(code)
e(0x3E, 0x11)
p1jr = len(code)
e(0x18, 0x00)

PAGE3 = BASE + len(code)
e(0x3E, 0x13)
p3jr = len(code)
e(0x18, 0x00)

SELECT_PAGE = BASE + len(code)
e(0x01); ew(PORT_7FFD)     # ld bc,#7FFD
e(0xED, 0x79)              # out (c),a
e(0xC9)                    # ret

def patch_jr(pos, target):
    next_addr = BASE + pos + 2
    disp = target - next_addr
    if not -128 <= disp <= 127:
        die("Internal loader JR out of range")
    code[pos + 1] = disp & 0xFF

patch_jr(p0jr, SELECT_PAGE)
patch_jr(p1jr, SELECT_PAGE)
patch_jr(p3jr, SELECT_PAGE)

START = BASE + len(code)

# MB03+ Slim: switch to MB02+ / BSDOS machine: m_zxi_000 = #01
# #703B = m_zxi register select, #713B = m_zxi data
e(0x01); ew(0x703B)
e(0xAF)                    # xor a -> register #00
e(0xED, 0x79)             # out (c),a
e(0x01); ew(0x713B)
e(0x3E, 0x01)
e(0xED, 0x79)

# 128K page 0 -> MB02+ bank 0, write enabled (96)
e(0x01); ew(PORT_7FFD)
e(0x3E, 0x10)
e(0xED, 0x79)
e(0x3E, 96)
e(0xD3, 23)
e(0x21); ew(0xC000)
e(0x11); ew(0x0000)
e(0x01); ew(0x4000)
e(0xED, 0xB0)

# 128K page 1 -> MB02+ bank 1, write enabled (97)
e(0x01); ew(PORT_7FFD)
e(0x3E, 0x11)
e(0xED, 0x79)
e(0x3E, 97)
e(0xD3, 23)
e(0x21); ew(0xC000)
e(0x11); ew(0x0000)
e(0x01); ew(0x4000)
e(0xED, 0xB0)

# 128K page 3 -> EasySD at #8000
e(0x01); ew(PORT_7FFD)
e(0x3E, 0x13)
e(0xED, 0x79)
e(0x21); ew(0xC000)
e(0x11); ew(0x8000)
e(0x01); ew(len(easy))
e(0xED, 0xB0)

# Select BSROM bank 0 read-only and start EasySD
e(0x3E, 64)
e(0xD3, 23)
e(0xC3); ew(0x8000)

loader = bytes(code)

# ------------------------------------------------------------
# TAP helpers
# ------------------------------------------------------------
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

TOK_CLEAR = 0xFD
TOK_LOAD = 0xEF
TOK_CODE = 0xAF
TOK_RANDOMIZE = 0xF9
TOK_USR = 0xC0

def zxnum(n):
    return str(n).encode("ascii") + bytes([0x0E,0,0,n&255,(n>>8)&255,0])

def line(n, content):
    content += b"\r"
    return struct.pack(">H", n) + struct.pack("<H", len(content)) + content

program = b"".join([
    line(10, bytes([TOK_CLEAR]) + b" " + zxnum(28671)),
    line(20, bytes([TOK_LOAD]) + b' "" ' + bytes([TOK_CODE]) + b" " + zxnum(BASE)),
    line(30, bytes([TOK_RANDOMIZE]) + b" " + bytes([TOK_USR]) + b" " + zxnum(PAGE0)),
    line(40, bytes([TOK_LOAD]) + b' "" ' + bytes([TOK_CODE]) + b" " + zxnum(0xC000)),
    line(50, bytes([TOK_RANDOMIZE]) + b" " + bytes([TOK_USR]) + b" " + zxnum(PAGE1)),
    line(60, bytes([TOK_LOAD]) + b' "" ' + bytes([TOK_CODE]) + b" " + zxnum(0xC000)),
    line(70, bytes([TOK_RANDOMIZE]) + b" " + bytes([TOK_USR]) + b" " + zxnum(PAGE3)),
    line(80, bytes([TOK_LOAD]) + b' "" ' + bytes([TOK_CODE]) + b" " + zxnum(0xC000)),
    line(90, bytes([TOK_RANDOMIZE]) + b" " + bytes([TOK_USR]) + b" " + zxnum(START)),
])

tap = header(0, "EASYSD_SLM", len(program), 10, len(program)) + tap_block(0xFF, program)
tap += code_file("SLIM128DIR", loader, BASE)
tap += code_file("BSROM140", bsrom, 0xC000)
tap += code_file("BSDOS", bsdos, 0xC000)
tap += code_file("EasySD_SLM", easy, 0xC000)

# Validate TAP block lengths/checksums before saving.
i = 0
blocks = 0
while i < len(tap):
    if i + 2 > len(tap):
        die("Internal TAP validation failed")
    ln = struct.unpack_from("<H", tap, i)[0]
    i += 2
    body = tap[i:i+ln]
    if len(body) != ln or checksum(body) != 0:
        die("Internal TAP checksum validation failed")
    i += ln
    blocks += 1

if i != len(tap):
    die("Internal TAP length validation failed")

OUT.write_bytes(tap)

print("TAP build OK")
print(f"  {OUT.name}: {len(tap)} bytes")
print(f"  EasySD_SLIM.bin: {len(easy)} bytes")
print(f"  Loader: {len(loader)} bytes")
print(f"  Blocks: {blocks}")
print(f"  PAGE0=#{PAGE0:04X} PAGE1=#{PAGE1:04X} PAGE3=#{PAGE3:04X} START=#{START:04X}")
