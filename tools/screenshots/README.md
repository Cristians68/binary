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
