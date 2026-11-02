# -*- coding: utf-8 -*-
"""
小红书「阿囤囤爆款风格」封面通用渲染工具
--------------------------------------------------
工艺：HTML/CSS 按阿囤囤规范排版 1080×1440 → Playwright 无头 Chrome 截图出 PNG。
中文大字全部走 CSS 渲染，不经文生图，杜绝错字。

用法示例：
  python tools\\cover\\cover.py --title "大佬开源压箱底" --subtitle "AI写代码不再翻车" \
      --person <人物图绝对路径> --style 1 --out <输出png绝对路径>

依赖：本机 Chrome + tools/record/node_modules/playwright-core + node.exe
"""
import argparse
import html
import os
import subprocess
import sys
import tempfile
from pathlib import Path

# ---------- 依赖路径：默认用仓库内的 playwright-core，可用环境变量覆盖 ----------
REPO_ROOT = Path(__file__).resolve().parents[2]
PW_CORE = os.environ.get("PW_CORE") or str(
    REPO_ROOT / "tools" / "record" / "node_modules" / "playwright-core"
)
NODE_EXE = os.environ.get("NODE_EXE") or "node"

CANVAS_W, CANVAS_H = 1080, 1440  # 3:4 竖版小红书封面
STROKE_DARK = "#0a0a0a"          # 文字粗黑描边固定色

# ---------- 颜色工具：由 --bg 推导渐变三档 ----------
def _hex_to_rgb(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))

def _rgb_to_hex(r, g, b):
    return "#%02x%02x%02x" % (max(0, min(255, int(r))),
                              max(0, min(255, int(g))),
                              max(0, min(255, int(b))))

def mix(color, target, ratio):
    """color 向 target 混合 ratio 比例，用于生成背景渐变亮/暗档"""
    a, b = _hex_to_rgb(color), _hex_to_rgb(target)
    return _rgb_to_hex(*[a[i] + (b[i] - a[i]) * ratio for i in range(3)])

# ---------- 字号自适应：保证大字不出安全区 ----------
def fit_size(text, base, max_w, letter_spacing, min_size=40):
    """按字数收缩字号：n*(字号+字距) <= max_w"""
    n = max(len(text), 1)
    return max(int(min(base, (max_w - n * letter_spacing) / n)), min_size)

# ---------- 背景代码纹理（纯装饰，必须保持主题中立，禁止出现具体仓库/产品名） ----------
CODE_BG = """<span class="cm">// notes from learning</span>
<span class="kw">def</span> <span class="fn">explain</span>(topic):
    <span class="kw">return</span> simple(topic)

<span class="cm"># 越聊越长，越用越熟</span>
<span class="kw">for</span> day <span class="kw">in</span> <span class="fn">progress</span>:
    <span class="fn">understand</span>(day)

<span class="kw">const</span> <span class="fn">aha</span> = <span class="kw">await</span> <span class="fn">deep_dive</span>()
<span class="kw">if</span> (confused) {
  <span class="fn">start_over</span>()
}"""

def base_css(bg, accent):
    """两种风格共用的画布 / 背景代码纹理 / 暗角样式"""
    bg_hi = mix(bg, "#ffffff", 0.06)
    bg_lo = mix(bg, "#000000", 0.5)
    return f"""
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  html, body {{ width: {CANVAS_W}px; height: {CANVAS_H}px; overflow: hidden; }}
  .cover {{
    position: relative;
    width: {CANVAS_W}px; height: {CANVAS_H}px;
    background: radial-gradient(120% 80% at 50% 0%, {bg_hi} 0%, {bg} 55%, {bg_lo} 100%);
    font-family: "Microsoft YaHei", "PingFang SC", "Noto Sans SC", "Source Han Sans SC", sans-serif;
    overflow: hidden;
  }}
  .code-bg {{
    position: absolute; inset: 0;
    opacity: 0.30; filter: blur(2px);
    color: #3d444d;
    font-family: "Cascadia Code", "Consolas", "SFMono-Regular", monospace;
    font-size: 26px; line-height: 1.55; letter-spacing: 0.5px;
    white-space: pre; user-select: none; pointer-events: none;
    padding: 40px 60px; transform: scale(1.05);
  }}
  .code-bg .kw {{ color: #6e7681; }}
  .code-bg .fn, .code-bg .cm {{ color: #2d333b; }}
  .vignette {{
    position: absolute; inset: 0; pointer-events: none;
    background: radial-gradient(110% 70% at 50% 38%, rgba(13,17,23,0) 40%, rgba(6,8,11,0.85) 100%);
  }}
  .title {{
    display: inline-block;
    font-weight: 900;
    color: {accent};
    -webkit-text-stroke: 14px {STROKE_DARK};
    paint-order: stroke fill;
    letter-spacing: 4px;
    text-shadow: 0 2px 0 rgba(255,255,255,0.55), 3px 4px 0 rgba(0,0,0,0.35);
  }}
  .avatar {{
    border-radius: 50%;
    border: 13px solid {accent};
    box-shadow: 0 0 0 6px {STROKE_DARK}, 0 18px 55px rgba(0,0,0,0.6);
    object-fit: cover;
    background: {bg};
  }}
  .source-bar {{
    position: absolute; left: 0; right: 0; bottom: 0; height: 86px;
    background: linear-gradient(180deg, rgba(13,17,23,0) 0%, rgba(13,17,23,0.9) 100%);
    display: flex; align-items: center; justify-content: center;
    color: #8b949e; font-size: 26px; letter-spacing: 1px; z-index: 6;
  }}
"""

