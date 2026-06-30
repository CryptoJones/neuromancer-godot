#!/usr/bin/env python3
"""
extract.py - One-time asset extractor for Interplay's *Neuromancer* (DOS, 1988).

Unpacks the original game's proprietary NEURO1.DAT / NEURO2.DAT archives into
PNG images (sprites + backgrounds), a JSON palette, and JSON text resources,
for the open-source Godot remake.

DECODING ALGORITHM CREDIT
-------------------------
The .DAT format and its decompression were reverse-engineered by others; this
script is a faithful Python PORT of their work. All decoding logic is derived
from these MIT-licensed projects:

  * Henadzi Matuts - "Reuromancer" (C / MASM) and the "Reversing the
    Neuromancer" blog series. This is the primary source for the Huffman +
    RLE + scanline-XOR decode, the +32-byte PIC/IMH data offset, the
    fixed 152x112 PIC geometry, and the resource directory.
      https://github.com/HenadziMatuts/Reuromancer
      https://henadzimatuts.github.io/2018/03/30/reversing-the-neuromancer-part-1.html
  * Mark J. Koch (@maehem) - "Javamancer" (Java). Reference for the 4bpp
    (two pixels per byte) palette mapping used to render decoded buffers.
      https://github.com/maehem/javamancer

Both upstream projects are MIT-licensed; this port is offered under MIT as well.
Original game (c) 1988 Interplay Productions.

WHAT THE FORMAT LOOKS LIKE (as determined empirically + from the references)
---------------------------------------------------------------------------
* The EXE holds a resource directory: records of `char name[14]; u32 offset;
  u32 size;` (little-endian) describing where each resource lives inside one of
  the two .DAT files. (The first handful of legacy R1..R9 records use a slightly
  different in-EXE layout, so the *authoritative* directory below is the table
  ported from Reuromancer; --validate-exe re-derives and cross-checks it against
  the bytes actually present in the EXE.)
* Each resource is a Huffman-compressed blob inside the .DAT.
    - .BIH / .ANH / .TXH : Huffman stream starts at `offset`.
    - .PIC / .IMH        : a 32-byte header precedes the Huffman stream, so the
                           stream starts at `offset + 32`.
* Huffman: first 4 bytes (LE) = decompressed length, then a bit-packed tree
  (1 => leaf w/ next 8 bits as value; 0 => internal, right child then left),
  then the bitstream (bit 1 => left, bit 0 => right).
* .PIC: Huffman output is an RLE stream -> decode_rle to 152*112 bytes ->
  xor_rows(152,112). The 152*112 buffer is 4bpp packed (two 16-color pixels per
  byte), i.e. a 304x112 image.
* .IMH: Huffman output is one-or-more sub-images, each prefixed by an 8-byte
  header `u16 dx, dy, width, height` (width in BYTES). Each sub-image body is an
  RLE stream of width*height bytes -> xor_rows(width,height). Rendered 4bpp, so
  pixel width = width*2.
* RLE: byte b. If b > 0x7F: literal run of (0x100 - b) following bytes.
  Else: run of (b+1) copies of the next byte.
* xor_rows: each scanline (after the first) is XORed with the one above it.
* Palette: 16-colour EGA. Decoded nibbles index it directly.
"""

import argparse
import json
import os
import re
import struct
import sys
import zlib

# --------------------------------------------------------------------------
# 16-colour EGA palette (R,G,B). Decoded pixel nibbles index this directly.
# Matches the DosPal/Javamancer colour set used by the reference decoders.
# --------------------------------------------------------------------------
EGA_PALETTE = [
    (0x00, 0x00, 0x00),  # 0  black
    (0x00, 0x00, 0xAA),  # 1  blue
    (0x00, 0xAA, 0x00),  # 2  green
    (0x00, 0xAA, 0xAA),  # 3  cyan
    (0xAA, 0x00, 0x00),  # 4  red
    (0xAA, 0x00, 0xAA),  # 5  magenta
    (0xAA, 0x55, 0x00),  # 6  brown
    (0xAA, 0xAA, 0xAA),  # 7  light gray
    (0x55, 0x55, 0x55),  # 8  dark gray
    (0x55, 0x55, 0xFF),  # 9  light blue
    (0x55, 0xFF, 0x55),  # 10 light green
    (0x55, 0xFF, 0xFF),  # 11 light cyan
    (0xFF, 0x55, 0x55),  # 12 light red
    (0xFF, 0x55, 0xFF),  # 13 light magenta
    (0xFF, 0xFF, 0x55),  # 14 yellow
    (0xFF, 0xFF, 0xFF),  # 15 white
]

