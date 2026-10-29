# B1nary — handoff (last updated 2026-10-29)

Read this first. It records what is live, what is waiting on the owner, and
the traps that cost real time. Older detail lives in `docs/AUTH-FIXES.md`,
`docs/IOS-GOOGLE-SIGNIN-AUDIT.md`, `docs/SECURITY.md` and `docs/RELEASE.md`.

For the latest App Store Connect preparation, saved bundle reviewer notes and
fresh production blockers, see
[APP-STORE-CONNECT-STATUS-2026-10-27.md](APP-STORE-CONNECT-STATUS-2026-10-27.md).
The October 19 setup history remains in
[APP-STORE-CONNECT-STATUS-2026-10-19.md](APP-STORE-CONNECT-STATUS-2026-10-19.md).

## 2026-10-29 — final audit and billing repaired

The owner requested a final audit before committing/pushing, then App Store
Connect preparation while they start Codemagic. All **729 Flutter**, **56 backend**,
**22 emulator** and **9 iOS verifier** tests pass; analyzer and backend lint are
clean. Seed validation and 14 fault checks pass, as do the JavaScript release
build and website layout/contrast/keyboard checks. The audit fixed an additional
stalled-product-loading case that could hide the trial. Version is **1.0.11+68**;
Codemagic derives the actual TestFlight build number. See
[FINAL-AUDIT-2026-10-29.md](FINAL-AUDIT-2026-10-29.md).

**Billing repaired with explicit owner approval:** project `binary-6a372` now
uses **`011D9D-8B93EA-A892D2`**, My Billing Account 1, and reports **billing enabled**.
No new payment ran. Secret Manager is enabled. Deployment stopped before functions
were created because RevenueCat secrets were absent. With explicit approval,
created the V1 key **Binary Firebase purchase verification**; securely configuring
it in Firebase, webhook setup, product audit and deployment remain in progress.
Do not expose key values in source, logs or handoff. Production rules are still older.

**Computer-use constraint:** interact only with the Chrome window on the left LG
monitor, never the main/game display. Native input has not reliably reached the
RevenueCat reveal control while the game retains input; background checks work.
The browser access host reports unavailable. Do not fight the user's pointer.

Generated screenshots/dashboard evidence stay local under ignored
`submission-assets/`; paid-content fixture exports remain ignored too. Preserve
manual App Store release. The owner will trigger Codemagic after the push;
do not start that build for them.

## Earlier October 29 checkpoint — seven-day trial and billing recheck

The owner resumed work and explicitly chose **one chosen course** for the
seven-day free trial. The paywall now offers course selection and trial
activation, independent of App Store products. No card or automatic charge;
one trial per Firebase account. Full course access expires after exactly seven
days; progress and free first modules remain. The server owns the grant and
expiry, rejects course switching/reuse, and safely returns the existing grant
on retry. Activation must be confirmed by a fresh server profile read.

Trial status, expiry, loading/retry and activation failures are visible in the
paywall. The website pricing explanation and support FAQ match. Existing
profile/feedback work was preserved; corrected its test setup for initials,
async sends and scrolling after keyboard layout, and cleared analyzer warnings.

**Fresh billing finding:** Binary is still linked to closed account
`012550-8FC12A-E19CC0` (Binary Academy), with billing disabled and zero functions.
However, the previously paid account **`011D9D-8B93EA-A892D2`, My Billing Account 1,
is now open**. Do not recommend another activation payment before considering
relinking the project to this open account. No relink or financial action ran.
The production secrets API remains disabled and deployed rules remain older.

Verification: **728 Flutter tests**, **56 backend tests**, **22 Firestore emulator
tests** pass; analysis reports zero issues and backend lint passes. Emulator
tests execute the actual trial transaction and verify content access, expiry,
progress preservation and competing trial requests. App tests cover selection,
double taps, failures, active/expired states, doubled text and downloaded-content
expiry. The JavaScript release web build succeeds; the existing optional Wasm
probe warning remains. Native iPhone testing and live deployment are outstanding.
See [TRIAL-STATUS-2026-10-29.md](TRIAL-STATUS-2026-10-29.md) for the exact checkpoint.

## Historical pause — October 27, resumed October 29, 2026

