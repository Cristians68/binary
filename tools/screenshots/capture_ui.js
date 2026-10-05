// Capture the local Flutter design fixture, with no production sign-in or writes.
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const puppeteer = require('puppeteer-core');
const root = path.resolve(__dirname, '../../build/ui_preview');
const out = path.resolve(__dirname, '../../.dart_tool/ui-review');
const types = { '.html': 'text/html', '.js': 'application/javascript', '.json': 'application/json',
  '.wasm': 'application/wasm', '.png': 'image/png', '.ttf': 'font/ttf', '.otf': 'font/otf' };
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const server = http.createServer((req, res) => {
  const pathname = new URL(req.url, 'http://localhost').pathname;
  const file = path.resolve(root, '.' + decodeURIComponent(pathname === '/' ? '/index.html' : pathname));
  if (!file.startsWith(root + path.sep)) { res.writeHead(403).end(); return; }
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404).end(); return; }
    res.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
    res.end(data);
  });
});
async function tap(page, label) {
  const bounds = await page.evaluate(label => {
    const nodes = [...document.querySelectorAll('flt-semantics')];
    const node = nodes.find(n => (n.getAttribute('aria-label') || n.textContent || '').trim() === label);
    if (!node) return null;
    const r = node.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  }, label);
  if (!bounds) throw new Error('Missing control: ' + label);
  await page.mouse.click(bounds.x, bounds.y);
  await sleep(500);
}
(async () => {
  let browser;
  try {
    fs.mkdirSync(out, { recursive: true });
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    browser = await puppeteer.launch({
      executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true,
      args: ['--force-color-profile=srgb'],
    });
    const page = await browser.newPage();
    const errors = [];
    const engineFontFetches = new Set();
    page.on('pageerror', error => { errors.push(error.message); console.error('[pageerror]', error.message); });
    page.on('console', message => {
      const value = message.text();
      if (/exception|overflowed|error|failed/i.test(value)) {
        console.log('[browser]', value);
        if (/EXCEPTION CAUGHT|overflowed by/.test(value)) errors.push(value);
      }
    });
    // A bundled font is a claim about the network, so check the network.
    // google_fonts silently falls back to fonts.gstatic.com for any weight it
    // cannot find locally, and that fallback is invisible on screen: the text
    // still renders, just after a round trip that leaks the user's IP.
    //
    // Only Inter fails the run. Roboto and the Noto emoji faces are fetched
    // from the same host here, but those are the Flutter web engine's own
    // glyph fallbacks rather than google_fonts, nothing in this repository
    // can stop them, and they do not exist on iOS — which is what ships.
    // Failing on those would hold the gate permanently red for a condition
    // the product does not have, so they are printed instead.
    page.on('request', request => {
      const url = request.url();
      if (!/fonts\.(gstatic|googleapis)\.com/.test(url)) return;
      if (/[/]inter[/]/i.test(url)) {
        errors.push('Inter fetched at runtime instead of bundled: ' + url);
      } else {
        engineFontFetches.add(new URL(url).pathname.split('/')[2] || url);
      }
    });
    page.on('requestfailed', request => console.error('[request]', request.url(), request.failure()?.errorText));
    const fixtures = [
      { name: '01-onboarding', screen: 'onboarding' },
      { name: '02-onboarding-practice', screen: 'onboarding', advance: true },
      { name: '03-home', screen: 'home' },
      { name: '04-library', screen: 'courses' },
      { name: '05-home-dark', screen: 'home', dark: true },
      { name: '06-library-desktop', screen: 'courses', width: 1280, height: 900 },
      { name: '07-lesson', screen: 'lesson', sample: true },
      { name: '08-quiz', screen: 'quiz' },
      { name: '09-progress', screen: 'progress' },
      { name: '10-downloads', screen: 'offline' },
      { name: '11-welcome', screen: 'welcome' },
      { name: '12-paywall', screen: 'paywall' },
      { name: '13-legal', screen: 'legal' },
      { name: '14-startup-recovery', screen: 'startup-error' },
      ...['welcome', 'home', 'courses', 'progress', 'paywall', 'onboarding', 'legal'].map(screen => ({
        name: 'large-text-' + screen, screen, width: 320, height: 568, scale: 2,
      })),
      ...['welcome', 'paywall'].map(screen => ({
        name: 'large-text-' + screen + '-actions', screen, width: 320,
        height: 568, scale: 2, scrollEnd: true,
      })),
    ];
    for (const fixture of fixtures.filter(f => !process.argv[2] || f.name === process.argv[2])) {
      await page.setViewport({ width: fixture.width || 440, height: fixture.height || 956, deviceScaleFactor: 3 });
      await page.goto('http://127.0.0.1:' + server.address().port + '/?screen=' + fixture.screen +
        '&dark=' + (fixture.dark ? 1 : 0) + '&scale=' + (fixture.scale || 1), { waitUntil: 'domcontentloaded' });
      await page.waitForSelector('flt-glass-pane', { timeout: 30000 });
      await page.waitForFunction(() => {
        document.querySelector('flt-semantics-placeholder')?.click();
        return document.querySelectorAll('flt-semantics').length > 4;
      }, { timeout: 45000 });
      await sleep(1500);
      if (fixture.sample) await tap(page, 'Practice with a sample');
      if (fixture.advance) { await tap(page, 'Continue'); await tap(page, 'DNS'); }
      if (fixture.scrollEnd) {
        await page.mouse.move(160, 300);
        const lastAction = fixture.screen === 'welcome'
          ? 'Already learning with us? Log in' : 'Privacy Policy';
        let visible = false;
        // Flutter limits a single wheel event. A giant delta can leave the
        // capture halfway down the screen, so verify the final control itself.
        for (let attempt = 0; attempt < 70; attempt++) {
          visible = await page.evaluate(label => {
            const node = [...document.querySelectorAll('flt-semantics')].find(n =>
              (n.getAttribute('aria-label') || n.textContent || '').trim() === label);
            if (!node) return false;
            const bounds = node.getBoundingClientRect();
            return bounds.height > 0 && bounds.top >= 0 && bounds.bottom <= innerHeight;
          }, lastAction);
          if (visible) break;
          await page.mouse.wheel({deltaY: 800});
          await sleep(200);
        }
        if (!visible) {
          await page.screenshot({path: path.join(out, fixture.name + '-failed.png')});
          const bounds = await page.evaluate(label => [...document.querySelectorAll('flt-semantics')]
            .filter(n => (n.getAttribute('aria-label') || n.textContent || '').trim() === label)
            .map(n => ({label: n.getAttribute('aria-label') || n.textContent,
              bounds: n.getBoundingClientRect().toJSON()})), lastAction);
          throw new Error('Scroll check did not reach: ' + lastAction + ' ' + JSON.stringify(bounds));
        }
      }
      await page.screenshot({ path: path.join(out, fixture.name + '.png') });
      const labels = await page.evaluate(() => [...document.querySelectorAll('flt-semantics')]
        .map(n => n.getAttribute('aria-label') || n.textContent).filter(Boolean));
      fs.writeFileSync(path.join(out, fixture.name + '.json'), JSON.stringify(labels, null, 2));
      console.log('Captured ' + fixture.name);
    }
    if (engineFontFetches.size) {
      console.log('[web-only engine fallback fonts, not shipped on iOS] ' +
        [...engineFontFetches].join(', '));
    }
    if (errors.length) throw new Error(errors.join('\n'));
    console.log('Preview screenshots: ' + out);
  } finally {
    if (browser) await browser.close();
    server.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
