"""One-time: wire the extracted Desync block (src/90) and tail (src/99) to the suite. Every change is an exact-text replacement that must
match exactly once, so a baseline that moved cannot be patched wrongly. Line patches ignore indentation (the inserted lines take the
indentation of the line they replace). A marker on the first line stops a second run; nothing is written unless every patch matched.

  python -I tools/patch_legacy.py
"""
import pathlib, re, sys

root = pathlib.Path(__file__).resolve().parent.parent
MARK = "-- [dh] wired to the suite by tools/patch_legacy.py\n"


def lines_patch(text, old, new, label):
    """Replace whole lines `old` (indentation ignored) with `new` (its first line's tabs are the base; the rest is relative)."""
    old_lines = old.rstrip("\n").split("\n")
    pattern = r"(?m)^([ \t]*)" + r"\n[ \t]*".join(re.escape(l.strip()) for l in old_lines) + r"$"
    found = list(re.finditer(pattern, text))
    if len(found) != 1:
        sys.exit(f"patch '{label}': expected exactly 1 match, found {len(found)}")
    m = found[0]
    indent = m.group(1)
    new_lines = new.rstrip("\n").split("\n")
    base = len(new_lines[0]) - len(new_lines[0].lstrip("\t"))
    out = "\n".join(indent + l[base:] if l.strip() else l for l in new_lines)
    return text[: m.start()] + out + text[m.end():]


def frag(text, old, new, label):
    n = text.count(old)
    if n != 1:
        sys.exit(f"patch '{label}': expected exactly 1 match, found {n}")
    return text.replace(old, new)


def cut(text, start, end, new, label):
    lines = text.split("\n")
    a = [i for i, l in enumerate(lines) if l.startswith(start)]
    b = [i for i, l in enumerate(lines) if l.startswith(end)]
    if len(a) != 1 or len(b) != 1 or b[0] <= a[0]:
        sys.exit(f"cut '{label}': start {len(a)} end {len(b)}")
    return "\n".join(lines[: a[0]] + new.split("\n") + lines[b[0]:])


path = root / "src" / "90_desync_legacy.lua"
text = path.read_bytes().decode("utf-8")
if text.startswith(MARK):
    sys.exit("already patched")

# 1. the packet layer is the suite's net module (same names: on, sent, failed, blocked, available, send, hold, release, stop, needsHeader)
text = cut(text, "\tlocal Rak = { on = false", "\tlocal function rakOn()",
           "\tlocal Rak = DH.Net -- the packet layer is the suite's net module (pure/codec.lua + src/30_net.lua), under the names this loop uses", "rak")
# 2. void and wanted: the suite can ask for them too
text = lines_patch(text, 'local function voiding() return Config.get("monster.fake") == true and Config.get("monster.fakeWhere") == "void" end',
                   "local function voiding() return DH.Void.active() end", "voiding")
text = lines_patch(text, 'local function wanted() return Config.get("monster.desync") == true or Config.get("monster.fake") == true end',
                   'local function wanted()\n'
                   '\tif DH.Fakepos.suspended() then return false end\n'
                   '\treturn Config.get("monster.desync") == true or Config.get("monster.fake") == true or DH.Void.active() or DH.Fakepos.hasForced()\n'
                   'end', "wanted")
# 3. a source of the suite (ragebot, api, defense) outranks the configured mode
text = lines_patch(text, "local function fakeOf(cframe)\n\tif onTarget() then",
                   "local function fakeOf(cframe)\n\tlocal forced = DH.Fakepos.forced(cframe)\n\tif forced then return forced end\n\tif onTarget() then", "forced")
# 4. the new modes (static, follow, jitter, anchor, thunder) before the older chain
text = lines_patch(text, 'if where ~= "freeze" then frozenAt = nil end\nif where == "offset" then',
                   'if where ~= "freeze" then frozenAt = nil end\n'
                   'local suite\n'
                   'if where == "thunder" then\n'
                   '\tlocal target = pick(cframe.Position)\n'
                   '\tlocal theirRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")\n'
                   '\tsuite = DH.Fakepos.compute(where, cframe, DH.Rage.centre() or (theirRoot and theirRoot.Position), rakOn())\n'
                   'else\n'
                   '\tsuite = DH.Fakepos.compute(where, cframe, nil, rakOn())\n'
                   'end\n'
                   'if suite then\n'
                   '\tcentre = suite\n'
                   'elseif where == "offset" then', "modes")
