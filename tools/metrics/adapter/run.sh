#!/usr/bin/env bash
#
# 本地 perf-data adapter（小红书）—— 契约与 xhs-explore/run.sh 一致
#
# 与上游 xhs-explore 的区别：不跑 Python crawler.py，改用本项目已验证的
# tools/metrics/pull.js（Playwright + session.json）抓创作者中心，再把
# data/metrics/latest.json 渲染成同一格式的 report.md。
#
# Usage:
#   bash run.sh <note_id> <video_folder> [<script_path>]
#
# Exit codes（与上游一致）:
#   0 = 成功（report.md 已写入）
#   1 = 登录态失效 / 需要登录
#   2 = 依赖缺失（node 未安装）
#   3 = 其他失败（抓取失败 / 找不到该笔记 / 写盘失败）

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
  echo "❌ 项目根定位失败：从 $VIDEO_FOLDER 向上找不到 .cheat-state.json" >&2
  exit 3
fi

if ! command -v node >/dev/null 2>&1; then
  echo "❌ node 未安装 — tools/metrics 依赖 Node 18+" >&2
  exit 2
fi

LATEST="$PROJECT_ROOT/data/metrics/latest.json"
SESSION="$PROJECT_ROOT/tools/metrics/session.json"

# 新鲜度：latest.json 缺失或超过 30h → 重新抓（全平台 ≤2 次/天，靠新鲜度天然限流）
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
    echo "❌ 缺少 tools/metrics/session.json，请先运行 node tools/metrics/login.js 扫码登录" >&2
    exit 1
  fi
  echo "[local-metrics] latest.json 缺失或过期，重新抓取…"
  ( cd "$PROJECT_ROOT" && node tools/metrics/pull.js )
  rc=$?
  case "$rc" in
    0) ;;
    2|3) echo "❌ 登录态失效（pull.js rc=$rc）——请重跑 node tools/metrics/login.js" >&2; exit 1 ;;
    *)   echo "❌ 抓取失败（pull.js rc=$rc）" >&2; exit 3 ;;
  esac
else
  echo "[local-metrics] 复用 latest.json（30h 内）"
fi

OUT="$VIDEO_FOLDER/report.md"
node "$PROJECT_ROOT/tools/metrics/adapter/report.mjs" "$LATEST" "$NOTE_ID" "$OUT" "$SCRIPT_PATH"
rc=$?
if [[ "$rc" -eq 2 ]]; then
  echo "❌ 本次抓取列表里没有 note_id=$NOTE_ID（发布超过列表窗口，或 note_id 有误）" >&2
  exit 3
elif [[ "$rc" -ne 0 ]]; then
  exit 3
fi

exit 0
