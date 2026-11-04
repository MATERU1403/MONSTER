"""Clean the Johan edit (the TikTok in clean/home_source.mp4) into clean/johan_clean.mp4.

    python -I tools/clean_johan.py <source.mp4> <animev3.onnx> <out.mp4>

  1. The picture is cut out of the vertical TikTok frame: 576 x 648 at row 188, up to 19.0 s
     (TikTok's end card starts at 19.03 s).
  2. The TikTok mark is painted out of every frame: it sits at the left edge for the first 150
     frames, then at the bottom right. Its shape is read off the clip itself (pixels that stay
     white or TikTok-coloured while the picture under them changes) and filled from around it.
  3. Each different drawing (the clip repeats frames: 216 of 570 are new) is upscaled 4x with
     Real-ESRGAN's anime video model (realesr-animevideov3, made from the ncnn files that come
     with the realesrgan-ncnn-py package, see tools/ncnn2onnx.py) and taken down to 910 x 1024.
  4. It is taken to 60 fps: between two drawings of one shot that follow each other quickly,
     the frames in between are made by optical flow (OpenCV DIS, both ways, each side weighted
     by where it can be seen). A cut, a flash, a held drawing or a move the flow cannot follow
     is not blended: the drawing is held and the next one comes in on time.
"""
import subprocess
import sys
import time

import cv2
import numpy as np
import onnxruntime as ort

SRC, MODEL, OUT = sys.argv[1:4]
FPS_IN, FPS_OUT = 30, 60
END = 19.0                       # s: TikTok's end card starts at 19.03
TOP, H, W = 188, 648, 576        # the picture in the TikTok frame
OUT_W, OUT_H = 910, 1024         # the picture in the film: its own shape, 1024 high
NEW = 1.2                        # mean difference that makes a frame a new drawing
CUT = 28                         # and one that makes it a cut (or a flash)
HELD = 0.15                      # s: a drawing held longer than this is not blended into the next
FLOW_BAD = 2.2                   # px: mean forward-backward disagreement past which flow is not trusted


def read_frames():
    cap = cv2.VideoCapture(SRC)
    frames = []
    while len(frames) < int(END * FPS_IN):
        ok, frame = cap.read()
        if not ok:
            break
        frames.append(frame)
    return frames


def watermark_masks(frames):
    """The TikTok mark's two places, read off the clip: steady and white (or TikTok's cyan and red)."""
    stack = np.array(frames).astype(np.float32)

    def build(a, b, box):
        y0, y1, x0, x1 = box
        seg = stack[a:b, y0:y1, x0:x1]
        mean, std = seg.mean(axis=0), seg.std(axis=0)
        lum, spread = mean.mean(axis=2), std.mean(axis=2)
        sat = mean.max(axis=2) - mean.min(axis=2)
        found = (((lum > 150) & (spread < 30)) | ((sat > 60) & (spread < 30))).astype(np.uint8) * 255
        mask = np.zeros(stack.shape[1:3], np.uint8)
        mask[y0:y1, x0:x1] = found
        return cv2.dilate(mask, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7)))

    return build(0, 150, (420, 640, 0, 120)), build(150, len(frames), (720, 900, 430, 576))


def clean(frames):
    left, right = watermark_masks(frames)
    out = []
    for index, frame in enumerate(frames):
        mask = left if index < 150 else right
        frame = cv2.inpaint(frame, mask, 6, cv2.INPAINT_TELEA)
        out.append(frame[TOP:TOP + H, :W].copy())
    return out


def drawings(pictures):
    """The frames that are new drawings, when each first shows, and whether a cut comes before it."""
    keep = [(0, False)]
    for index in range(1, len(pictures)):
        diff = float(np.abs(pictures[index].astype(np.int16) - pictures[index - 1].astype(np.int16)).mean())
        if diff > NEW:
            keep.append((index, diff > CUT))
    return keep


def upscale(sess, picture):
    x = cv2.cvtColor(picture, cv2.COLOR_BGR2RGB).astype(np.float32).transpose(2, 0, 1)[None] / 255
    y = sess.run(None, {"input": x})[0][0].transpose(1, 2, 0)
    big = cv2.cvtColor((np.clip(y, 0, 1) * 255 + 0.5).astype(np.uint8), cv2.COLOR_RGB2BGR)
    return cv2.resize(big, (OUT_W, OUT_H), interpolation=cv2.INTER_AREA)