The owner asked to remember today's work and continue tomorrow. Stop live
changes and billing checks at this checkpoint. Read this section and the
October 27 App Store Connect status report first when resuming.

- **Objective:** finish preparing for App Review. Version **1.0.11**, build
  **67**, remains Prepare for Submission with manual release. Both bundles'
  review notes were saved; the app review notes now identify build 67 and
  the Everything plan label. No submission or deployment occurred.
- **Billing link:** project `binary-6a372` still uses
  **`012550-8FC12A-E19CC0`**, renamed **Binary Academy**. The Blaze upgrade
  succeeded, but the account remained closed / not in good standing. Google
  Payments Center showed a **$30 minimum activation payment** for this account.
- **Payment mismatch:** the owner's successful **$10 receipt** is for a
  different account, **`011D9D-8B93EA-A892D2`**, **My Billing Account 1**.
  Its receipt says payment should appear within 24 hours. The latest API and
  console checks still showed both accounts closed; the paid account had no
  linked projects. Do not treat this receipt as payment to Binary's account.
- **First step tomorrow:** recheck both accounts and the project's billing
  link. Run the existing read-only scripts:
  `node tools/auth/audit-remote.js`,
  `node tools/auth/audit-payments.js --save`, and the ignored diagnostic
  `node .dart_tool/payment-audit/check-billing-link.cjs` (checks both accounts).
  Use the existing CLI login without printing tokens or secret values.
  If the paid $10 account opens, investigate using it for Binary and guide
  the owner through any billing relinking. Check this option before
  recommending another payment. The assistant made no payment or saved-card
  preference change; financial transactions remain owner actions.
- **After billing is enabled:** verify RevenueCat offerings/products, secrets,
  notifications/webhook and legacy receipts per `PURCHASES.md`; deploy
  functions then rules; perform iPhone purchase, multiple-course unlock,
  restore/refund, sign-in and account-deletion checks. Last audit: zero
  functions, disabled Secret Manager and older rules lacking purchase-snapshot
  authorization. Actual device testing is still outstanding.
- **Submission assets:** capture functional review screenshots for seven
  courses and two bundles, compare storefront previews with the native build,
  then attach the current IAPs for review. The legacy single is restore-only.
- **Workspace:** pre-existing uncommitted app/build/test changes remain intact.
  Today's local changes concern handoff/status documentation. No commit or
  push was requested or performed.

## 2026-10-27 — App Store preparation, 1.0.11 (67)

The owner asked to finish preparing for App Review in App Store Connect.
Saved missing review notes for both bundles and clarified the version notes
with build 67 and the actual Everything plan label. Version 1.0.11 remains
Prepare for Submission, with build 67 and manual release selected.

Fresh read-only production checks still show **billing disabled, zero Cloud
Functions, Secret Manager disabled and older rules without the private
purchase snapshot check**. Purchase-review screenshot slots remain empty;
functional iPhone checkout/restore/deletion checks are still required.
No review submission, upload, billing change or production deployment occurred.
Existing local source edits were preserved; no commit or push was requested.

Later the same evening, the owner completed the Blaze upgrade. The live
Firebase dialog confirms success for the correct project, but direct Cloud
Billing metadata still reports billing disabled: the linked Firebase Payment
account is closed. A different same-name account open in Edge is also closed
and has no linked projects. The owner needs to resolve/reopen the linked
account or link an active account before backend deployment. See the October
27 status report for the precise follow-up; no financial action was taken.

At 8:35 PM EDT the linked account was identified as
`012550-8FC12A-E19CC0`. Its management page confirms Binary is linked, and the
disabled Reopen button says the account is **not in good standing**. All eight
accounts shown by the owner are closed. The payment iframe did not expose a
more specific alert during inspection; resolution may require Google Cloud
Billing Support. The correct linked account's management page was left open.

## 2026-10-18 — billing audit, restore fixes and search, 1.0.11+65

The owner requested payment/unlock/restore verification, then search checks and
a Community tab for questions, answers and study help. They subsequently asked
to finish here, update pubspec, commit and push. Community remains future work;
no implementation or organizational preference was finalized.