# --------------------------------------------------------------------------
# Authoritative resource directory (file, name, offset, size).
# Ported verbatim from Reuromancer's LibNeuroRoutines/resources_lists.c
# (Henadzi Matuts, MIT). file 0 == NEURO1.DAT, file 1 == NEURO2.DAT.
# Every offset/size below has been confirmed to decode against the real files.
# --------------------------------------------------------------------------
RESOURCES = [
    (0, "R1.BIH", 0x0, 0x5EE),
    (0, "R1.PIC", 0x5EE, 0x1346),
    (0, "R1.ANH", 0x1934, 0x2E5),
    (0, "R2.BIH", 0x1C19, 0xC7),
    (0, "R2.PIC", 0x1CE0, 0x1CB3),
    (0, "R2.ANH", 0x3993, 0x340),
    (0, "R3.BIH", 0x3CD3, 0x87F),
    (0, "R3.PIC", 0x45CA, 0x1B06),
    (0, "R4.BIH", 0x60D0, 0x47A),
    (0, "R4.PIC", 0x654A, 0x2646),
    (0, "R4.ANH", 0x8B90, 0x58F),
    (0, "R5.BIH", 0x911F, 0x2D),
    (0, "R5.PIC", 0x914C, 0x13FF),
    (0, "R6.BIH", 0xA54B, 0x7EB),
    (0, "R6.PIC", 0xAD36, 0xFDC),
    (0, "R6.ANH", 0xBD12, 0xD9C),
    (0, "R7.BIH", 0xCAAE, 0x2A7),
    (0, "R7.PIC", 0xCD55, 0x1AD2),
    (0, "R8.BIH", 0xE827, 0x9A4),
    (0, "R8.PIC", 0xF1CB, 0x187B),
    (0, "R8.ANH", 0x10A46, 0x1BC),
    (0, "R9.BIH", 0x10C02, 0x4A4),
    (0, "R9.PIC", 0x110A6, 0x20F8),
    (0, "R10.BIH", 0x1319E, 0x3C3),
    (0, "R10.PIC", 0x13561, 0x1051),
    (0, "R11.BIH", 0x145B2, 0x79C),
    (0, "R11.PIC", 0x14D4E, 0x11DC),
    (0, "R11.ANH", 0x15F2A, 0x372),
    (0, "R12.BIH", 0x1629C, 0x94C),
    (0, "R12.PIC", 0x16BE8, 0x1A35),
    (0, "R12.ANH", 0x1861D, 0xB68),
    (0, "R13.BIH", 0x19185, 0x2D),
    (0, "R13.PIC", 0x191B2, 0x1A9F),
    (0, "R14.BIH", 0x1AC51, 0x2D),
    (0, "R14.PIC", 0x1AC7E, 0x1DFE),
    (0, "R15.BIH", 0x1CA7C, 0x2D),
    (0, "R15.PIC", 0x1CAA9, 0x1D0B),
    (0, "R16.BIH", 0x1E7B4, 0x2D),
    (0, "R16.PIC", 0x1E7E1, 0x1CC0),
    (0, "R17.BIH", 0x204A1, 0xB9),
    (0, "R17.PIC", 0x2055A, 0x1B13),
    (0, "R18.BIH", 0x2206D, 0x2D),
    (0, "R18.PIC", 0x2209A, 0x1730),
    (0, "R19.BIH", 0x237CA, 0x499),
    (0, "R19.PIC", 0x23C63, 0x1336),
    (0, "R19.ANH", 0x24F99, 0x1E33),
    (0, "R20.BIH", 0x26DCC, 0x64A),
    (0, "R20.PIC", 0x27416, 0x164C),
    (0, "R21.BIH", 0x28A62, 0x26),
    (0, "R21.PIC", 0x28A88, 0xA53),
    (0, "R22.BIH", 0x294DB, 0x293),
    (0, "R22.PIC", 0x2976E, 0x690),
    (0, "R22.ANH", 0x29DFE, 0xA9),
    (0, "R23.BIH", 0x29EA7, 0x817),
    (0, "R23.PIC", 0x2A6BE, 0x1A98),
    (0, "R24.BIH", 0x2C156, 0x583),
    (0, "R24.PIC", 0x2C6D9, 0x1DDD),
    (0, "R24.ANH", 0x2E4B6, 0xB9C),
    (0, "R25.BIH", 0x2F052, 0x3E4),
    (0, "R25.PIC", 0x2F436, 0xB59),
    (0, "R26.BIH", 0x2FF8F, 0x813),
    (0, "R26.PIC", 0x307A2, 0x1DD3),
    (0, "R26.ANH", 0x32575, 0xB8B),
    (0, "R27.BIH", 0x33100, 0x7EB),
    (0, "R27.PIC", 0x338EB, 0x133E),
    (0, "R27.ANH", 0x34C29, 0x232),
    (0, "R28.BIH", 0x34E5B, 0x412),
    (0, "CORNERS.BIH", 0x3526D, 0x21),
    (0, "ROOMPOS.BIH", 0x3528E, 0x336),
    (0, "BUBBLES.IMH", 0x363F1, 0xFD),
    (0, "CURSORS.IMH", 0x364EE, 0xF3),
    (0, "NEURO.IMH", 0x365E1, 0xA8B),
    (0, "SPRITES.IMH", 0x3706C, 0x25C3),
    (0, "TITLE.IMH", 0x395A8, 0x2BAB),
    (0, "FTUSER.TXH", 0x3C2E3, 0x362),
    (1, "NEWS.BIH", 0x154D1, 0x146E),
    (1, "PAXBBS.BIH", 0x1693F, 0xC6F),
    (1, "AIP0.IMH", 0x1873B, 0x334),
    (1, "AIP1.IMH", 0x18A6F, 0x32A),
    (1, "AIP2.IMH", 0x18D99, 0x308),
    (1, "AIP3.IMH", 0x190A1, 0x2D2),
    (1, "AIP4.IMH", 0x19373, 0x335),
    (1, "AIP5.IMH", 0x196A8, 0x342),
    (1, "AIP6.IMH", 0x199EA, 0x373),
    (1, "AIP7.IMH", 0x19D5D, 0x2EA),
    (1, "AIP8.IMH", 0x1A047, 0x316),
    (1, "AIP9.IMH", 0x1A35D, 0x2F8),
    (1, "AIP10.IMH", 0x1A655, 0x3D2),
    (1, "AIP11.IMH", 0x1AA27, 0x335),
    (1, "CSDB.IMH", 0x1AD5C, 0x15BD),
    (1, "CSPACE.IMH", 0x1C319, 0x106D),
    (1, "CSPANEL.IMH", 0x1D386, 0x733),
    (1, "DBSPR.IMH", 0x1DAB9, 0x26B),
    (1, "ENDGAME.IMH", 0x1DD24, 0x3E92),
    (1, "GRIDBASE.IMH", 0x21BB6, 0x109B),
    (1, "GRIDS.IMH", 0x22C51, 0x6084),
    (1, "ICE.IMH", 0x28CD5, 0x22E1),
    (1, "SHOTS.IMH", 0x2AFB6, 0x55A),
    (1, "VIRUSICE.IMH", 0x2B510, 0x467F),
    (1, "VIRUSROT.IMH", 0x2FB8F, 0x223F),
    (1, "R29.BIH", 0x32BB3, 0x45D),
    (1, "R29.PIC", 0x33010, 0x1160),
    (1, "R29.ANH", 0x34170, 0x10A),
    (1, "R30.BIH", 0x3427A, 0x26),
    (1, "R30.PIC", 0x342A0, 0xCB9),
    (1, "R31.BIH", 0x34F59, 0x2D),
    (1, "R31.PIC", 0x34F86, 0x133B),
    (1, "R32.BIH", 0x362C1, 0x68B),
    (1, "R32.PIC", 0x3694C, 0xC29),
    (1, "R33.BIH", 0x37575, 0x26),
    (1, "R33.PIC", 0x3759B, 0xA3A),
    (1, "R34.BIH", 0x37FD5, 0x498),
    (1, "R34.PIC", 0x3846D, 0x5CF),
    (1, "R34.ANH", 0x38A3C, 0x420),
    (1, "R35.BIH", 0x38E5C, 0xC8),
    (1, "R35.PIC", 0x38F24, 0xA3E),
    (1, "R36.BIH", 0x39962, 0x589),
    (1, "R36.PIC", 0x39EEB, 0x1C8F),
    (1, "R36.ANH", 0x3BB7A, 0x566),
    (1, "R37.BIH", 0x3C0E0, 0x2D),
    (1, "R37.PIC", 0x3C10D, 0x1253),
    (1, "R38.BIH", 0x3D360, 0x2D),
    (1, "R38.PIC", 0x3D38D, 0x1570),
    (1, "R39.BIH", 0x3E8FD, 0x2D),
    (1, "R39.PIC", 0x3E92A, 0x13FD),
    (1, "R40.BIH", 0x3FD27, 0x532),
    (1, "R40.PIC", 0x40259, 0xD39),
    (1, "R41.BIH", 0x40F92, 0x284),
    (1, "R41.PIC", 0x41216, 0x707),
    (1, "R41.ANH", 0x4191D, 0x13E),
    (1, "R42.BIH", 0x41A5B, 0x12E),
    (1, "R42.PIC", 0x41B89, 0x96D),
    (1, "R44.BIH", 0x424F6, 0x918),
    (1, "R44.PIC", 0x42E0E, 0x12F3),
    (1, "R44.ANH", 0x44101, 0x3CE),
    (1, "R45.BIH", 0x444CF, 0xD8),
    (1, "R45.PIC", 0x445A7, 0x16AA),
    (1, "R45.ANH", 0x45C51, 0x489),
    (1, "R46.BIH", 0x460DA, 0x7F7),
    (1, "R46.PIC", 0x468D1, 0xAE2),
    (1, "R47.BIH", 0x473B3, 0xAF),
    (1, "R47.PIC", 0x47462, 0x139C),
    (1, "R49.BIH", 0x487FE, 0x2D),
    (1, "R49.PIC", 0x4882B, 0x14B7),
    (1, "R50.BIH", 0x49CE2, 0x5E7),
    (1, "R50.PIC", 0x4A2C9, 0x216D),
    (1, "R50.ANH", 0x4C436, 0x6D4),
    (1, "R51.BIH", 0x4CB0A, 0xBF),
    (1, "R51.PIC", 0x4CBC9, 0xAC3),
    (1, "R52.BIH", 0x4D68C, 0x466),
    (1, "R52.PIC", 0x4DAF2, 0x2151),
    (1, "R52.ANH", 0x4FC43, 0x31B),
    (1, "R53.BIH", 0x4FF5E, 0x510),
    (1, "R53.PIC", 0x5046E, 0x876),
    (1, "R53.ANH", 0x50CE4, 0x74B),
    (1, "R54.BIH", 0x5142F, 0x26),
    (1, "R54.PIC", 0x51455, 0x1396),
    (1, "R55.BIH", 0x527EB, 0x26),
    (1, "R55.PIC", 0x52811, 0x13B1),
    (1, "R56.BIH", 0x53BC2, 0x388),
    (1, "R56.PIC", 0x53F4A, 0x1612),
    (1, "R57.BIH", 0x5555C, 0x209),
    (1, "R57.PIC", 0x55765, 0x15F7),
    (1, "R58.BIH", 0x56D5C, 0xB3),
    (1, "R58.PIC", 0x56E0F, 0x170C),
]