def build_style1(opts):
    """风格 1 · 大字压顶风：主标题压顶，人物圆形居中偏下，可选贴纸"""
    e = html.escape
    accent, bg = opts.accent, opts.bg
    t_fs = fit_size(opts.title, 132, 980, 4)
    sub_html = ""
    if opts.subtitle:
        s_fs = fit_size(opts.subtitle, 56, 980, 3)
        sub_html = (f'<div class="subtitle" style="font-size:{s_fs}px">{e(opts.subtitle)}</div>')
    # 主题贴纸：emoji 装饰（主题中立）默认开；文字卡片必须显式传 --sticker-label 才渲染，
    # 防止上一期的文案残留到下一期（ep03 教训：「技能包·开源·免费」残留）
    stickers = ""
    if opts.stickers:
        stickers = """
    <div class="sticker st-code">&lt;/&gt;</div>
    <div class="sticker st-arrow">➜</div>
    <div class="sticker st-check">✅</div>"""
        if opts.sticker_label:
            card_sub = f'<div class="v">{e(opts.sticker_sub)}</div>' if opts.sticker_sub else ""
            stickers += f"""
    <div class="sticker skill-card">
      <div class="k">{e(opts.sticker_label)}</div>
      {card_sub}
    </div>"""
    caption_html = ""
    if opts.caption:
        caption_html = f'<div class="source-bar">{e(opts.caption)}</div>'
    avatar_html = (
        '<div class="avatar-pedestal"></div>\n'
        f'    <img class="avatar" src="{opts.person_uri}" alt="cover person">'
    ) if opts.has_person else ""
    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head><meta charset="UTF-8"><style>
{base_css(bg, accent)}
  .subtitle {{
    margin-top: 26px; display: inline-block;
    font-weight: 900; color: #ffffff;
    -webkit-text-stroke: 8px {STROKE_DARK};
    paint-order: stroke fill; letter-spacing: 3px;
    text-shadow: 2px 3px 0 rgba(0,0,0,0.45);
  }}
  .title-wrap {{ position: absolute; {('top: 46%; transform: translateY(-50%);' if not opts.has_person else 'top: 70px;')} left: 0; right: 0; text-align: center; z-index: 5; }}
  .avatar {{
    position: absolute; left: 50%; bottom: 182px; transform: translateX(-50%);
    width: 528px; height: 528px; z-index: 4;
  }}
  .avatar-pedestal {{
    position: absolute; left: 50%; bottom: 120px; transform: translateX(-50%);
    width: 820px; height: 260px; z-index: 3;
    background: radial-gradient(60% 100% at 50% 0%, rgba(253,255,167,0.20), rgba(253,255,167,0) 70%);
  }}
  .sticker {{ position: absolute; z-index: 7; font-weight: 900; user-select: none; }}
  .st-code {{
    top: 470px; left: 60px;
    font-family: "Cascadia Code", "Consolas", monospace;
    font-size: 78px; color: {accent};
    -webkit-text-stroke: 6px {STROKE_DARK}; paint-order: stroke fill;
    transform: rotate(-12deg);
  }}
  .st-arrow {{
    top: 300px; right: 70px; font-size: 96px; color: {accent};
    -webkit-text-stroke: 5px {STROKE_DARK}; paint-order: stroke fill;
    transform: rotate(18deg); text-shadow: 2px 3px 0 rgba(0,0,0,0.4);
  }}
  .st-check {{ bottom: 560px; right: 80px; font-size: 84px; filter: drop-shadow(2px 3px 0 rgba(0,0,0,0.5)); }}
  .skill-card {{
    bottom: 700px; left: 52px; width: 260px; padding: 22px 24px;
    background: {accent}; border: 7px solid {STROKE_DARK}; border-radius: 22px;
    color: {STROKE_DARK}; transform: rotate(-7deg); box-shadow: 4px 6px 0 rgba(0,0,0,0.4);
  }}
  .skill-card .k {{ font-size: 30px; font-weight: 900; line-height: 1.15; }}
  .skill-card .v {{ font-size: 22px; font-weight: 700; margin-top: 6px; }}