**Fresh live audit: billing disabled, zero deployed Cloud Functions, Secret
Manager API disabled, and older deployed Firestore rules.** The live rules lack
the private snapshot authorization needed for multiple purchased courses.
RevenueCat/App Store setup and real iOS transactions remain unverified. No
connected browser/dashboard was available, and no billing upgrade was approved
or performed. See [the full audit and next steps](PAYMENT-AUDIT-2026-10-18.md).

Restore now preserves pending outcomes for delayed inventory, retries temporary
verification/read failures, stops on account changes before another request,
and rejects incomplete responses. Five regressions reproduced the old failures.
Search checks cover all seven titles, skills, case/whitespace, filters, clear,
empty results and the keyboard action. There was no search implementation change.

All **705 Flutter tests pass; analysis reports zero issues**. The 49 backend
tests and lint pass. All 20 emulator tests pass, including four
new scenarios that run the real reconciliation code and transactions before
checking course access through the real rules. The RevenueCat responses are
synthetic; this does not establish live billing readiness. No deployment,
TestFlight build, actual charge/restore/refund, or App Store submission ran.

`pubspec.yaml` and README now identify **1.0.11+65**. The previous iteration was
committed and pushed as `d45e800` before this audit began.

## 2026-10-18 — finalize the pending 1.0.10+64 checkpoint

Resuming found the October 17 implementation still uncommitted on `master`.
A fresh fetch confirmed `origin/master` and local HEAD both at `2a4e112`.
Reviewed the pending practice, theme, website, preview and documentation work
and retained version **1.0.10+64** for this same iteration.

Fresh verification: **698 Flutter tests pass; analyzer reports zero issues**;
`git diff --check` is clean. The successful October 17 JavaScript web build and
browser-check logs were inspected, not rerun. The full-suite log for this
continuation is `.dart_tool/release-tests-1.0.10-resume.log` (ignored).

The next product priorities remain in `MARKET-AND-PRODUCT-2026-10-17.md`.
Production billing/functions and the intended iPhone build still need the
release checks below; their production status was not rechecked today.
No hosting deployment, content publication, TestFlight build or App Store
submission was performed during this continuation.

## 2026-10-17 — recall practice, focused quizzes and website, 1.0.10+64

The owner resumed development, requested market research and improvements to
both the app and website, then asked to finish this iteration, update pubspec,
commit and push. Work continues from `2a4e112`; origin/master matched that
revision when fetched. `pubspec.yaml` and README now identify **1.0.10+64**.

- Lessons offer **Practice recall**: reveal hidden definitions/examples,
  self-assess recall, and repeat only difficult cards. Returning preserves the
  original lesson position. Loaded/downloaded lesson content is reused.
- Quiz results offer **Practice missed questions**, with fresh option ordering,
  explanations, and optional rounds of remaining mistakes. Practice never
  changes the original result, course completion, points, or spaced-review due
  dates. Both practice modes keep session-local state only.
- Completed the shared light-theme work, including readable course accents,
  form focus states, profile/navigation text, and control boundaries. Browser
  review also led to top-aligned lesson content, uncut course-filter labels,
  readable dark practice buttons, and a wrapping login footer at doubled text.
- The website's Flutter app shares these features. The marketing site uses
  matching colors, an interactive recall sample, accurate offline/practice
  descriptions, and all seven courses (including AI & Machine Learning).
- [Market research and priorities](MARKET-AND-PRODUCT-2026-10-17.md) records
  sources, implementation decisions, and a prioritized follow-up roadmap.

Verification: **698 Flutter tests pass; analyzer reports zero issues.** The
browser suite captured 60 scenarios and exposed the large-text login footer
overflow, now fixed with two regression tests. Website checks pass at desktop,
phone and 320px doubled text in both themes, including palette contrast,
keyboard interaction, no-JavaScript recall, and all public support/legal pages.
These checks do not establish native iOS accessibility or purchase behavior.

Generated outputs and logs stay ignored in `.dart_tool/`, `build/` and `public/`.
Use `BINARY_UI_PREVIEW_DIR=build/ui_preview_final` with capture_ui.js to inspect
the final fixture build; `--polish` selects the screens changed during review.
The purchase/functions and native-device release gates below remain unresolved.
No hosting deployment, production content writes, TestFlight build or App Store
submission was performed during this iteration; the owner ended with commit/push.

## 2026-10-16 — quiz feedback and navigation, version 1.0.9+63

