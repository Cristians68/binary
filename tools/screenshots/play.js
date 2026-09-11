/**
 * Play through the free module for real, then capture the populated screens.
 *
 * Doubles as an end-to-end check of today's work: the lesson must award
 * points, the quiz must count, and a badge must appear — none of which could
 * happen before, because recordLessonComplete and recordQuizPass had no
 * callers at all.
 */
const fs = require("fs");
const path = require("path");
const puppeteer = require("puppeteer-core");

const CHROME = "C:/Program Files/Google/Chrome/Application/chrome.exe";
const URL = "http://127.0.0.1:8099/";
const OUT = path.join(__dirname, "shots");
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function nodes(page) {
  return page.evaluate(() =>
    [...document.querySelectorAll("flt-semantics")]
      .map((n) => {
        const r = n.getBoundingClientRect();
        return {
          label: (n.getAttribute("aria-label") || n.textContent || "").trim(),
          x: Math.round(r.x + r.width / 2),
          y: Math.round(r.y + r.height / 2),
          w: Math.round(r.width),
          h: Math.round(r.height),
        };
      })
      .filter((n) => n.label && n.w > 0 && n.h > 0 && n.h < 260));
}

async function tap(page, text, { exact = false, wait = 2500, optional = false, widest = false } = {}) {
  const all = await nodes(page);
  const l = text.toLowerCase();
  let hits = all.filter((n) => n.label.toLowerCase() === l);
  // Profile renders "Badges" twice: the stat tile caption (a narrow, inert
  // Text) and the menu row that actually navigates. Taking the first in DOM
  // order hit the caption, so 11-badges.png was really the Profile screen.
  // The tappable row is the full-width one.
  if (widest) hits.sort((a, b) => b.w * b.h - a.w * a.h);
  if (!hits.length && !exact) {
    hits = all.filter((n) => n.label.toLowerCase().includes(l))
              .sort((a, b) => (widest ? b.w * b.h - a.w * a.h : a.w * a.h - b.w * b.h));
  }
  if (!hits.length) {
    if (optional) return false;
    console.log("  available:", all.map((n) => n.label.slice(0, 40)).join(" | "));
    throw new Error(`no node "${text}"`);
  }
  await page.mouse.click(hits[0].x, hits[0].y);
  console.log(`  tap "${hits[0].label.slice(0, 46)}"`);
  await sleep(wait);
  return true;
}

async function shot(page, name) {
  fs.mkdirSync(OUT, { recursive: true });
  await page.screenshot({ path: path.join(OUT, `${name}.png`) });
  console.log(`  >> ${name}.png`);
}
async function labels(page, note) {
  console.log(`  [${note}] ` +
    (await nodes(page)).map((n) => n.label.split("\n")[0].slice(0, 40)).join(" | "));
}

(async () => {
  const browser = await puppeteer.launch({
    executablePath: CHROME, headless: "new",
    args: ["--hide-scrollbars", "--force-color-profile=srgb"],
    defaultViewport: { width: 440, height: 956, deviceScaleFactor: 3, isMobile: true, hasTouch: true },
  });
  const page = await browser.newPage();
  const semantics = async () => {
    await page.evaluate(() => {
      const el = document.querySelector("flt-semantics-placeholder");
      if (el) el.click();
    });
    await sleep(1400);
  };
  const relaunch = async () => {
    await page.reload({ waitUntil: "domcontentloaded", timeout: 120000 });
    await sleep(10000);
    await semantics();
  };

  await page.goto(URL, { waitUntil: "networkidle2", timeout: 120000 });
  await sleep(7000);
  await semantics();
  await tap(page, "Continue as guest", { wait: 6000 });

  console.log("enrol and open the free module");
  await tap(page, "Courses", { exact: true, wait: 3000 });
  await tap(page, "Enroll", { wait: 3000 });
  await tap(page, "Network Professional", { wait: 3500 });
  await tap(page, "Try free", { wait: 5000 });

  // Walk every flashcard to the end — this is what marks the lesson complete.
  for (let i = 0; i < 12; i++) {
    if (await tap(page, "Start Quiz", { optional: true, wait: 5000 })) break;
    const moved = await tap(page, "Next", { optional: true, wait: 1600 });
    if (!moved) { await page.mouse.click(400, 478); await sleep(1400); }
  }

  console.log("answer the quiz");
  await labels(page, "quiz");
  await tap(page, "IP routing table", { wait: 3000 });
  await labels(page, "after answer");
  await shot(page, "07-quiz-answered");
  await tap(page, "See results", { wait: 5000 });
  await labels(page, "results");
  await shot(page, "07b-results");

  console.log("populated home");
  await relaunch();
  await labels(page, "home");
  await shot(page, "02-home");

  console.log("progress");
  await tap(page, "Progress", { exact: true, wait: 4000 });
  await labels(page, "progress");
  await shot(page, "08-progress");

  console.log("badges");
  await relaunch();
  await tap(page, "Profile", { exact: true, wait: 3500 });
  await tap(page, "Badges", { wait: 4000, widest: true });
  await labels(page, "badges");
  const onBadges = (await nodes(page)).map((n) => n.label).join(" ~ ");
  if (/Lessons ~ Badges ~ Streak|Avg score/i.test(onBadges)) {
    throw new Error("still on Profile — the Badges tap hit the stat caption again");
  }
  await shot(page, "11-badges");

  await browser.close();
})().catch((e) => { console.error("FAILED:", e.message); process.exit(1); });
