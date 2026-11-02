/**
 * Headless recording driver for the web-video-presentation runtime.
 *
 * Why this exists: the runtime advances on `audio.ended` + reading-protection
 * trail (default 1500ms, override with TRAIL_MS env), so the
 * ONLY reliable way to get a perfectly synced master is to let the real
 * browser drive the timing. Playwright records the *video* (no audio), and
 * we rebuild the audio track afterwards from the per-step mp3s using the
 * *actual* step transition timestamps measured inside the page.
 *
 * Output:
 *   <outDir>/video.webm   — silent 1920x1080 capture
 *   <outDir>/marks.json   — { t0, start, marks: [{id, t}], total }
 *                           all in ms on the page's performance.now() clock
 */
import { chromium } from "playwright-core";
import { mkdir, readdir, rename, writeFile } from "node:fs/promises";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

// Chrome executable: prefer the env var, then the default Windows install path
const CHROME =
  process.env.CHROME_PATH ||
  "C:/Program Files/Google/Chrome/Application/chrome.exe";

/**
 * Both aspect ratios share this one script, switched by env vars:
 *   VARIANT=wide      16:9  1920x1080  Bilibili → <project>/raw/
 *   VARIANT=vertical   3:4  1080x1440  Xiaohongshu → <project>/raw-vertical/
 *
 * Other env vars:
 *   VIDEO_PROJECT      video project dir (default <repo>/videos/personal-agent-deep-dive)
 *   PRESENTATION_DIR   web project dir (default <project>/presentation[-vertical])
 *   PORT               dev-server port (wide default 5174 / vertical default 5175)
 *   TOTAL_STEPS        total steps (default: length of <PRESENTATION_DIR>/audio-segments.json)
 *   STORAGE_KEY        browser local cursor key (default presentation-cursor-v8)
 */
const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const VARIANT = process.env.VARIANT === "vertical" ? "vertical" : "wide";
const PROJECT_DIR = process.env.VIDEO_PROJECT
  ? path.resolve(process.env.VIDEO_PROJECT)
  : path.join(REPO_ROOT, "videos", "personal-agent-deep-dive");
const PRESENTATION_DIR = process.env.PRESENTATION_DIR
  ? path.resolve(process.env.PRESENTATION_DIR)
  : path.join(PROJECT_DIR, VARIANT === "vertical" ? "presentation-vertical" : "presentation");

const CFG = {
  wide: {
    port: Number(process.env.PORT || 5174),
    w: 1920,
    h: 1080,
    out: path.join(PROJECT_DIR, "raw"),
  },
  vertical: {
    port: Number(process.env.PORT || 5175),
    w: 1080,
    h: 1440,
    out: path.join(PROJECT_DIR, "raw-vertical"),
  },
}[VARIANT];

// Reading-protection time: the page default is 1500ms when TRAIL_MS is not passed; TRAIL_MS=800 shortens the whole video.
const TRAIL = process.env.TRAIL_MS ? `&trail=${process.env.TRAIL_MS}` : "";
const URL = `http://localhost:${CFG.port}/?auto=1${TRAIL}`;
const OUT_DIR = CFG.out;
const STAGE_W = CFG.w;
const STAGE_H = CFG.h;
const STORAGE_KEY = process.env.STORAGE_KEY || "presentation-cursor-v8";

function countSteps() {
  if (process.env.TOTAL_STEPS) return Number(process.env.TOTAL_STEPS);
  try {
    const segs = JSON.parse(
      readFileSync(path.join(PRESENTATION_DIR, "audio-segments.json"), "utf-8"),
    );
    return Array.isArray(segs) ? segs.length : 999;
  } catch {
    return 999;
  }
}
const TOTAL_STEPS = countSteps();

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const log = (...a) => console.log(`[${new Date().toISOString()}]`, ...a);

await mkdir(OUT_DIR, { recursive: true });

const browser = await chromium.launch({
  executablePath: CHROME,
  headless: true,
  args: [
    "--autoplay-policy=no-user-gesture-required",
    "--force-device-scale-factor=1",
    "--hide-scrollbars",
    "--disable-background-timer-throttling",
    "--disable-renderer-backgrounding",
    "--disable-backgrounding-occluded-windows",
  ],
});

const context = await browser.newContext({
  viewport: { width: STAGE_W, height: STAGE_H },
  deviceScaleFactor: 1,
  recordVideo: { dir: OUT_DIR, size: { width: STAGE_W, height: STAGE_H } },
});

const page = await context.newPage();
page.on("console", (m) => {
  const t = m.text();
  if (t.includes("audio play failed") || m.type() === "error") {
    log("PAGE:", t);
  }
});

log("goto", URL);
await page.goto(URL, { waitUntil: "load" });