def warp(image, flow):
    h, w = flow.shape[:2]
    gx, gy = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    return cv2.remap(image, gx + flow[..., 0], gy + flow[..., 1], cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)


class Pair:
    """Flow both ways between two drawings, worked out at half size and scaled up."""
    dis = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)

    def __init__(self, a, b):
        small = (OUT_W // 2, OUT_H // 2)
        ga = cv2.cvtColor(cv2.resize(a, small, interpolation=cv2.INTER_AREA), cv2.COLOR_BGR2GRAY)
        gb = cv2.cvtColor(cv2.resize(b, small, interpolation=cv2.INTER_AREA), cv2.COLOR_BGR2GRAY)
        f01 = self.dis.calc(ga, gb, None)
        f10 = self.dis.calc(gb, ga, None)
        # how far the two flows disagree (a point sent there and back should come home)
        back = warp(f10, f01)
        err = np.linalg.norm(f01 + back, axis=2)
        self.ok = float(err.mean()) < FLOW_BAD
        self.f01 = cv2.resize(f01, (OUT_W, OUT_H)) * 2
        self.f10 = cv2.resize(f10, (OUT_W, OUT_H)) * 2
        vis = np.clip(1 - cv2.resize(err, (OUT_W, OUT_H)) / 4, 0.05, 1).astype(np.float32)
        self.v0 = cv2.GaussianBlur(vis, (0, 0), 3)[..., None]
        back1 = warp(f01, f10)
        err1 = np.linalg.norm(f10 + back1, axis=2)
        self.v1 = cv2.GaussianBlur(np.clip(1 - cv2.resize(err1, (OUT_W, OUT_H)) / 4, 0.05, 1).astype(np.float32), (0, 0), 3)[..., None]
        self.a, self.b = a.astype(np.float32), b.astype(np.float32)

    def at(self, t):
        # the flow from the moment t back to each side (linear motion between the two drawings)
        ft0 = -(1 - t) * t * self.f01 + t * t * self.f10
        ft1 = (1 - t) * (1 - t) * self.f01 - t * (1 - t) * self.f10
        i0, i1 = warp(self.a, ft0), warp(self.b, ft1)
        w0, w1 = (1 - t) * self.v0, t * self.v1
        return np.clip((w0 * i0 + w1 * i1) / (w0 + w1), 0, 255).astype(np.uint8)


def main():
    began = time.time()
    frames = read_frames()
    pictures = clean(frames)
    keep = drawings(pictures)
    print(f"{len(frames)} frames, {len(keep)} drawings, {sum(1 for _, cut in keep if cut)} cuts", flush=True)

    sess = ort.InferenceSession(MODEL, providers=["CPUExecutionProvider"])
    big = []
    for n, (index, _) in enumerate(keep):
        big.append(upscale(sess, pictures[index]))
        if n % 20 == 0:
            print(f"  upscaled {n}/{len(keep)}  {time.time() - began:.0f}s", flush=True)

    times = [index / FPS_IN for index, _ in keep]
    count = int(round(END * FPS_OUT))
    enc = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "bgr24", "-s", f"{OUT_W}x{OUT_H}", "-r", str(FPS_OUT),
                            "-i", "-", "-c:v", "libx264", "-preset", "slow", "-crf", "14", "-pix_fmt", "yuv420p", OUT], stdin=subprocess.PIPE)
    pairs, blended, held = {}, 0, 0
    for k in range(count):
        t = k / FPS_OUT
        a = max(i for i, at in enumerate(times) if at <= t + 1e-9)
        frame = big[a]
        if a + 1 < len(keep):
            b = a + 1
            gap = times[b] - times[a]
            if not keep[b][1] and gap <= HELD + 1e-9:
                if a not in pairs:
                    pairs = {a: Pair(big[a], big[b])}          # (one pair at a time: they come in order)
                pair = pairs[a]
                w = (t - times[a]) / gap
                if pair.ok and w > 1e-6:
                    frame = pair.at(w)
                    blended += 1
                else:
                    frame = big[b] if (not pair.ok and w >= 0.5) else big[a]
                    held += 1
        enc.stdin.write(np.ascontiguousarray(frame).tobytes())
        if k % 120 == 0:
            print(f"  frame {k}/{count}  {time.time() - began:.0f}s", flush=True)
    enc.stdin.close()
    enc.wait()
    print(f"done: {count} frames at {FPS_OUT} fps, {blended} made by flow, {held} held where flow was not trusted, {time.time() - began:.0f}s")


if __name__ == "__main__":
    main()