PIC_WIDTH_BYTES = 152
PIC_HEIGHT = 112


# ==========================================================================
# Decoders  (ported from Reuromancer LibNeuroRoutines, MIT - Henadzi Matuts)
# ==========================================================================
class _BitReader:
    """MSB-first bit reader over a bytes buffer, starting at a byte offset."""

    def __init__(self, src, pos):
        self.src = src
        self.pos = pos
        self.mask = 0
        self.cur = 0

    def bits(self, n):
        v = 0
        src = self.src
        for _ in range(n):
            if self.mask == 0:
                self.cur = src[self.pos]
                self.pos += 1
                self.mask = 0x80
            v = (v << 1) | (1 if (self.cur & self.mask) else 0)
            self.mask >>= 1
        return v


def huffman_decompress(src, off):
    """Decompress a length-prefixed Huffman stream beginning at src[off]."""
    sys.setrecursionlimit(1_000_000)
    length = struct.unpack_from("<I", src, off)[0]
    br = _BitReader(src, off + 4)

    def build():
        # 1 -> leaf (next 8 bits = value); 0 -> internal (right then left)
        if br.bits(1):
            return ("L", br.bits(8))
        right = build()
        left = build()
        return ("N", left, right)

    root = build()
    out = bytearray()
    node = root
    while len(out) < length:
        node = node[1] if br.bits(1) else node[2]  # 1 -> left, 0 -> right
        if node[0] == "L":
            out.append(node[1])
            node = root
    return bytes(out)