The owner resumed the October 15 work, including the previously requested
version bump and commit/push to master. Remote master matched the starting
revision `d63ff4d` when fetched on October 16.

- Results show the pass mark and offer mistake review with the selected
  answer, correct answer and explanation. Perfect attempts offer all-answer
  review. Viewing feedback cannot resubmit scores or change review schedules.
- Retakes clear old answers, reshuffle options and reset scrolling. Each new
  question also starts at the top. Leaving an answered quiz requires
  confirmation; back navigation is blocked during saving.
- Immediate feedback announces correctness and names the correct answer after
  a miss. Options expose descriptive accessibility labels and support focus.
  System back from result review returns to the summary without losing scores.
- Visual inspection caught low-contrast dark-mode result controls and answer
  labels; these now use readable text colors. The nine quiz browser fixtures
  cover feedback, results, review, dark mode and 320px doubled text, including
  scrolling to the final actions and starting a fresh attempt.
- Eight quiz widget regressions cover review accuracy, unchanged schedules,
  retakes, scrolling, exits, system back and screen-reader feedback. Their
  storage helper drains both real and fake async clocks; reset the review
  queue between tests to avoid retaining callbacks from a disposed test clock.

Verification on October 16: all **682 Flutter tests** pass, analysis reports
zero issues, and JavaScript release and debug preview web builds succeed.
The existing optional Wasm probe warning remains in `purchases_flutter`.
The targeted browser captures check runtime errors/overflows and are inspected
visually. They use fake Firestore and synthetic questions, not learner data.

Unchanged components retain the October 15 verification: backend lint and
**49 backend tests**, **16 Firestore emulator tests**, **9 iOS archive-verifier
tests**, 504 flashcards and 504 quiz questions with zero validation errors or
warnings, and all 14 injected content fault classes detected. See
[REVIEW-READINESS.md](REVIEW-READINESS.md) for scope and the reviewer route.

Local evidence stays ignored under `.dart_tool/ui-review/`,
`.dart_tool/release-tests-1.0.9.log` and `.dart_tool/security-tests-1.0.9.log`.
Flutter requires SDK-cache access outside the sandbox on this machine. Use
`C:\flutter\bin\flutter.bat`; direct formatting uses
`C:\flutter\bin\cache\dart-sdk\bin\dart.exe`.

Next release work: verify the unresolved production billing/functions setup,
then build the intended source revision in Codemagic and perform the iPhone
purchase/restore/deletion, session and accessibility checks listed below.
No production deployment, content writes, TestFlight build or App Store
submission ran. The October 5 production findings were not rechecked here.

## 2026-10-13 — learning and review audit

Version **1.0.8+62** adds course skill summaries and search, clearer onboarding,
robust account-scoped review sessions, accessible review layouts and corrected
sample/seed wording. Both CI workflows now enforce stricter content validation.
All 674 Flutter, 49 backend, 16 Firestore emulator and 9 iOS verifier tests pass;
the analyzer is clean. All 504 seed flashcards and 504 questions pass validation,
and 14 injected content fault classes are detected.

See [REVIEW-READINESS.md](REVIEW-READINESS.md) for the concrete reviewer route,
verification scope and unresolved production/device submission gates. No live
content, Firebase deployment, TestFlight upload or App Store submission ran.
The October 5 billing/functions findings below remain unresolved, not freshly
verified. Seed corrections must be compared with live IDs before publication.

## 2026-10-09 — release recovery and App Store screenshots

The owner requested release readiness, remaining bug fixes, a commit/push to
`origin/master`, and polished screenshots of the actual app screens.

- Session checks now run one at a time, including when Face ID emits another
  resume. A failed expiry keeps its timestamp across backgrounding; retry finishes
  the account transition even if Firebase already cleared its credentials.
- Successful recovery clears the error screen. Unlock checks expiry again, so
  leaving the lock screen open cannot revive an expired account through Face ID.
  The same check runs after a native prompt that stayed pending in the background.
- Six new regression tests reproduced these failures before the fix. All
  **665 Flutter tests**, **49 backend tests**, **16 Firestore emulator tests**,
  and **9 iOS verifier tests** pass. Analysis has zero issues; the JavaScript
  release web build succeeds. The existing optional Wasm probe warning remains.
