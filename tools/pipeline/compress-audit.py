# -*- coding: utf-8 -*-
"""
compress-audit.py —— 口播稿压缩审计（半自动）
==============================================
对比 article.md（素材长文）与同目录 script.md（口播稿），用 difflib 找出
「article 里有、但 script 里没了（或相似度低于阈值）」的句子 = 被删句，
并对每条被删句判定是否属于「必保项」（分类 / 过渡 / 限定 / 框架），
提醒人工复核是否压缩过头。

背景：一次返工把 article 的 1007 字压到 script 的 646 字，删过头了 ——
框架句（「第一种读结构化数据，里面又分两路」）、过渡句（「它们转起来是个很朴素的
循环」）、关键举例句都被当成「重复解释」删掉，导致口播逻辑断裂。
本工具让这类「删过头」肉眼可见。

用法（在仓库根目录下运行）：
  python tools/pipeline/compress-audit.py --article <article.md> --script <script.md> [--out <report.md>]

参数：
  --article  素材长文路径（.md），必填
  --script   口播稿路径（.md），必填
  --out      报告输出路径（.md）；缺省打印到标准输出

退出码：0 = 正常（含两文件皆空）；2 = 参数/环境错误（文件不存在等）。

零第三方依赖（difflib / re / argparse / pathlib）。
"""

import argparse
import difflib
import re
import sys
from pathlib import Path

# 被删句判定阈值：article 句与 script 中最佳匹配句的相似度 < 该值时，
# 视为「被删」。中文短句在 difflib 下的相似度天然偏高，故取 0.6。
SIM_THRESHOLD = 0.6

# ---- 必保项关键词启发式（大小写/全半角无关，经 norm_key 归一后再匹配）----
# 分类句：分类 / 序号词
KW_CLASSIFY = ["分", "两类", "两种", "三种", "第一", "第二", "第三",
               "里面又", "一路", "二路", "一类", "二类"]
# 过渡句：承接词（另含「句首疑问句」）
KW_TRANSITION = ["转起来", "怎么", "那", "所以", "因此", "也就是说",
                 "接下来", "回到", "先看", "再看", "换句话说", "这时候"]
# 限定语：限定 / 免责词
KW_LIMIT = ["不是", "只有", "一家", "以一个", "至少", "不低于", "不宣称",
            "不一定", "可能", "并非"]
# 框架句：定义句式（另需句长 ≥ 18）
KW_FRAME = ["是", "叫", "就是", "指的是"]
FRAME_MIN_LEN = 18

# 句首疑问词（用于「过渡句」判定）
Q_HEAD = ["哪", "怎么", "为什么", "为何", "如何", "吗", "谁", "什么",
          "几", "多少", "是否", "难道"]

# 必保类型 → 排序权重（必保项在前，普通在最后）
TYPE_ORDER = {"分类": 0, "过渡": 1, "限定": 2, "框架": 3, "普通": 4}


# ---------------------------------------------------------------------------
# 文本预处理
# ---------------------------------------------------------------------------
def strip_markdown(text):
    """去掉 Markdown 标题（#…）/引用（>…）行与分隔线（--- / *** / ___），保留正文。"""
    kept = []
    for line in text.splitlines():
        s = line.strip()
        if not s:
            continue
        if s.startswith("#") or s.startswith(">"):
            continue
        if re.fullmatch(r"[-*_]{3,}", s):
            continue
        kept.append(s)
    return "\n".join(kept)


# 非终止标点 + 可选的一个终止标点，作为一句
_SENT_RE = re.compile(r"[^。！？；\n]+[。！？；]?")


def split_sentences(text):
    """按中文标点（。！？；）与换行切句，返回原始句（含尾标点）列表。

    丢弃「无任何内容字符（纯标点 / 空白 / BOM）」的伪句。
    """
    out = []
    for m in _SENT_RE.findall(text):
        s = m.strip()
        if s and norm(s):
            out.append(s)
    return out


def to_halfwidth(s):
    """全角 → 半角（含全角空格），便于大小写/全半角无关地做匹配。"""
    out = []
    for ch in s:
        o = ord(ch)
        if o == 0x3000:
            out.append(" ")
        elif 0xFF01 <= o <= 0xFF5E:
            out.append(chr(o - 0xFEE0))
        else:
            out.append(ch)
    return "".join(out)


def norm(s):
    """相似度比较用的归一化：全角转半角 + 小写 + 只留字母数字与汉字。"""
    return re.sub(r"\W+", "", to_halfwidth(s).lower())


def norm_key(s):
    """关键词匹配用的归一化：全角转半角 + 小写 + 去空白。"""
    return re.sub(r"\s+", "", to_halfwidth(s).lower())


# ---------------------------------------------------------------------------
# 判定
# ---------------------------------------------------------------------------
def find_deleted(article_sents, script_sents, threshold=SIM_THRESHOLD):
    """返回被删句列表 [(句子, 最佳相似度), ...]（保持 article 原序）。"""
    script_norms = [norm(s) for s in script_sents]
    script_norms = [n for n in script_norms if n]
    deleted = []
    for sent in article_sents:
        target = norm(sent)
        best = 0.0
        for sn in script_norms:
            if target == sn:
                best = 1.0
                break
            ratio = difflib.SequenceMatcher(None, target, sn).ratio()
            if ratio > best:
                best = ratio
                if best == 1.0:
                    break
        if best < threshold:
            deleted.append((sent, best))
    return deleted