def decode_rle(src, i, length):
    """Expand `length` output bytes of RLE from src starting at index i.
    Returns (decoded_bytes, next_index)."""
    dst = bytearray()
    while length > 0:
        b = src[i]
        if b > 0x7F:
            cnt = 0x100 - b
            i += 1
            for _ in range(cnt):
                dst.append(src[i])
                i += 1
                length -= 1
        else:
            num = src[i] + 1
            val = src[i + 1]
            i += 2
            dst.extend(bytes([val]) * num)
            length -= num
    return bytes(dst), i


def xor_rows(buf, w, h):
    b = bytearray(buf)
    for i in range(h - 1):
        base0 = i * w
        base1 = base0 + w
        for j in range(w):
            b[base1 + j] ^= b[base0 + j]
    return bytes(b)


def decode_pic(blob, off):
    """Decode a .PIC resource -> (width_bytes, height, pixel_buffer)."""
    huff = huffman_decompress(blob, off + 32)  # PIC data is 32 bytes in
    pix, _ = decode_rle(huff, 0, PIC_WIDTH_BYTES * PIC_HEIGHT)
    pix = xor_rows(pix, PIC_WIDTH_BYTES, PIC_HEIGHT)
    return PIC_WIDTH_BYTES, PIC_HEIGHT, pix


