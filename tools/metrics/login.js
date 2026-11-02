// One-off login: opens the creator center, waits for the user to log in via QR code / SMS, then saves storageState.
// Output: tools/metrics/session.json (contains login credentials; never commit or share it)
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright-core');

const CHROME =
  process.env.CHROME_PATH ||
  'C:/Program Files/Google/Chrome/Application/chrome.exe';
const SESSION = path.join(__dirname, 'session.json');
const RESULT = path.join(__dirname, 'login-result.txt');

const out = [];
const say = (s) => { out.push(s); console.log(s); };

(async () => {
  const browser = await chromium.launch({
    executablePath: CHROME,
    headless: false,
    args: ['--start-maximized'],
  });
  const ctx = await browser.newContext({ viewport: null });
  const page = await ctx.newPage();
  await page.goto('https://creator.xiaohongshu.com/login', { waitUntil: 'domcontentloaded' });
  say('Browser opened. Please log in in the window (QR code or SMS); waiting up to 8 minutes.');

  const deadline = Date.now() + 8 * 60 * 1000;
  let logged = false;
  while (Date.now() < deadline) {
    await page.waitForTimeout(3000);
    if (!page.url().includes('/login')) { logged = true; break; }
  }
  if (!logged) {
    say('TIMEOUT: login not detected within 8 minutes.');
    fs.writeFileSync(RESULT, out.join('\n'), 'utf8');
    await browser.close();
    process.exit(3);
  }

  await page.goto('https://creator.xiaohongshu.com/creator/data/note', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(8000);
  say('URL   : ' + page.url());
  say('TITLE : ' + (await page.title()));
  const body = (await page.evaluate(() => document.body.innerText)).replace(/\s+/g, ' ').slice(0, 500);
  say('BODY  : ' + body);

  await ctx.storageState({ path: SESSION });
  say('SESSION SAVED: ' + SESSION);
  fs.writeFileSync(RESULT, out.join('\n'), 'utf8');
  await browser.close();
})().catch((e) => {
  out.push('FATAL ' + (e && e.stack ? e.stack : e));
  fs.writeFileSync(RESULT, out.join('\n'), 'utf8');
  console.error(e);
  process.exit(1);
});
