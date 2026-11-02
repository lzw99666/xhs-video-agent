// 把 data/metrics/latest.json 渲染成 xhs-explore 约定的 report.md
// 用法：node report.mjs <latest.json> <note_id> <out_report.md> [script_path]
// 退出码：0 成功 / 2 笔记不在本次抓取列表 / 3 参数或写盘错误
import fs from 'node:fs';
import path from 'node:path';

const [latestPath, noteId, outPath, scriptPath] = process.argv.slice(2);
if (!latestPath || !noteId || !outPath) {
  console.error('[FATAL] 用法：node report.mjs <latest.json> <note_id> <out_report.md> [script_path]');
  process.exit(3);
}

let data;
try {
  data = JSON.parse(fs.readFileSync(latestPath, 'utf8'));
} catch (e) {
  console.error('[FATAL] 读 latest.json 失败: ' + e.message);
  process.exit(3);
}

const note = (data.notes || []).find((n) => n.note_id === noteId);
if (!note) {
  console.error(`[FATAL] latest.json 中找不到 note_id=${noteId}（本次抓到 ${(data.notes || []).length} 条）`);
  process.exit(2);
}

const pct = (a, b) => (b ? ((a / b) * 100).toFixed(2) + '%' : 'N/A');
const p1 = (v) => (typeof v === 'number' ? (Math.round(v * 100) / 100).toString() : 'N/A');

const lines = [];
lines.push(`# 小红书笔记数据：${note.title || noteId}`);
lines.push('');
lines.push(`- 笔记 ID: ${note.note_id}`);
lines.push(`- 标题: ${note.title || ''}`);
lines.push(`- 发布时间: ${note.post_time || ''}`);
lines.push(`- 类型: ${note.type || ''}`);
lines.push(`- 链接: https://www.xiaohongshu.com/explore/${note.note_id}`);
lines.push(`- 抓取时间: ${data.pulled_at || ''}（UTC）`);
lines.push('');
lines.push('## 数据快照');
lines.push('');
lines.push(`- 曝光: ${p1(note.impressions)}`);
lines.push(`- 浏览: ${p1(note.reads)}`);
lines.push(`- 点击率: ${((note.ctr || 0) * 100).toFixed(1)}%`);
lines.push(`- 点赞: ${p1(note.likes)}`);
lines.push(`- 收藏: ${p1(note.favorites)}`);
lines.push(`- 评论: ${p1(note.comments)}`);
lines.push(`- 分享: ${p1(note.shares)}`);
lines.push(`- 弹幕: ${p1(note.danmaku)}`);
lines.push(`- 涨粉: ${p1(note.fans_gained)}`);
lines.push(`- 人均观看: ${p1(note.avg_watch_s)}s`);
lines.push('');
lines.push('## 派生比率');
lines.push('');
lines.push(`- 赞/阅读: ${pct(note.likes, note.reads)}`);
lines.push(`- 藏/阅读: ${pct(note.favorites, note.reads)}`);
lines.push(`- 评/阅读: ${pct(note.comments, note.reads)}`);
lines.push(`- 分/阅读: ${pct(note.shares, note.reads)}`);
lines.push('');
lines.push('> 数据口径：创作者中心累计值（截至抓取时刻），非定点值；跨时点不可比速率。');
lines.push('> 本 adapter 拿不到的字段：exit_view2s_rate / finish5s_rate / play60s_count（需人工点开单篇详情）。');
lines.push('');
lines.push('## galaxy 原始字段 JSON');
lines.push('');
lines.push('```json');
lines.push(JSON.stringify(note, null, 2));
lines.push('```');

if (scriptPath && fs.existsSync(scriptPath)) {
  lines.push('');
  lines.push('## 原始稿子');
  lines.push('');
  lines.push('```');
  lines.push(fs.readFileSync(scriptPath, 'utf8').trim());
  lines.push('```');
}

try {
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, lines.join('\n') + '\n', 'utf8');
} catch (e) {
  console.error('[FATAL] 写 report.md 失败: ' + e.message);
  process.exit(3);
}

console.log(`[OK] report.md -> ${outPath}`);
process.exit(0);
