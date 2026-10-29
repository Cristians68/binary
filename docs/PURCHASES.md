# Purchases — local implementation, updated 2026-10-18

This code is tested locally and **not deployed**. Start with `HANDOFF.md`.
Real StoreKit purchase/restore still needs testing. On 2026-10-18, 20 local
emulator scenarios passed, including real purchase reconciliation followed by
learner content reads. The live audit confirmed billing disabled, zero deployed
functions, Secret Manager disabled, and older deployed rules lacking multiple
course authorization. See [the audit](PAYMENT-AUDIT-2026-10-18.md) and
`tools/security/README.md` for exact verification scope and next steps.

## Seven-day free trial (2026-10-29 local update)

The owner chose one full course per account for seven days. The trial is a
server-granted preview, separate from the non-consumable IAPs below: no card,
automatic payment or renewal. Open Plans & Pricing, choose the trial course,
then tap **Start 7-day free trial**. Course-specific paywalls name that course;
generic paywalls require an explicit selection. A fresh server profile read
must confirm the trial before the app reports success.

`startTrial` verifies the authenticated Firebase account and runs
`functions/trial_service.js` in a Firestore transaction. It stores the existing
protected fields `trialCourseId`, `trialExpiry`, `trialStartedAt`, `hasUsedTrial`.
Expiry is server time plus exactly 168 hours. Concurrent requests can grant
only one course. Retrying the same active grant returns its original expiry;
switching courses or restarting after expiry is denied. Historical trial
records count as used. Paid access and learner progress are preserved.

The paywall shows active/expired status and the local expiry date and time.
Expired trials lose paid-content access, including through downloads; the
first module of every course remains free. The existing server rules already
enforce trial expiry using `request.time`.

Local verification: 728 Flutter tests, 56 backend tests, 22 emulator tests,
clean analyzer and backend lint. Neither the callable nor app changes are live.
The current billing account is closed, but the account the owner previously
paid is now open; see [the October 29 checkpoint](TRIAL-STATUS-2026-10-29.md).

