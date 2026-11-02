// Scrape Xiaohongshu creator-center data (account overview + all notes summary) and save it as workflow-ready JSON.
// Usage: node pull.js
// Requires: tools/metrics/session.json (run node login.js once to log in by QR code)
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright-core');

const CHROME =
  process.env.CHROME_PATH ||
  'C:/Program Files/Google/Chrome/Application/chrome.exe';
const SESSION = path.join(__dirname, 'session.json');
const OUTDIR = path.resolve(__dirname, '../../data/metrics');
fs.mkdirSync(OUTDIR, { recursive: true });

const HOME = 'https://creator.xiaohongshu.com/new/home';
const ANALYSIS = 'https://creator.xiaohongshu.com/statistics/data-analysis';

const cap = { list: null, account: null };
const n = (v) => (typeof v === 'number' ? v : 0);
const iso = (ms) => (ms ? new Date(ms).toISOString() : null);
const day = (ms) => (ms ? new Date(ms).toISOString().slice(0, 10) : null);

function pickAccount(s) {
  if (!s) return null;
  const series = (arr) => (arr || []).map((x) => ({ date: day(x.date), count: x.count }));
  return {
    period: [iso(s.begin_time), iso(s.end_time)],
    impressions: n(s.impl_count),
    reads: n(s.view_count),
    ctr: n(s.cover_click_rate), // decimal, e.g. 0.054 = 5.4%
    full_view_rate: n(s.video_full_view_rate),
    likes: n(s.like_count),
    comments: n(s.comment_count),
    favorites: n(s.collect_count),
    shares: n(s.share_count),
    danmaku: n(s.danmaku_count),
    fans_gained: n(s.rise_fans_count),
    fans_lost: n(s.loss_fans_count),
    net_fans: n(s.net_rise_fans_count),
    home_visitors: n(s.home_view_count),
    avg_watch_s: n(s.avg_view_time),
    daily_impressions: series(s.impl_count_list),
    daily_reads: series(s.view_count_list),
  };
}

(async () => {
  if (!fs.existsSync(SESSION)) {
    console.error('[FATAL] session.json is missing, run first: node login.js');
    process.exit(2);
  }
  const browser = await chromium.launch({ executablePath: CHROME, headless: true });
  const ctx = await browser.newContext({ storageState: SESSION, viewport: { width: 1600, height: 1000 } });
  const page = await ctx.newPage();

  page.on('response', async (res) => {
    const u = res.url();
    try {
      if (u.includes('/datacenter/note/analyze/list')) cap.list = JSON.parse(await res.text());
      else if (u.includes('/v2/creator/datacenter/account/base')) cap.account = JSON.parse(await res.text());
    } catch {}
  });

  try {
    await page.goto(HOME, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForTimeout(6000);
    if (page.url().includes('/login')) {
      console.error('[FATAL] session expired, run node login.js again to log in by QR code');
      await browser.close();
      process.exit(3);
    }
    await page.goto(ANALYSIS, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForTimeout(10000);
  } catch (e) {
    console.error('[FATAL] page load failed: ' + e.message);
    await browser.close();
    process.exit(4);
  }

  if (!cap.list) {
    console.error('[FATAL] note-list API was not captured (session may have expired or the page changed)');
    await browser.close();
    process.exit(5);
  }

  const acc = (cap.account && cap.account.data) || {};
  const noteInfos = (cap.list.data && cap.list.data.note_infos) || [];

  const result = {
    pulled_at: new Date().toISOString(),
    source: 'creator.xiaohongshu.com/statistics/data-analysis',
    account: { seven: pickAccount(acc.seven), thirty: pickAccount(acc.thirty) },
    notes: noteInfos.map((x) => ({
      note_id: x.id,
      title: x.title,
      post_time: iso(x.post_time),
      type: x.type === 2 ? 'video' : 'image',
      impressions: n(x.imp_count),
      reads: n(x.read_count),
      ctr: n(x.coverClickRate),
      likes: n(x.like_count),
      favorites: n(x.fav_count),
      comments: n(x.comment_count),
      shares: n(x.share_count),
      danmaku: n(x.danmaku_count),
      fans_gained: n(x.increase_fans_count),
      avg_watch_s: n(x.view_time_avg),
    })),
  };

  fs.mkdirSync(OUTDIR, { recursive: true });
  fs.writeFileSync(path.join(OUTDIR, 'latest.json'), JSON.stringify(result, null, 2), 'utf8');
  fs.appendFileSync(path.join(OUTDIR, 'history.jsonl'), JSON.stringify(result) + '\n', 'utf8');

  console.log(`[OK] notes=${result.notes.length} account7d=${!!result.account.seven} account30d=${!!result.account.thirty}`);
  console.log('[OK] -> data/metrics/latest.json');
  await browser.close();
})().catch((e) => { console.error('[FATAL] ' + (e && e.stack ? e.stack : e)); process.exit(1); });
