// Capture real Flutter widgets, then frame the untouched screen images for
// App Store Connect. Optional --input accepts corresponding iPhone captures.
// All generated images and exported course content remain outside Git.
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const puppeteer = require('puppeteer-core');

const root = path.resolve(__dirname, '../..');
const build = path.join(root, 'build/ui_preview');
const args = process.argv.slice(2);
function option(name, fallback) {
  const index = args.indexOf(name);
  if (index < 0) return fallback;
  if (!args[index + 1] || args[index + 1].startsWith('--')) {
    throw new Error('Missing value for ' + name);
  }
  return path.resolve(args[index + 1]);
}
const out = option('--output', path.join(root, '.dart_tool/app-store'));
const input = option('--input', null);
const raw = path.join(out, 'raw');
const upload = path.join(out, 'iphone-1320x2868');
const screens = path.join(out, 'iphone-screens');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
const escape = value => value.replace(/[&<>"']/g, character =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[character]);
const dataUri = file => 'data:image/png;base64,' + fs.readFileSync(file).toString('base64');

const slides = [
  { file: '01-home', screen: 'home', ready: 'Continue learning', theme: 'navy',
    title: ['Build your', 'IT confidence.'],
    subtitle: 'A clear next step, every time you open the app.' },
  { file: '02-courses', screen: 'courses', ready: 'Courses', theme: 'ice',
    title: ['A new skill.', 'A new direction.'],
    subtitle: 'Explore cloud, networking, cybersecurity and more.' },
  { file: '03-flashcards', screen: 'lesson', ready: 'Flashcard', theme: 'blue',
    title: ['Learn a little.', 'Remember more.'],
    subtitle: 'Make time for focused flashcard lessons.' },
  { file: '04-quiz', screen: 'quiz', ready: 'Question 1', theme: 'mint',
    title: ['Test what', 'you know.'],
    subtitle: 'Put each lesson into practice with quizzes.' },
  { file: '05-progress', screen: 'progress', ready: 'Progress', theme: 'ice',
    title: ['Small steps.', 'Real progress.'],
    subtitle: 'Track your learning. Keep your streak going.' },
  { file: '06-dark-mode', screen: 'home', dark: true, ready: 'Continue learning', theme: 'night',
    title: ['Your goals.', 'Your rhythm.'],
    subtitle: 'Settle into your next lesson with dark mode.' },
];

const fonts = [
  ['Inter-Regular.otf', 400], ['Inter-SemiBold.otf', 600], ['Inter-ExtraBold.otf', 800],
].map(([file, weight]) => `@font-face{font-family:Inter;font-weight:${weight};src:url(data:font/otf;base64,${
  fs.readFileSync(path.join(root, 'google_fonts', file)).toString('base64')})}`).join('\n');

// OS chrome is a local rendering, not evidence of a physical device capture.
// Do not overlay it on supplied native images: their pixels stay untouched.
function iphoneScreen(slide, screenshot) {
  return `<!doctype html><html><head><style>${fonts}
    *{box-sizing:border-box}body{margin:0;background:#000}
    .screen{position:relative;width:440px;height:956px;transform:scale(3);
      transform-origin:top left;color:${slide.dark ? '#fff' : '#000'};overflow:hidden}
    img{position:absolute;inset:0;width:440px;height:956px}
    .time{position:absolute;left:41px;top:18px;font:600 17px Inter,sans-serif;letter-spacing:-.5px}
    .island{position:absolute;left:157px;top:11px;width:126px;height:37px;
      background:#000;border-radius:22px}
    .camera{position:absolute;right:12px;top:12px;width:12px;height:12px;
      border-radius:50%;background:radial-gradient(circle at 45% 40%,#0c1830 0,#070c17 45%,#020308 70%);
      border:1px solid #0c111a}
    .status{position:absolute;right:32px;top:21px;display:flex;gap:6px;align-items:center;height:14px}
    .signal{display:flex;align-items:flex-end;gap:1.5px;height:12px}
    .signal i{width:3px;background:currentColor;border-radius:1px}
    .signal i:nth-child(1){height:4px}.signal i:nth-child(2){height:6px}
    .signal i:nth-child(3){height:9px}.signal i:nth-child(4){height:12px}
    .wifi{width:16px;height:13px}
    .battery{width:25px;height:12px;border:1px solid currentColor;border-radius:3px;position:relative}
    .battery::before{content:'';position:absolute;inset:1.5px;border-radius:1px;background:currentColor}
    .battery::after{content:'';position:absolute;right:-3px;top:3px;width:2px;height:4px;
      background:currentColor;border-radius:0 1px 1px 0;opacity:.5}
    .home{position:absolute;left:153px;bottom:8px;width:134px;height:5px;background:currentColor;border-radius:3px}
  </style></head><body><main class="screen"><img src="${screenshot}" alt="App screen">
    <div class="time">9:41</div><div class="island"><div class="camera"></div></div>
    <div class="status"><div class="signal"><i></i><i></i><i></i><i></i></div>
      <svg class="wifi" viewBox="0 0 16 13" fill="currentColor"><path d="M0 3.2a12.6 12.6 0 0 1 16 0l-1.8 2A9.8 9.8 0 0 0 1.8 5.2ZM3 6.5a7.8 7.8 0 0 1 10 0l-1.8 2a5.1 5.1 0 0 0-6.4 0ZM6 10a3.1 3.1 0 0 1 4 0L8 12.3Z"/></svg>
      <div class="battery"></div></div><div class="home"></div>
  </main></body></html>`;
}

function poster(slide, index, screenshot) {
  return `<!doctype html><html><head><meta charset="utf-8"><style>
    ${fonts}
    *{box-sizing:border-box}body{margin:0;font-family:Inter,sans-serif}
    .poster{width:1320px;height:2868px;position:relative;overflow:hidden;
      background:var(--bg);color:var(--ink);--bg:#edf2fa;--ink:#102345;
      --accent:#3358ee;--muted:#4a5d79;--line:rgba(38,69,134,.10)}
    .navy{--bg:#102447;--ink:#fff;--accent:#b6f3dd;--muted:#c3d1e5;--line:rgba(178,230,225,.13)}
    .blue{--bg:#3659e8;--ink:#fff;--accent:#c4f9e7;--muted:#e3eaff;--line:rgba(234,242,255,.18)}
    .mint{--bg:#daf3e9;--ink:#102e31;--accent:#25665e;--muted:#456962;--line:rgba(39,112,92,.12)}
    .night{--bg:#0b1225;--ink:#f6f8ff;--accent:#adbefc;--muted:#b6c3e3;--line:rgba(143,168,234,.15)}
    .orbit{position:absolute;width:1660px;height:1660px;left:-170px;top:1180px;
      border:2px solid var(--line);border-radius:50%;pointer-events:none}
    .orbit::before,.orbit::after{content:'';position:absolute;inset:110px;border:2px solid var(--line);border-radius:50%}
    .orbit::after{inset:220px}.dot{position:absolute;width:28px;height:28px;
      border-radius:50%;background:var(--accent);left:43px;top:1060px;opacity:.65}
    .brand{position:absolute;top:90px;left:102px;display:flex;align-items:center;gap:20px;
      font-size:29px;font-weight:600;letter-spacing:4px}
    .mark{display:grid;place-items:center;width:66px;height:66px;border-radius:20px;
      border:2px solid var(--line);background:var(--accent);color:var(--bg);
      font-size:34px;font-weight:800;letter-spacing:-4px;padding-right:4px}
    .count{position:absolute;right:108px;top:109px;font-size:24px;letter-spacing:5px;color:var(--muted)}
    h1{position:absolute;top:218px;left:100px;right:70px;margin:0;font-size:112px;
      line-height:1.055;letter-spacing:-6px;font-weight:800}
    h1 span{color:var(--accent)}
    .subtitle{position:absolute;top:482px;left:105px;right:85px;margin:0;
      font-size:34px;line-height:1.45;letter-spacing:-.5px;color:var(--muted)}
    .device{position:absolute;left:140px;top:620px;width:1040px;padding:17px;
      border:3px solid #9099a8;border-radius:135px;background:#080a0e;
      box-shadow:0 28px 70px rgba(4,15,39,.26),inset 0 0 0 3px #333e51,
        inset 0 0 0 6px #131a28}
    .device img{display:block;width:1000px;height:auto;border-radius:116px}
    .button{position:absolute;background:linear-gradient(90deg,#344258,#8d96a3,#263346);
      width:6px;border-radius:3px;left:-7px;border:1px solid #46546a}
    .action{top:230px;height:62px}.volume-up{top:343px;height:130px}
    .volume-down{top:498px;height:130px}.power{left:auto;right:-7px;top:410px;height:178px}
    .camera-control{left:auto;right:-6px;top:1390px;height:105px;width:5px}
  </style></head><body><main class="poster ${slide.theme}">
    <div class="orbit"></div><div class="dot"></div>
    <div class="brand"><span class="mark">b1</span>B1NARY ACADEMY</div>
    <div class="count">${String(index + 1).padStart(2, '0')} / 06</div>
    <h1>${escape(slide.title[0])}<br><span>${escape(slide.title[1])}</span></h1>
    <p class="subtitle">${escape(slide.subtitle)}</p>
    <div class="device"><i class="button action"></i><i class="button volume-up"></i>
      <i class="button volume-down"></i><i class="button power"></i><i class="button camera-control"></i>
      <img src="${screenshot}" alt="${escape(slide.screen)} screen from B1nary"></div>
  </main></body></html>`;
}

function localServer() {
  const types = { '.html': 'text/html', '.js': 'application/javascript', '.json': 'application/json',
    '.wasm': 'application/wasm', '.png': 'image/png', '.ttf': 'font/ttf', '.otf': 'font/otf' };
  return http.createServer((request, response) => {
    let file;
    try {
      const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
      file = path.resolve(build, '.' + (pathname === '/' ? '/index.html' : pathname));
    } catch { response.writeHead(400).end(); return; }
    if (!file.startsWith(build + path.sep)) { response.writeHead(403).end(); return; }
    fs.readFile(file, (error, data) => {
      if (error) { response.writeHead(404).end(); return; }
      response.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
      response.end(data);
    });
  });
}

(async () => {
  let browser;
  let server;
  try {
    fs.mkdirSync(raw, { recursive: true });
    fs.mkdirSync(upload, { recursive: true });
    fs.mkdirSync(screens, { recursive: true });
    if (!input) {
      if (!fs.existsSync(path.join(build, 'index.html'))) throw new Error('Build ui_preview.dart first.');
      server = localServer();
      await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    }
    browser = await puppeteer.launch({
      executablePath: process.env.CHROME_PATH || 'C:/Program Files/Google/Chrome/Application/chrome.exe',
      headless: true, args: ['--force-color-profile=srgb'],
    });
    const page = await browser.newPage();
    const failures = [];
    page.on('pageerror', error => failures.push(error.message));
    page.on('console', message => {
      if (/EXCEPTION CAUGHT|overflowed by/.test(message.text())) failures.push(message.text());
    });
    for (const slide of slides) {
      const file = path.join(raw, slide.file + '.png');
      if (input) {
        const source = path.join(input, slide.file + '.png');
        if (!fs.existsSync(source)) throw new Error('Missing iPhone capture: ' + source);
        if (path.resolve(source) !== path.resolve(file)) fs.copyFileSync(source, file);
      } else {
        await page.setViewport({ width: 440, height: 956, deviceScaleFactor: 3 });
        await page.goto(`http://127.0.0.1:${server.address().port}/?store=1&screen=${slide.screen}&dark=${slide.dark ? 1 : 0}`,
          { waitUntil: 'domcontentloaded' });
        try {
          await page.waitForFunction(ready => {
            document.querySelector('flt-semantics-placeholder')?.click();
            return [...document.querySelectorAll('flt-semantics')].some(node =>
              (node.getAttribute('aria-label') || node.textContent || '').toLowerCase().includes(ready.toLowerCase()));
          }, { timeout: 30000 }, slide.ready);
        } catch (error) {
          await page.screenshot({ path: path.join(out, slide.file + '-capture-error.png') });
          throw new Error('Screen did not become ready: ' + slide.file, { cause: error });
        }
        await pause(1800);
        if (slide.screen === 'quiz') {
          // Select a real answer through the widget's UI so the capture shows
          // its feedback and explanation. Never paint a simulated answer state.
          const fixture = fs.readFileSync(path.join(__dirname, 'fixture_content.dart'), 'utf8');
          const content = JSON.parse(fixture.slice(fixture.indexOf('{'), fixture.lastIndexOf('}') + 1));
          const course = content.courses.find(course => course.id === 'binary-network-professional');
          const questions = course.modules.flatMap(module => module.quiz || []);
          const answer = await page.evaluate(questions => {
            const nodes = [...document.querySelectorAll('flt-semantics')];
            const label = node => (node.getAttribute('aria-label') || node.textContent || '').trim();
            const question = questions.find(question => nodes.some(node => label(node) === question.question));
            if (!question) return null;
            const node = nodes.find(node => label(node) === question.options[question.correctIndex]);
            if (!node) return null;
            const bounds = node.getBoundingClientRect();
            return { x: bounds.x + bounds.width / 2, y: bounds.y + bounds.height / 2 };
          }, questions);
          if (!answer) throw new Error('The quiz answer was not found in the visible screen.');
          await page.mouse.click(answer.x, answer.y);
          await page.waitForFunction(() => [...document.querySelectorAll('flt-semantics')]
            .some(node => /Next/.test(node.getAttribute('aria-label') || node.textContent || '')));
          await pause(350);
        }
        const labels = await page.evaluate(() => [...document.querySelectorAll('flt-semantics')]
          .map(node => node.getAttribute('aria-label') || node.textContent).filter(Boolean));
        if (labels.some(label => /Sample practice|content unavailable|Try again/i.test(label))) {
          throw new Error(slide.file + ' did not load the published screen content.');
        }
        await page.screenshot({ path: file });
        fs.writeFileSync(path.join(raw, slide.file + '.json'), JSON.stringify(labels, null, 2));
      }
      console.log('Captured ' + slide.file);
    }
    if (failures.length) throw new Error(failures.join('\n'));
    await page.setViewport({ width: 1320, height: 2868, deviceScaleFactor: 1 });
    for (const [index, slide] of slides.entries()) {
      const rawFile = path.join(raw, slide.file + '.png');
      const screenFile = path.join(screens, slide.file + '.png');
      if (input) {
        fs.copyFileSync(rawFile, screenFile);
      } else {
        await page.setContent(iphoneScreen(slide, dataUri(rawFile)));
        await page.evaluate(() => document.fonts.ready);
        await page.waitForFunction(() => [...document.images].every(image => image.complete && image.naturalWidth > 0));
        await page.screenshot({ path: screenFile, omitBackground: false });
      }
      await page.setContent(poster(slide, index, dataUri(screenFile)));
      await page.evaluate(() => document.fonts.ready);
      await page.waitForFunction(() => [...document.images].every(image => image.complete && image.naturalWidth > 0));
      const dimensions = await page.$eval('.device img', image => ({width: image.naturalWidth, height: image.naturalHeight}));
      if (Math.abs(dimensions.width / dimensions.height - 1320 / 2868) > 0.005) {
        throw new Error('Capture aspect ratio does not match the iPhone frame: ' + slide.file);
      }
      await page.screenshot({ path: path.join(upload, slide.file + '.png'), omitBackground: false });
      console.log('Rendered ' + slide.file + ' (1320 × 2868)');
    }

    const cards = slides.map(slide => `<figure><img src="iphone-1320x2868/${slide.file}.png"><figcaption>${escape(slide.file)}</figcaption></figure>`).join('');
    fs.writeFileSync(path.join(out, 'preview.html'), `<!doctype html><html><head><meta charset="utf-8"><title>B1nary — App Store screenshots</title>
      <style>body{margin:40px;background:#e7edf5;color:#142545;font:16px system-ui}h1{font-size:32px}p{max-width:900px;line-height:1.6}
      main{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:25px}figure{margin:0}img{width:100%;border-radius:16px}figcaption{margin:10px 0 24px;font-weight:600}
      @media(max-width:800px){main{grid-template-columns:repeat(2,minmax(0,1fr))}}</style></head><body>
      <h1>B1nary Academy</h1><p>App Store screenshot collection · 1320 × 2868 pixels · Upload the six numbered PNGs in order.</p>
      <p>${input ? 'Source: supplied iPhone captures.' : 'Source: actual Flutter screens rendered in Chrome with published free lesson content and a fictional learner. iPhone 17 Pro Max styling, Dynamic Island and status bar are rendered; these are not physical-device captures.'}</p>
      <main>${cards}</main></body></html>`);
    await page.setViewport({ width: 1500, height: 2300, deviceScaleFactor: 1 });
    const contact = slides.map(slide => `<figure><img src="${dataUri(path.join(upload, slide.file + '.png'))}"><figcaption>${escape(slide.file)}</figcaption></figure>`).join('');
    await page.setContent(`<html><head><style>body{margin:40px;background:#e7edf5;color:#132545;font:18px Arial}h1{margin:0 0 10px}p{margin:0 0 32px}main{display:grid;grid-template-columns:repeat(3,1fr);gap:24px}figure{margin:0}img{display:block;width:100%;border-radius:15px}figcaption{margin:12px 0 15px}</style></head><body><h1>B1nary Academy</h1><p>App Store screenshot collection · Six actual app screens</p><main>${contact}</main></body></html>`);
    await page.waitForFunction(() => [...document.images].every(image => image.complete));
    await page.screenshot({ path: path.join(out, 'contact-sheet.png'), fullPage: true });
    fs.writeFileSync(path.join(out, 'capture-manifest.json'), JSON.stringify({
      capturedAt: new Date().toISOString(), source: input ? 'supplied iPhone captures' : 'Flutter web preview with iOS theme',
      dimensions: { width: 1320, height: 2868 }, slides,
      devicePresentation: 'iPhone 17 Pro Max',
      systemChrome: input ? 'Unmodified supplied image' : 'Rendered Dynamic Island, 9:41 status bar, home indicator; safe areas 62/34 logical pixels',
      content: input ? 'Supplied images; check that only fictional account data is visible.' :
        'Published free first-module content. Fictional learner Alex; no real account data. Quiz shows answer feedback.',
      nativeDeviceVerified: false,
    }, null, 2));
    console.log('Screenshot collection: ' + out);
  } finally {
    if (browser) await browser.close();
    if (server) server.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
