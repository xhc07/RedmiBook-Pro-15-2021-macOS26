#!/usr/bin/env python3
"""Split a concatenated ACPI table dump (e.g. RW-Everything "Save all as bin",
or AcpiTbls.bin) into individual table files.

Usage:  python split_acpi.py <AcpiTbls.bin> [outdir]
"""
import os
import struct
import sys


def pkglen_ok(sig: bytes) -> bool:
    return len(sig) == 4 and all((65 <= c <= 90) or (48 <= c <= 57) for c in sig)


def main() -> None:
    src = sys.argv[1] if len(sys.argv) > 1 else "AcpiTbls.bin"
    out = sys.argv[2] if len(sys.argv) > 2 else "tables"
    data = open(src, "rb").read()
    os.makedirs(out, exist_ok=True)

    off = 0
    idx = 0
    while off + 36 <= len(data):
        sig = data[off:off + 4]
        if pkglen_ok(sig):
            length = struct.unpack_from("<I", data, off + 4)[0]
            if 36 <= length <= len(data) - off:
                oem = data[off + 10:off + 16].decode("latin1").rstrip("\x00 ")
                tbl = data[off + 16:off + 24].decode("latin1").rstrip("\x00 ")
                name = f"{idx:02d}_{sig.decode()}_{tbl.replace(' ', '_') or 'na'}.bin"
                open(os.path.join(out, name), "wb").write(data[off:off + length])
                print(f"{idx:2d} @0x{off:06X} {sig.decode()} len={length:6d} OEM={oem!r} Tbl={tbl!r}")
                idx += 1
                off += length
                continue

        # resync: look for the next plausible ACPI header
        nxt = None
        for j in range(off + 1, len(data) - 36):
            s = data[j:j + 4]
            if not pkglen_ok(s):
                continue
            ln = struct.unpack_from("<I", data, j + 4)[0]
            if 36 <= ln <= 200000 and j + ln <= len(data):
                nxt = j
                break
        if nxt is None:
            break
        off = nxt

    print(f"done: {idx} tables -> {out}")


if __name__ == "__main__":
    main()
