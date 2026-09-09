/**
 * Read the guest's own user document straight from Firestore at each step, so
 * the streak behaviour is observed rather than inferred from the UI.
 */
const puppeteer = require("puppeteer-core");
const CHROME = "C:/Program Files/Google/Chrome/Application/chrome.exe";
const URL = "http://127.0.0.1:8099/";
const PROJECT = "binary-6a372";
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
async function tap(page, text, { exact = false, wait = 2500, optional = false } = {}) {
  const all = await nodes(page);
  const l = text.toLowerCase();
  let hits = all.filter((n) => n.label.toLowerCase() === l);
  if (!hits.length && !exact) {
    hits = all.filter((n) => n.label.toLowerCase().includes(l)).sort((a, b) => a.w * a.h - b.w * b.h);
  }
  if (!hits.length) { if (optional) return false; throw new Error(`no node "${text}"`); }
  await page.mouse.click(hits[0].x, hits[0].y);
  await sleep(wait);
  return true;
}

/** The signed-in user's uid and ID token, out of Firebase Auth's IndexedDB. */
async function creds(page) {
  return page.evaluate(async () => {
    const db = await new Promise((res, rej) => {
      const r = indexedDB.open("firebaseLocalStorageDb");
      r.onsuccess = () => res(r.result);
      r.onerror = () => rej(r.error);
    });
    const rows = await new Promise((res, rej) => {
      const tx = db.transaction("firebaseLocalStorage", "readonly");
      const req = tx.objectStore("firebaseLocalStorage").getAll();
      req.onsuccess = () => res(req.result);
      req.onerror = () => rej(req.error);
    });
    for (const row of rows) {
      const v = row.value;
      if (v && v.uid && v.stsTokenManager) {
        return { uid: v.uid, token: v.stsTokenManager.accessToken };
      }
    }
    return null;
  });
}

async function readUserDoc(page, label) {
  const c = await creds(page);
  if (!c) { console.log(`  [${label}] no credentials yet`); return; }
  const doc = await page.evaluate(async (project, uid, token) => {
    const url = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/users/${uid}`;
    const r = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
    return { status: r.status, body: await r.text() };
  }, PROJECT, c.uid, c.token);
  let out = doc.body;
  try {
    const j = JSON.parse(doc.body);
    const f = j.fields || {};
    const pick = (k) => JSON.stringify(f[k]);
    out = ["streak", "dailyGoal", "badges", "lessonsCompleted", "quizzesPassed",
           "completedCourses", "enrolledCourses"].map((k) => `${k}=${pick(k)}`).join("\n     ");
  } catch (_) {}
  console.log(`  [${label}] uid=${c.uid.slice(0, 8)} status=${doc.status}\n     ${out}`);
}

(async () => {
  const browser = await puppeteer.launch({
    executablePath: CHROME, headless: "new",
    defaultViewport: { width: 440, height: 956, deviceScaleFactor: 1, isMobile: true, hasTouch: true },
  });
  const page = await browser.newPage();
  page.on("console", (m) => {
    const t = m.text();
    if (/permission|denied|error|exception|failed/i.test(t)) console.log("  [console]", t.slice(0, 300));
  });
  page.on("pageerror", (e) => console.log("  [pageerror]", String(e).slice(0, 300)));
  const semantics = async () => {
    await page.evaluate(() => {
      const el = document.querySelector("flt-semantics-placeholder");
      if (el) el.click();
    });
    await sleep(1400);
  };

  await page.goto(URL, { waitUntil: "networkidle2", timeout: 120000 });
  await sleep(7000);
  await semantics();
  await tap(page, "Continue as guest", { wait: 8000 });
  await readUserDoc(page, "after guest sign-in + home");

  await tap(page, "Courses", { exact: true, wait: 3000 });
  await tap(page, "Enroll", { wait: 3500 });
  await readUserDoc(page, "after enrol");

  await tap(page, "Network Professional", { wait: 3500 });
  await tap(page, "Try free", { wait: 5000 });
  for (let i = 0; i < 12; i++) {
    if (await tap(page, "Start Quiz", { optional: true, wait: 5000 })) break;
    if (!(await tap(page, "Next", { optional: true, wait: 1600 }))) {
      await page.mouse.click(400, 478); await sleep(1400);
    }
  }
  await readUserDoc(page, "after lesson complete");

  await tap(page, "IP routing table", { wait: 3000 });
  await tap(page, "See results", { wait: 8000 });
  await readUserDoc(page, "after quiz pass");

  await browser.close();
})().catch((e) => { console.error("FAILED:", e.message); process.exit(1); });
