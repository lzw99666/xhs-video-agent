# -*- coding: utf-8 -*-
"""
compress-audit.py — narration script compression audit (semi-automatic)
==============================================
Compare article.md (the long source article) with script.md (the narration script) in
the same directory, and use difflib to find sentences that "exist in article but are
gone (or below the similarity threshold) in script" = deleted sentences, then judge
whether each deleted sentence is a "must-keep item" (classification / transition /
qualification / framework), warning that human review is needed in case compression went too far.

Background: one rework compressed the article from 1007 characters down to a 646-character
script, cutting too much — the framework sentence ("the first kind reads structured data, and inside it splits into two routes"),
transition sentences ("when they spin it is a very plain loop"), and key example sentences were all deleted as
"repeated explanation", breaking the narration's logic. This tool makes such "cut too much" cases visible.

Usage (run from the repo root):
  python tools/pipeline/compress-audit.py --article <article.md> --script <script.md> [--out <report.md>]

Arguments:
  --article  long source article path (.md), required
  --script   narration script path (.md), required
  --out      report output path (.md); default prints to stdout

Exit codes: 0 = OK (including both files empty); 2 = argument/environment error (file missing, etc.).

Zero third-party dependencies (difflib / re / argparse / pathlib).
"""

import argparse
import difflib
import re
import sys
from pathlib import Path

# Deleted-sentence threshold: when the similarity between an article sentence and its best match
# in script is < this value, treat it as "deleted". Short sentences score naturally high
# under difflib, so use 0.6.
SIM_THRESHOLD = 0.6

# ---- Must-keep keyword heuristics (case/full-width agnostic, matched after norm_key) ----
# Keywords are matched against norm_key(), which lowercases and strips ALL whitespace, so
# multi-word English keywords must be written space-free (e.g. "twokinds", not "two kinds").
# Classification sentences: classification / ordinal words
KW_CLASSIFY = ["classify", "classification", "category", "categories",
               "twokinds", "twotypes", "threekinds", "threetypes",
               "tworoutes", "routeone", "routetwo", "splitsinto", "splitsintotwo",
               "subtype", "subcategory", "firstkind", "secondkind",
               "firsttype", "secondtype", "firstroute", "secondroute",
               "kindone", "kindtwo", "typeone", "typetwo",
               "first", "second", "third"]
# Transition sentences: linking words (also includes "question at sentence start")
KW_TRANSITION = ["then", "so", "next", "therefore", "thus", "hence",
                 "however", "but", "whichmeans", "thatmeans", "thatsaid",
                 "inotherwords", "atthispoint", "backto", "backtothe",
                 "lookat", "firstlook", "nowlook", "turnsout", "itturnsout"]
# Qualifiers: limitation / disclaimer words
KW_LIMIT = ["not", "only", "just", "atleast", "atmost", "upto", "nomorethan",
            "maybe", "might", "possibly", "probably", "roughly", "cannot",
            "dont", "doesnt", "isnt", "never"]
# Framework sentences: definition patterns (also requires sentence length ≥ 18)
KW_FRAME = ["iscalled", "isdefinedas", "isknownas", "definedas", "refersto",
            "means", "istheprocessof", "isthepracticeof", "isatypeof",
            "isakindof", "isamethodof", "whatwecall", "thatiswhat"]
FRAME_MIN_LEN = 18

# Sentence-initial question words (used for the "transition" judgment)
# is_question() compares the raw sentence prefix case-sensitively, so the English entries are
# listed in both lowercase and sentence-initial capitalized form.
Q_HEAD = ["what", "What", "why", "Why", "how", "How", "who", "Who",
          "which", "Which", "when", "When", "where", "Where",
          "can", "Can", "could", "Could", "do", "Do", "does", "Does",
          "did", "Did", "is", "Is", "are", "Are", "should", "Should",
          "would", "Would", "have", "Have", "has", "Has"]

# Must-keep type → sort weight (must-keep first, normal last)
TYPE_ORDER = {"classify": 0, "transition": 1, "qualifier": 2, "frame": 3, "normal": 4}


# ---------------------------------------------------------------------------
# Text preprocessing
# ---------------------------------------------------------------------------
def strip_markdown(text):
    """Remove Markdown heading (#…)/quote (>…) lines and rules (--- / *** / ___), keep the body."""
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


# Non-terminal punctuation + an optional terminal punctuation, as one sentence
_SENT_RE = re.compile(r"[^。！？；\n]+[。！？；]?")


def split_sentences(text):
    """Split by Chinese punctuation (。！？；) and newlines, returning raw sentences (including trailing punctuation).

    Discard pseudo-sentences that have "no content characters (pure punctuation / whitespace / BOM)".
    """
    out = []
    for m in _SENT_RE.findall(text):
        s = m.strip()
        if s and norm(s):
            out.append(s)
    return out