</style></head>
<body>
  <div class="cover">
    <div class="code-bg">{CODE_BG}</div>
    <div class="vignette"></div>
    <div class="title-wrap">
      <div class="title" style="font-size:{t_fs}px">{e(opts.title)}</div>
      {sub_html}
    </div>
    {stickers}
    {avatar_html}
    {caption_html}
  </div>
</body></html>"""

def build_style4(opts):
    """风格 4 · 教程清单风：标题压顶，左侧绿色 ✅ 竖排清单，人物居右，底部浅黄横幅"""
    e = html.escape
    accent, bg = opts.accent, opts.bg
    t_fs = fit_size(opts.title, 110, 980, 4)
    items_html = "".join(
        f'<div class="item"><span class="ck">✅</span><span class="tx">{e(it)}</span></div>'
        for it in opts.items
    )
    banner_html = ""
    banner_bottom = 0
    if opts.subtitle:
        b_fs = fit_size(opts.subtitle, 52, 900, 3)
        banner_bottom = 86 if opts.caption else 0
        banner_html = f'<div class="banner" style="bottom:{banner_bottom}px;font-size:{b_fs}px">{e(opts.subtitle)}</div>'
    caption_html = ""
    if opts.caption:
        caption_html = f'<div class="source-bar">{e(opts.caption)}</div>'
    avatar_html = (
        f'<img class="avatar" src="{opts.person_uri}" alt="cover person">'
    ) if opts.has_person else ""
    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head><meta charset="UTF-8"><style>
{base_css(bg, accent)}
  .title-wrap {{ position: absolute; top: 64px; left: 0; right: 0; text-align: center; z-index: 5; }}
  .checklist {{
    position: absolute; left: 56px; {('top: 42%; transform: translateY(-50%); width: 900px;' if not opts.has_person else 'top: 330px; width: 500px;')} z-index: 5;
    display: flex; flex-direction: column; gap: 34px;
  }}
  .checklist .item {{ display: flex; align-items: flex-start; gap: 16px; }}
  .checklist .ck {{ font-size: 42px; line-height: 1.2; filter: drop-shadow(2px 3px 0 rgba(0,0,0,0.5)); }}
  .checklist .tx {{
    font-size: 40px; font-weight: 900; color: #ffffff; line-height: 1.25; letter-spacing: 2px;
    -webkit-text-stroke: 5px {STROKE_DARK}; paint-order: stroke fill;
    text-shadow: 2px 3px 0 rgba(0,0,0,0.45);
  }}
  .avatar {{
    position: absolute; right: 50px; top: 430px;
    width: 460px; height: 460px; z-index: 4;
  }}
  .banner {{
    position: absolute; left: 40px; right: 40px;
    background: {accent}; color: {STROKE_DARK};
    font-weight: 900; letter-spacing: 3px; text-align: center;
    padding: 26px 20px; border: 8px solid {STROKE_DARK}; border-radius: 24px;
    box-shadow: 5px 7px 0 rgba(0,0,0,0.45); z-index: 6;
  }}
</style></head>
<body>
  <div class="cover">
    <div class="code-bg">{CODE_BG}</div>
    <div class="vignette"></div>
    <div class="title-wrap">
      <div class="title" style="font-size:{t_fs}px">{e(opts.title)}</div>
    </div>
    <div class="checklist">{items_html}</div>
    {avatar_html}
    {banner_html}
    {caption_html}
  </div>
</body></html>"""

# ---------- Playwright 截图脚本（node + playwright-core） ----------
SHOT_JS = r"""
const { chromium } = require(process.env.PW_PATH);

(async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  const ctx = await browser.newContext({
    viewport: { width: 1080, height: 1440 },
    deviceScaleFactor: 1,
    locale: "zh-CN",
  });
  const page = await ctx.newPage();
  await page.goto(process.argv[2], { waitUntil: "load", timeout: 60000 });
  // 等字体与人物位图全部就绪再截，避免半渲染
  await page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all([...document.images].map(img =>
      img.complete ? Promise.resolve() :
      new Promise((res, rej) => { img.onload = res; img.onerror = rej; })));
  });
  await page.screenshot({ path: process.argv[3], clip: { x: 0, y: 0, width: 1080, height: 1440 } });
  await browser.close();
})().catch(e => { console.error("ERR:", e.message); process.exit(1); });
"""

