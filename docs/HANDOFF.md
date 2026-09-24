# B1nary — handoff (last updated 2026-09-23)

Read this first. It records what is live, what is waiting on the owner, and
the traps that cost real time. Older detail lives in `docs/AUTH-FIXES.md`,
`docs/IOS-GOOGLE-SIGNIN-AUDIT.md`, `docs/SECURITY.md` and `docs/RELEASE.md`.

## Can we resubmit? NO (assessed 2026-09-23, build `efe660b`)

Certain App Review rejections: (1) purchases unlock nothing and (2) Delete
account fails with `not-found`, both because zero Cloud Functions are
deployed; (3) Sign in with Apple fails (`invalid-credential`), and it must
work because Google sign-in is offered (4.8). Also needed: App Privacy labels
updated (profile photos, Crashlytics), device paywall screenshot, review
notes, and a device test of the 2026-09-23 features.

Order: Apple fix (needs the `token:` line from a device) → owner upgrades to
Blaze + confirms Paid Apps Agreement/bank/tax → deploy functions → build the
payment system (instant unlock via a server check against RevenueCat, one
product per course; design awaiting the owner's yes) → sandbox purchase and
restore on device → submission prep.

## Where things are

- Work branch: `feature/notifications-and-streaks`. **`master` must be
  fast-forwarded to it before every iOS build**: Codemagic's "Start new
  build" defaults to `master`.
  `git push origin feature/notifications-and-streaks:master`
- iOS builds: Codemagic workflow **iOS → TestFlight**. Always confirm the
  build page shows the commit you expect before debugging a device report.
- Checks: `flutter analyze` (zero issues) and `flutter test` (602 passing),
  `cd functions && npm test` (23 passing),
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

1. Fast-forward `master`, then build iOS → TestFlight (App Lock, profile
   photo and the Apple fixes are not on any device yet).

## Open work, in the owner's priority order

1. **Apple sign-in fails**: `Invalid OAuth response from apple.com
   (invalid-credential)`. Ruled out: provider enabled (empty
   `appleSignInConfig`, normal for native iOS); iOS app registered as
   `com.cristians.b1nary` (a stale `com.example.binary` iOS app also exists).
   Built: on that failure the copied error now ends with
   `token: aud …, iss …, exp …, iat …, nonce …` (`apple_token_diagnostics.dart`).
   **Next: get that line from the device, then fix what it names.** Note the
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
   the purchase redesign, App Store screenshots/IAPs, Android Google sign-in
   (`oauth_client: []` in `google-services.json`), and leftover legacy course
   docs `networking` and `binary-network-pro` (hidden by the catalogue
   allow-list).

## Paywall audit (2026-09-23)

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
