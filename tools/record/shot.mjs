/**
 * 单步截图工具（竖版预览用）。
 *
 * 用法：
 *   node shot.mjs <chapterIndex> <stepIndex> <outPng> [--wide]
 *
 * 例：
 *   node shot.mjs 0 1 ../_shots/hook-1.png
 *
 * 会写入 localStorage 光标 → reload → 等动画播完 → 截图。
 * 录制态 UI（进度条 / 模式按钮）默认隐藏，与实际成片构图一致。
 */
import { chromium } from "playwright-core";

const CHROME =
  process.env.CHROME_PATH ||
  "C:/Program Files/Google/Chrome/Application/chrome.exe";
const STORAGE_KEY = process.env.STORAGE_KEY || "presentation-cursor-v8";
const args = process.argv.slice(2);
const wide = args.includes("--wide");
const [chapter, step, out] = args.filter((a) => !a.startsWith("--"));

const PORT = wide ? 5174 : 5175;
const W = wide ? 1920 : 1080;
const H = wide ? 1080 : 1440;

const browser = await chromium.launch({
  executablePath: CHROME,
  headless: true,
});
const ctx = await browser.newContext({
  viewport: { width: W, height: H },
  deviceScaleFactor: 1,
});
const page = await ctx.newPage();

await page.goto(`http://localhost:${PORT}/`, { waitUntil: "load" });
await page.evaluate(
  ({ c, s, key }) =>
    localStorage.setItem(
      key,
      JSON.stringify({ chapter: c, step: s }),
    ),
  { c: Number(chapter), s: Number(step), key: STORAGE_KEY },
);
await page.reload({ waitUntil: "load" });
await page.addStyleTag({
  content: ".pb-hover, .at-hover { display: none !important; }",
});
await page.evaluate(() => document.fonts.ready);
await new Promise((r) => setTimeout(r, 3200)); // 等入场动画播完
await page.screenshot({ path: out });
await browser.close();
console.log("shot →", out);