- `tools/screenshots/store_screenshots.js` produces six coordinated **1320 × 2868
  RGB PNGs**, plus untouched raw captures, a contact sheet, preview page and
  capture manifest. The screens are actual Flutter widgets, with current
  published free-module content and a fictional learner. No generated UI or
  real learner information is used. Exported content and output stay untracked.
- Captures use Chrome with the iOS theme on Windows. They have **not** been
  verified against the intended iPhone/TestFlight build. The renderer accepts
  `--input` to replace them with corresponding native iPhone captures. See
  `tools/screenshots/README.md` for the workflow and upload order.
- The owner requested an iPhone 17 Pro Max appearance, then explicitly accepted
  rendered previews. The fixture reserves top/bottom safe areas and the renderer
  adds Dynamic Island, status icons and home indicator. Both plain screen images
  (`iphone-screens`) and framed marketing images (`iphone-1320x2868`) are exported.
  Native `--input` images receive no system overlays. These remain rendered
  previews, not verified physical-device captures.

No Firebase deployment, TestFlight build, screenshot upload or App Store
submission was performed. The billing/functions blockers below were last
audited on October 5 and have not been rechecked in production this session.
Apple sign-in was confirmed working by the owner on October 7.

## 2026-10-07 — session expiry

The owner confirmed Apple sign-in now works on the installed iOS build, but
noticed that Face ID only unlocked an indefinitely persisted Firebase session.
Registered accounts now sign out after 24 hours away, including on a cold
launch; App Lock still uses Face ID after two minutes. Anonymous guests keep
their identity so their progress remains recoverable. The app version is
`1.0.6+60`. Confirm the installed TestFlight build's revision includes this
change before checking it on a device.

## 2026-10-07 — Codemagic dependency resolution fixed locally

The 2026-10-06 Codemagic build failed in step 6, `Test purchase and account
services`, at `npm ci` in `functions/`. `firebase-functions@5.1.1` requires
`firebase-admin` `^11.10.0 || ^12.0.0`, but the root project requests
`firebase-admin@^13.10.0`; npm reported `ERESOLVE`. Upgraded
`firebase-functions` to `^6.6.0` and regenerated `functions/package-lock.json`.
A clean `npm ci`, backend lint, and all 49 backend tests pass locally. A new
Codemagic build is still needed to verify the hosted pipeline. Local verification
used Node 24; Codemagic is configured for Node 22.

## Current checkpoint — 2026-10-05

The owner resumed work, selected **release readiness**, and explicitly requested
that **all Binary Academy changes be committed and pushed to `origin/master`**.
The September notes below are historical; this section takes precedence.

Completed locally, including the unfinished October changes:

- Startup paints immediately, shows recovery after failure or a 30-second wait,
  and reuses pending native initialization on retry. Repeated taps cannot launch
  duplicate work. Firebase and optional SDK initialization are reused across retries.
- A failed fresh-install Keychain sign-out now keeps the previous account behind
  recovery. Theme and onboarding preferences resolve inside that same gate; there
  is no second asynchronous entry check that can leave a blank screen.
- Notifications apply local reminders after initialization actually completes,
  even when the app has already stopped waiting for the optional SDK.
- Apple authentication uses the Apple-specific Firebase credential, preserves
  the first authorized name, and requests a fresh token if a failed guest link
  has consumed the original. iOS deletion reauthentication keeps the scene-safe
  native presenter. These changes still need an actual iOS device check.
- Account deletion requires recent authentication on the server and refreshes
  the client token after reauthentication. The account, purchase and iOS archive
  checks run in CI; the privacy manifest and policy include profile photos.
- Small-screen welcome, paywall, deletion and progress layouts accommodate large
  text. Screenshot checks include startup recovery and verify the final welcome
  and paywall actions can actually be scrolled into view.
- **16 real Firestore emulator tests pass**, covering two separate purchases,
  bundles plus singles, trials, refunds/transfers, forged old profile fields,
  private purchase records, owner progress, and profile-photo limits. Both CI
  workflows run this gate with Node 22 and Java 21. See `tools/security/README.md`.