def to_halfwidth(s):
    """Full width → half width (including full-width spaces), so matching can ignore case/full-width."""
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
    """Normalization for similarity comparison: full-width to half-width + lowercase + keep only letters, digits and Chinese characters."""
    return re.sub(r"\W+", "", to_halfwidth(s).lower())


def norm_key(s):
    """Normalization for keyword matching: full-width to half-width + lowercase + strip whitespace."""
    return re.sub(r"\s+", "", to_halfwidth(s).lower())


# ---------------------------------------------------------------------------
# Judgment
# ---------------------------------------------------------------------------
def find_deleted(article_sents, script_sents, threshold=SIM_THRESHOLD):
    """Return the list of deleted sentences [(sentence, best similarity), ...] (keeping the original article order)."""
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
    """Whether it is a question (ends with a question mark, or starts with a question word)."""
    t = sent.strip()
    if t.endswith("？") or t.endswith("?"):
        return True
    return any(t.startswith(w) for w in Q_HEAD)


def classify(sent):
    """Determine the must-keep type: classify / transition / qualifier / frame / normal (in this priority order)."""
    key = norm_key(sent)
    if any(k in key for k in KW_CLASSIFY):
        return "classify"
    if any(k in key for k in KW_TRANSITION) or is_question(sent):
        return "transition"
    if any(k in key for k in KW_LIMIT):
        return "qualifier"
    if len(key) >= FRAME_MIN_LEN and any(k in key for k in KW_FRAME):
        return "frame"
    return "normal"


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
def build_report(art_path, scr_path, n_art, n_scr, rows):
    """rows: [(sentence, type, must-keep bool), ...] (already sorted). Returns Markdown text."""
    m = sum(1 for _, _, must in rows if must)
    n = len(rows)

    lines = []
    lines.append("# Compression audit report")
    lines.append("")
    lines.append(f"- article: `{art_path}` ({n_art} sentences)")
    lines.append(f"- script: `{scr_path}` ({n_scr} sentences)")
    lines.append(f"- Similarity threshold: {SIM_THRESHOLD:.2f} (a sentence below this value is treated as deleted)")
    lines.append("")
    lines.append("## Deleted sentences")
    lines.append("")
    lines.append("| # | Deleted sentence | Must-keep type | Must-keep |")
    lines.append("| --- | --- | --- | --- |")
    for i, (sent, typ, must) in enumerate(rows, 1):
        cell = sent.replace("|", "\\|").replace("\n", " ")
        mark = "✅ must-keep" if must else "—"
        lines.append(f"| {i} | {cell} | {typ} | {mark} |")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append(f"{n} sentences deleted, of which {m} are must-keep items ⚠️")
    lines.append("")
    if m > 0:
        lines.append("⚠️ Compression may have deleted framework/transition sentences; human confirmation needed.")
    else:
        lines.append("No must-keep items were deleted ✅")
    lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main flow
# ---------------------------------------------------------------------------
def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="compress-audit.py",
        description="Compare article.md with script.md, list sentences removed by compression and mark must-keep items.",
    )
    parser.add_argument("--article", required=True, help="long source article article.md path")
    parser.add_argument("--script", required=True, help="narration script script.md path")
    parser.add_argument("--out", default=None, help="report output path (default prints to stdout)")
    args = parser.parse_args(argv)

    art_path = Path(args.article)
    scr_path = Path(args.script)

    for path, name in ((art_path, "--article"), (scr_path, "--script")):
        if not path.exists():
            sys.stderr.write(f"[ERROR] the file specified by {name} does not exist: {path}\n")
            return 2
        if path.is_dir():
            sys.stderr.write(f"[ERROR] {name} points to a directory, not a file: {path}\n")
            return 2

    art_text = art_path.read_text(encoding="utf-8-sig", errors="replace")
    scr_text = scr_path.read_text(encoding="utf-8-sig", errors="replace")

    article_sents = split_sentences(strip_markdown(art_text))
    script_sents = split_sentences(strip_markdown(scr_text))

    if not article_sents and not script_sents:
        sys.stdout.write("Both files are empty (or contain only heading/quote lines); nothing to audit, exiting normally.\n")
        return 0

    deleted = find_deleted(article_sents, script_sents)

    rows = []
    for idx, (sent, _ratio) in enumerate(deleted):
        typ = classify(sent)
        must = typ != "normal"
        rows.append((sent, typ, must, idx))
    # Must-keep items first, preserving original article order within each group
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
            sys.stderr.write(f"[ERROR] failed to write report: {out_path} ({e})\n")
            return 2
        sys.stdout.write(f"Report written to: {out_path}\n")
        # Also print the summary line to stdout so a human sees it at a glance
        sys.stdout.write(report.split("## Summary")[-1].strip().splitlines()[0] + "\n")
    else:
        sys.stdout.write(report + "\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
