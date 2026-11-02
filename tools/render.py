"""Render the MONSTER films straight into BasedHub's film format.

    python -I tools/render.py intro     # the launch intro, cut to the attached track
    python -I tools/render.py board     # the Home-tab board film

Frames are composed here (square picture over a blurred copy of itself, graded, with the
wordmark burned in) and piped to one ffmpeg run that writes a preview mp4 plus the hd
(1024x576) and ultra (two 912x1024 tiles, 2 px overlap) JPEG sets, as tools/film.py does.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

import cv2
import numpy as np

HERE = Path(__file__).resolve().parent
BUILD = HERE.parent
CLEAN = BUILD / "clean"
OUT = BUILD / "out"
WS = Path(os.environ["LOCALAPPDATA"]) / "Potassium" / "workspace" / "BasedHub"
ATTACHED = Path.home() / "Downloads" / "v142ffg50001dbdskpvog65ug5p4usrg.mp4"
FONT = WS / "fonts" / "Archivo-ExpandedBlack.ttf"

W, H, SQ = 1820, 1024, 1024
X0 = (W - SQ) // 2
HALF, OVERLAP = 910, 2
TILE = HALF + OVERLAP

SKULL_OFFSET = 0.048          # skull_clean t=0 sits this far into the attached track
BEAT0, BEAT = 6.370, 0.3985   # the drop, and the beat after it (150.56 bpm)


def beat(n):
    return BEAT0 + BEAT * n


FINAL = beat(48)              # the last downbeat before the song stops (25.498)
SONG_END = 25.66              # the song's own end: the TikTok end card's sound starts at 25.70
SKULL_END = 25.70             # the skull edit's last frame, in track time
END = 27.0                    # the fade to black is done by 26.9


def reader(path, size, gray=False):
    proc = subprocess.Popen(["ffmpeg", "-v", "error", "-i", str(path), "-f", "rawvideo", "-pix_fmt", "gray" if gray else "bgr24", "-"],
                            stdout=subprocess.PIPE, bufsize=1 << 26)
    n = size * size * (1 if gray else 3)
    while True:
        buf = proc.stdout.read(n)
        if len(buf) < n:
            break
        yield np.frombuffer(buf, np.uint8).reshape((size, size) if gray else (size, size, 3))


class Forward:
    """Frames of a video read in order; asking for an earlier one returns the latest."""
    def __init__(self, path, size):
        self.it, self.i, self.cur = reader(path, size), -1, None

    def get(self, index):
        while self.i < index:
            nxt = next(self.it, None)
            if nxt is None:
                break
            self.cur, self.i = nxt, self.i + 1
        return self.cur


def lut(fn):
    x = np.arange(256, dtype=np.float32) / 255
    return np.clip(fn(x) * 255 + 0.5, 0, 255).astype(np.uint8)


def smooth(x):
    return x * x * (3 - 2 * x)


# grades: the Salvatore clip stays black and white with a cold-blood cast; the skull edit is
# very dark at source, so its mids are lifted and its colour pulled toward red-black
SAL_L = lut(lambda x: np.clip((x - 0.03) / 0.95, 0, 1) ** 1.08)
SAL_TINT = np.array([0.90, 0.90, 1.0], np.float32)        # B, G, R multipliers
SK_CURVE = lut(lambda x: np.clip(0.5 + (x ** 0.72 - 0.5) * 1.18, 0, 1))
SK_TINT = np.array([0.90, 0.92, 1.04], np.float32)


def grade_sal(gray):
    g = cv2.LUT(gray, SAL_L).astype(np.float32)
    return np.clip(g[..., None] * SAL_TINT, 0, 255).astype(np.uint8)


def grade_skull(bgr):
    x = cv2.LUT(bgr, SK_CURVE).astype(np.float32)
    luma = x @ np.array([0.114, 0.587, 0.299], np.float32)
    x = luma[..., None] + (x - luma[..., None]) * 0.72
    return np.clip(x * SK_TINT, 0, 255).astype(np.uint8)


def square(img, zoom, sharpen):
    """The source cropped by `zoom` about its centre, at SQ x SQ."""
    s = img.shape[0]
    c = s / max(zoom, 1.0)
    a = (s - c) / 2
    crop = img[int(a):int(a + c), int(a):int(a + c)] if zoom > 1.0005 else img
    up = crop.shape[0] < SQ
    out = cv2.resize(crop, (SQ, SQ), interpolation=cv2.INTER_LANCZOS4 if up else cv2.INTER_AREA)
    if sharpen:
        blur = cv2.GaussianBlur(out, (0, 0), 1.3)
        out = cv2.addWeighted(out, 1.55, blur, -0.55, 0)
    return out


_edge = np.ones(SQ, np.float32)
_ramp = 48
_edge[:_ramp] = smooth(np.linspace(0, 1, _ramp))
_edge[-_ramp:] = _edge[:_ramp][::-1]
EDGE = np.tile(_edge, (SQ, 1))[..., None]
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
_r = ((xx - W / 2) / (W * 0.62)) ** 2 + ((yy - H / 2) / (H * 0.70)) ** 2
VIGNETTE = np.clip(1 - 0.55 * _r, 0.25, 1)[..., None].astype(np.float32)


def compose(sq):
    small = cv2.resize(sq, (228, 228), interpolation=cv2.INTER_AREA)[50:178]
    bg = cv2.resize(cv2.GaussianBlur(small, (0, 0), 7), (W, H), interpolation=cv2.INTER_LINEAR).astype(np.float32) * 0.30
    out = bg
    out[:, X0:X0 + SQ] = sq.astype(np.float32) * EDGE + out[:, X0:X0 + SQ] * (1 - EDGE)
    return out * VIGNETTE


def title_art():
    """MONSTER in Archivo Expanded Black, as an alpha mask (rendered by ffmpeg: no PIL here)."""
    path = BUILD / "work" / "title.png"
    font = str(FONT).replace("\\", "/").replace(":", "\\:")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", "color=c=black@0:s=3600x700,format=rgba",
                    "-vf", f"drawtext=fontfile='{font}':text=MONSTER:fontsize=330:fontcolor=white:x=(w-tw)/2:y=(h-th)/2",
                    "-frames:v", "1", str(path)], check=True)
    a = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)[..., 3]
    ys, xs = np.nonzero(a > 8)
    a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return np.pad(a, 120).astype(np.float32) / 255


BONE = np.array([214, 226, 236], np.float32)       # B, G, R
BLOOD = np.array([18, 10, 190], np.float32)


def stamp(out, art, glow, width, alpha, dx=0, dy=0):
    if alpha <= 0.003:
        return
    scale = width / art.shape[1]
    w, h = int(art.shape[1] * scale), int(art.shape[0] * scale)
    a = cv2.resize(art, (w, h), interpolation=cv2.INTER_AREA if scale < 1 else cv2.INTER_LINEAR)
    g = cv2.resize(glow, (w, h), interpolation=cv2.INTER_LINEAR)
    x, y = int(W / 2 - w / 2 + dx), int(H / 2 - h / 2 + dy)
    x0, y0, x1, y1 = max(x, 0), max(y, 0), min(x + w, W), min(y + h, H)
    a, g = a[y0 - y:y1 - y, x0 - x:x1 - x, None] * alpha, g[y0 - y:y1 - y, x0 - x:x1 - x, None] * alpha
    region = out[y0:y1, x0:x1]
    region *= 1 - g * 0.55                                  # a dark bed so the letters read on anything
    region += BLOOD * g * 0.85
    region[:] = region * (1 - a) + BONE * a


# ---------------------------------------------------------------- the intro's cut
def intro_plan():
    sal, cuts = [], []
    # the build: (music in, music out, source in, source out, push from, push to)
    sal += [(0.00, 2.52, 0.17, 2.40, 1.00, 1.06), (2.52, 2.80, 2.40, 2.68, 1.02, 1.05), (2.80, 3.23, 2.70, 2.97, 1.00, 1.04),
            (3.23, 3.705, 3.37, 3.77, 1.00, 1.04), (3.705, 4.18, 2.97, 3.37, 1.00, 1.04), (4.18, 4.38, 9.45, 9.65, 1.04, 1.06),
            (4.38, 5.35, 3.77, 4.53, 1.00, 1.08), (5.35, 5.89, 12.53, 12.93, 1.02, 1.07), (5.89, 6.37, 13.77, 14.13, 1.04, 1.12)]
    # inserts after the drop: (first beat, beats long, source in, source out)
    inserts = [(6, 2, 6.17, 6.97), (10, 2, 9.77, 10.57), (12, 1, 7.80, 8.17), (14, 1, 10.57, 10.97),
               (18, 1, 6.97, 7.37), (22, 1, 8.97, 9.37), (26, 1, 11.33, 11.73), (30, 1, 11.73, 12.13),
               (33, 1, 12.17, 12.50), (35, 1, 12.93, 13.33), (37, 1, 13.33, 13.73), (39, 1, 14.13, 14.53),
               (41, 1, 14.53, 14.93), (43, 1, 14.93, 15.30), (44, 1, 15.30, 15.70), (46, 1, 15.73, 16.13)]
    for first, n, a, b in inserts:
        sal.append((beat(first), beat(first + n), a, b, 1.03, 1.0))
    # The song stops at 25.65 and the TikTok end card's sound starts at 25.70: the film ends on the
    # last downbeat (FINAL) with the wordmark as the song fades out under it.
    flashes = [(2.52, 0.35, 0.12), (4.18, 0.55, 0.15), (4.38, 0.7, 0.2), (BEAT0, 1.0, 0.32), (beat(16), 0.6, 0.25), (FINAL, 1.0, 0.35)]
    flashes += [(beat(first), 0.28, 0.1) for first, *_ in inserts]
    punches = [(BEAT0, 0.14, 0.45), (FINAL, 0.12, 0.5)] + [(beat(4 * k), 0.05, 0.3) for k in range(1, 12)]
    return {"sal": sorted(sal), "flashes": flashes, "punches": punches, "end": END, "fps": 60,
            "titles": [(BEAT0, beat(4), 0.25), (FINAL, 99, 0)], "breath": (6.02, BEAT0), "fadeOut": (26.2, 26.9)}


def render_intro():
    plan = intro_plan()
    fps, end = plan["fps"], plan["end"]
    count = int(round(end * fps))
    sal_frames = list(reader(CLEAN / "damon_clean.mp4", 720, gray=True))
    skull = Forward(CLEAN / "skull_clean.mp4", 1080)
    art = title_art()
    glow = cv2.GaussianBlur(art, (0, 0), 38)
    glow = np.clip(glow * 2.2, 0, 1)
    rng = np.random.default_rng(7)
    # bump the tag on every re-cut: Roblox keeps a registered file by its name for good
    sink = open_sink("monster", "mon3", count, fps, plan_audio=("attached", end))
    for i in range(count):
        t = i / fps
        seg = next((s for s in plan["sal"] if s[0] <= t < s[1]), None)
        punch = 1.0
        for at, amp, dur in plan["punches"]:
            if at <= t < at + dur:
                punch += amp * (1 - smooth((t - at) / dur))
        if seg and t < FINAL:
            m0, m1, s0, s1, z0, z1 = seg
            p = (t - m0) / (m1 - m0)
            src = s0 + p * (s1 - s0)
            gray = sal_frames[min(len(sal_frames) - 1, int(src * 30))]
            sq = square(grade_sal(gray), (z0 + (z1 - z0) * p) * punch, sharpen=True)
        else:
            idx = int(round((min(t, SKULL_END) - SKULL_OFFSET) * 60))
            frame = skull.get(max(idx, 0))
            drift = 1.0 + 0.07 * smooth(min(1, max(0, (t - FINAL) / 2.5)))
            sq = square(grade_skull(frame), punch * drift, sharpen=False)
        out = compose(sq)
        if t > FINAL + 0.35:
            # the picture sinks back under the wordmark while the song fades
            out *= 1 - 0.5 * smooth(min(1, (t - FINAL - 0.35) / 1.2))
        b0, b1 = plan["breath"]
        if b0 <= t < b1:
            out *= 1 - 0.8 * smooth((t - b0) / (b1 - b0))
        for at, amp, dur in plan["flashes"]:
            if at <= t < at + dur:
                f = amp * (1 - (t - at) / dur) ** 2
                out += (255 - out) * f
        for at, until, leave in plan["titles"]:
            if at <= t:
                k = (t - at)
                enter = smooth(min(1, k / 0.18))
                width = 1150 * (1.45 - 0.45 * enter)
                alpha = min(1, k / 0.07)
                if until < 99 and t > until:
                    q = min(1, (t - until) / max(leave, 1e-3))
                    alpha *= 1 - q
                    width *= 1 + 0.08 * q
                shake = max(0, 1 - k / 0.2) * 9
                stamp(out, art, glow, width, alpha, rng.normal() * shake, rng.normal() * shake)
        f0, f1 = plan["fadeOut"]
        if t >= f0:
            out *= 1 - smooth(min(1, (t - f0) / (f1 - f0)))
        sink.stdin.write(np.clip(out, 0, 255).astype(np.uint8).tobytes())
        if i % 120 == 0:
            print(f"  {i}/{count}", flush=True)
    finish(sink, "monster", "mon3", count, fps)


def render_board():
    frames = list(reader(CLEAN / "damon_clean.mp4", 720, gray=True))
    fps, count = 30, len(frames)
    sink = open_sink("monsterboard", "mob1", count, fps, plan_audio=("board", count / fps))
    still = None
    for i, gray in enumerate(frames):
        out = compose(square(grade_sal(gray), 1.0, sharpen=True))
        frame = np.clip(out, 0, 255).astype(np.uint8)
        if i == int(2.5 * fps):
            still = frame
        sink.stdin.write(frame.tobytes())
    cv2.imwrite(str(WS / "monsterboard" / "mob1_still.jpg"), cv2.resize(still, (1024, 576), interpolation=cv2.INTER_AREA), [cv2.IMWRITE_JPEG_QUALITY, 92])
    finish(sink, "monsterboard", "mob1", count, fps)


def open_sink(folder, tag, count, fps, plan_audio):
    film = WS / folder
    for sub in ("hd", "ultra"):
        d = film / sub
        if d.exists():
            for f in d.iterdir():
                f.unlink()
        d.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(exist_ok=True)
    # Picture only here: with the track in the same run, ffmpeg quit silently ~70 s in while
    # frames came at render speed. The sound is made, and joined to the preview, in finish().
    graph = (f"[0:v]split=3[p][h][u];[h]scale=1024:576:flags=lanczos,format=yuvj444p[hd];"
             f"[u]format=yuvj444p,split[ua][ub];[ua]crop={TILE}:{H}:0:0[ul];[ub]crop={TILE}:{H}:{HALF - OVERLAP}:0[ur]")
    jpg = ["-q:v", "2", "-start_number", "0", "-fps_mode", "passthrough"]
    cmd = ["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "bgr24", "-s", f"{W}x{H}", "-r", str(fps), "-i", "-",
           "-filter_complex", graph,
           "-map", "[p]", "-c:v", "libx264", "-preset", "medium", "-crf", "14", "-pix_fmt", "yuv420p", str(OUT / f"{folder}_picture.mp4"),
           "-map", "[hd]", *jpg, str(film / "hd" / f"{tag}_h_%04d.jpg"),
           "-map", "[ul]", *jpg, str(film / "ultra" / f"{tag}_l_%04d.jpg"),
           "-map", "[ur]", *jpg, str(film / "ultra" / f"{tag}_r_%04d.jpg")]
    sink = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    sink.plan_audio = plan_audio
    return sink


def sound(kind, seconds):
    """The film's track: its source file and the filter that cuts it to the picture."""
    if kind == "attached":
        # the track as it is, faded out to its own end; nothing after SONG_END of the file is used,
        # so the TikTok end card's sound never plays
        return ATTACHED, (f"atrim=0:{SONG_END:.4f},asetpts=PTS-STARTPTS,afade=t=out:st={SONG_END - 0.8:.3f}:d=0.8:curve=qsin,"
                          f"apad,atrim=0:{seconds:.4f},aresample=44100")
    return CLEAN / "damon_clean.mp4", f"atrim=0:{seconds:.4f},aresample=44100"


