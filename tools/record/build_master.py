"""
把无头录制得到的静音视频 + 79 段口播 mp3 合成成片。

对轨原理
--------
运行时是「音频播完 + 200ms → 推进下一步」，所以浏览器真实跑出来的每步
时长和我们按 mp3 时长推算的值会有几十毫秒级累积误差。录制时页面里记录了
每一步切换的 performance.now() 时刻（marks.json），这里直接用这些真实
时刻把 mp3 摆到时间轴上，而不是靠时长累加。

音频用「解码成 PCM → Python 按偏移写入 → 统一编码」的方式拼，
不依赖 ffmpeg 滤镜的版本差异（本机 ffmpeg 是 2018 年的构建，
`apad=pad_dur` 不可用）。

用法
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

# 视频项目目录：优先 VIDEO_PROJECT，其次命令行第 1 个参数，最后回退到示例项目
_default_project = REPO_ROOT / "videos" / "personal-agent-deep-dive"
ROOT = Path(os.environ.get("VIDEO_PROJECT") or (sys.argv[1] if len(sys.argv) > 1 else _default_project)).resolve()

# wide = 16:9 B站版；vertical = 3:4 小红书版。用 VARIANT=vertical 切换。
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
    sys.exit("找不到 ffmpeg：请安装 ffmpeg 或设置 FFMPEG 环境变量")


FFMPEG = _find_ffmpeg()

SR = 24000          # 解码用原生采样率（无损，PCM 字节率据此算）
SR_OUT = 48000       # 输出采样率：48k，匹配绝大多数播放器/系统的原生输出率
CH = 1              # 单声道
BYTES_PER_SEC = SR * CH * 2  # s16le（仅用于按文件大小算时长）

DUR_RE = re.compile(r"Duration: (\d+):(\d\d):(\d\d\.\d+)")


def probe_duration(path: Path) -> float:
    """@ffmpeg-installer 只带 ffmpeg.exe，没有 ffprobe，所以解析 stderr。"""
    out = subprocess.run(
        [FFMPEG, "-hide_banner", "-i", str(path)],
        capture_output=True, text=True,
    )
    m = DUR_RE.search(out.stderr)
    if not m:
        raise RuntimeError(f"读不出时长: {path}")
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
        print("✗ marks.json 里没有 start（Space 时刻），无法对轨", file=sys.stderr)
        return 1

    n = min(len(marks), len(segs))
    if n != len(segs):
        print(f"⚠ marks {len(marks)} 段 vs 音频 {len(segs)} 段")

    # 每步音频在时间轴上的起点（秒，0 = 按下 Space 那一刻）。
    # 第 0 步的 mark 是打点器启动时记的（早于 Space），强制归零——
    # 它的音频是在 autoStarted 变 true 时才开始播的。
    offsets = [0.0]
    for i in range(1, n):
        offsets.append((marks[i]["t"] - start) / 1000.0)

    print("前 6 步起点(s):", [round(o, 2) for o in offsets[:6]])
    print("末 3 步起点(s):", [round(o, 2) for o in offsets[-3:]])

    # ── 1. 逐段解码为 PCM ──────────────────────────────────────────────
    pcm_dir = RAW / "pcm"
    pcm_dir.mkdir(exist_ok=True)
    durs = []
    for i, s in enumerate(segs[:n]):
        dst = pcm_dir / f"{i:02d}.pcm"
        decode_mp3(AUDIO / s["audio"], dst)
        durs.append(dst.stat().st_size / BYTES_PER_SEC)
    print(f"\n解码 {n} 段，合计 {sum(durs):.1f}s")

    # ── 2. 按实测时刻写入时间轴 ────────────────────────────────────────
    # 关键：偏移必须对齐到「样本」(偶数字节)，不能用 int(秒 * 字节率)——
    # 秒是小数，int 后可能是奇数，导致该段整体错 1 字节、s16le 被字节交换成
    # 高频乱码（就是用户听到的"脉冲式爆破杂音"）。这里先转成样本数再 *2。
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
    print(f"音轨总长 {len(buf)/BYTES_PER_SEC:.1f}s")

    audio_out = RAW / "narration.wav"
    subprocess.run(
        [FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
         "-f", "s16le", "-ar", str(SR), "-ac", str(CH), "-i", str(pcm_path),
         # ── 关键修复：改用无损 PCM，彻底消除「拖条/倍速时的脉冲式爆音」──
         # 之前的 48k AAC 在拖条/变速时仍爆音，根因是「有损解码器状态」而非采样率：
         # 播放器在 seek 或 atempo(变速) 时会重启 AAC 解码器的内部缓冲，
         # 产生一段不连续样本 → 短促连续的高频爆破杂音（撕拉感）。PCM 没有解码器、
         # 没有帧边界、没有 priming 样本，seek 直接定位到样本级，变速也只是把样本
         # 搬快/慢，不会再触发解码器重置 → 爆音根因消失。
         # 24k 源用 SoX 高质量重采样器整数倍上采样到 48k（precision=32 长 FIR）。
         # 48k 下上采样的镜像落在 24–36kHz（不可闻），无需 lowpass，
         # 人声亮度完整保留 → 也不会再"糊"。
         "-af", "aresample=48000:resampler=soxr:precision=32",
         "-c:a", "pcm_s16le", "-ar", "48000", str(audio_out)],
        check=True,
    )
    print(f"✓ 音轨编码完成 {probe_duration(audio_out):.1f}s")

    # ── 3. 对齐视频起点 ────────────────────────────────────────────────
    video = RAW / "video.webm"
    v_total = probe_duration(video)
    meta = json.loads((RAW / "timing.json").read_text(encoding="utf-8"))
    d_after_space = (meta["close_node"] - meta["press_node"]) / 1000.0
    offset = max(0.0, v_total - d_after_space)

    # 理论值会有系统性误差（Playwright 的 webm 时间轴和墙上时间不完全等价），
    # 所以用 verify_sync.py 实测出的画面跳变偏差来修正。
    fix_path = RAW / "sync.json"
    delta = 0.0
    if fix_path.exists():
        delta = json.loads(fix_path.read_text(encoding="utf-8"))["offset_delta"]
    offset = max(0.0, offset + delta)

    print(f"\n视频总长 {v_total:.1f}s ｜ Space 之后 {d_after_space:.1f}s")
    print(f"理论裁切 {v_total - d_after_space:.2f}s ｜ 实测修正 {delta:+.2f}s "
          f"→ 实际裁掉 {offset:.2f}s")

    # ── 4. 合成无损成片（MKV 原生支持 pcm_s16le，根治拖条/变速爆音）──────
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
    print(f"\n✓ 无损成片(本地验证用): {final_pcm}")
    print(f"  时长 {dur/60:.1f} 分钟 ({dur:.0f}s) ｜ "
          f"大小 {final_pcm.stat().st_size/1024/1024:.0f} MB")

    # ── 5. 导出 MP4（供上传小红书；平台会二次转码，
    #        从源头 PCM 重新编码为干净 AAC，避免继承有损解码器爆音）─────────
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
    print(f"✓ 上传版(小红书): {final_mp4}")
    print(f"  时长 {dm/60:.1f} 分钟 ({dm:.0f}s) ｜ "
          f"大小 {final_mp4.stat().st_size/1024/1024:.0f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
