# Payment and restore audit — October 18, 2026

Version **1.0.11+65**. **Production payments are not ready.** The owner asked
to verify purchases, course unlocking and restores, then requested a checkpoint,
version bump, commit and push before further work.

## Live findings

Read-only checks used the existing Firebase CLI login against `binary-6a372`.

| Check | Result |
| --- | --- |
| Firebase billing | Disabled |
| Deployed Cloud Functions | Zero; the function listing was complete |
| Secret Manager | API disabled (`403`, `SERVICE_DISABLED`); secret existence and values remain unverified |
| Deployed Firestore rules | Older than the checkout; last updated September 24 |
| Additional course grants | Live rules lack `hasVerifiedCoursePurchase` and the private snapshot check |
| Protected profile fields | Live rules do not protect `purchasedCourseIds`, `pendingCourseId`, or `pendingBundleCourseIds`; local rules do |
| RevenueCat offerings, restore policy, webhook, Apple notifications | Not verified; no connected dashboard/browser was available |
| App Store products, agreements, banking/tax | Not verified |
| Actual iOS purchase, reinstall/restore, transfer and refund | Not performed |

The current app's preflight refuses to open payment when the verification
function is unavailable. An older installed app must be assessed by its source
revision. The absent functions prevent production purchase activation, restore
verification and account deletion. Deploying only app code cannot resolve this.

The deployed rules source was retrieved and compared directly. It authorizes
the legacy single course and bundle fields, but not additional courses from the
new private snapshot. The snapshot and protected-field rules must be deployed
with the purchase backend, following the functions-before-rules sequence in
[PURCHASES.md](PURCHASES.md). No production changes were made.

## Fixed locally

- A store-reported purchase with an empty server inventory remains pending
  after retries; it no longer becomes “Nothing to Restore.”
- Temporary server lookup and profile-read failures retry verification without
  invoking the store restore operation twice.
- Changing accounts between retries stops before the next backend request.
- Incomplete or malformed restore responses cannot report restored access.
- Pending messaging does not promise a one-minute recovery or suggest buying
  again. A historical purchase record is not proof of current entitlement.

Five new regressions failed against the old code and pass with the fixes.

## Verification and its limits

- **705 Flutter tests pass; analysis reports zero issues.** Tests cover checkout preflight, exact-course activation, cancellation,
  multiple purchases, all four bundle selections, restore outcomes, account
  changes and retry failures.
- **49 backend tests and lint pass**, including webhook authorization, retries,
  aliases, refunds, transfers, stale snapshots, immutable bundle receipt bindings,
  product-ID mapping, and failed verification preserving existing access.
- **20 Firestore emulator tests pass.** Four new integration scenarios run the
  shipping reconciliation code with real Admin SDK transactions, then read
  course content as a learner through the actual rules. They cover two course
  purchases, restoring a missing profile cache, partial refunds, preserving a
  bundle's four choices on transfer, All Courses plus a single purchase, and
  denial of unresolved receipts. RevenueCat responses are synthetic.
- Search widget checks pass for all seven course titles, multi-word skills,
  case/whitespace handling, category filters, clearing, no-results recovery and
  the keyboard Search action. Search includes descriptions and skills, so a
  title can also return related courses. This is not a native-device check.

No StoreKit transaction, receipt transfer, production entitlement write,
production deployment or TestFlight build occurred. The emulator integration
does not validate App Store or RevenueCat account configuration.

Read-only audit commands:

```powershell
node tools/auth/audit-remote.js
node tools/auth/audit-payments.js --save
```

The second script prints only configuration metadata and rule hashes. It never
accesses secret values or customer records. `--save` stores the report and live
rules under ignored `.dart_tool/payment-audit/`. Test evidence is in ignored
`.dart_tool/billing-regression-before.log`, `billing-regression-after.log`,
`billing-rules-2026-10-18.log`, `search-verification-2026-10-18.log`, and
`release-tests-1.0.11.log`.

## Resume from here

1. The owner enables Blaze billing; this introduces usage-based charges. No
   approval or completed billing upgrade was received before the checkpoint.
2. Verify App Store product IDs and non-consumable types, store agreements,
   RevenueCat offerings, restore-transfer policy and Apple server notifications.
   Check any existing legacy receipts and recover their original bindings.
3. Enable required services, configure the RevenueCat API/webhook secrets,
   deploy functions then matching rules, configure the webhook, and verify
   actual delivery. Never print or commit the secret values.
4. Build this revision and test on iPhone: buy A, buy B, verify both and denial
   of C; buy a bundle; restore after reinstall and on another account; refund
   one purchase and check only its access disappears; verify outages prevent
   payment or show pending activation accurately.

RevenueCat's official references checked during this audit:
[customer schema](https://www.revenuecat.com/docs/api-v1/customer-info-model),
[restoring purchases](https://www.revenuecat.com/docs/getting-started/restoring-purchases),
[restore behavior](https://www.revenuecat.com/docs/projects/restore-behavior),
and [non-subscription purchases](https://www.revenuecat.com/docs/platform-resources/non-subscriptions).
Restore transfers depend on project configuration; one-time purchase refunds
need the platform notification setup described in those references.

## Community request — next work, not implemented

The owner also requested a Community tab where learners can ask questions,
answer one another, and discuss study topics or confusing concepts. No
Community code, backend, rules or navigation was added before the owner asked
to finish. A choice between course-specific, general, or both kinds of
discussion was offered but remained unanswered. Both is the proposed default,
not a confirmed preference. Plan moderation, reporting/blocking, account and
deletion behavior together with the posting flow when this work resumes.