def finish(sink, folder, tag, count, fps):
    sink.stdin.close()
    if sink.wait() != 0:
        raise SystemExit("ffmpeg failed")
    film = WS / folder
    source, afilter = sound(*sink.plan_audio)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(source), "-vn", "-af", afilter, "-c:a", "libvorbis", "-q:a", "8",
                    str(film / f"{tag}_audio.ogg")], check=True)
    picture = OUT / f"{folder}_picture.mp4"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(picture), "-i", str(source), "-filter_complex", f"[1:a]{afilter}[a]",
                    "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart",
                    str(OUT / f"{folder}_preview.mp4")], check=True)
    picture.unlink()
    for sub, per in (("hd", 1), ("ultra", 2)):
        n = len(list((film / sub).iterdir()))
        size = sum(f.stat().st_size for f in (film / sub).iterdir())
        assert n == count * per, f"{sub}: {n} files, expected {count * per}"
        print(f"{folder}/{sub}: {n} files, {size / 1e6:.1f} MB")
    spec = {"version": 1, "fps": fps, "count": count, "duration": round(count / fps, 4), "audio": f"{folder}/{tag}_audio.ogg",
            "sets": {"hd": {"width": 1024, "height": 576, "digits": 4,
                            "tiles": [{"path": f"{folder}/hd/{tag}_h_", "x": 0, "w": 1, "rectX": 0, "rectW": 1024, "texW": 1024}]},
                     "ultra": {"width": W, "height": H, "digits": 4,
                               "tiles": [{"path": f"{folder}/ultra/{tag}_l_", "x": 0, "w": 0.5, "rectX": 0, "rectW": HALF, "texW": TILE},
                                         {"path": f"{folder}/ultra/{tag}_r_", "x": 0.5, "w": 0.5, "rectX": OVERLAP, "rectW": HALF, "texW": TILE}]}}}
    (OUT / f"{folder}.json").write_text(json.dumps(spec, indent=1))
    print("spec ->", OUT / f"{folder}.json")


if __name__ == "__main__":
    {"intro": render_intro, "board": render_board}[sys.argv[1]]()
