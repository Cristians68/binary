// Capture the local Flutter design fixture, with no production sign-in or writes.
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const puppeteer = require('puppeteer-core');
const root = path.resolve(__dirname, '../..', process.env.BINARY_UI_PREVIEW_DIR || 'build/ui_preview');
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
async function reveal(page, label) {
  await page.mouse.move(160, 300);
  for (let attempt = 0; attempt < 40; attempt++) {
    const bounds = await page.evaluate(label => {
      const node = [...document.querySelectorAll('flt-semantics')].find(n =>
        (n.getAttribute('aria-label') || n.textContent || '').trim() === label);
      if (!node) return null;
      const r = node.getBoundingClientRect();
      return { top: r.top, bottom: r.bottom, height: r.height };
    }, label);
    if (bounds && bounds.height > 0 && bounds.top >= 0 && bounds.bottom <= page.viewport().height) {
      await sleep(500);
      return;
    }
    await page.mouse.wheel({ deltaY: bounds && bounds.top < 0 ? -200 : 200 });
    await sleep(150);
  }
  throw new Error('Could not reach control: ' + label);
}
async function tapVisible(page, label) {
  await reveal(page, label);
  await tap(page, label);
}
async function scrollQuizToEnd(page) {
  // Flutter may expose only the visible part of a clipped semantics node.
  // Scroll these bounded, synthetic fixtures fully before capturing their
  // final controls, then verify the control by actually activating it.
  await page.mouse.move(160, 300);
  for (let i = 0; i < 20; i++) {
    await page.mouse.wheel({ deltaY: 600 });
    await sleep(100);
  }
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
      { name: '15-review', screen: 'review' },
      { name: '16-review-feedback', screen: 'review', reviewAnswer: true },
      { name: '17-review-summary', screen: 'review', reviewAnswer: true, reviewFinish: true },
      { name: '18-review-empty', screen: 'review-empty' },
      { name: '19-onboarding-skills', screen: 'onboarding', onboardingSkills: true },
      { name: '20-quiz-results', screen: 'quiz-feedback', quizFeedback: true },
      { name: '21-quiz-mistakes', screen: 'quiz-feedback', quizFeedback: true, quizMistakes: true },
      { name: '22-quiz-mistakes-dark', screen: 'quiz-feedback', quizFeedback: true, quizMistakes: true, dark: true },
      { name: '23-quiz-answer-dark', screen: 'quiz-feedback', quizAnswer: true, dark: true },
      { name: '24-login', screen: 'login', focusField: true },
      { name: '25-signup', screen: 'signup' },
      { name: '26-profile', screen: 'profile' },
      { name: '27-profile-feedback', screen: 'profile', profileFeedback: true },
      { name: '28-navigation-desktop', screen: 'navigation', width: 1280, height: 900 },
      { name: '29-login-dark', screen: 'login', dark: true, focusField: true },
      { name: '30-profile-dark', screen: 'profile', dark: true },
      { name: '31-lesson-dark', screen: 'lesson', sample: true, dark: true },
      { name: '32-recall', screen: 'recall', recall: true },
      { name: '33-recall-answer', screen: 'recall', recall: true, recallAnswer: true },
      { name: '34-recall-summary', screen: 'recall', recall: true, recallSummary: true },
      { name: '35-recall-dark', screen: 'recall', recall: true, recallAnswer: true, dark: true },
      { name: '36-focused-practice', screen: 'quiz-feedback', quizFeedback: true, focused: true },
      { name: '37-focused-summary', screen: 'quiz-feedback', quizFeedback: true, focused: true, focusedSummary: true },
      { name: 'large-text-recall', screen: 'recall', recall: true, recallAnswer: true, width: 320, height: 568, scale: 2 },
      { name: 'large-text-recall-summary', screen: 'recall', recall: true, recallSummary: true, width: 320, height: 568, scale: 2 },
      { name: 'large-text-focused', screen: 'quiz-feedback', quizFeedback: true, focused: true, focusedSummary: true, width: 320, height: 568, scale: 2 },
      { name: 'large-text-login', screen: 'login', width: 320, height: 568, scale: 2 },
      { name: 'large-text-profile', screen: 'profile', width: 320, height: 568, scale: 2 },
      { name: 'large-text-quiz-answer', screen: 'quiz-feedback', quizAnswer: true,
        width: 320, height: 568, scale: 2 },
      { name: 'large-text-quiz-results', screen: 'quiz-feedback', quizFeedback: true,
        width: 320, height: 568, scale: 2 },
      { name: 'large-text-quiz-mistakes', screen: 'quiz-feedback', quizFeedback: true, quizMistakes: true,
        width: 320, height: 568, scale: 2 },
      { name: 'large-text-quiz-results-actions', screen: 'quiz-feedback', quizFeedback: true,
        quizActions: true, width: 320, height: 568, scale: 2 },
      { name: 'large-text-quiz-mistakes-actions', screen: 'quiz-feedback', quizFeedback: true,
        quizMistakes: true, quizActions: true, width: 320, height: 568, scale: 2 },
      ...['welcome', 'home', 'courses', 'progress', 'paywall', 'onboarding', 'legal'].map(screen => ({
        name: 'large-text-' + screen, screen, width: 320, height: 568, scale: 2,
      })),
      ...['welcome', 'paywall'].map(screen => ({
        name: 'large-text-' + screen + '-actions', screen, width: 320,
        height: 568, scale: 2, scrollEnd: true,
      })),
      { name: 'large-text-review', screen: 'review', width: 320, height: 568, scale: 2 },
      { name: 'large-text-onboarding-skills', screen: 'onboarding', onboardingSkills: true,
        width: 320, height: 568, scale: 2 },
      { name: 'large-text-review-empty', screen: 'review-empty', width: 320, height: 568, scale: 2 },
      { name: 'large-text-review-summary', screen: 'review', width: 320, height: 568, scale: 2,
        reviewAnswer: true, reviewFinish: true },
    ];
    for (const fixture of fixtures.filter(f => !process.argv[2] || f.name === process.argv[2] ||
      (process.argv[2] === '--quiz-feedback' && (f.quizFeedback || f.quizAnswer)) ||
      (process.argv[2] === '--polish' && ['04-library', '07-lesson', '26-profile', '30-profile-dark', '31-lesson-dark', '35-recall-dark', 'large-text-courses', 'large-text-login'].includes(f.name)) ||
      (process.argv[2] === '--practice' && (f.recall || f.focused)))) {
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
      if (fixture.focusField) { await page.click('input'); await sleep(300); }
      if (fixture.profileFeedback) await tapVisible(page, 'Send feedback');
      if (fixture.advance) { await tap(page, 'Continue'); await tap(page, 'DNS'); }
      if (fixture.onboardingSkills) { await tap(page, 'Continue'); await tap(page, 'Continue'); }
      if (fixture.recall) {
        await tapVisible(page, 'Practice recall');
        if (fixture.recallAnswer) await tapVisible(page, 'Reveal answer');
        if (fixture.recallSummary) {
          await tapVisible(page, 'Reveal answer');
          await tapVisible(page, 'Needs practice');
          await tapVisible(page, 'Reveal answer');
          await tapVisible(page, 'Got it');
          if (fixture.scale) await scrollQuizToEnd(page);
        }
      }
      if (fixture.quizAnswer) {
        await tapVisible(page, 'DHCP');
        if (fixture.scale) await scrollQuizToEnd(page);
      }
      if (fixture.quizFeedback) {
        await tapVisible(page, 'DHCP');
        await tapVisible(page, 'Next question');
        await tapVisible(page, 'Check the cable and link lights');
        await tapVisible(page, 'See results');
        if (fixture.quizMistakes) await tapVisible(page, 'Review mistakes (1)');
        if (fixture.quizActions) await scrollQuizToEnd(page);
        if (fixture.focused) {
          await tapVisible(page, 'Practice missed questions (1)');
          if (fixture.focusedSummary) {
            await tapVisible(page, 'DNS');
            await tapVisible(page, 'Finish round');
            if (fixture.scale) await scrollQuizToEnd(page);
          }
        }
      }
      if (fixture.reviewAnswer) {
        // At large text sizes, answers are below the initial viewport.
        await page.mouse.move(160, 320);
        for (let attempt = 0; attempt < 25; attempt++) {
          const visible = await page.evaluate(() => [...document.querySelectorAll('flt-semantics')]
            .some(n => n.getAttribute('aria-label') === 'Use feedback to adapt' &&
              n.getBoundingClientRect().bottom <= innerHeight && n.getBoundingClientRect().top >= 0));
          if (visible) break;
          await page.mouse.wheel({deltaY: 300});
          await sleep(150);
        }
        await tap(page, 'Use feedback to adapt');
      }
      if (fixture.reviewFinish) await tap(page, 'Finish');
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
      if (fixture.recallSummary) {
        await tapVisible(page, 'Practice remaining (1)');
        await page.waitForFunction(() => [...document.querySelectorAll('flt-semantics')]
          .some(n => (n.getAttribute('aria-label') || n.textContent || '').includes('Round 2 · Card 1 of 1')));
      }
      if (fixture.focusedSummary) {
        await tapVisible(page, 'Back to quiz results');
        await page.waitForFunction(() => [...document.querySelectorAll('flt-semantics')]
          .some(n => (n.getAttribute('aria-label') || n.textContent || '').includes('You scored 1 out of 2')));
      }
      if (fixture.quizActions) {
        await tap(page, 'Try again');
        await page.waitForFunction(() => [...document.querySelectorAll('flt-semantics')]
          .some(n => (n.getAttribute('aria-label') || n.textContent || '').trim() === 'Question 1 of 2' &&
            n.getBoundingClientRect().top >= 0 && n.getBoundingClientRect().bottom <= innerHeight));
      }
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
