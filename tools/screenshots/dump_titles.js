/** Walk every course and dump its module titles, to audit trademark use. */
const puppeteer = require("puppeteer-core");
const CHROME = "C:/Program Files/Google/Chrome/Application/chrome.exe";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function nodes(page) {
  return page.evaluate(() =>
    [...document.querySelectorAll("flt-semantics")].map((n) => {
      const r = n.getBoundingClientRect();
      return {
        label: (n.getAttribute("aria-label") || n.textContent || "").trim(),
        x: Math.round(r.x + r.width / 2), y: Math.round(r.y + r.height / 2),
        w: Math.round(r.width), h: Math.round(r.height),
      };
    }).filter((n) => n.label && n.w > 0 && n.h > 0 && n.h < 260));
}
async function tap(page, text, exact, wait = 2500) {
  const all = await nodes(page);
  const l = text.toLowerCase();
  let hits = all.filter((n) => n.label.toLowerCase() === l);
  if (!hits.length && !exact) {
    hits = all.filter((n) => n.label.toLowerCase().includes(l))
              .sort((a, b) => a.w * a.h - b.w * b.h);
  }
  if (!hits.length) return false;
  await page.mouse.click(hits[0].x, hits[0].y);
  await sleep(wait);
  return true;
}

(async () => {
  const browser = await puppeteer.launch({
    executablePath: CHROME, headless: "new",
    defaultViewport: { width: 440, height: 956, deviceScaleFactor: 1, isMobile: true, hasTouch: true },
  });
  const page = await browser.newPage();
  await page.goto("http://127.0.0.1:8099/", { waitUntil: "networkidle2", timeout: 120000 });
  await sleep(7000);
  const semantics = async () => page.evaluate(() => {
    const el = document.querySelector("flt-semantics-placeholder");
    if (el) el.click();
  });
  await semantics();
  await sleep(1500);
  await tap(page, "Continue as guest", false, 5000);
  await sleep(3000);

  const courses = ["IT Service Management Foundations", "Agile & Scrum Foundations"];

  for (const c of courses) {
    await page.reload({ waitUntil: "networkidle2", timeout: 120000 });
    await sleep(7000); await semantics(); await sleep(1200);
    if (!(await tap(page, "Courses", true, 3000))) { console.log("no courses tab"); continue; }
    // Scroll the list so later courses are reachable.
    for (let i = 0; i < 6; i++) {
      if (await tap(page, c, false, 3500)) break;
      await page.mouse.wheel({ deltaY: 400 }); await sleep(900);
    }
    const all = await nodes(page);
    console.log(`\n=== ${c} ===`);
    console.log(all.map((n) => n.label.split("\n")[0]).join(" | "));
  }
  await browser.close();
})().catch((e) => { console.error("FAILED:", e.message); process.exit(1); });
