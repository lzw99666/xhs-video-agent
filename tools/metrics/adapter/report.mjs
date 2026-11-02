// Render data/metrics/latest.json into the report.md format expected by xhs-explore
// Usage: node report.mjs <latest.json> <note_id> <out_report.md> [script_path]
// Exit codes: 0 success / 2 note not in this pull / 3 argument or write error
import fs from 'node:fs';
import path from 'node:path';

const [latestPath, noteId, outPath, scriptPath] = process.argv.slice(2);
if (!latestPath || !noteId || !outPath) {
  console.error('[FATAL] usage: node report.mjs <latest.json> <note_id> <out_report.md> [script_path]');
  process.exit(3);
}

let data;
try {
  data = JSON.parse(fs.readFileSync(latestPath, 'utf8'));
} catch (e) {
  console.error('[FATAL] failed to read latest.json: ' + e.message);
  process.exit(3);
}

const note = (data.notes || []).find((n) => n.note_id === noteId);
if (!note) {
  console.error(`[FATAL] note_id=${noteId} not found in latest.json (this pull captured ${(data.notes || []).length} notes)`);
  process.exit(2);
}

const pct = (a, b) => (b ? ((a / b) * 100).toFixed(2) + '%' : 'N/A');
const p1 = (v) => (typeof v === 'number' ? (Math.round(v * 100) / 100).toString() : 'N/A');

const lines = [];
lines.push(`# Xiaohongshu note data: ${note.title || noteId}`);
lines.push('');
lines.push(`- Note ID: ${note.note_id}`);
lines.push(`- Title: ${note.title || ''}`);
lines.push(`- Published at: ${note.post_time || ''}`);
lines.push(`- Type: ${note.type || ''}`);
lines.push(`- Link: https://www.xiaohongshu.com/explore/${note.note_id}`);
lines.push(`- Pulled at: ${data.pulled_at || ''} (UTC)`);
lines.push('');
lines.push('## Data snapshot');
lines.push('');
lines.push(`- Impressions: ${p1(note.impressions)}`);
lines.push(`- Reads: ${p1(note.reads)}`);
lines.push(`- Click-through rate: ${((note.ctr || 0) * 100).toFixed(1)}%`);
lines.push(`- Likes: ${p1(note.likes)}`);
lines.push(`- Favorites: ${p1(note.favorites)}`);
lines.push(`- Comments: ${p1(note.comments)}`);
lines.push(`- Shares: ${p1(note.shares)}`);
lines.push(`- Danmaku: ${p1(note.danmaku)}`);
lines.push(`- Fans gained: ${p1(note.fans_gained)}`);
lines.push(`- Avg watch time: ${p1(note.avg_watch_s)}s`);
lines.push('');
lines.push('## Derived ratios');
lines.push('');
lines.push(`- Likes/reads: ${pct(note.likes, note.reads)}`);
lines.push(`- Favorites/reads: ${pct(note.favorites, note.reads)}`);
lines.push(`- Comments/reads: ${pct(note.comments, note.reads)}`);
lines.push(`- Shares/reads: ${pct(note.shares, note.reads)}`);
lines.push('');
lines.push('> Metric definition: cumulative creator-center values (as of the pull time), not fixed-window values; rates are not comparable across pull times.');
lines.push('> Fields this adapter cannot get: exit_view2s_rate / finish5s_rate / play60s_count (need to open the note detail manually).');
lines.push('');
lines.push('## Raw galaxy fields JSON');
lines.push('');
lines.push('```json');
lines.push(JSON.stringify(note, null, 2));
lines.push('```');

if (scriptPath && fs.existsSync(scriptPath)) {
  lines.push('');
  lines.push('## Original script');
  lines.push('');
  lines.push('```');
  lines.push(fs.readFileSync(scriptPath, 'utf8').trim());
  lines.push('```');
}

try {
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, lines.join('\n') + '\n', 'utf8');
} catch (e) {
  console.error('[FATAL] failed to write report.md: ' + e.message);
  process.exit(3);
}

console.log(`[OK] report.md -> ${outPath}`);
process.exit(0);
