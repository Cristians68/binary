/**
 * Capture App Store screenshots from the Flutter web build.
 *
 * 440x956 CSS px at deviceScaleFactor 3 is exactly the iPhone 6.9" screenshot
 * size Apple asks for: 1320x2868.
 *
 * Flutter web paints into a canvas, so there is nothing to click by selector.
 * Enabling the semantics tree gives a real DOM of aria-labelled elements —
 * both how a screen reader drives the app and how this script does.
 */
const fs = require("fs");
const path = require("path");
const puppeteer = require("puppeteer-core");

const CHROME = "C:/Program Files/Google/Chrome/Application/chrome.exe";
const URL = "http://127.0.0.1:8099/";
const OUT = path.join(__dirname, "shots");

const WIDTH = 440;
const HEIGHT = 956;
const SCALE = 3;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function nodes(page) {
  return page.evaluate(() =>
    [...document.querySelectorAll("flt-semantics")]
      .map((n) => {
        const r = n.getBoundingClientRect();
        const label = (n.getAttribute("aria-label") || n.textContent || "")
          .trim();
        return {
          label,
          x: Math.round(r.x + r.width / 2),
          y: Math.round(r.y + r.height / 2),
          w: Math.round(r.width),
          h: Math.round(r.height),
        };
      })
      .filter((n) => n.label && n.w > 0 && n.h > 0 && n.h < 260),
  );
}

/**
 * Click a node. Prefers an exact label match, then the smallest containing
 * one — "Courses" must hit the tab, not the "MY COURSES" section heading.
 */
async function tap(page, text, opts = {}) {
  const { optional = false, exact = false, wait = 2200, nth = 0 } = opts;
  const all = await nodes(page);
  const lower = text.toLowerCase();
  let hits = all.filter((n) => n.label.toLowerCase() === lower);
  if (hits.length === 0 && !exact) {
    hits = all
      .filter((n) => n.label.toLowerCase().includes(lower))
      .sort((a, b) => a.w * a.h - b.w * b.h);
  }
  if (hits.length <= nth) {
    if (optional) {
      console.log(`  (skip) no node "${text}"`);
      return false;
    }
    console.log("  available:", all.map((n) => n.label).join(" | "));
    throw new Error(`no node matching "${text}"`);
  }
  const t = hits[nth];
  await page.mouse.click(t.x, t.y);
  console.log(`  tapped "${t.label.slice(0, 44)}" @${t.x},${t.y}`);
  await sleep(wait);
  return true;
}

async function shot(page, name) {
  fs.mkdirSync(OUT, { recursive: true });
  await page.screenshot({ path: path.join(OUT, `${name}.png`) });
  console.log(`  >> ${name}.png`);
}

async function labels(page, note) {
  const all = await nodes(page);
  console.log(`  [${note}] ` + all.map((n) => n.label.slice(0, 34)).join(" | "));
}

(async () => {
  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: "new",
    args: [
      `--window-size=${WIDTH},${HEIGHT}`,
      "--hide-scrollbars",
      "--force-color-profile=srgb",
    ],
    defaultViewport: {
      width: WIDTH,
      height: HEIGHT,
      deviceScaleFactor: SCALE,
      isMobile: true,
      hasTouch: true,
    },
  });

  const page = await browser.newPage();
  page.on("console", (m) => {
    const t = m.text();
    if (/error|denied|failed/i.test(t)) console.log("  [page]", t.slice(0, 200));
  });

  await page.goto(URL, { waitUntil: "networkidle2", timeout: 120000 });
  await sleep(6000);
  await page.evaluate(() => {
    const el = document.querySelector("flt-semantics-placeholder");
    if (el) el.click();
  });
  await sleep(1500);

  await shot(page, "01-welcome");
  await tap(page, "Continue as guest");
  await sleep(5000);
  await shot(page, "02-home");

  console.log("courses tab");
  await tap(page, "Courses", { exact: true, wait: 3000 });
  await labels(page, "courses");
  await shot(page, "03-courses");

  console.log("enroll in Network Professional");
  await tap(page, "Enroll", { nth: 0, wait: 3000 });
  await shot(page, "04-after-enroll");

  await tap(page, "Network Professional", { wait: 3500 });
  await labels(page, "course detail");
  await shot(page, "05-course-detail");

  console.log("open the free module");
  await tap(page, "Try free", { wait: 5000 });
  await labels(page, "lesson");
  await shot(page, "06-lesson");

  console.log("quiz");
  await tap(page, "Start Quiz", { wait: 4500 });
  await labels(page, "quiz");
  await shot(page, "07-quiz");

  /** Reload back into the app. The guest session persists, and the routing
   *  fix means a signed-in user lands in MainNavigation rather than being
   *  shown the welcome screen again. */
  async function relaunch() {
    await page.reload({ waitUntil: "networkidle2", timeout: 120000 });
    await sleep(7000);
    await page.evaluate(() => {
      const el = document.querySelector("flt-semantics-placeholder");
      if (el) el.click();
    });
    await sleep(1500);
  }

  console.log("progress tab");
  await relaunch();
  await labels(page, "after reload");
  await tap(page, "Progress", { exact: true, wait: 3500 });
  await shot(page, "08-progress");

  console.log("paywall");
  await tap(page, "Courses", { exact: true, wait: 3000 });
  await tap(page, "View Plans", { wait: 6000 });
  await labels(page, "paywall");
  await shot(page, "09-paywall");

  console.log("profile");
  await relaunch();
  await tap(page, "Profile", { exact: true, wait: 3500 });
  await shot(page, "10-profile");

  await browser.close();
  console.log("done");
})().catch((e) => {
  console.error("FAILED:", e.message);
  process.exit(1);
});
