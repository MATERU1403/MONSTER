"""One-time: split the baseline MONSTER loader (_monster_rak.lua, 2026-11-09 03:57) into the three parts the build keeps.

  src/00_skin_head.lua     lines 1-543   the skin, BasedHub boot, the film/theme code, the RAGE block
  src/90_desync_legacy.lua lines 545-1334 the Desync / Fake position block (edited in place from here on)
  src/99_tail.lua          lines 1336-end the unload wrapper and the loaded notice

Run:  python -I tools/extract_baseline.py   (refuses to overwrite parts that already exist)
"""
import pathlib, sys

root = pathlib.Path(__file__).resolve().parent.parent
base = (root / "baseline" / "_monster_rak.base.lua").read_bytes().decode("utf-8")
base = base.replace("\r\n", "\n")   # the baseline is CRLF; the parts (and the build) are LF
lines = base.split("\n")
print("baseline lines:", len(lines))

# the cut points are checked against the text so a changed baseline cannot be cut in the wrong place
assert lines[544].startswith("-- ---- Desync and Fake position (Da Hood)"), lines[544]
assert lines[1335].startswith("-- ---- Unload: nothing of MONSTER"), lines[1335]
assert lines[1333] == "end", repr(lines[1333])

parts = {
    "src/00_skin_head.lua": lines[0:544],
    "src/90_desync_legacy.lua": lines[544:1334],
    "src/99_tail.lua": lines[1335:],
}
for name, chunk in parts.items():
    target = root / name
    if target.exists():
        print("exists, kept:", name)
        continue
    target.write_bytes("\n".join(chunk).encode("utf-8"))
    print("wrote", name, len(chunk), "lines")
