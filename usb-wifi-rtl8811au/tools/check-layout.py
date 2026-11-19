#!/usr/bin/env python3
"""Compare struct layouts (size and member offsets) between two ELF modules' DWARF.

usage: tools/check-layout.py STOCK.ko BUILT.ko
STOCK.ko is the car's own /system/wifi/bcmdhd.ko (it carries debug info); BUILT.ko is an UNSTRIPPED build
(build with EXTRA_LDFLAGS= on the make line: the driver's Makefile passes --strip-debug to the linker,
which leaves almost no struct types to compare, and build-driver.sh's own strip step must be skipped). LLVM_DWARFDUMP names llvm-dwarfdump if it isn't on PATH.
Prints how many named structs/unions both modules define, which of them differ, and why.
"""
import os
import re
import subprocess
import sys

DUMP = os.environ.get("LLVM_DWARFDUMP", "llvm-dwarfdump")
DIE = re.compile(r"^0x[0-9a-f]+:(\s+)DW_TAG_(\w+)")
ATTR = re.compile(r"^\s+DW_AT_(\w+)\s+\((.*)\)\s*$")


def num(text):
    m = re.match(r"(0x[0-9a-f]+|\d+)", text)
    return int(m.group(1), 0) if m else None


def name_of(text):
    m = re.search(r'"(.*)"', text)
    return m.group(1) if m else None


def structs(path):
    out, records = {}, []
    proc = subprocess.Popen([DUMP, "--debug-info", path], stdout=subprocess.PIPE, text=True, errors="replace")
    stack = []  # (depth, kind, record)
    cur = None
    for line in proc.stdout:
        m = DIE.match(line)
        if m:
            depth, tag = len(m.group(1)), m.group(2)
            while stack and stack[-1][0] >= depth:
                stack.pop()
            cur = {"tag": tag, "name": None, "size": None, "off": None, "decl": False, "members": []}
            if tag in ("structure_type", "union_type"):
                records.append(cur)
                stack.append((depth, tag, cur))
            elif tag == "member" and stack and stack[-1][0] == depth - 2:
                stack[-1][2]["members"].append(cur)
                stack.append((depth, tag, cur))
            else:
                stack.append((depth, tag, cur))
            continue
        a = ATTR.match(line)
        if a and cur is not None:
            k, v = a.group(1), a.group(2)
            if k == "name":
                cur["name"] = name_of(v)
            elif k == "byte_size":
                cur["size"] = num(v)
            elif k == "data_member_location":
                e = re.search(r"DW_OP_plus_uconst\s+(0x[0-9a-f]+|\d+)", v)
                cur["off"] = int(e.group(1), 0) if e else num(v)
            elif k == "declaration":
                cur["decl"] = True
    proc.wait()
    for rec in records:
        if rec["name"] and not rec["decl"]:
            out.setdefault((rec["tag"], rec["name"]), rec)
    return out


def shape(rec):
    return (rec["size"], tuple((m["name"], m["off"]) for m in rec["members"] if m["name"]))


def main():
    stock, built = structs(sys.argv[1]), structs(sys.argv[2])
    common = sorted(set(stock) & set(built), key=lambda k: k[1])
    diff = [k for k in common if shape(stock[k]) != shape(built[k])]
    print("structs/unions: stock %d, built %d, in both %d, same layout %d, different %d"
          % (len(stock), len(built), len(common), len(common) - len(diff), len(diff)))
    for k in diff:
        s, b = stock[k], built[k]
        why = []
        if s["size"] != b["size"]:
            why.append("size %s vs %s" % (s["size"], b["size"]))
        sm = {m["name"]: m["off"] for m in s["members"] if m["name"]}
        bm = {m["name"]: m["off"] for m in b["members"] if m["name"]}
        moved = [n for n in sm if n in bm and sm[n] != bm[n]]
        if moved:
            why.append("offsets differ: " + ", ".join(moved[:4]))
        gone = [n for n in sm if n not in bm]
        added = [n for n in bm if n not in sm]
        if gone or added:
            why.append("members: -%s +%s" % (",".join(gone[:3]) or "none", ",".join(added[:3]) or "none"))
        print("  DIFF %s %s: %s" % (k[0].replace("_type", ""), k[1], "; ".join(why)))


main()
