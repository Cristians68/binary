// Read-only browser checks against the assembled local website.
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const assert = require('node:assert/strict');
const puppeteer = require('puppeteer-core');
const root = path.resolve(__dirname, '../../public');
const output = path.resolve(__dirname, '../../.dart_tool/site-review');
const types = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.png': 'image/png', '.svg': 'image/svg+xml', '.wasm': 'application/wasm' };
const server = http.createServer((req, res) => {
  let filename = path.resolve(root, '.' + decodeURIComponent(new URL(req.url, 'http://localhost').pathname));
  if (!filename.startsWith(root + path.sep) && filename !== root) return res.writeHead(403).end();
  if (fs.existsSync(filename) && fs.statSync(filename).isDirectory()) filename = path.join(filename, 'index.html');
  if (!fs.existsSync(filename) && !path.extname(filename)) filename += '.html';
  fs.readFile(filename, (error, data) => {
    if (error) return res.writeHead(404).end();
    res.setHeader('Content-Type', types[path.extname(filename)] || 'application/octet-stream');
    res.end(data);
  });
});

(async () => {
  let browser;
  try {
    fs.mkdirSync(output, { recursive: true });
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    browser = await puppeteer.launch({
      executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
      headless: true,
      args: ['--force-color-profile=srgb'],
    });
    const page = await browser.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    const base = 'http://127.0.0.1:' + server.address().port;
    for (const mode of ['light', 'dark']) {
      await page.emulateMediaFeatures([{ name: 'prefers-color-scheme', value: mode }, { name: 'prefers-reduced-motion', value: 'reduce' }]);
      for (const viewport of [{ width: 1280, height: 900 }, { width: 390, height: 844 }, { width: 320, height: 568, large: true }]) {
        await page.setViewport({ width: viewport.width, height: viewport.height, deviceScaleFactor: 1 });
        await page.goto(base, { waitUntil: 'networkidle0' });
        if (viewport.large) await page.evaluate(() => document.documentElement.style.fontSize = '200%');
        const report = await page.evaluate(() => {
          const css = getComputedStyle(document.documentElement);
          const color = name => css.getPropertyValue(name).trim();
          const luminance = hex => {
            const values = hex.replace('#', '').match(/../g).map(x => parseInt(x, 16) / 255)
              .map(x => x <= .04045 ? x / 12.92 : ((x + .055) / 1.055) ** 2.4);
            return values[0] * .2126 + values[1] * .7152 + values[2] * .0722;
          };
          const ratio = (a, b) => (Math.max(luminance(a), luminance(b)) + .05) / (Math.min(luminance(a), luminance(b)) + .05);
          const contrast = [];
          for (const bg of ['--bg', '--surface', '--card']) {
            for (const fg of ['--text', '--subtext', '--accent-text']) contrast.push({ fg, bg, ratio: ratio(color(fg), color(bg)), min: 4.5 });
            contrast.push({ fg: '--outline', bg, ratio: ratio(color('--outline'), color(bg)), min: 3 });
          }
          contrast.push({ fg: 'button text', bg: '--brand', ratio: ratio('#ffffff', color('--brand')), min: 4.5 });
          return {
            contrast,
            overflow: [...document.querySelectorAll('main *')].filter(el => {
              const r = el.getBoundingClientRect();
              return r.width && (r.right > innerWidth + 1 || r.left < -1);
            }).map(el => el.tagName + '.' + el.className),
            missingAnchors: [...document.querySelectorAll('a[href^="#"]')].map(a => a.getAttribute('href')).filter(id => !document.querySelector(id)),
            courses: document.querySelectorAll('#courses article').length,
          };
        });
        assert.deepEqual(report.overflow, [], JSON.stringify(report.overflow));
        assert.deepEqual(report.missingAnchors, []);
        assert.equal(report.courses, 7);
        for (const c of report.contrast) assert.ok(c.ratio >= c.min, `${mode} ${c.fg} on ${c.bg}: ${c.ratio}`);
        const name = `${mode}-${viewport.width}${viewport.large ? '-large' : ''}`;
        await page.screenshot({ path: path.join(output, name + '.png') });
        const summary = await page.$('.recall-demo summary');
        await summary.evaluate(el => el.scrollIntoView({ block: 'center' }));
        await summary.focus();
        await page.keyboard.press('Enter');
        assert.equal(await page.$eval('.recall-demo details', el => el.open), true);
        await page.screenshot({ path: path.join(output, name + '-recall.png') });
        await page.keyboard.press('Enter');
        assert.equal(await page.$eval('.recall-demo details', el => el.open), false);
        console.log(`Verified ${name}: layout, palette contrast, seven courses, keyboard recall`);
      }
    }
    // Native details must still work without the enhancement script.
    await page.setJavaScriptEnabled(false);
    await page.goto(base, { waitUntil: 'domcontentloaded' });
    await page.click('.recall-demo summary');
    assert.equal(await page.$eval('.recall-demo details', el => el.open), true);
    for (const file of ['index.html', 'support.html', 'privacy.html', 'terms.html', 'accessibility.html']) {
      const response = await page.goto(base + '/' + file, { waitUntil: 'domcontentloaded' });
      assert.equal(response.status(), 200);
      assert.equal(await page.$$eval('h1', nodes => nodes.length), 1, file);
    }
    assert.deepEqual(errors, []);
    console.log('Website checks passed, including JavaScript-disabled recall and all public pages.');
  } finally {
    if (browser) await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
