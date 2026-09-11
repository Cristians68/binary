/**
 * Prove the tabs are live, not frozen at launch.
 *
 * The bug: Home's "My courses", the Courses tab's Enrolled state and Profile's
 * stats were each a one-shot get() in initState. MainNavigation builds every
 * tab in an IndexedStack at launch, so all three ran before the user had done
 * anything and never ran again — enrol on Courses, go Home, and Home still
 * said "No courses yet" until the next cold start.
 *
 * No unit test can catch this: the parsers were always correct, the wiring was
 * not. So drive the real app and read the real screens.
 *
 * The assertion that matters is the NEGATIVE one: Home must be empty BEFORE
 * enrolling. A check that only looks for the course after enrolling passes on
 * a build where Home shows every course all the time.
 */
const fs = require("fs");
const path = require("path");
const puppeteer = require("puppeteer-core");

const CHROME = "C:/Program Files/Google/Chrome/Application/chrome.exe";
const URL = "http://127.0.0.1:8099/";
const OUT = path.join(__dirname, "shots", "verify");
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
// Card labels join title and subtitle with a newline.
const NL = String.fromCharCode(10);

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

async function tap(page, text, { exact = false, wait = 2600 } = {}) {
  const all = await nodes(page);
  const l = text.toLowerCase();
  let hits = all.filter((n) => n.label.toLowerCase() === l);
  if (!hits.length && !exact) {
    hits = all.filter((n) => n.label.toLowerCase().includes(l))
              .sort((a, b) => a.w * a.h - b.w * b.h);
  }
  if (!hits.length) {
    console.log("  available:", all.map((n) => n.label.slice(0, 38)).join(" | "));
    throw new Error(`no node "${text}"`);
  }
  await page.mouse.click(hits[0].x, hits[0].y);
  console.log(`  tap "${hits[0].label.slice(0, 46)}"`);
  await sleep(wait);
  return hits[0].label;
}

async function shot(page, name) {
  fs.mkdirSync(OUT, { recursive: true });
  await page.screenshot({ path: path.join(OUT, `${name}.png`) });
  console.log(`  >> verify/${name}.png`);
}

const results = [];
function check(name, pass, detail) {
  results.push({ name, pass, detail });
  console.log(`  ${pass ? "PASS" : "FAIL"} — ${name}${detail ? ` (${detail})` : ""}`);
}