Verification: Flutter analysis reports zero issues; the full Flutter suite passes
653 tests, including the CI configuration checks. Backend lint and 49 tests pass;
all 9 iOS verifier tests pass. All 23 preview captures passed the runtime/overflow
gate, with the updated heading and final actions checked again visually.
The JavaScript release web build succeeds. The optional Wasm probe still
reports the existing `purchases_flutter` incompatibility; Wasm is not the built
release target. Local visual captures live in `.dart_tool/ui-review/` (untracked).
The test-only Firebase CLI has remaining transitive npm advisories documented in
`tools/security/README.md`; these packages are not shipped in the app or functions.

**Release is still blocked. Read-only production audit on 2026-10-05:**

- Firebase billing is **disabled** and the complete Cloud Functions list is
  **empty**. Purchases, restores and account deletion cannot work end to end.
- Apple, Google, email and anonymous authentication providers are enabled.
  This confirms provider configuration, not successful native Apple sign-in.
- No production deployment, StoreKit transaction, TestFlight build or App Store
  submission was performed. A Git push does not itself produce an iOS update.

Next: the owner enables Blaze billing and confirms store agreements/product
setup; configure RevenueCat secrets and any legacy receipt bindings, deploy
functions then rules following `PURCHASES.md`, and test Apple sign-in, deletion,
purchases/restores/refunds on the intended TestFlight revision. Update App Store
privacy answers and real-device screenshots before submission.

## Historical pause — 2026-09-24

Work stopped after finishing the local purchase implementation and checks.
At the owner's follow-up request, local `master` was fast-forwarded to the
existing work at `1f534b9`, and this checkpoint is committed on **`master`**
as `cf0c758`, "Complete server-verified course purchases and restores".
The owner subsequently authorized publishing all local commits to GitHub
`origin/master`, including this handoff update. No Firebase deployment,
App Store submission, or TestFlight build was performed in this session.

Completed locally:

- One non-consumable per course (`binary_course_<lowercase course code>`),
  with paywall selection and localized pricing using that course's product.
  The old `binary_course_single` is restore-only. The two bundle IDs stay.
- `refreshEntitlement` now verifies RevenueCat's current non-subscription
  inventory using the server-only `REVENUECAT_SECRET_API_KEY` secret.
- Every checkout verifies server readiness **before payment**, including All
  Courses. Activation checks the exact course(s), so an older unrelated
  purchase cannot produce a false success. Multiple course purchases coexist.
- Restore verifies server state; launch/access checks no longer trigger an
  implicit StoreKit restore. A bundle owner can also use a separate trial.
- Webhooks reconcile refunds and both sides of transfers. The processed-event
  marker is written after successful processing; older API snapshots cannot
  undo newer access updates. Bundle choices are attached to a verified receipt
  and stay the same when restored to another account.
- Firestore rules protect the new profile field and read the always-private
  purchase snapshot to authorize additional courses. Old client-written pending
  fields are ignored. See [PURCHASES.md](PURCHASES.md) for the precise schema,
  product IDs, legacy-purchase migration requirements, and deployment order.

Verification on 2026-09-24:

- `flutter analyze --no-pub`: **zero issues**.
- `flutter test --no-pub --reporter expanded`: **619 passing** (630 after the
  Apple support-details change the same day).
- `cd functions && npm test`: **49 passing**.
- `python -m unittest discover -s tools/ios -p 'test_*.py'`: **7 passing**.
- No live purchase, iOS runtime, or updated Firestore-rules emulator test was
  performed. The fake Firestore/transaction tests do not enforce rules.

**2026-09-24 (later): Apple support details now cover every failure stage.**
Every Apple sign-in failure shows, under the error and in "Copy details for
support", a block like:

```
stage: firebase            (starting | apple-sheet | apple-token | firebase | profile)
build: 1.0.3 (57) @ 1f534b9 (read from Info.plist; "unstamped" = not a Codemagic build)
code: invalid-credential
native: <NSError domain + code, when Apple itself refused>
token: aud ok, iss ok, ... (or "token: none received")
```