def fail(msg):
    print(f"[错误] {msg}", file=sys.stderr)
    sys.exit(1)

def main():
    ap = argparse.ArgumentParser(description="阿囤囤风格小红书封面渲染工具（1080×1440 PNG）")
    ap.add_argument("--title", required=True, help="主标题（大字压顶，必填）")
    ap.add_argument("--subtitle", default="", help="副标题（可选）")
    ap.add_argument("--person", default="", help="人物素材图绝对路径（真人照/头像等真实位图，仅圆形裁切+描边）；与 --no-person 二选一")
    ap.add_argument("--no-person", action="store_true", help="无人物版（无合适真人照时渲染纯文字封面，缺口请在交付说明中记录）")
    ap.add_argument("--style", type=int, default=1, help="风格编号：1=大字压顶风，4=教程清单风（默认 1）")
    ap.add_argument("--out", required=True, help="输出 PNG 绝对路径（严格 1080×1440）")
    ap.add_argument("--accent", default="#FDFFA7", help="主色（柔和浅黄），默认 #FDFFA7")
    ap.add_argument("--bg", default="#0d1117", help="背景色（GitHub 暗色），默认 #0d1117")
    ap.add_argument("--items", action="append", default=[], help="风格 4 的绿色勾选清单条目，可重复传")
    ap.add_argument("--caption", default="", help="底部来源标注文字（可选）")
    ap.add_argument("--stickers", action=argparse.BooleanOptionalAction, default=True,
                    help="是否加主题贴纸（仅风格 1 生效，默认开，--no-stickers 关闭）")
    ap.add_argument("--sticker-label", default="", help="风格 1 文字卡片贴纸主文案（不传则不渲染卡片；禁止沿用上一期文案）")
    ap.add_argument("--sticker-sub", default="", help="风格 1 文字卡片贴纸副文案（配合 --sticker-label）")
    opts = ap.parse_args()

    # ---------- 依赖与参数校验 ----------
    if not Path(PW_CORE).exists():
        fail(f"未找到 playwright-core：{PW_CORE}，请确认 tools/record 依赖已安装")
    if not Path(NODE_EXE).exists():
        fail(f"未找到 node.exe：{NODE_EXE}，无法调用 Playwright 截图")
    person = Path(opts.person)
    if opts.no_person:
        if opts.person:
            print("[提示] 已指定 --no-person，忽略 --person。", file=sys.stderr)
        opts.has_person = False
        opts.person_uri = ""
    else:
        if not opts.person:
            fail("--person 与 --no-person 必须二选一")
        if not person.is_absolute():
            fail("--person 必须是绝对路径")
        if not person.exists():
            fail(f"人物素材图不存在：{person}（本工具不生成人脸，请提供真实位图，或用 --no-person）")
        opts.has_person = True
        opts.person_uri = person.resolve().as_uri()
    if opts.style not in (1, 4):
        fail(f"风格 {opts.style} 尚未实现，当前仅支持 1（大字压顶风）和 4（教程清单风）")
    if opts.style == 4 and not opts.items:
        fail("风格 4 需要至少一条 --items 清单条目")
    for name, val in (("accent", opts.accent), ("bg", opts.bg)):
        try:
            _hex_to_rgb(val)
        except Exception:
            fail(f"--{name} 不是合法十六进制颜色：{val}")
    out = Path(opts.out)
    if not out.is_absolute():
        out = out.resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    if not opts.title.strip():
        fail("--title 不能为空")

    html_str = build_style1(opts) if opts.style == 1 else build_style4(opts)

    # ---------- 临时目录渲染 + 截图，用后即删 ----------
    tmpdir = tempfile.mkdtemp(prefix="xhs_cover_")
    html_file = Path(tmpdir) / "cover.html"
    js_file = Path(tmpdir) / "shot.cjs"
    html_file.write_text(html_str, encoding="utf-8")
    js_file.write_text(SHOT_JS, encoding="utf-8")
    env = dict(os.environ)
    env["PW_PATH"] = PW_CORE
    try:
        r = subprocess.run([NODE_EXE, str(js_file), html_file.as_uri(), str(out)],
                           capture_output=True, text=True, env=env, timeout=180)
        if r.returncode != 0:
            fail(f"截图失败（node 退出码 {r.returncode}）：{(r.stderr or r.stdout).strip()[:500]}")
    finally:
        for f in (html_file, js_file):
            try:
                f.unlink()
            except OSError:
                pass
        try:
            os.rmdir(tmpdir)
        except OSError:
            pass

    if not out.exists():
        fail(f"截图流程结束但未生成输出文件：{out}")
    print(f"[完成] 风格 {opts.style} 封面已输出：{out}（1080×1440）")

if __name__ == "__main__":
    main()
