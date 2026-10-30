# Binary Academy — October 29, 2026 trial checkpoint

The owner resumed development and chose **one full course of the learner's
choice** for the seven-day trial. This file records the initial local checkpoint;
the later deployment and verification are in
[FINAL-AUDIT-2026-10-29.md](FINAL-AUDIT-2026-10-29.md). The trial is now live.

## Implemented

- The paywall offers **Start 7-day free trial**, with explicit course selection
  at generic entry points and a named course at course-specific entry points.
- One trial per Firebase account, exactly 168 hours from server activation.
  No card, automatic charge or renewal. The selected course cannot be changed.
- A server transaction prevents repeated or competing grants. A retry of the
  same active trial returns its original expiry instead of extending it.
- The callable verifies the Firebase account still exists, accepts no supplied
  identity or expiry, and preserves profile, paid purchases and progress.
- The app verifies access with a fresh server profile read, handles account
  changes, and shows loading, retry, failures, active status and local expiry.
- Expiry blocks paid lessons, quizzes and downloads. Free first modules remain.
- Website pricing and support copy describe the same trial.
- Existing profile/feedback changes remain. Their test failures were corrected:
  avatar initials are scoped to the avatar, pending-send tests drain real async
  work, and keyboard layout settles before scrolling to the submit action.
  Cleared their unused import and intentional test-double analyzer findings.

## Validation

- `flutter test --no-pub --reporter expanded`: **728 passing**.
- `flutter analyze --no-pub`: **zero issues**.
- `npm test` in `functions`: **56 passing**; `npm run lint`: passes.
- `npm test` in `tools/security` with Android Studio Java 21: **22 passing**.
  Includes actual Admin SDK trial transactions, simultaneous requests, and
  authenticated learner content reads checked by the real Firestore rules.
- `git diff --check`: clean.
- `flutter build web --release --no-pub`: succeeds. The existing optional Wasm
  dry-run warning in `purchases_flutter` remains; the built JavaScript target passes.
- Full Flutter test log: ignored `.dart_tool/trial-full-tests-2026-10-29.log`.

These are local checks; native iPhone and live trial activation remain untested.

## Fresh production audit and next step

The existing read-only CLI audits ran with the current Firebase login.
No tokens, secret values, customer records or receipts were printed.

At **2026-10-29 23:30:44 UTC**, Cloud Billing reported:

| Item | Result |
| --- | --- |
| Project | `binary-6a372` |
| Billing enabled | `false` |
| Linked account | `012550-8FC12A-E19CC0`, Binary Academy |
| Linked account open | `false` |
| Previously paid account | `011D9D-8B93EA-A892D2`, My Billing Account 1 |
| Previously paid account open | **`true`** |
| Deployed functions | Zero, complete listing |
| Secret Manager metadata | HTTP 403 `SERVICE_DISABLED` |
| Production rules | Older rules; private purchase snapshot check absent |

The account receiving the earlier $10 payment is now open. Investigate linking
Binary to it before recommending another payment. Relinking changes which account
pays for future project usage, so obtain the owner's explicit confirmation for
that account change. No relink, payment, deployment, upload, commit, push or App
Store submission occurred in this continuation.

After billing is enabled, deploy and verify `startTrial` and the applicable
rules before distributing the updated app. The trial has no RevenueCat secret
dependency. Purchase/account deployment still requires the separate RevenueCat,
legacy receipt and device checks in `PURCHASES.md`; trial tests do not establish
purchase readiness. Confirm the intended source revision before a TestFlight build.