The build line comes from `BinarySourceRevision`, which Codemagic already
stamps (`tools/ios/verify_release.py --stamp`); Runner serves it on channel
`org.binaryapp/build-info`. Tests: `test/apple_sign_in_support_test.dart`
(drives the real `signInWithApple` through the sheet, token and Firebase
stages; stage mutations killed). The Swift side is source-checked only.
**Why the owner saw no `token:` line:** that line only existed after Firebase
rejected a token Apple returned, and only reached remote `master` (the branch
Codemagic builds) at 22:12 on 09-23 (`40f01be`). A build started earlier
lacked it entirely. With this change, a copied error with no `build:` line
means the installed build predates it — ask for the block, not a specific line.

Earlier note: Apple sign-in is still unresolved. The owner said the error **does not give a
`token:` diagnostic line**. Inspection confirmed that the current native path
only appends it after a Firebase rejection with a received token. The welcome
screen's copy button copies the displayed error. No Apple-flow or error-screen
changes were made before the owner asked to pause. On resuming, verify the
installed build first, then make the support details available for every failed
stage (including when Apple returns no token), with installed build identity.
Do not claim the Apple issue is fixed or request the same unavailable line again.

## Can we resubmit? NO (local reassessment 2026-09-24)

Certain App Review rejections: (1) purchases unlock nothing and (2) Delete
account fails with `not-found`, both because zero Cloud Functions are
deployed; (3) Sign in with Apple fails (`invalid-credential`), and it must
work because Google sign-in is offered (4.8). Also needed: App Privacy labels
updated (profile photos, Crashlytics), device paywall screenshot, review
notes, and a device test of the 2026-09-23 features.

Order: establish the installed Apple-sign-in build and expose usable failure
details → owner upgrades to Blaze + confirms Paid Apps Agreement/bank/tax →
configure products/secrets and review any legacy receipt bindings → deploy the
locally implemented purchase functions and rules per `docs/PURCHASES.md` →
sandbox purchase and restore on device → submission prep.

## Where things are

- Work branch: **`master`**, at the owner's explicit request on 2026-09-24.
  The old feature branch remains at `1f534b9`; it does not contain this
  purchase checkpoint. Codemagic's "Start new build" defaults to remote
  `master`, so publish the intended master commit before any iOS build:
  `git push origin master`.
- iOS builds: Codemagic workflow **iOS → TestFlight**. Always confirm the
  build page shows the commit you expect before debugging a device report.
- Checks: `flutter analyze` (zero issues) and `flutter test` (619 passing),
  `cd functions && npm test` (49 passing),
  `python -m unittest discover -s tools/ios -p 'test_*.py'`.
- Live security probe: serve `build/web` on 127.0.0.1:8099, then
  `node tools/security/run_probe.js`. Last result: PC 5/5, AB 18/18.

## Done on 2026-09-23 (all verified)

| What | Evidence |
|---|---|
| Root cause of "Google crashes again": every build 50–55 came from stale `master` @ `c196c04` | Codemagic build list; Crashlytics iOS had never received an event |
| Google sign-in works on device | Owner confirmed on the `476b9f3` build |
| google_sign_in_ios 6.3.5 floor, Swift `anchor!` trap removed | `test/ios_native_crash_guards_test.dart` |
| Apple name kept through a failed attempt; replacement credential used after `credential-already-in-use` | `test/apple_profile_name_test.dart` |
| CI analyze failure (`ui_preview.dart` imports gitignored fixture) | `analysis_options.yaml` exclude |
| Private profile photo (Firestore Blob, ≤150 KB, custom → Google photo → initials) | spec + plan in `docs/superpowers/`; rules deployed; probe PC-5, AB-16/17/18 |
| Delete account now uses `recursiveDelete` | `functions/test/account.test.js` (functions still undeployed) |
| AI & ML Foundations course live | read back: 7 modules × 12 cards × 12 questions |
| Paid lesson prose sealed (F-02) | 0 prose on module docs, 80 in `body/lesson`; probe AB-15 on network-professional |
| Copyright scan: ITIL glossary + Scrum Guide sentences reworded in app | commit `79daaa5` |
| Copyright: 10 Firestore items reworded (owner ran the script); live re-scan finds none of the flagged wording | `admin/migrate/2026-09-23-reword-official-definitions.js` |
| App Lock (opt-in Face ID/passcode after 2 min away; first-open offer + Profile switch) | `test/app_lock_test.dart`, 17 tests, mutation-checked; `NSFaceIDUsageDescription` guarded |
| Four 20-module courses made playable (480 original flashcards + 400 quiz moved to `quiz`) | owner ran the restore script; re-run finds 0 to do; network-pro module-1 has 6 cards + 5 questions |