def is_question(sent):
    """是否疑问句（以 ？ 结尾，或以疑问词开头）。"""
    t = sent.strip()
    if t.endswith("？") or t.endswith("?"):
        return True
    return any(t.startswith(w) for w in Q_HEAD)


def classify(sent):
    """判定必保类型：分类 / 过渡 / 限定 / 框架 / 普通（按此优先级）。"""
    key = norm_key(sent)
    if any(k in key for k in KW_CLASSIFY):
        return "分类"
    if any(k in key for k in KW_TRANSITION) or is_question(sent):
        return "过渡"
    if any(k in key for k in KW_LIMIT):
        return "限定"
    if len(key) >= FRAME_MIN_LEN and any(k in key for k in KW_FRAME):
        return "框架"
    return "普通"


# ---------------------------------------------------------------------------
# 报告
# ---------------------------------------------------------------------------
def build_report(art_path, scr_path, n_art, n_scr, rows):
    """rows: [(句子, 类型, 是否必保bool), ...]（已排序）。返回 Markdown 文本。"""
    m = sum(1 for _, _, must in rows if must)
    n = len(rows)

    lines = []
    lines.append("# 压缩审计报告")
    lines.append("")
    lines.append(f"- article：`{art_path}`（{n_art} 句）")
    lines.append(f"- script：`{scr_path}`（{n_scr} 句）")
    lines.append(f"- 相似度阈值：{SIM_THRESHOLD:.2f}（低于此值即视为被删句）")
    lines.append("")
    lines.append("## 被删句子")
    lines.append("")
    lines.append("| 序号 | 被删句 | 必保类型 | 是否必保 |")
    lines.append("| --- | --- | --- | --- |")
    for i, (sent, typ, must) in enumerate(rows, 1):
        cell = sent.replace("|", "\\|").replace("\n", " ")
        mark = "✅ 必保" if must else "—"
        lines.append(f"| {i} | {cell} | {typ} | {mark} |")
    lines.append("")
    lines.append("## 汇总")
    lines.append("")
    lines.append(f"共删 {n} 句，其中必保项 {m} 句 ⚠️")
    lines.append("")
    if m > 0:
        lines.append("⚠️ 压缩可能删掉了框架/过渡句，需人工确认。")
    else:
        lines.append("未发现必保项被删 ✅")
    lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="compress-audit.py",
        description="对比 article.md 与 script.md，列出被压缩删掉的句子并标出必保项。",
    )
    parser.add_argument("--article", required=True, help="素材长文 article.md 路径")
    parser.add_argument("--script", required=True, help="口播稿 script.md 路径")
    parser.add_argument("--out", default=None, help="报告输出路径（缺省打印到标准输出）")
    args = parser.parse_args(argv)

    art_path = Path(args.article)
    scr_path = Path(args.script)

    for path, name in ((art_path, "--article"), (scr_path, "--script")):
        if not path.exists():
            sys.stderr.write(f"[错误] {name} 指定的文件不存在：{path}\n")
            return 2
        if path.is_dir():
            sys.stderr.write(f"[错误] {name} 指定的是目录而非文件：{path}\n")
            return 2

    art_text = art_path.read_text(encoding="utf-8-sig", errors="replace")
    scr_text = scr_path.read_text(encoding="utf-8-sig", errors="replace")

    article_sents = split_sentences(strip_markdown(art_text))
    script_sents = split_sentences(strip_markdown(scr_text))

    if not article_sents and not script_sents:
        sys.stdout.write("两个文件均为空（或只有标题/引用行），无可审计内容，正常退出。\n")
        return 0

    deleted = find_deleted(article_sents, script_sents)

    rows = []
    for idx, (sent, _ratio) in enumerate(deleted):
        typ = classify(sent)
        must = typ != "普通"
        rows.append((sent, typ, must, idx))
    # 必保项在前，组内保持 article 原序
    rows.sort(key=lambda r: (TYPE_ORDER[r[1]], r[3]))
    rows = [(s, t, m) for (s, t, m, _i) in rows]

    report = build_report(art_path, scr_path, len(article_sents),
                          len(script_sents), rows)

    if args.out:
        out_path = Path(args.out)
        try:
            out_path.parent.mkdir(parents=True, exist_ok=True)
            out_path.write_text(report, encoding="utf-8")
        except OSError as e:
            sys.stderr.write(f"[错误] 写入报告失败：{out_path}（{e}）\n")
            return 2
        sys.stdout.write(f"报告已写入：{out_path}\n")
        # 汇总行同时打到 stdout，便于人一眼看到
        sys.stdout.write(report.split("## 汇总")[-1].strip().splitlines()[0] + "\n")
    else:
        sys.stdout.write(report + "\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
