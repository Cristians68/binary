/**
 * Runs probe_rules.js inside a Chrome page, because the shell in this
 * environment cannot reach googleapis.com while Chrome can.
 *
 * Serve any page on 127.0.0.1:8099 first (the built web app works):
 *   cd build/web && python -m http.server 8099
 */
const fs = require('fs');
const path = require('path');
const puppeteer = require('../screenshots/node_modules/puppeteer-core');

const CHROME = process.env.CHROME_PATH
  || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const ORIGIN = process.env.PROBE_ORIGIN || 'http://127.0.0.1:8099/';

(async () => {
  const probe = fs.readFileSync(path.join(__dirname, 'probe_rules.js'), 'utf8');
  const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new' });
  const page = await browser.newPage();
  let failed = false;
  page.on('console', (m) => {
    const t = m.text();
    if (t.includes('Failed to load resource')) return;   // expected on every denial
    if (/^FAIL|NOT DENIED|PROVE NOTHING|prove NOTHING/.test(t)) failed = true;
    console.log(t);
  });
  await page.goto(ORIGIN, { waitUntil: 'domcontentloaded', timeout: 120000 });
  await new Promise((r) => setTimeout(r, 3000));
  await page.evaluate(probe);
  await new Promise((r) => setTimeout(r, 8000));
  await browser.close();
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error('RUNNER ERROR:', e.message); process.exit(2); });