## Waiting on the owner (production writes; auto mode blocks the assistant)

1. Push the intended `master` commit, then build iOS → TestFlight (App Lock, profile
   photo and the Apple fixes are not on any device yet).

## Open work, in the owner's priority order

1. **Apple sign-in fails**: `Invalid OAuth response from apple.com
   (invalid-credential)`. Ruled out: provider enabled (empty
   `appleSignInConfig`, normal for native iOS); iOS app registered as
   `com.cristians.b1nary` (a stale `com.example.binary` iOS app also exists).
   Built: on that failure the copied error now ends with
   `token: aud …, iss …, exp …, iat …, nonce …` (`apple_token_diagnostics.dart`).
   **2026-09-24 update: the owner says that line is not shown. Next, verify
   the installed build and make complete support details visible for every
   failure stage before requesting another device report.** Note the
   iOS path has no fallback to `_appleViaFirebaseProvider` (FlutterFire builds
   its own nonce/credential); a fallback on `invalid-credential` is an option
   if the nonce is the cause.
2. **Free trial = one full module**: already true in code and rules; every
   course's Module 1 now has 5-12 cards and 5-12 questions. The "one question"
   the owner saw was the broken-course fallback sample. Re-test on device.
3. Go-live readiness, DONE 2026-09-23: fresh installs sign out any session
   iOS restored from the Keychain (`lib/fresh_install.dart`); a one-time
   per-account "What do you want to learn?" picker (`course_picker.dart`); an
   intro slide listing every course; no hardcoded accounts in `lib/`.
4. Still outstanding from earlier: zero Cloud Functions deployed (needs the
   Blaze plan: purchases, restore and delete account are dead in production),
   deploying/testing the local purchase redesign, App Store screenshots/IAPs, Android Google sign-in
   (`oauth_client: []` in `google-services.json`), and leftover legacy course
   docs `networking` and `binary-network-pro` (hidden by the catalogue
   allow-list).

## Paywall audit (2026-09-23)

Historical production audit. The 2026-09-24 local implementation above fixes
the code issues described below; production/store configuration is unchanged.

Fixed in the app (`f945d86`): bundle course no longer locked in; a purchase
whose entitlement never lands is no longer reported as success; every paywall
entry swipes back.

**Purchases still cannot work in production. These are server/store issues,
not app code:**
- **Zero Cloud Functions deployed** (Spark plan). `setPendingPurchase`
  (which courses were bought) and the RevenueCat webhook (which grants the
  plan) do not exist live. A real buyer is charged and gets nothing; the app
  now at least says so and points to Restore. Fix: Blaze plan, then
  `firebase deploy --only functions`, then set the RevenueCat webhook URL and
  secret.
- `binary_course_single` is ONE non-consumable: an Apple ID can buy it once,
  ever, so a second single course is impossible. The approved redesign is
  one product per course (`binary_course_<code>`); see the purchase-redesign
  notes (brainstorm was paused mid-way).
- Webhook ignores `TRANSFER` (restore on a new account grants nothing) and
  does not revoke on refunds (`CANCELLATION`).
- Unknown: whether the three products exist and are attached to a RevenueCat
  offering. App Store Connect has not been checked from this machine.

## Traps

- **A fix is not a failure until the installed build contains it.** Check
  the Codemagic build's commit first.
- **Local `flutter analyze` can pass while CI fails**: move
  `tools/screenshots/fixture_content.dart` aside to reproduce CI.
- **`tools/security/probe_rules.js` runs inside a Chrome page**, so there is
  no Node `Buffer`. It must probe a course that actually had prose (pinned to
  `binary-network-professional`); `courses[0]` passed vacuously once the AI
  course sorted first.
- **The repo is public.** Never commit paid content (`fixture_content.dart`,
  `admin/private/`).
- **`fake_cloud_firestore` enforces no security rules.** Test that shared
  documents are unchanged; don't just test that a write succeeded.
- Course data has two shapes. The app reads `flashcards` and `quiz`
  ordered by `order`. A course with anything else is silently unplayable.