def decode_imh(blob, off):
    """Decode a .IMH resource -> list of sub-images (dx, dy, w_bytes, h, pixels)."""
    huff = huffman_decompress(blob, off + 32)  # IMH data is 32 bytes in
    subs = []
    i = 0
    n = len(huff)
    while i + 8 <= n:
        dx, dy, w, h = struct.unpack_from("<HHHH", huff, i)
        if w == 0 or h == 0 or w > 1024 or h > 1024:
            break
        i += 8
        pix, i = decode_rle(huff, i, w * h)
        pix = xor_rows(pix, w, h)
        subs.append((dx, dy, w, h, pix))
    return subs


# ==========================================================================
# Pure-stdlib PNG writer (RGB).  Pixels are 4bpp: 2 nibbles per source byte.
# ==========================================================================
def write_png_4bpp(path, pix, width_bytes, height):
    if width_bytes == 0 or height == 0:
        return False
    out_w = width_bytes * 2
    raw = bytearray()
    pal = EGA_PALETTE
    for y in range(height):
        raw.append(0)  # filter type 0 (None)
        row = y * width_bytes
        for x in range(width_bytes):
            p = pix[row + x]
            for nib in (p >> 4, p & 0x0F):
                r, g, b = pal[nib]
                raw += bytes((r, g, b))

    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", out_w, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
    with open(path, "wb") as f:
        f.write(png)
    return True