// Force a clean start at the very first step, then reload so both the
// stepper and the audio player mount from step 0.
await page.evaluate(
  (key) =>
    localStorage.setItem(key, JSON.stringify({ chapter: 0, step: 0 })),
  STORAGE_KEY,
);
await page.reload({ waitUntil: "load" });

await page.evaluate(() => document.fonts.ready);
await sleep(1200);
log("fonts ready");

// Do not show any editing-mode UI in the final video: chapter progress bar / mode toggle button.
// (AutoStartGate must stay, because recording relies on it to catch Space and start.)
await page.addStyleTag({
  content: ".pb-hover, .at-hover { display: none !important; }",
});

// ── instrumentation ────────────────────────────────────────────────────
await page.evaluate((key) => {
  const w = window;
  w.__t0 = performance.now();
  w.__start = null;
  w.__marks = [];

  // Timestamp the exact moment auto playback is released.
  w.addEventListener(
    "keydown",
    (e) => {
      if (e.key === " " && w.__start === null) w.__start = performance.now();
    },
    true,
  );

  // Record every step transition on the same clock.
  let last = null;
  w.__timer = setInterval(() => {
    try {
      const raw = localStorage.getItem(key);
      if (!raw) return;
      const c = JSON.parse(raw);
      const id = `${c.chapter}:${c.step}`;
      if (id !== last) {
        last = id;
        w.__marks.push({ id, t: performance.now() });
      }
    } catch {
      /* ignore */
    }
  }, 16);
}, STORAGE_KEY);

const gate = await page.$(".auto-gate");
if (!gate) throw new Error("Auto start gate not found — is ?auto=1 active?");

log("pressing Space to release auto playback");
await page.keyboard.press("Space");
const press_node = Date.now();
await sleep(400);

// ── wait for the run to finish ──────────────────────────────────────────
const startedAt = Date.now();
const HARD_TIMEOUT_MS = 20 * 60 * 1000;
let lastCount = -1;
let stableSince = Date.now();
let marks = [];

let snapshot = { marks: [], start: null, t0: null };

while (Date.now() - startedAt < HARD_TIMEOUT_MS) {
  await sleep(2000);

  let snap;
  try {
    snap = await page.evaluate(() => ({
      marks: window.__marks,
      start: window.__start,
      t0: window.__t0,
    }));
  } catch (err) {
    // Chrome occasionally dies mid-take (long screencast + AV scanning the
    // growing webm). Keep whatever we captured so the run is diagnosable.
    log("!! page died:", err.message);
    break;
  }

  snapshot = snap;
  marks = snap.marks;

  // Flush every poll so a crash never costs more than 2s of marks.
  await writeFile(
    path.join(OUT_DIR, "marks.json"),
    JSON.stringify(snapshot, null, 2),
    "utf-8",
  );

  if (marks.length !== lastCount) {
    lastCount = marks.length;
    stableSince = Date.now();
    log(`step ${marks.length}/${TOTAL_STEPS} — ${marks.at(-1)?.id}`);
    continue;
  }

  // Reached the final step and nothing has moved for a while → audio done.
  const idle = Date.now() - stableSince;
  if (marks.length >= TOTAL_STEPS && idle > 12000) {
    log(`idle ${idle}ms after ${marks.length} marks — finishing`);
    break;
  }
  if (idle > 60000) {
    log(`stalled at ${marks.length} marks — aborting`);
    break;
  }
}

let final = snapshot;
try {
  final = await page.evaluate(() => ({
    marks: window.__marks,
    start: window.__start,
    t0: window.__t0,
  }));
} catch {
  log("(final evaluate failed — using last snapshot)");
}

await writeFile(
  path.join(OUT_DIR, "marks.json"),
  JSON.stringify(final, null, 2),
  "utf-8",
);
log("marks saved:", final.marks.length, "start:", final.start);

const close_node = Date.now();
await writeFile(
  path.join(OUT_DIR, "timing.json"),
  JSON.stringify(
    { press_node, close_node, page_start: final.start, page_t0: final.t0 },
    null,
    2,
  ),
  "utf-8",
);
log("timing saved — press→close:", (close_node - press_node) / 1000, "s");

try {
  await context.close(); // flushes the video file
} catch (err) {
  log("context.close failed:", err.message);
}
try {
  await browser.close();
} catch {
  /* already gone */
}

// Playwright writes to a random name — normalise it.
const files = await readdir(OUT_DIR);
const webm = files.find((f) => f.endsWith(".webm"));
if (webm) {
  await rename(path.join(OUT_DIR, webm), path.join(OUT_DIR, "video.webm"));
  log("video →", path.join(OUT_DIR, "video.webm"));
} else {
  log("!! no .webm produced");
}
log("done");
