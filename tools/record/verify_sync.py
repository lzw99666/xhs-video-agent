"""
校验成片的音画同步。

思路：把成片按 5fps 抽成小灰度帧，算相邻帧差异，找出"画面跳变"的时刻；
再和录制时页面里实测的每步切换时刻对比。两者应该一一对应。
如果整体对不上，说明片头裁掉的秒数算错了。
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

# wide = 16:9 B站版；vertical = 3:4 小红书版。用 VARIANT=vertical 切换。
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
    sys.exit("找不到 ffmpeg：请安装 ffmpeg 或设置 FFMPEG 环境变量")


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
    print(f"抽帧 {n_frames} 张，等效 {n_frames / FPS:.1f}s")

    frames = [data[i * frame_size:(i + 1) * frame_size] for i in range(n_frames)]

    def diff(a: bytes, b: bytes) -> float:
        return sum(abs(x - y) for x, y in zip(a, b)) / frame_size

    diffs = [diff(frames[i], frames[i + 1]) for i in range(n_frames - 1)]

    mean = sum(diffs) / len(diffs)
    ranked = sorted(diffs, reverse=True)
    # 用 p99 而不是峰值来定阈值：编码接缝处偶尔会有一个整帧翻转
    # （差分能到 18+），拿峰值当基准会把阈值顶到所有真实跳变之上。
    p99 = ranked[max(0, min(len(ranked) - 1, int(len(ranked) * 0.01)))]
    # 取灵敏的一档：阈值太高手上有用的跳变会被滤掉，样本少结论就不稳。
    # 实测 0.8~2.5 六档算出的对齐量都在 0.05s 内，低阈值那档命中最多。
    thresh = max(mean * 8, p99 * 0.4)
    print(f"帧间差异 均值 {mean:.2f} / p99 {p99:.2f} / 峰值 {ranked[0]:.2f} "
          f"/ 阈值 {thresh:.2f}")

    # 合并连续超过阈值的帧为一次跳变
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

    print(f"\n检出画面跳变 {len(events)} 次")

    marks = json.loads((RAW / "marks.json").read_text(encoding="utf-8"))
    start = marks["start"]
    expected = [0.0] + [(m["t"] - start) / 1000.0 for m in marks["marks"][1:]]

    # 不能对每个期望切换点「取最近跳变」—— 一步内部本身有多次画面变化
    # （元素逐个入场），最近的那个未必是真正的步起点，结果会呈现双峰误配。
    # 改用全局互相关：扫一个整体平移量 s，数有多少个期望切换点在 E+s 处
    # 真的找到了跳变；命中数最多的 s 就是片头裁切该修的秒数。
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

    print(f"\n互相关最佳平移 {best_s:+.2f}s，命中 {best_hits}/{len(exp)} 个切换点")

    # 在最佳平移附近细化：取命中点的残差均值
    res = [x - (e + best_s) for e in exp for x in events
           if abs(x - (e + best_s)) <= TOL]
    if not res:
        print("✗ 没匹配上任何切换点，无法校验")
        return
    delta = best_s + sum(res) / len(res)
    print(f"细化后修正量 {delta:+.2f}s（参与细化 {len(res)} 个残差）")

    out = RAW / "sync.json"
    if abs(delta) > 0.25:
        print(f"\n⚠ 整体偏差 {delta:+.2f}s —— 片头裁切要修正，"
              f"已写入 sync.json，重跑 build_master.py 会套用")
        out.write_text(json.dumps({"offset_delta": delta}, indent=2), "utf-8")
    else:
        print("\n✓ 音画对齐（偏差在 0.25s 内）")
        if out.exists():
            out.unlink()


if __name__ == "__main__":
    main()