# ==========================================================================
# EXE directory parse (validation / enumeration)
# ==========================================================================
_REC_NAME = re.compile(rb"^[A-Z0-9]{1,10}\.(?:BIH|PIC|ANH|IMH|TXH|BIN|NMC|SAV)\x00*$")


def parse_exe_directory(exe):
    """Scan the EXE for `char name[14]; u32 offset; u32 size;` records.

    The reference projects hard-code the directory rather than parse it, because
    the earliest R1..R9 entries use a legacy in-EXE layout. This scan recovers
    the bulk of the directory (R10.. plus all named resources) and is used to
    cross-check the embedded RESOURCES table, not to drive extraction.
    """
    recs = []
    i = 0
    end = len(exe) - 22
    while i < end:
        name_field = exe[i:i + 14]
        if _REC_NAME.match(name_field):
            name = name_field.split(b"\x00")[0].decode("ascii")
            off, size = struct.unpack_from("<II", exe, i + 14)
            recs.append((name, off, size))
            i += 22
        else:
            i += 1
    return recs


# ==========================================================================
# Text helpers
# ==========================================================================
_PRINTABLE = re.compile(rb"[\x20-\x7e]{4,}")


def extract_strings(blob, minlen=4):
    return [m.group().decode("ascii", "replace") for m in _PRINTABLE.finditer(blob)]


