"""
Combine the silent video from headless recording with the 79 narration mp3 segments into a master.

Sync principle
--------------
The runtime advances to the next step after "audio finishes + 200ms", so the real
duration of each step in the browser accumulates tens of milliseconds of error
compared with the value computed from mp3 durations. During recording the page logs
the performance.now() timestamp of every step switch (marks.json); here we place the
mp3 files on the timeline using those real timestamps instead of accumulating durations.

Audio is assembled by "decode to PCM → Python writes at offsets → encode once",
so it does not depend on ffmpeg filter version differences (the local ffmpeg is a 2018
build, where `apad=pad_dur` is unavailable).

Usage
----
    python build_master.py
"""
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

# Video project dir: prefer VIDEO_PROJECT, then the 1st CLI argument, finally fall back to the sample project
_default_project = REPO_ROOT / "videos" / "personal-agent-deep-dive"
ROOT = Path(os.environ.get("VIDEO_PROJECT") or (sys.argv[1] if len(sys.argv) > 1 else _default_project)).resolve()

# wide = 16:9 Bilibili version; vertical = 3:4 Xiaohongshu version. Switch with VARIANT=vertical.
VARIANT = os.environ.get("VARIANT", "wide")
if VARIANT == "vertical":
    RAW = ROOT / "raw-vertical"
    PRES = ROOT / "presentation-vertical"
    FINAL = ROOT / f"{ROOT.name}-vertical.mp4"
else:
    RAW = ROOT / "raw"
    PRES = ROOT / "presentation"
    FINAL = ROOT / f"{ROOT.name}.mp4"

AUDIO = PRES / "public" / "audio"


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

SR = 24000          # native sample rate for decoding (lossless; the PCM byte rate is computed from it)
SR_OUT = 48000       # output sample rate: 48k, matching the native output rate of most players/systems
CH = 1              # mono
BYTES_PER_SEC = SR * CH * 2  # s16le (used only to derive duration from file size)

DUR_RE = re.compile(r"Duration: (\d+):(\d\d):(\d\d\.\d+)")


def probe_duration(path: Path) -> float:
    """@ffmpeg-installer ships only ffmpeg.exe, no ffprobe, so parse stderr."""
    out = subprocess.run(
        [FFMPEG, "-hide_banner", "-i", str(path)],
        capture_output=True, text=True,
    )
    m = DUR_RE.search(out.stderr)
    if not m:
        raise RuntimeError(f"cannot read duration: {path}")
    h, mi, s = m.groups()
    return int(h) * 3600 + int(mi) * 60 + float(s)


def decode_mp3(src: Path, dst: Path) -> None:
    subprocess.run(
        [FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
         "-i", str(src),
         "-f", "s16le", "-ar", str(SR), "-ac", str(CH), str(dst)],
        check=True,
    )


