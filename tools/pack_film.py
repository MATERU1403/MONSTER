"""Pack a rendered film into the repo so the loader can download it.

    python -I tools/pack_film.py <workspace/BasedHub/monsterboard> <tag> <films/monsterboard>

The film's frames (hd/<tag>_h_*.jpg, ultra/<tag>_l_*.jpg and ultra/<tag>_r_*.jpg) are joined, in
order, into packs of at most PACK_MB each, one size of picture per pack, and its sound and still
are copied as they are. <tag>.json says what is in each pack and how long each frame is, so the
loader can cut them apart again: { tag, files = [...], packs = [ { name, set, bytes, frames =
[ [path, size], ... ] } ] }, every path relative to the film's folder.
"""
import json
import shutil
import sys
from pathlib import Path

PACK_MB = 15

src, tag, dst = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
dst.mkdir(parents=True, exist_ok=True)
for old in dst.glob(f"{tag}_*"):
    old.unlink()

index = {"tag": tag, "files": [], "packs": []}
for name in (f"{tag}_audio.ogg", f"{tag}_still.jpg"):
    shutil.copyfile(src / name, dst / name)
    index["files"].append(name)

for set_name, sides in (("hd", ("h",)), ("ultra", ("l", "r"))):
    frames = []
    for side in sides:
        frames += sorted((src / set_name).glob(f"{tag}_{side}_*.jpg"))
    pack, size, number = [], 0, 0

    def flush():
        global pack, size, number
        if not pack:
            return
        number += 1
        name = f"{tag}_{set_name}_{number}.bin"
        with open(dst / name, "wb") as out:
            for path, _ in pack:
                out.write((src / path).read_bytes())
        index["packs"].append({"name": name, "set": set_name, "bytes": size, "frames": [[p, n] for p, n in pack]})
        pack, size = [], 0

    for frame in frames:
        n = frame.stat().st_size
        if pack and size + n > PACK_MB * 1024 * 1024:
            flush()
        pack.append((f"{set_name}/{frame.name}", n))
        size += n
    flush()

(dst / f"{tag}.json").write_text(json.dumps(index, separators=(",", ":")))
total = sum(p["bytes"] for p in index["packs"])
print(f"{tag}: {len(index['packs'])} packs, {total / 1e6:.1f} MB of frames, "
      + ", ".join(f"{s} {sum(p['bytes'] for p in index['packs'] if p['set'] == s) / 1e6:.1f} MB" for s in ("hd", "ultra")))
