# Binary Academy final audit — October 29, 2026

Prepared before the owner's requested commit and Codemagic build. Version
**1.0.11+68** preserves the current App Store version; Codemagic determines the
next TestFlight build number and stamps the actual source revision.

## Source audit

Reviewed all pending changes, including the older adaptive layout and feedback
work, seven-day trial UI/backend, authorization rules, CI and native settings.

- The trial is one chosen course per Firebase account, exactly 168 hours from
  server activation, with no card, renewal or automatic charge. Its transaction
  preserves paid access, rejects course switching/reuse, and makes retries
  idempotent. The app confirms a fresh server profile before reporting success.
- Trial expiry denies paid lesson, quiz and downloaded-content access. Free
  first modules and progress remain. Concurrent activation is tested against
  real Firestore transactions and actual authorization rules.
- Found and fixed one additional audit issue: a stalled product lookup could
  indefinitely hide the trial. Product loading now times out after 15 seconds
  and keeps the trial and plans reachable. A regression reproduces the stall.
- Adaptive layouts retain tab/search state across window-width changes;
  landscape, small windows and doubled text are covered. Feedback preserves
  drafts on failure, prevents duplicate sends and remains usable with a keyboard.
  Private feedback no longer selectively triggers public rating requests.
- Verified Xcode 27.1 is available in Codemagic's published machine inventory.
  Local Flutter 3.47.2 matches both CI workflows. Signing, Apple entitlement,
  minimum iOS target, source stamping and exported-archive checks remain in CI.
- Generated screenshots, dashboard evidence and paid-content fixtures stay out
  of the public repository. Source changes do not publish new course content.

## Verification

| Check | Result |
| --- | --- |
| Complete Flutter suite after final fix | **729 passing** |
| Flutter analyzer | **Zero issues** |
| Backend lint and tests | Pass, **56 tests** |
| Real Firestore emulator | **22 passing** |
| iOS archive verifier tests | **9 passing** |
| Offline learning-content validation | 504 cards, 504 questions, zero errors/warnings |
| Validator fault tests | All 14 fault classes detected |
| JavaScript release web build, `/app/` base | Success |
| Website layout/contrast/keyboard/public pages | Pass in light/dark, desktop, phone and doubled text |

The existing optional Wasm dry-run warning originates in `purchases_flutter`;
the JavaScript release target builds successfully. Native archive compilation,
StoreKit, VoiceOver, Face ID and real-device flows still require the exact new
Codemagic build. Local tests do not establish those outcomes.

## Production changes and remaining gates

The owner explicitly approved linking the project to the now-open billing
account. At **2026-10-29 23:44:19 UTC**, Cloud Billing confirmed project
`binary-6a372` linked to **`011D9D-8B93EA-A892D2`**, My Billing Account 1,
with **billingEnabled: true**. The older Binary Academy account remains closed.
No additional payment or payment-method change was made.

Enabled Secret Manager and the backend build APIs. The first function deployment
attempt stopped before deployment because the RevenueCat secrets did not exist.
The owner then explicitly approved generating and configuring the V1 key
**Binary Firebase purchase verification** in the RevenueCat project. The key was
created. Secret transfer/configuration and backend deployment are still pending;
no secret value is present in the repository or audit output.

The current production rules still lack the private purchase snapshot check.
Complete RevenueCat products/packages, secrets, webhook/notification setup and
legacy receipt review, then deploy functions before the corresponding rules.
Verify live trial activation and sandbox purchase/restore/refund/account deletion
before App Review. Never replace existing receipt choices with new selections.

The owner will start Codemagic after the audited commit is pushed. Continue App
Store Connect preparation afterward; do not claim the unbuilt revision is already
on a device or submit with unverified checkout. Preserve manual release.

Audit logs remain local in `.dart_tool/final-audit-tests-2026-10-29.log`,
`.dart_tool/payment-audit/` and `.dart_tool/site-review/`.

Toolchain source: [Codemagic Xcode 27.1 image](https://docs.codemagic.io/specs-macos/xcode-27-1/).

## Background continuation after the audited source commit

The owner requested **background-only work** while playing. No further browser
input was issued after that instruction. Live RevenueCat/App Store Connect edits
are pending; prepared copy and the product checklist are in
[APP-STORE-CONNECT-DRAFT-2026-10-29.md](APP-STORE-CONNECT-DRAFT-2026-10-29.md).

Source commit **bfe63c4** was pushed to `origin/master`; the owner starts Codemagic.
The website and app were deployed to Firebase Hosting and verified at both
`https://binaryapp.org` and `https://binary-6a372.web.app`: all six checked paths
return 200, trial copy is present, `/app/` has the correct base URL, and the live
JavaScript bundle's SHA-256 matches the audited local release.

The subsequent deployment dependency installation exposed additional npm
advisories. Applied compatible dependency patches, plus scoped `qs` 6.x and
CommonJS-compatible `uuid` 11.x overrides. The Google SDK callers use no-argument
UUID v4 generation, which is supported by both versions. Firebase SDK major
versions remain unchanged. A clean `npm ci` succeeds, **all 56 backend tests and
lint pass**, and **npm audit reports zero vulnerabilities**, including production
dependencies. A separate emulator run using the actual patched production SDK
also verifies a real trial transaction, idempotent retry and recursive deletion.

To avoid unrelated missing RevenueCat parameters blocking the free trial,
prepared an ignored deployment package containing the exact audited `startTrial`
handler and its modules, plus the audited `deleteAccount`. No purchase or scheduled
notification functions are included. Both functions are now **ACTIVE** on Node 22.
A seven-day cleanup policy covers generated deployment images. Deployed the
matching rules after confirming that the diff preserves existing grants and
adds protection for purchase fields and verified purchase snapshots.

At **2026-10-30 00:07 UTC** (October 29 locally), verified the live backend with
one disposable anonymous account: unauthenticated calls denied, free preview
readable, paid content initially denied, chosen course unlocked, unrelated course
denied, exact seven-day expiry, retry keeps the original expiry, course switching
denied, and deployed account deletion successfully removes the synthetic account.
The fresh production audit confirms **billing enabled**, **two ACTIVE functions**,
and **deployed rules matching the checkout**.

Remaining: transfer the approved RevenueCat key to Secret Manager, configure
offerings/products and webhook, deploy purchase verification/reconciliation, and
test native purchases/restores/refunds. The created key remains in RevenueCat;
no secret values have been copied into the repository. App Store Connect edits
remain prepared locally because the owner requested background-only work.
