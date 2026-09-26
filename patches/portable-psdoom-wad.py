#!/usr/bin/env python3
"""Make the psdoom level WADs load against any IWAD, shareware included.

Two problems, two fixes:

1. psdoom1.wad shipped the original Doom texture directory (TEXTURE1/TEXTURE2/
   PNAMES). A PWAD's lumps win over the IWAD's, so loading it against Freedoom
   replaced Freedoom's texture set with Doom's and any texture outside that
   subset died with "R_TextureNumForName: <name> not found". The level only
   uses stock texture names, so those three lumps are simply dropped.

2. With --shareware, E1M1 is also rewritten to use only what the shareware
   doom1.wad contains: it lacks the ASHWALL texture, the FLAT19/FLAT5_8 flats
   and the BFG, plasma gun and cell sprites. Each is swapped for a close
   shareware equivalent (see SUBST_*). The swaps exist in every Doom 1 IWAD,
   so the result still runs on registered/Ultimate Doom and Freedoom.

Usage:  portable-psdoom-wad.py [--shareware] <wad> [more.wad ...]
        portable-psdoom-wad.py --self-check
"""

import struct
import sys

STRIP = {"TEXTURE1", "TEXTURE2", "PNAMES"}
SUBST_TEXTURE = {b"ASHWALL": b"STONE2", b"FLAT19": b"FLAT20", b"FLAT5_8": b"FLAT5_5"}
# thing type: BFG -> rocket box, plasma gun -> bullet box, cell pack -> shell box
SUBST_THING = {2006: 2046, 2004: 2048, 17: 2049}
HEADER = struct.Struct("<4sii")
ENTRY = struct.Struct("<ii8s")


def read_wad(data):
    """Return (signature, [(name, bytes), ...]) in directory order."""
    sig, count, dir_offset = HEADER.unpack_from(data, 0)
    if sig not in (b"IWAD", b"PWAD"):
        raise ValueError(f"not a WAD file (magic {sig!r})")
    lumps = []
    for i in range(count):
        pos, size, raw = ENTRY.unpack_from(data, dir_offset + i * ENTRY.size)
        name = raw.rstrip(b"\0").decode("latin1")
        lumps.append((name, data[pos:pos + size]))
    return sig, lumps


def write_wad(sig, lumps):
    """Rebuild a WAD from (name, bytes) pairs, laying lumps out contiguously."""
    body = bytearray()
    directory = bytearray()
    offset = HEADER.size
    for name, payload in lumps:
        # Zero-length lumps are markers (PP_START/PP_END); keep offset sane.
        directory += ENTRY.pack(offset + len(body), len(payload),
                                name.encode("latin1").ljust(8, b"\0"))
        body += payload
    return (HEADER.pack(sig, len(lumps), offset + len(body))
            + bytes(body) + bytes(directory))


def swap_names(payload, record, fields):
    """Replace 8-byte texture names at `fields` offsets in fixed-size records."""
    out = bytearray(payload)
    for base in range(0, len(out) - record + 1, record):
        for f in fields:
            name = bytes(out[base + f:base + f + 8]).rstrip(b"\0").upper()
            if name in SUBST_TEXTURE:
                out[base + f:base + f + 8] = SUBST_TEXTURE[name].ljust(8, b"\0")
    return bytes(out)


def swap_things(payload):
    out = bytearray(payload)
    for base in range(0, len(out) - 9, 10):  # x, y, angle, type, flags
        kind = struct.unpack_from("<h", out, base + 6)[0]
        if kind in SUBST_THING:
            struct.pack_into("<h", out, base + 6, SUBST_THING[kind])
    return bytes(out)


def make_shareware_safe(name, payload):
    if name == "SIDEDEFS":
        return swap_names(payload, 30, (4, 12, 20))  # upper, lower, middle
    if name == "SECTORS":
        return swap_names(payload, 26, (4, 12))      # floor, ceiling
    if name == "THINGS":
        return swap_things(payload)
    return payload


def convert(lumps, shareware):
    kept = [(n, p) for n, p in lumps if n.upper() not in STRIP]
    if shareware:
        kept = [(n, make_shareware_safe(n.upper(), p)) for n, p in kept]
    return kept


def process(path, shareware):
    with open(path, "rb") as fh:
        data = fh.read()
    sig, lumps = read_wad(data)
    out = write_wad(sig, convert(lumps, shareware))
    if out == data:
        print(f"{path}: already portable")
        return
    with open(path, "wb") as fh:
        fh.write(out)
    print(f"{path}: rewritten ({len(data)} -> {len(out)} bytes)")


def self_check():
    side = struct.pack("<hh8s8s8sh", 0, 0, b"-", b"ASHWALL", b"STONE3", 0)
    sector = struct.pack("<hh8s8shhh", 0, 128, b"FLAT19", b"CEIL5_1", 160, 0, 0)
    things = struct.pack("<hhhhh", 0, 0, 0, 2006, 7) + struct.pack("<hhhhh", 0, 0, 0, 3, 7)
    original = write_wad(b"PWAD", [
        ("E1M1", b""), ("THINGS", things), ("SIDEDEFS", side),
        ("SECTORS", sector), ("TEXTURE1", b"clobber"), ("PNAMES", b"clobber too"),
    ])
    sig, lumps = read_wad(original)
    assert sig == b"PWAD"

    after = dict(read_wad(write_wad(sig, convert(lumps, shareware=False)))[1])
    assert list(after) == ["E1M1", "THINGS", "SIDEDEFS", "SECTORS"]
    assert after["SIDEDEFS"] == side  # untouched without --shareware

    after = dict(read_wad(write_wad(sig, convert(lumps, shareware=True)))[1])
    assert after["SIDEDEFS"][12:20] == b"STONE2\0\0"
    assert after["SIDEDEFS"][20:28] == b"STONE3\0\0"  # non-listed name kept
    assert after["SECTORS"][4:12] == b"FLAT20\0\0"
    assert after["SECTORS"][12:20] == b"CEIL5_1\0"
    assert struct.unpack_from("<h", after["THINGS"], 6)[0] == 2046
    assert struct.unpack_from("<h", after["THINGS"], 16)[0] == 3
    print("self-check passed")


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    if args[0] == "--self-check":
        self_check()
        sys.exit()
    shareware = "--shareware" in args
    for wad in (a for a in args if a != "--shareware"):
        process(wad, shareware)