# 5. the void's place: the strafe orbit, the two big constants, or the measured sky / far boxes
text = lines_patch(text, "local spot = Vector3.new(voidRandom:NextNumber(-1000, 1000), voidRandom:NextNumber(600, 1000), voidRandom:NextNumber(-1000, 1000))",
                   'local style = DH.Void.style()\n'
                   'if style == "orbit" or style == "orbit-thunder" then\n'
                   '\tRak.hold(DH.Fakepos.compute("thunder", real, DH.Rage.centre(), true), root, dt)\n'
                   '\treturn\n'
                   'end\n'
                   'local spot = Vector3.new(voidRandom:NextNumber(-1000, 1000), voidRandom:NextNumber(600, 1000), voidRandom:NextNumber(-1000, 1000))', "void sky")
text = lines_patch(text,
                   'if Config.get("monster.voidSpam") or not voidSpot then\n'
                   'voidSpot = Vector3.new(voidRandom:NextNumber(-1.5e9, 1.5e9), voidRandom:NextNumber(4e8, 2e9), voidRandom:NextNumber(-1.5e9, 1.5e9))\n'
                   'end\n'
                   'put, putVoid = CFrame.new(voidSpot), true',
                   'local style = DH.Void.style()\n'
                   'if style == "orbit" or style == "orbit-thunder" then\n'
                   '\tput, putVoid = DH.Fakepos.compute("thunder", real, DH.Rage.centre(), false), true\n'
                   'else\n'
                   '\tif Config.get("monster.voidSpam") or not voidSpot or style == "nan1" or style == "nan2" then\n'
                   '\t\tvoidSpot = DH.Void.spot(style == "sky" and "far" or style)\n'
                   '\tend\n'
                   '\tput, putVoid = CFrame.new(voidSpot), true\n'
                   'end', "void far")
# 6. the suite is told what the server has
text = lines_patch(text, "fake = faced(fake, real)", 'fake = faced(fake, real)\nDH.Fakepos.publish(real, fake, packets and "raknet" or "swap")', "publish")
text = lines_patch(text, "strike.on = false\nRak.release(root and root.CFrame)",
                   "strike.on = false\nRak.release(root and root.CFrame)\nDH.Fakepos.publish(root and root.CFrame, nil)\nDH.Fakepos.onIdle(character)", "idle")
text = lines_patch(text, "real = root.CFrame\n-- Void: after each physics step the body is put far out (a new spot every step unless Spam is off) and put",
                   "real = root.CFrame\nDH.Fakepos.applyVelocity(root)\n-- Void: after each physics step the body is put far out (a new spot every step unless Spam is off) and put", "velocity")
# 7. the tab: the new modes in Where, and the suite's own controls at the end
text = frag(text, '{ "above", "Above" } }, default = "decoy" })', '{ "above", "Above" }, table.unpack(DH.Fakepos.MODES) }, default = "decoy" })', "dropdown")
text = frag(text, 'min = 0, max = 25, step = 1, default = 12, suffix = " st" })\n',
            'min = 0, max = 25, step = 1, default = 12, suffix = " st" })\n\t\t\tDH.UI.extras(page)\n', "extras")
# 8. panic and unload reach this block
text = lines_patch(text, "function Desync.stop()", "DH.desyncStop = function() Desync.stop() end\nfunction Desync.stop()", "desyncStop")

tail = root / "src" / "99_tail.lua"
t = tail.read_bytes().decode("utf-8")
if t.startswith(MARK):
    sys.exit("tail already patched")
t = lines_patch(t, "Desync.stop()", "DH.stop()", "unload")
t = frag(t, '" caught=" .. tostring(caught))', '" caught=" .. tostring(caught) .. " dh=" .. DH.build .. (DH.skipped and (" (" .. DH.skipped .. ")") or ""))', "notice")

path.write_bytes((MARK + text).encode("utf-8"))
tail.write_bytes((MARK + t).encode("utf-8"))
print("patched src/90_desync_legacy.lua and src/99_tail.lua")
