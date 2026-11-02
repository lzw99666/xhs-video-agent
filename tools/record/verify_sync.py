"""
Verify audio/video sync of the master.

Idea: extract small grayscale frames from the master at 5fps, compute adjacent-frame
differences, and find the moments of "frame change"; then compare them with the
per-step switch timestamps measured in the page during recording. They should map
one-to-one. If they do not line up overall, the seconds trimmed from the intro were
computed wrong.
"""
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

_default_project = REPO_ROOT / "videos" / "personal-agent-deep-dive"
ROOT = Path(os.environ.get("VIDEO_PROJECT") or (sys.argv[1] if len(sys.argv) > 1 else _default_project)).resolve()

# wide = 16:9 Bilibili version; vertical = 3:4 Xiaohongshu version. Switch with VARIANT=vertical.
VARIANT = os.environ.get("VARIANT", "wide")
if VARIANT == "vertical":
    RAW = ROOT / "raw-vertical"
    FINAL = ROOT / f"{ROOT.name}-vertical.mp4"
else:
    RAW = ROOT / "raw"
    FINAL = ROOT / f"{ROOT.name}.mp4"


def _find_ffmpeg() -> str:
    env = os.environ.get("FFMPEG")
    if env:
        return env
    local = (REPO_ROOT / "tools" / "record" / "node_modules"
             / "@ffmpeg-installer" / "win32-x64" / "ffmpeg.exe")
    if local.exists():
        return str(local)
    found = shutil.which("ffmpeg")
    if found:
        return found
    sys.exit("ffmpeg not found: install ffmpeg or set the FFMPEG environment variable")


FFMPEG = _find_ffmpeg()

FPS = 5
W, H = 64, 36


def main() -> None:
    raw_path = RAW / "frames.raw"
    if not raw_path.exists():
        subprocess.run(
            [FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
             "-i", str(FINAL),
             "-vf", f"fps={FPS},scale={W}:{H}",
             "-f", "rawvideo", "-pix_fmt", "gray", str(raw_path)],
            check=True,
        )

    data = raw_path.read_bytes()
    frame_size = W * H
    n_frames = len(data) // frame_size
    print(f"extracted {n_frames} frames, equivalent to {n_frames / FPS:.1f}s")

    frames = [data[i * frame_size:(i + 1) * frame_size] for i in range(n_frames)]

    def diff(a: bytes, b: bytes) -> float:
        return sum(abs(x - y) for x, y in zip(a, b)) / frame_size

    diffs = [diff(frames[i], frames[i + 1]) for i in range(n_frames - 1)]

    mean = sum(diffs) / len(diffs)
    ranked = sorted(diffs, reverse=True)
    # Use p99 rather than the peak to set the threshold: an occasional whole-frame flip at an
    # encoding seam can reach 18+ in difference; using the peak as the baseline would push the
    # threshold above every real transition.
    p99 = ranked[max(0, min(len(ranked) - 1, int(len(ranked) * 0.01)))]
    # Pick the sensitive setting: too high a threshold filters out useful transitions, and with
    # few samples the conclusion is unstable. Measured across six settings from 0.8 to 2.5, the
    # alignments all land within 0.05s; the low-threshold setting has the most hits.
    thresh = max(mean * 8, p99 * 0.4)
    print(f"frame diff mean {mean:.2f} / p99 {p99:.2f} / peak {ranked[0]:.2f} "
          f"/ threshold {thresh:.2f}")

    # Merge consecutive frames above the threshold into a single transition
    events = []
    i = 0
    while i < len(diffs):
        if diffs[i] > thresh:
            j = i
            while j + 1 < len(diffs) and diffs[j + 1] > thresh * 0.5:
                j += 1
            events.append(((i + j) / 2 + 1) / FPS)
            i = j + 1
        else:
            i += 1

    print(f"\ndetected {len(events)} frame changes")

    marks = json.loads((RAW / "marks.json").read_text(encoding="utf-8"))
    start = marks["start"]
    expected = [0.0] + [(m["t"] - start) / 1000.0 for m in marks["marks"][1:]]

    # Do not "take the nearest transition" for every expected switch point — a single step
    # itself contains multiple frame changes (elements entering one by one), so the nearest one
    # is not necessarily the real step start, producing a bimodal mismatch.
    # Use global cross-correlation instead: scan one overall shift s and count how many expected
    # switch points actually find a transition at E+s; the s with the most hits is the number of
    # seconds the intro trim should be corrected by.
    TOL = 0.4
    exp = expected[1:]

    def hits(s: float) -> int:
        return sum(1 for e in exp if any(abs(x - (e + s)) <= TOL for x in events))

    best_s, best_hits = 0.0, -1
    s = -8.0
    while s <= 8.0:
        h = hits(s)
        if h > best_hits:
            best_s, best_hits = s, h
        s += 0.1

    print(f"\ncross-correlation best shift {best_s:+.2f}s, hits {best_hits}/{len(exp)} switch points")

    # Refine around the best shift: take the mean residual of the hit points
    res = [x - (e + best_s) for e in exp for x in events
           if abs(x - (e + best_s)) <= TOL]
    if not res:
        print("✗ no switch point matched, cannot verify")
        return
    delta = best_s + sum(res) / len(res)
    print(f"refined correction {delta:+.2f}s ({len(res)} residuals used)")

    out = RAW / "sync.json"
    if abs(delta) > 0.25:
        print(f"\n⚠ overall deviation {delta:+.2f}s — the intro trim needs correction,"
              f" written to sync.json; rerunning build_master.py will apply it")
        out.write_text(json.dumps({"offset_delta": delta}, indent=2), "utf-8")
    else:
        print("\n✓ audio/video in sync (deviation within 0.25s)")
        if out.exists():
            out.unlink()


if __name__ == "__main__":
    main()
