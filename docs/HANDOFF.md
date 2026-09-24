# B1nary — handoff (last updated 2026-09-23)

Read this first. It records what is live, what is waiting on the owner, and
the traps that cost real time. Older detail lives in `docs/AUTH-FIXES.md`,
`docs/IOS-GOOGLE-SIGNIN-AUDIT.md`, `docs/SECURITY.md` and `docs/RELEASE.md`.

## Where things are

- Work branch: `feature/notifications-and-streaks`. **`master` must be
  fast-forwarded to it before every iOS build**: Codemagic's "Start new
  build" defaults to `master`.
  `git push origin feature/notifications-and-streaks:master`
- iOS builds: Codemagic workflow **iOS → TestFlight**. Always confirm the
  build page shows the commit you expect before debugging a device report.
- Checks: `flutter analyze` (zero issues) and `flutter test` (562 passing),
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

## Waiting on the owner (production writes; auto mode blocks the assistant)

1. `GOOGLE_CLOUD_PROJECT=binary-6a372 NODE_PATH=functions/node_modules node admin/migrate/2026-09-23-restore-pro-course-content.js --commit`
   — makes Network Pro, Cybersecurity Pro, Cloud Fundamentals and Cloud
   Architecture playable (480 flashcards + 400 quiz questions). Dry run
   passed. Card content is in gitignored `admin/private/flashcards/`: keep
   that folder, it exists only on the owner's PC.
2. `GOOGLE_CLOUD_PROJECT=binary-6a372 NODE_PATH=functions/node_modules node admin/migrate/2026-09-23-reword-official-definitions.js --commit`
   — rewords 9 Firestore items copied from official ITIL/Scrum wording and
   fixes "AXELOS owns ITIL" (PeopleCert since 2021). Dry run: 9 edits.
3. Fast-forward `master`, then build iOS → TestFlight.

## Open work, in the owner's priority order

1. **Apple sign-in fails**: `Invalid OAuth response from apple.com
   (invalid-credential)`. Checked and ruled out: the Apple provider is enabled
   (empty `appleSignInConfig`, normal for native iOS) and the iOS Firebase app
   is registered as `com.cristians.b1nary`. A stale `com.example.binary` iOS
   app also exists (harmless). Next step: on failure, decode the identity
   token's non-identifying claims on the device (`aud`, `iss`, `exp`/`iat`
   against device time, and whether `nonce` equals SHA-256 of the raw nonce)
   and add them to "Copy details for support". Do not log email or `sub`.
2. **Free trial should be one full module**, then purchase to continue.
   Module 1 is already free in the rules (`module-1`/`module-01`); check what
   the in-app "Try free" flow actually gives.
3. **"Sign out 2 minutes after closing the app"** was requested. Recommend
   a Face ID/passcode app lock instead: signing out a guest loses their
   account for good, and Apple/Google users would sign in on every launch.
   Confirm with the owner before building.
4. **Go-live readiness**: every new user must get onboarding and course
   picking; confirm no test data or owner account is baked in.
5. Still outstanding from earlier: zero Cloud Functions deployed (needs the
   Blaze plan: purchases, restore and delete account are dead in production),
   the purchase redesign, App Store screenshots/IAPs, Android Google sign-in
   (`oauth_client: []` in `google-services.json`), and leftover legacy course
   docs `networking` and `binary-network-pro` (hidden by the catalogue
   allow-list).

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
