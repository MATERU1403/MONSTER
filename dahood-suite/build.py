"""Build the MONSTER Da Hood suite into one file.

  python -I build.py            writes ../_monster_dh.lua and dist/_monster_dh.lua, then runs the compile gate (lune)
  python -I build.py --no-gate  skip the gate

The file is, in order: the skin head (src/00), the suite (pure/*.lua as factories, then src/10..89 inside one `do` block, so its
locals do not count against the main chunk's 200), the Desync block (src/90, edited from the baseline), and the tail (src/99).
"""
import pathlib, subprocess, sys, datetime, hashlib

root = pathlib.Path(__file__).resolve().parent
ws = root.parent

PURE = ["codec", "orbit", "patterns", "estimators", "voidsm", "threat", "targeting", "modes", "physcore", "cfgstore"]


def read(path):
    return path.read_bytes().decode("utf-8").replace("\r\n", "\n")


def build():
    out = []
    head = read(root / "src" / "00_skin_head.lua").rstrip("\n")
    out.append(head)
    out.append("")
    out.append("-- ============================================================================")
    out.append("--  MONSTER Da Hood suite: net, fake position, void, orbit, physrep, ragebot, resolver, defense")
    out.append("--  (built from monster-build/: pure/*.lua are the offline-tested modules, src/*.lua the runtime)")
    out.append("-- ============================================================================")
    out.append("local DH = { F = {} }")
    out.append("do")
    for name in PURE:
        out.append(f"-- >>> pure/{name}.lua")
        out.append(f"DH.F.{name} = (function()")
        out.append(read(root / "pure" / f"{name}.lua").rstrip("\n"))
        out.append("end)()")
    middle = sorted(p for p in (root / "src").glob("*.lua") if p.name[:2] not in ("00", "90", "99"))
    for path in middle:
        out.append(f"-- >>> src/{path.name}")
        # the core keeps its few shared locals (genv, S, K, ZERO ...) for the others; every other module is its own scope
        wrap = not path.name.startswith("10_")
        out.append("do" if wrap else "-- (shared scope)")
        out.append(read(path).rstrip("\n"))
        if wrap:
            out.append("end")
    out.append("end")
    out.append("")
    out.append("-- >>> src/90_desync_legacy.lua")
    out.append(read(root / "src" / "90_desync_legacy.lua").rstrip("\n"))
    out.append("")
    out.append("-- >>> src/99_tail.lua")
    out.append(read(root / "src" / "99_tail.lua").rstrip("\n"))
    out.append("")
    return "\n".join(out)


def main():
    text = build()
    stamp = datetime.datetime.now().strftime("%Y%m%d.%H%M")
    text = text.replace("__DH_BUILD__", stamp)
    (root / "dist").mkdir(exist_ok=True)
    for target in (ws / "_monster_dh.lua", root / "dist" / "_monster_dh.lua"):
        target.write_bytes(text.encode("utf-8"))
    digest = hashlib.sha256(text.encode("utf-8")).hexdigest()[:12]
    print(f"built _monster_dh.lua: {len(text):,} bytes, {text.count(chr(10)) + 1:,} lines, build {stamp}, sha256 {digest}")
    if "--no-gate" not in sys.argv:
        result = subprocess.run(
            [str(pathlib.Path.home() / ".rokit" / "bin" / "lune.exe"), "run", "tools/gate", str(ws / "_monster_dh.lua")],
            cwd=str(root), capture_output=True, text=True, timeout=120)
        print(result.stdout.strip())
        if result.returncode != 0:
            print(result.stderr.strip())
            sys.exit(1)


if __name__ == "__main__":
    main()
