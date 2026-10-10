# B1nary — handoff (last updated 2026-10-09)

Read this first. It records what is live, what is waiting on the owner, and
the traps that cost real time. Older detail lives in `docs/AUTH-FIXES.md`,
`docs/IOS-GOOGLE-SIGNIN-AUDIT.md`, `docs/SECURITY.md` and `docs/RELEASE.md`.

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