# ==========================================================================
# Main driver
# ==========================================================================
def main():
    here = os.path.dirname(os.path.abspath(__file__))
    d = lambda *p: os.path.normpath(os.path.join(here, *p))

    ap = argparse.ArgumentParser(
        description="Extract Neuromancer (1988) .DAT assets to PNG/JSON.")
    ap.add_argument("--exe", default=d("..", "..", "..", "neuro.exe"),
                    help="path to neuro.exe")
    ap.add_argument("--dat1", default=d("..", "..", "..", "neuro1.dat"),
                    help="path to neuro1.dat")
    ap.add_argument("--dat2", default=d("..", "..", "..", "neuro2.dat"),
                    help="path to neuro2.dat")
    ap.add_argument("--out", default=d("..", "..", "assets"),
                    help="output assets dir (sprites/backgrounds/palettes/text)")
    ap.add_argument("--validate-exe", action="store_true",
                    help="also parse the EXE directory and cross-check it")
    args = ap.parse_args()

    for label, path in (("exe", args.exe), ("dat1", args.dat1), ("dat2", args.dat2)):
        if not os.path.isfile(path):
            ap.error("--%s not found: %s" % (label, path))

    exe = open(args.exe, "rb").read()
    dats = [open(args.dat1, "rb").read(), open(args.dat2, "rb").read()]
    dat_names = [os.path.basename(args.dat1), os.path.basename(args.dat2)]

    out_sprites = os.path.join(args.out, "sprites")
    out_bg = os.path.join(args.out, "backgrounds")
    out_pal = os.path.join(args.out, "palettes")
    out_txt = os.path.join(args.out, "text")
    for p in (out_sprites, out_bg, out_pal, out_txt):
        os.makedirs(p, exist_ok=True)

    # --- palette JSON -----------------------------------------------------
    pal_doc = {
        "name": "neuromancer_ega16",
        "note": "16-colour EGA palette used by the original game's 4bpp images.",
        "colors_rgb": [list(c) for c in EGA_PALETTE],
        "colors_hex": ["#%02X%02X%02X" % c for c in EGA_PALETTE],
    }
    with open(os.path.join(out_pal, "ega16.json"), "w") as f:
        json.dump(pal_doc, f, indent=2)

    # --- directory enumeration -------------------------------------------
    table_counts = {0: 0, 1: 0}
    for fnum, _name, _off, _size in RESOURCES:
        table_counts[fnum] += 1

    print("=" * 70)
    print("Neuromancer .DAT extractor")
    print("=" * 70)
    print("Resource directory (authoritative, ported from Reuromancer):")
    print("  NEURO1.DAT (file 0): %d resources" % table_counts[0])
    print("  NEURO2.DAT (file 1): %d resources" % table_counts[1])
    print("  total              : %d resources" % len(RESOURCES))

    if args.validate_exe:
        exe_recs = parse_exe_directory(exe)
        embedded = {n: (o, s) for _f, n, o, s in RESOURCES}
        matched = sum(1 for n, o, s in exe_recs if embedded.get(n) == (o, s))
        print("EXE directory scan (char[14]+u32 off+u32 size records):")
        print("  records found in EXE  : %d" % len(exe_recs))
        print("  confirming embedded   : %d / %d" % (matched, len(embedded)))
        print("  (R1..R9 use a legacy EXE layout and are not matched by the scan)")

    # --- decode + write ---------------------------------------------------
    ok = fail = skipped = oob = 0
    examples = []
    text_doc = {}

    print("-" * 70)
    for fnum, name, off, size in RESOURCES:
        dat = dats[fnum]
        ext = name.rsplit(".", 1)[-1]

        if off < 0 or off + size > len(dat):
            print("  OOB  %-14s %s off=0x%X size=0x%X exceeds %s"
                  % (name, "f%d" % fnum, off, size, dat_names[fnum]))
            oob += 1
            fail += 1
            continue

        blob = dat  # decoders index absolute offsets within the dat buffer
        try:
            if ext == "PIC":
                wb, h, pix = decode_pic(blob, off)
                path = os.path.join(out_bg, name.replace(".", "_") + ".png")
                write_png_4bpp(path, pix, wb, h)
                ok += 1
                if len(examples) < 8:
                    examples.append("%s -> %dx%d (background)" % (name, wb * 2, h))

            elif ext == "IMH":
                subs = decode_imh(blob, off)
                if not subs:
                    raise ValueError("no sub-images decoded")
                # Stack sub-images vertically into one sheet.
                sheet_wb = max(s[2] for s in subs)
                sheet_h = sum(s[3] for s in subs)
                sheet = bytearray(sheet_wb * sheet_h)
                y = 0
                for _dx, _dy, w, h, pix in subs:
                    for row in range(h):
                        dst = (y + row) * sheet_wb
                        src = row * w
                        sheet[dst:dst + w] = pix[src:src + w]
                    y += h
                path = os.path.join(out_sprites, name.replace(".", "_") + ".png")
                write_png_4bpp(path, bytes(sheet), sheet_wb, sheet_h)
                ok += 1
                if len(examples) < 8:
                    examples.append("%s -> %dx%d (%d sub-images, sprite)"
                                    % (name, sheet_wb * 2, sheet_h, len(subs)))

            elif ext in ("TXH", "BIH"):
                raw = huffman_decompress(blob, off)  # no +32 for these
                strings = extract_strings(raw)
                if strings:
                    text_doc[name] = strings
                ok += 1

            elif ext == "ANH":
                # Animation header: decompresses fine but frame layout references
                # IMH-style sub-images we don't reassemble here. Just validate it
                # decompresses; not rendered.
                huffman_decompress(blob, off)
                skipped += 1

            else:  # BIN / NMC / SAV - not asset data
                skipped += 1

        except Exception as e:  # noqa: BLE001 - report and continue
            print("  FAIL %-14s (%s): %s" % (name, ext, e))
            fail += 1

    if text_doc:
        with open(os.path.join(out_txt, "game_text.json"), "w") as f:
            json.dump(text_doc, f, indent=2)

    # --- summary ----------------------------------------------------------
    print("-" * 70)
    print("Decoded OK : %d   Failed: %d   Skipped(non-image): %d   OOB: %d"
          % (ok, fail, skipped, oob))
    print("Text resources with strings: %d (-> %s)"
          % (len(text_doc), os.path.join(out_txt, "game_text.json")))
    print("Palette: %s" % os.path.join(out_pal, "ega16.json"))
    if examples:
        print("Examples:")
        for ex in examples:
            print("  " + ex)
    print("Output dir: %s" % args.out)
    print("=" * 70)


if __name__ == "__main__":
    main()
