#!/usr/bin/env bash
#
# Local perf-data adapter (Xiaohongshu) — same contract as xhs-explore/run.sh
#
# Difference from upstream xhs-explore: it does not run the Python crawler.py.
# Instead it uses this project's proven tools/metrics/pull.js (Playwright + session.json)
# to scrape the creator center, then renders data/metrics/latest.json into a report.md
# with the same format.
#
# Usage:
#   bash run.sh <note_id> <video_folder> [<script_path>]
#
# Exit codes (same as upstream):
#   0 = success (report.md written)
#   1 = login state expired / login required
#   2 = missing dependency (node not installed)
#   3 = other failure (scrape failed / note not found / write failed)

set -uo pipefail

NOTE_ID="${1:-}"
VIDEO_FOLDER="${2:-}"
SCRIPT_PATH="${3:-}"

if [[ -z "$NOTE_ID" || -z "$VIDEO_FOLDER" ]]; then
  echo "Usage: bash run.sh <note_id> <video_folder> [<script_path>]" >&2
  exit 3
fi

mkdir -p "$VIDEO_FOLDER"
VIDEO_FOLDER="$( cd "$VIDEO_FOLDER" && pwd )"

PROJECT_ROOT="$( cd "$VIDEO_FOLDER" && pwd )"
while [[ "$PROJECT_ROOT" != "/" && ! -f "$PROJECT_ROOT/.cheat-state.json" ]]; do
  PROJECT_ROOT="$( dirname "$PROJECT_ROOT" )"
done
if [[ ! -f "$PROJECT_ROOT/.cheat-state.json" ]]; then
  echo "❌ Could not locate project root: no .cheat-state.json found above $VIDEO_FOLDER" >&2
  exit 3
fi

if ! command -v node >/dev/null 2>&1; then
  echo "❌ node is not installed — tools/metrics requires Node 18+" >&2
  exit 2
fi

LATEST="$PROJECT_ROOT/data/metrics/latest.json"
SESSION="$PROJECT_ROOT/tools/metrics/session.json"

# Freshness: latest.json missing or older than 30h → scrape again (platform limit ≤2/day,
# so freshness naturally rate-limits us)
STALE="$(node -e '
const fs = require("fs");
const p = process.argv[1];
if (!fs.existsSync(p)) { console.log("1"); process.exit(0); }
try {
  const a = JSON.parse(fs.readFileSync(p, "utf8"));
  const h = (Date.now() - Date.parse(a.pulled_at)) / 3600000;
  console.log(h > 30 ? "1" : "0");
} catch (e) { console.log("1"); }
' "$LATEST")"

if [[ "$STALE" == "1" ]]; then
  if [[ ! -f "$SESSION" ]]; then
    echo "❌ tools/metrics/session.json is missing; run node tools/metrics/login.js and scan the QR code first" >&2
    exit 1
  fi
  echo "[local-metrics] latest.json missing or stale, scraping again..."
  ( cd "$PROJECT_ROOT" && node tools/metrics/pull.js )
  rc=$?
  case "$rc" in
    0) ;;
    2|3) echo "❌ Login state expired (pull.js rc=$rc) — rerun node tools/metrics/login.js" >&2; exit 1 ;;
    *)   echo "❌ Scrape failed (pull.js rc=$rc)" >&2; exit 3 ;;
  esac
else
  echo "[local-metrics] Reusing latest.json (within 30h)"
fi

OUT="$VIDEO_FOLDER/report.md"
node "$PROJECT_ROOT/tools/metrics/adapter/report.mjs" "$LATEST" "$NOTE_ID" "$OUT" "$SCRIPT_PATH"
rc=$?
if [[ "$rc" -eq 2 ]]; then
  echo "❌ note_id=$NOTE_ID not found in this scrape (published outside the list window, or wrong note_id)" >&2
  exit 3
elif [[ "$rc" -ne 0 ]]; then
  exit 3
fi

exit 0
