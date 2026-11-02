# -*- coding: utf-8 -*-
"""
blind-read-check.py —— 「盲读复述」执行器
=========================================
把 SCRIPT-STYLE 第 5 节「执行器 · 盲读复述」落成可调用脚本：读一份 script.md，
生成一段可直接交给【隔离 sub-agent】的派活 prompt。主控自己写稿看不出结构
问题（作者视角自带上下文），所以要假手一个"只有观众信息量"的读者 —— 只给它
script.md，不给 article.md / facts.md / outline.md。

用法（在仓库根目录下运行）：
  python tools/pipeline/blind-read-check.py --script <script.md> [--out <path>]

参数：
  --script  口播稿 script.md 路径（.md），必填
  --out     prompt 输出路径（.md）；缺省写 cache/clarity/<视频目录名>/blind-read-prompt.md

输出：把生成的 prompt 落盘，并回显生成路径到 stdout。
退出码：0 = 正常；2 = 参数/环境错误（文件不存在等）。

零第三方依赖（argparse / pathlib / sys）。
"""

import argparse
import sys
from pathlib import Path

# SCRIPT-STYLE.md 第 5 节「执行器 · 盲读复述」派活 prompt 模板（照抄，仅替换路径）
PROMPT_TEMPLATE = """\
你是一名第一次看这条视频的观众。只读下面这份口播稿，不要读任何其它文件
（尤其不要去找 article.md / facts.md / outline.md）。读完只输出 4 项，不要评价、不要改稿：

1. 分类树：这篇讲了哪几类、每类下有几项？画成一棵树，量词和序号照抄原文。
2. 术语表：全片出现过的英文名 / 专业术语各是哪些？每个第一次出现是在第几拍？
   该拍有没有紧跟中文解释？
3. 编号项清单：文中的"N 件事 / N 条 / N 种"分别在哪？各自把 N 项都列出来了吗？
4. 逐章逻辑链：每一章为什么承接上一章？讲不清的章直接写"说不出"。

输入文件：{script_path}（只读这一个，禁止读取 {forbidden}）
"""


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="blind-read-check.py",
        description="生成「盲读复述」派活 prompt，交给隔离 sub-agent 做结构复述（只给 script.md）。",
    )
    parser.add_argument("--script", required=True, help="口播稿 script.md 路径")
    parser.add_argument(
        "--out",
        default=None,
        help="prompt 输出路径（缺省 cache/clarity/<视频目录名>/blind-read-prompt.md）",
    )
    args = parser.parse_args(argv)

    script_path = Path(args.script)
    if not script_path.exists():
        sys.stderr.write(f"[错误] --script 指定的文件不存在：{script_path}\n")
        return 2
    if script_path.is_dir():
        sys.stderr.write(f"[错误] --script 指定的是目录而非文件：{script_path}\n")
        return 2

    full = script_path.resolve()
    prompt = PROMPT_TEMPLATE.format(
        script_path=full,
        forbidden="article.md / facts.md / outline.md",
    )

    if args.out:
        out_path = Path(args.out)
    else:
        video_dir = full.parent.name
        out_path = Path("cache") / "clarity" / video_dir / "blind-read-prompt.md"

    try:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(prompt, encoding="utf-8")
    except OSError as e:
        sys.stderr.write(f"[错误] 写入 prompt 失败：{out_path}（{e}）\n")
        return 2

    sys.stdout.write(f"盲读复述 prompt 已生成：{out_path.resolve()}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
