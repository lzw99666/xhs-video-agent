// 一次性登录：打开创作者中心，等用户扫码/短信登录，成功后保存 storageState。
// 产物：tools/metrics/session.json（含登录凭证，勿提交/勿外传）
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
  say('浏览器已打开，请在窗口内完成登录（扫码或短信），最多等待 8 分钟。');

  const deadline = Date.now() + 8 * 60 * 1000;
  let logged = false;
  while (Date.now() < deadline) {
    await page.waitForTimeout(3000);
    if (!page.url().includes('/login')) { logged = true; break; }
  }
  if (!logged) {
    say('TIMEOUT: 8 分钟内未检测到登录完成。');
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
