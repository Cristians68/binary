# Purchases — local implementation, 2026-09-24

This code is tested locally and **not deployed**. Start with `HANDOFF.md`.
Real StoreKit purchase/restore and Firestore rule enforcement still need testing.

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
2. Verify the rules in a Firestore emulator, including: first module remains
   readable, each purchased course is readable, unrelated courses are denied,
   profile entitlement edits fail, and purchase-state/intent/binding documents
   cannot be read or written by a client. Include a preexisting forged
   `purchasedCourseIds` profile list with no private snapshot: it must not grant
   content access. The local unit-test fake does not test these rules.
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
