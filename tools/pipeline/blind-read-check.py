# -*- coding: utf-8 -*-
"""
blind-read-check.py — "blind-read restatement" executor
=========================================
Turn section 5 of SCRIPT-STYLE, "Executor · blind-read restatement", into a callable
script: read a script.md and generate a task prompt that can be handed directly to an
[isolated sub-agent]. The lead cannot see structural problems in its own script (the
author's view carries context), so we use a reader with only the viewer's information —
give it script.md and nothing else, not article.md / facts.md / outline.md.

Usage (run from the repo root):
  python tools/pipeline/blind-read-check.py --script <script.md> [--out <path>]

Arguments:
  --script  narration script script.md path (.md), required
  --out     prompt output path (.md); default cache/clarity/<video dir name>/blind-read-prompt.md

Output: writes the generated prompt to disk and echoes the generated path to stdout.
Exit codes: 0 = OK; 2 = argument/environment error (file missing, etc.).

Zero third-party dependencies (argparse / pathlib / sys).
"""

import argparse
import sys
from pathlib import Path

# Section 5 of SCRIPT-STYLE.md, "Executor · blind-read restatement" task prompt template (copy as-is, only replace the path)
PROMPT_TEMPLATE = """\
You are a viewer watching this video for the first time. Read only the narration script below; do not read any other file
(in particular do not look for article.md / facts.md / outline.md). After reading, output only 4 items; do not evaluate and do not edit the script:

1. Classification tree: how many categories does this cover, and how many items under each? Draw it as a tree, copying the quantifiers and numbering verbatim from the original.
2. Terminology list: which English names / technical terms appear throughout? At which beat does each first appear?
   Does that beat immediately follow with a Chinese explanation?
3. Numbered-item checklist: where are the "N things / N items / N kinds" in the text? Did each list all N items?
4. Chapter-by-chapter logic chain: why does each chapter follow the previous one? For a chapter you cannot explain, write "cannot say".

Input file: {script_path} (read only this one; reading {forbidden} is forbidden)
"""


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="blind-read-check.py",
        description="Generate a 'blind-read restatement' task prompt for an isolated sub-agent to restate the structure (script.md only).",
    )
    parser.add_argument("--script", required=True, help="narration script script.md path")
    parser.add_argument(
        "--out",
        default=None,
        help="prompt output path (default cache/clarity/<video dir name>/blind-read-prompt.md)",
    )
    args = parser.parse_args(argv)

    script_path = Path(args.script)
    if not script_path.exists():
        sys.stderr.write(f"[ERROR] the file specified by --script does not exist: {script_path}\n")
        return 2
    if script_path.is_dir():
        sys.stderr.write(f"[ERROR] --script points to a directory, not a file: {script_path}\n")
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
        sys.stderr.write(f"[ERROR] failed to write prompt: {out_path} ({e})\n")
        return 2

    sys.stdout.write(f"blind-read restatement prompt generated: {out_path.resolve()}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
