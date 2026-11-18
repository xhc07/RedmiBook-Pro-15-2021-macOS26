#!/usr/bin/env python3
"""Scan ACPI table files for the RedmiBook hotkey plumbing.

Checks for:
  * the RedmiBook keyboard-event GUID 46C93E13-EE9B-4262-8488-563BCA757FEF
  * _WDG / _WED / PNP0C14 / MIFS markers
  * EC query methods (_Qxx) and the argument they pass to WMID.QV20()

Usage:  python scan_acpi.py <file-or-directory> [...]
"""
import os
import re
import sys

GUID = bytes.fromhex("133EC9469BEE62428488563BCA757FEF")  # 46C93E13-EE9B-4262-8488-563BCA757FEF
QV20 = b"QV20"


def pkglen(b, i):
    lead = b[i]
    extra = lead >> 6
    if extra == 0:
        return lead & 0x3F, 1
    val = lead & 0x0F
    for k in range(extra):
        val |= b[i + 1 + k] << (4 + 8 * k)
    return val, 1 + extra


def const(b, i):
    op = b[i]
    if op == 0x00:
        return 0, i + 1
    if op == 0x01:
        return 1, i + 1
    if op == 0x0A:
        return b[i + 1], i + 2
    return None, i


def query_args(b):
    """Return list of (query_name, arg) for _Qxx methods calling ...QV20(n)."""
    out = []
    i = 0
    while i < len(b) - 8:
        if b[i] == 0x14:  # MethodOp
            try:
                ln, nb = pkglen(b, i + 1)
                name = b[i + 1 + nb:i + 5 + nb]
                body_s = i + 1 + nb + 4 + 1
                body_e = i + 1 + ln
                if (len(name) == 4 and body_s < body_e <= len(b)):
                    body = b[body_s:body_e]
                    if QV20 in body and name.startswith(b"_Q"):
                        k = body.find(QV20) + len(QV20)
                        arg, _ = const(body, k)
                        if arg is not None:
                            out.append((name.decode("latin1"), arg))
                    i = body_e
                    continue
            except Exception:
                pass
        i += 1
    return out


def main():
    paths = []
    for a in sys.argv[1:] or ["."]:
        if os.path.isdir(a):
            paths += [os.path.join(a, f) for f in sorted(os.listdir(a)) if f.endswith(".bin")]
        else:
            paths.append(a)

    for p in paths:
        b = open(p, "rb").read()
        hits = []
        if GUID in b:
            hits.append("GUID-46C93E13")
        for m in (b"_WDG", b"_WED", b"PNP0C14", b"MIFS", b"WMID"):
            if m in b:
                hits.append(f"{m.decode()} x{b.count(m)}")
        if hits:
            print(f"=== {os.path.basename(p)} ({len(b)} B)")
            print("    " + ", ".join(hits))
            for q, a in query_args(b):
                print(f"    {q} -> QV20(0x{a:02X})")


if __name__ == "__main__":
    main()