(async () => {
  const browser = await puppeteer.launch({
    executablePath: CHROME, headless: "new",
    args: ["--hide-scrollbars", "--force-color-profile=srgb"],
    defaultViewport: { width: 440, height: 956, deviceScaleFactor: 3, isMobile: true, hasTouch: true },
  });
  const page = await browser.newPage();
  page.on("console", (m) => {
    const t = m.text();
    if (t.includes("[DIAG]") || t.includes("Error")) console.log("  [console]", t.slice(0, 160));
  });

  const semantics = async () => {
    await page.evaluate(() => {
      const el = document.querySelector("flt-semantics-placeholder");
      if (el) el.click();
    });
    await sleep(1500);
  };

  console.log("\n1. Load and sign in as guest");
  await page.goto(URL, { waitUntil: "domcontentloaded", timeout: 120000 });
  await sleep(11000);
  await semantics();

  let all = await nodes(page);
  console.log(`  semantics nodes: ${all.length}`);
  if (all.length === 0) throw new Error("semantics tree empty — cannot read labels, screenshot and use coordinates");
  await shot(page, "01-welcome");

  await tap(page, "Continue as guest", { wait: 9000 });
  await semantics();
  await shot(page, "02-home-before");

  console.log("\n2. Home BEFORE enrolling — must be empty (the negative check)");
  let labels = (await nodes(page)).map((n) => n.label).join(" ~ ");
  const emptyBefore = /no courses yet|browse courses|get started/i.test(labels);
  check("Home starts with no enrolled courses", emptyBefore,
        emptyBefore ? "empty state present" : `labels: ${labels.slice(0, 220)}`);

  console.log("\n3. Enrol on the Courses tab");
  await tap(page, "Courses", { exact: true, wait: 3500 });
  await semantics();
  await shot(page, "03-courses");

  const before = (await nodes(page)).map((n) => n.label);
  console.log("  course labels:", before.filter((l) => l.length > 3).slice(0, 14).join(" | ").slice(0, 400));

  // The card whose Enroll button we are about to press, so Home can be
  // checked for that exact course rather than for "something, anything".
  const enrolledCourseTitle = await page.evaluate(() => {
    const ns = [...document.querySelectorAll("flt-semantics")];
    const btn = ns.find((n) => (n.getAttribute("aria-label") || "").trim().toLowerCase() === "enroll");
    if (!btn) return "";
    const by = btn.getBoundingClientRect().y;
    const cards = ns
      .map((n) => ({ l: (n.getAttribute("aria-label") || "").trim(), r: n.getBoundingClientRect() }))
      .filter((c) => c.l.includes(NL) && c.r.y <= by && by - c.r.y < 260)
      .sort((a, b) => b.r.y - a.r.y);
    return cards.length ? cards[0].l : "";
  });
  console.log(`  enrolling in: ${JSON.stringify((enrolledCourseTitle || "").split(NL)[0])}`);

  // Every course title on offer. flt-semantics nodes carry no usable
  // geometry, so pairing a card with its own Enroll button by position does
  // not work — collect the titles instead and check Home against the set.
  const catalogueTitles = before
    .filter((l) => l.includes(NL))
    .map((l) => l.split(NL)[0].trim())
    .filter((t) => t.length > 3);
  console.log(`  catalogue: ${catalogueTitles.join(" / ")}`);

  await tap(page, "Enroll", { wait: 4500 });
  await semantics();
  await shot(page, "04-courses-after-enroll");

  const afterCourses = (await nodes(page)).map((n) => n.label).join(" ~ ");
  const coursesLive = /enrolled|continue|start learning/i.test(afterCourses);
  check("Courses tab reflects the enrolment immediately", coursesLive,
        coursesLive ? "tile switched state" : `labels: ${afterCourses.slice(0, 220)}`);

  console.log("\n4. THE FIX: switch to Home — no relaunch — and it must show the course");
  await tap(page, "Home", { exact: true, wait: 4500 });
  await semantics();
  await shot(page, "05-home-after-enroll");

  labels = (await nodes(page)).map((n) => n.label).join(" ~ ");
  const stillEmpty = /no courses yet|enroll in courses to add them/i.test(labels);
  // The absence of the empty state is NOT enough: a Home that rendered
  // nothing at all would also lack it. Require the course itself by name.
  // Match whole card titles, not substrings of the joined blob: the legacy
  // "networking" course id is a substring of the Network Professional
  // card's own subtitle ("...modern networking...").
  const homeTitles = (await nodes(page)).map((n) => n.label.split(NL)[0].trim());
  const onHome = catalogueTitles.filter((t) => homeTitles.includes(t));
  check("Home is no longer showing the empty state", !stillEmpty,
        stillEmpty ? "STILL says 'No courses yet' — the fix did not take" : "empty state gone");
  // Home was verified empty before the enrolment, so a course appearing here
  // can only have come from it. Exactly one: more would mean Home is listing
  // the catalogue rather than the enrolments.
  check("Home lists exactly the one course just enrolled in", onHome.length === 1,
        onHome.length === 1 ? `"${onHome[0]}" under MY COURSES`
                            : `matched ${onHome.length}: ${onHome.join(" / ") || "none"}`);

  console.log("\n  Home labels:", labels.slice(0, 500));

  // Wait for recordLogin() to land before comparing tabs. Without this the
  // check is a coin flip: ServerClock has to round-trip before the streak is
  // written, and a run where both tabs read 0 proves nothing either way.
  let homeStreak = 0;
  for (let i = 0; i < 20; i++) {
    const m = (await nodes(page)).map((n) => n.label).join(" ~ ").match(/([0-9]+) day streak/i);
    homeStreak = m ? parseInt(m[1], 10) : 0;
    if (homeStreak > 0) break;
    await sleep(1000);
    await semantics();
  }
  check("Home's streak was written this session", homeStreak > 0,
        homeStreak > 0 ? `${homeStreak} day streak` : "still 0 after 20s — recordLogin never landed");

  console.log("\n5. Profile stats are live too");
  await tap(page, "Profile", { exact: true, wait: 4000 });
  await semantics();
  await shot(page, "06-profile");
  const profLabels = (await nodes(page)).map((n) => n.label.trim());
  const prof = profLabels.join(" ~ ");
  check("Profile rendered its stats row", /lesson|badge|day|streak/i.test(prof),
        prof.slice(0, 200));

  // The stats row renders four values, then their four captions. Its streak
  // must agree with the one Home is showing — on the pre-fix build Profile's
  // one-shot read ran before recordLogin() had written anything, so Home said
  // "1 day streak!" while Profile sat on 0 for the whole session.
  const capIdx = profLabels.indexOf("Lessons");
  const profStreak = capIdx >= 4 ? profLabels[capIdx - 2] : "(not found)";
  const streakLive = profStreak === String(homeStreak);
  check("Profile's streak agrees with Home's", streakLive,
        streakLive ? `both show ${homeStreak}` : `Profile read "${profStreak}" while Home showed ${homeStreak}`);

  console.log("\n─────────────  RESULT  ─────────────");
  const failed = results.filter((r) => !r.pass);
  results.forEach((r) => console.log(`${r.pass ? "  PASS" : "  FAIL"}  ${r.name}`));
  console.log(failed.length ? `\n${failed.length} CHECK(S) FAILED` : "\nALL CHECKS PASSED");

  await browser.close();
  process.exit(failed.length ? 1 : 0);
})().catch(async (e) => {
  console.error("\nSCRIPT ERROR:", e.message);
  process.exit(2);
});
