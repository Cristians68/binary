# Driving the real app on Windows

There is no Xcode or simulator on this machine, so these scripts drive the
**built web app** in headless Chrome. Same Flutter widgets, same code paths —
it is the app, not a mock.

## Setup

```
flutter build web --release
cd build/web && python -m http.server 8099
npm install puppeteer-core       # uses the installed Chrome, downloads nothing
```

## The scripts

| script | what it does |
|---|---|
| `shoot.js` | Walks the app and captures App Store screenshots |
| `play.js` | Plays a lesson and quiz through to a pass, then captures the populated screens |
| `probe.js` | Reads the signed-in user's own Firestore document at each step |
| `dump_titles.js` | Dumps every course's module titles — used for the trademark audit |

## Two things that make this work

**Screenshot size.** A 440x956 viewport at `deviceScaleFactor: 3` renders at
exactly **1320x2868**, which is the iPhone 6.9" size App Store Connect asks
for. No scaling or padding afterwards.

**Clicking.** Flutter web paints into a canvas, so there is nothing to select.
Clicking the hidden `flt-semantics-placeholder` turns the semantics tree on and
every widget becomes an `flt-semantics` element with an `aria-label` and a
bounding box — the same tree a screen reader uses. Match labels EXACTLY where
you can: a substring search for "Courses" hits the "MY COURSES" heading rather
than the tab.

## The design preview (`capture_ui.js`)

`shoot.js` and `play.js` drive the **production** app and need a real sign-in.
`capture_ui.js` does not: it renders `ui_preview.dart`, a fixture entrypoint
backed by `FakeFirebaseFirestore` and a fictional learner, so it touches no
account and writes nothing to production. Use it to review the UI.

```
flutter build web --no-pub --debug -t tools/screenshots/ui_preview.dart --output build/ui_preview
node tools/screenshots/capture_ui.js            # all 23 fixtures
node tools/screenshots/capture_ui.js 08-quiz    # just one
```

Screenshots and the semantics-label dump for each land in
`.dart_tool/ui-review/`.

**`--debug` is not optional.** `fake_cloud_firestore` refuses to install its
platform mocks in a release build, and `ui_preview.dart` says so at the top.

**It is a gate, not just a camera.** The run collects `EXCEPTION CAUGHT` and
`overflowed by` messages out of the browser console and exits non-zero at the
end, so a layout overflow or a thrown build fails the run even though the
screenshot still got written. Two real defects it caught on 2026-09-19:

- `Random().nextInt(1 << 32)` for the quiz attempt id. `1 << 32` is 4294967296
  on the VM and **0** on the web, because dart2js truncates any shift above 31
  (`js_number.dart::_shlPositive`). `nextInt(0)` throws, and it was in a field
  initialiser, so every quiz on web died before painting. `flutter test` cannot
  reproduce this — the VM computes the bound correctly.
- `AnimatedSize` inside `LearningHero`. The hero's Stack measures itself
  against that subtree, so the AnimatedSize is never a relayout boundary and
  re-dirtied itself inside its own `performLayout`.

Both were invisible to the analyzer and to all 494 tests.

**Regenerate the fixture** with `node tools/screenshots/export_content.js`.
It reads published catalogue metadata and free first-module content through a
temporary guest identity, then deletes that identity. The generated
`fixture_content.dart` is deliberately gitignored; do not commit it.

## App Store screenshot collection

```powershell
node tools/screenshots/export_content.js
flutter build web --no-pub --debug -t tools/screenshots/ui_preview.dart --output build/ui_preview
node tools/screenshots/store_screenshots.js
```

The `store=1` preview seeds the published free flashcards and quizzes into fake
Firestore, so it renders the **actual lesson and quiz screens**, rather than
the sample fallback used by the older design fixtures. Home and progress use
fictional learner Alex. The quiz capture selects an answer through the actual
widget to show its feedback. Capturing has no production writes.

Output is in `.dart_tool/app-store/`:

- `iphone-1320x2868/`: six numbered RGB PNGs with headlines and device framing.
- `iphone-screens/`: six full-size screen images without headlines or an outer
  frame. Local previews include rendered Dynamic Island, 9:41 status icons and
  a home indicator, with native-like top and bottom safe areas.
- `raw/`: the full, untouched screen captures and their accessibility labels.
- `contact-sheet.png` and `preview.html`: a review of the whole collection.
- `capture-manifest.json`: capture source, dimensions and native-verification status.

Upload order: home → courses → flashcards → quiz → progress → dark mode. Upload
only the six PNGs in `iphone-1320x2868`, not the contact sheet or raw captures.
The output uses Apple's accepted **1320 × 2868** portrait size for large
Dynamic Island iPhones. The current Xcode target is iPhone only, so this set
does not include iPad images. Check [Apple's screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
when preparing another device family.

The device presentation follows iPhone 17 Pro Max proportions, with rounded
screen corners, slim bezels and side buttons. OS chrome is rendered separately
from the app widgets, and is not added to supplied `--input` captures.

These are Flutter web captures with the iOS theme and rendered system chrome,
**not iPhone runtime captures**. Compare their layout and content with the exact TestFlight build
before submitting. To render native screenshots in the same design, place
six portrait PNGs named `01-home.png`, `02-courses.png`, `03-flashcards.png`,
`04-quiz.png`, `05-progress.png`, and `06-dark-mode.png` in a local folder:

```powershell
node tools/screenshots/store_screenshots.js --input C:/path/to/iphone-captures --output C:/path/to/store-assets
```

Use the corresponding full iPhone screen captures with matching aspect ratio
and fictional account information. The tool frames the images without changing
their contents and refuses incompatible aspect ratios. `CHROME_PATH` can point
to another installed Chrome executable. Generated assets remain local; do not
commit exported course content to this public repository.

## Reading the backend

`probe.js` takes the uid and ID token out of IndexedDB
(`firebaseLocalStorageDb` -> `firebaseLocalStorage`) and calls the Firestore
REST API directly. This is how the `PERMISSION_DENIED` bug in
`ProgressService.completeModule` was found: a release web build obfuscates
every exception to "Error: Error", so the only way to see what happened is to
read the data the app actually wrote.

## Gotcha

Reload with `waitUntil: "domcontentloaded"`. The quiz confetti animation never
lets the page reach `networkidle2`, so that option times out.