def main() -> int:
    marks_doc = json.loads((RAW / "marks.json").read_text(encoding="utf-8"))
    segs = json.loads((PRES / "audio-segments.json").read_text(encoding="utf-8"))

    start = marks_doc["start"]
    marks = marks_doc["marks"]
    if start is None:
        print("✗ marks.json has no start (Space timestamp), cannot sync", file=sys.stderr)
        return 1

    n = min(len(marks), len(segs))
    if n != len(segs):
        print(f"⚠ marks {len(marks)} segments vs audio {len(segs)} segments")

    # Start point of each step's audio on the timeline (seconds, 0 = the moment Space is pressed).
    # Step 0's mark is recorded when the marker starts (before Space), so force it to zero —
    # its audio only starts playing when autoStarted turns true.
    offsets = [0.0]
    for i in range(1, n):
        offsets.append((marks[i]["t"] - start) / 1000.0)

    print("first 6 step starts (s):", [round(o, 2) for o in offsets[:6]])
    print("last 3 step starts (s):", [round(o, 2) for o in offsets[-3:]])

    # ── 1. Decode each segment to PCM ──────────────────────────────────────
    pcm_dir = RAW / "pcm"
    pcm_dir.mkdir(exist_ok=True)
    durs = []
    for i, s in enumerate(segs[:n]):
        dst = pcm_dir / f"{i:02d}.pcm"
        decode_mp3(AUDIO / s["audio"], dst)
        durs.append(dst.stat().st_size / BYTES_PER_SEC)
    print(f"\ndecoded {n} segments, {sum(durs):.1f}s total")

    # ── 2. Write onto the timeline at measured timestamps ──────────────────
    # Key: the offset must be aligned to "samples" (even byte count), not int(seconds * byte rate) —
    # seconds are fractional and int may land on an odd number, which shifts the whole segment by 1
    # byte and byte-swaps s16le into high-frequency garbage (the "pulsing blast noise" the user hears).
    # Here convert to a sample count first, then ×2.
    total = offsets[-1] + durs[-1] + 0.4
    buf = bytearray(int(total * SR) * 2)

    for i in range(n):
        at = int(offsets[i] * SR) * 2
        data = (pcm_dir / f"{i:02d}.pcm").read_bytes()
        end = at + len(data)
        if end > len(buf):
            buf.extend(bytearray(end - len(buf)))
        buf[at:end] = data

    pcm_path = RAW / "narration.pcm"
    pcm_path.write_bytes(buf)
    print(f"audio track total {len(buf)/BYTES_PER_SEC:.1f}s")

    audio_out = RAW / "narration.wav"
    subprocess.run(
        [FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
         "-f", "s16le", "-ar", str(SR), "-ac", str(CH), "-i", str(pcm_path),
         # ── Key fix: switch to lossless PCM to fully eliminate "pulsing pops when scrubbing/speed-changing" ──
         # The previous 48k AAC still popped when scrubbing/speed-changing; the root cause is "lossy decoder state",
         # not the sample rate: when the player seeks or applies atempo (speed change) it restarts the AAC decoder's
         # internal buffer, producing a run of discontinuous samples → short bursts of high-frequency blast noise
         # (a tearing feel). PCM has no decoder, no frame boundaries, no priming samples; seeking lands exactly at
         # the sample level, and speed changes just play samples faster/slower without triggering a decoder reset →
         # the root cause of the pops is gone.
         # The 24k source is upsampled to 48k by an integer factor with SoX's high-quality resampler (precision=32 long FIR).
         # At 48k the upsampling image falls at 24–36kHz (inaudible), so no lowpass is needed, and the
         # narration's brightness is fully preserved → no "muddiness" either.
         "-af", "aresample=48000:resampler=soxr:precision=32",
         "-c:a", "pcm_s16le", "-ar", "48000", str(audio_out)],
        check=True,
    )
    print(f"✓ audio track encoded {probe_duration(audio_out):.1f}s")

    # ── 3. Align the video start point ─────────────────────────────────────
    video = RAW / "video.webm"
    v_total = probe_duration(video)
    meta = json.loads((RAW / "timing.json").read_text(encoding="utf-8"))
    d_after_space = (meta["close_node"] - meta["press_node"]) / 1000.0
    offset = max(0.0, v_total - d_after_space)

    # Theoretical values carry systematic error (Playwright's webm timeline is not fully equivalent to wall-clock time),
    # so correct it with the frame-change offset measured by verify_sync.py.
    fix_path = RAW / "sync.json"
    delta = 0.0
    if fix_path.exists():
        delta = json.loads(fix_path.read_text(encoding="utf-8"))["offset_delta"]
    offset = max(0.0, offset + delta)

    print(f"\nvideo total {v_total:.1f}s ｜ after Space {d_after_space:.1f}s")
    print(f"theoretical trim {v_total - d_after_space:.2f}s ｜ measured correction {delta:+.2f}s "
          f"→ actually trimmed {offset:.2f}s")

    # ── 4. Compose the lossless master (MKV natively supports pcm_s16le, curing scrub/speed-change pops) ──────
    final_pcm = FINAL.with_suffix(".mkv")
    subprocess.run(
        [FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
         "-ss", f"{offset:.3f}", "-i", str(video),
         "-i", str(audio_out),
         "-map", "0:v:0", "-map", "1:a:0",
         "-c:v", "libx264", "-preset", "medium", "-crf", "20",
         "-g", "25", "-keyint_min", "25",
         "-pix_fmt", "yuv420p",
         "-c:a", "copy",
         "-shortest", str(final_pcm)],
        check=True,
    )
    dur = probe_duration(final_pcm)
    print(f"\n✓ lossless master (for local verification): {final_pcm}")
    print(f"  duration {dur/60:.1f} min ({dur:.0f}s) ｜ "
          f"size {final_pcm.stat().st_size/1024/1024:.0f} MB")

    # ── 5. Export MP4 (for uploading to Xiaohongshu; the platform re-transcodes,
    #        re-encoding from the source PCM into clean AAC to avoid inheriting lossy-decoder pops) ─────────
    final_mp4 = FINAL.with_suffix(".mp4")
    subprocess.run(
        [FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
         "-i", str(final_pcm),
         "-map", "0:v:0", "-map", "0:a:0",
         "-c:v", "copy",
         "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
         "-movflags", "+faststart",
         "-shortest", str(final_mp4)],
        check=True,
    )
    dm = probe_duration(final_mp4)
    print(f"✓ upload version (Xiaohongshu): {final_mp4}")
    print(f"  duration {dm/60:.1f} min ({dm:.0f}s) ｜ "
          f"size {final_mp4.stat().st_size/1024/1024:.0f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