Implementation references: [Firebase callable authentication/errors](https://firebase.google.com/docs/functions/callable)
and [Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions).

## Products and store setup

Create one non-consumable for each course in App Store Connect and RevenueCat.
Include each in the current RevenueCat offering under its own custom package.
Prices come from each returned store product; the app does not set store prices.

| Course | Product ID |
| --- | --- |
| IT Service Management Foundations | `binary_course_itsm` |
| Agile & Scrum Foundations | `binary_course_scrm` |
| Network Professional | `binary_course_netp` |
| Cybersecurity Professional | `binary_course_secp` |
| Cloud Fundamentals | `binary_course_cldf` |
| Cloud Architecture | `binary_course_clda` |
| AI & Machine Learning Foundations | `binary_course_aiml` |
| Any 4 Courses | `binary_bundle_4` |
| Everything | `binary_bundle_all` |

Retire `binary_course_single` from the offering. It remains recognized for
restoration but cannot be used for a new checkout. Never map it to a newly
selected course. The same Apple ID can buy each of these non-consumables once;
the four-course bundle therefore restores its original four choices.

## Verification and storage

`functions/purchase_reconciliation.js` uses RevenueCat's current
`subscriber.non_subscriptions` inventory. A shared entitlement's single
`product_identifier` cannot represent several independently owned courses.
Unknown products grant nothing. Malformed/failed API responses preserve the
existing snapshot and return a retryable error.

- `users/{uid}/purchaseState/current`: server-only authoritative snapshot,
  including `revenueCatCheckedAtMs`, active products and unresolved choices.
- `users/{uid}/purchaseIntents/binary_bundle_4`: server-only checkout choice,
  written after verification and before StoreKit opens. No entitlement by itself.
- `purchase_bindings/{sha256}`: immutable bundle/legacy course selection keyed
  by `[store, is_sandbox, productId, RevenueCat transaction id]`. It follows the
  receipt on transfer; the receiving account cannot choose new courses.
- `users/{uid}`: server-written `subscriptionPlan`, `purchasedCourseIds`, and
  compatibility fields `subscribedCourseId`/`bundleCourseIds`. The client reads
  them but cannot modify them. Rules use the private snapshot for additional
  course grants, since the new profile field was writable before this release.
- `processed_rc_events/{sha256(event.id)}`: created after all affected accounts
  reconcile successfully. Failed or partially completed events remain retryable.

`setPendingPurchase` requires a valid product and matching course selection,
then checks RevenueCat before permitting checkout. All Courses also runs this
check. Older function responses without `alreadyOwned` are rejected by the new
client. Success after payment requires the exact chosen access in a fresh
Firestore read. A second single-course purchase cannot hide behind the first.

`refreshEntitlement` takes identity only from Firebase Authentication, never
from a supplied UID. Both callables check that the Firebase account still exists.
Webhook transfer arrays and Firebase aliases are reconciled; deleted accounts
and RevenueCat anonymous IDs are skipped. Events request a current lookup and
never directly command a grant or revoke. This also avoids revoking an unrelated
course on a refund, or prematurely revoking a paused subscription.

## Legacy receipts and bundle edge cases

**Audit existing generic-single and bundle receipts before rollout.** Any old
receipt lacking a verified `purchase_bindings` entry stays unresolved and does
not grant access. A refresh replaces the old plan cache, so do not deploy this
against existing legacy buyers without first recovering their original choices.
The old top-level `pendingCourseId` and `pendingBundleCourseIds` were client
writable and must never be promoted or blindly backfilled.

For a confirmed legacy buyer, an administrator must verify the receipt against
RevenueCat and recover the original course(s) from trusted purchase/support
records. Use `readPurchases()` to derive the receipt's binding key, then create
the server-only document containing its `productId`, exact catalogued `courseIds`
(one or four unique IDs), and `createdAt`. Never infer the selection from a new
paywall choice. No migration or production backfill ran in this session.

A pending bundle choice is reserved for 30 minutes to prevent another device
from changing it while a payment sheet is open. Retrying the same selection is
allowed. After cancellation, changing the selection may require waiting for that
window. A purchase completed outside its intent's 30-minute window stays
unresolved for support recovery. These are deliberate limitations of this
checkpoint; cancellation-aware intent cleanup can improve the UX later.

## Deployment and verification

1. Confirm Blaze billing, Paid Apps Agreement, banking/tax, and all products in
   the offering. Configure Apple platform server notifications in RevenueCat
   so non-subscription refunds are detected.
2. Run `npm --prefix tools/security ci` and `npm --prefix tools/security test`
   with Node 22+ and Java 21. This exercises the checked-in rules in a local demo
   project. Coverage includes: first module remains
   readable, each purchased course is readable, unrelated courses are denied,
   profile entitlement edits fail, and purchase-state/intent/binding documents
   cannot be read or written by a client. Include a preexisting forged
   `purchasedCourseIds` profile list with no private snapshot: it must not grant
   content access. This gate now passes locally and runs in CI. The Flutter
   unit-test fake itself still does not enforce rules. After deployment, run
   the separate live probe to verify the rules actually reached production.
3. Complete any required legacy receipt binding review above.
4. Set `REVENUECAT_SECRET_API_KEY` (a RevenueCat v1 secret `sk_...` key) and
   `REVENUECAT_WEBHOOK_SECRET` in Firebase Secret Manager. Never put them in the
   app, repository, or a copied error. Deploy the functions, then the rules
   together in the same release window, **before shipping this app update**.
   This extends the order in `SECURITY.md`; do not ship the new app with old
   rules, which cannot authorize the second separately purchased course.
5. Configure the webhook URL and matching Authorization header in RevenueCat.
   Include purchases, cancellations/refunds, expiration and transfers. Send a
   test event and verify delivery, then exercise real sandbox transactions.
6. Build the intended commit through Codemagic and confirm its revision. On a
   device: buy course A, buy B, check both and denial of C; buy a four-course
   bundle; restore on reinstall and another account; refund one product and
   verify only that access disappears. Confirm a backend outage stops checkout
   before the payment sheet and never tells a paid buyer to purchase again.

No production operation above was performed in this session.

## Sources checked during implementation

- [RevenueCat customer inventory schema](https://www.revenuecat.com/docs/api-v1/customer-info-model)
- [Get or create customer](https://www.revenuecat.com/docs/api-v1/customers)
- [Webhook event and transfer fields](https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields)
- [Non-subscription purchases and refund notifications](https://www.revenuecat.com/docs/platform-resources/non-subscriptions)

Local checks: 619 Flutter tests, 49 function tests, 7 iOS verifier tests;
Flutter analysis reports zero issues. These do not certify live store setup.
