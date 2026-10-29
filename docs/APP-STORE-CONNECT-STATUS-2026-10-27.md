# App Store Connect preparation — 2026-10-27

App: B1nary Academy (`com.cristians.b1nary`, Apple ID `6762030524`).
The owner asked to finish preparing for App Review. Version **1.0.11** remains
**Prepare for Submission**, with **build 67** attached and **manual release**
selected. Nothing was submitted to Apple for review during this continuation.

## Completed in App Store Connect

- Saved review notes for `binary_bundle_4`: the guest route through Profile →
  Legal & Purchases → Plans & Pricing, the **Any 4 Courses** option, exactly
  four course selections, the **Unlock 4 Courses** button, and restore behavior
  preserving the original choices.
- Saved review notes for `binary_bundle_all`: the same entry route, the
  **Everything** option, **Unlock Everything**, and Restore purchases.
- Updated the version's review notes to identify **1.0.11 (67)** explicitly and
  identify `binary_bundle_all` as **Everything / All Courses**, matching the
  purchase-screen label.
- Verified Save became disabled after each save. Reviewed the live product
  list: seven course products, two bundles, and the legacy single-course product
  are still drafts. The IT service management and Agile products retain their
  previously saved course-specific review instructions.
- Inspected the storefront screenshot panel. The selected Dynamic Island
  medium display inherits five existing images: `05_quiz.jpg`,
  `04_flashcard.jpg`, `01_home.jpg`, `02_courses.jpg`, and
  `03_course_detail.jpg`. No screenshots were replaced.

## Fresh production audit

The existing read-only audit scripts ran successfully against `binary-6a372`.
The payment audit timestamp is **2026-10-28 00:15:55 UTC**, October 27 in the
owner's timezone. Authentication used the existing Firebase CLI login without
printing credentials. Secret values, customer records and receipts were not
fetched.

| Check | Current result |
| --- | --- |
| Firebase billing | Disabled |
| Cloud Functions | Zero; complete listing |
| RevenueCat API/webhook secret metadata | HTTP 403, `SERVICE_DISABLED` |
| Deployed Firestore rules | Do not match checkout |
| Private purchase snapshot authorization | Missing from deployed rules |
| Rules last updated | September 24, 2026, 01:19:46 UTC |
| Anonymous, email, Google, Apple providers | Enabled; not a native sign-in test |

Audit command: `node tools/auth/audit-remote.js`.
Payment/rules command: `node tools/auth/audit-payments.js --save`.
The latter stores metadata and deployed rule source in ignored
`.dart_tool/payment-audit/`; the checked-in rules were not deployed.

## What must happen next

**Billing follow-up, October 27 at 8:25 PM EDT:** The owner completed the
Blaze upgrade and supplied the success dialog. The live Firebase console
confirms that success dialog belongs to `binary-6a372`. A direct Cloud Billing
metadata check nevertheless reports `billingEnabled: false`, a linked billing
account named **Firebase Payment**, and `open: false` for that linked account.
The separate account open in Edge has a different account ID, is also named
Firebase Payment, is marked closed, and lists no linked projects. Its Reopen
billing account control is disabled. Do not assume the two same-name accounts
are the same. The immediate blocker is an active billing-account link, not
repeating the Firebase plan upgrade. The owner needs to resolve/reopen the
linked account or link a usable active account. No account was reopened or
relinked by the assistant.

**Billing follow-up, 8:35 PM EDT:** Matched the project's billing link to
`012550-8FC12A-E19CC0` (the first Firebase Payment account in the owner's list).
Its Account management page lists Binary / `binary-6a372` as the linked
project. The disabled Reopen button's accessible description explicitly says:
"You can’t reopen this billing account because this account is not in good
standing." The account's Health checks page supplies no more specific payment
cause; its recommendation concerns budget alerts. All eight accounts in the
owner's displayed list are marked Closed. Repeating the Blaze upgrade or
selecting another listed closed account does not establish enabled billing.

**Owner-provided billing guidance, approximately 8:40 PM EDT:** The owner
relayed an account-status message stating that a one-time minimum payment of
$30 USD is required to restore good standing. This is the supplied guidance,
not an independently verified transaction requirement or a completed payment.
No payment was submitted by the assistant. Recheck the live billing flags after
the owner completes any payment required by the official account page.

**Independently verified in Google Payments Center later that evening:**
Opened Subscriptions & services, selected Manage for the Google Cloud account
`012550-8FC12A-E19CC0`, and opened Critical alerts. The matching account alert
explicitly requires a one-time payment of **at least $30.00 to become active**.
It also says an already-made payment should be credited soon. The alert and
its Pay now control were left open for the owner. No Pay now control was
clicked and no payment or payment-method change was submitted. The owner must
complete the financial transaction; then recheck enabled billing and continue
backend setup. Screenshot evidence is in ignored
`.dart_tool/app-store-review-2026-10-27/required-activation-payment.jpg`.

**Owner payment receipt, 8:45 PM EDT:** The owner supplied a successful
**$10.00** receipt for **`011D9D-8B93EA-A892D2`**, My Billing Account 1.
This differs from Binary's linked `012550-8FC12A-E19CC0` account, whose alert
requires at least $30. The receipt says the payment should appear within
24 hours. A read-only check at 00:45:57 UTC still reports both accounts closed,
with Binary billing disabled and its link unchanged. Investigate whether the
paid account becomes usable and can then be linked to Binary before assuming
another payment is necessary. No relinking, payment or saved-card preference
change was performed by the assistant.

1. **Owner resolves the closed billing account** for `binary-6a372`, as
   described above, until Cloud Billing reports billing enabled. The owner
   completed the Blaze upgrade; the assistant made no billing change.
2. Configure RevenueCat's nine current products/packages, API and webhook
   secrets, store notifications and restore policy; verify store agreements
   and any legacy receipt bindings. Follow [PURCHASES.md](PURCHASES.md).
3. Deploy the purchase/account functions, then the matching Firestore rules.
   Verify webhook delivery and actual purchase activation. Checkout preflight,
   restore verification and account deletion depend on the absent functions.
4. On the exact iPhone/TestFlight build, test guest access, Apple/Google sign-in,
   a free first module, two separate course purchases, both bundles,
   reinstall/restore, a refund, and account deletion. Record the installed
   source revision; this continuation did not prove build 67's code revision.
5. Capture functional purchase screens for the nine current products and add
   them as Review Information screenshots. The two bundles, IT service
   management and Agile still show empty screenshot slots. The October 19
   audit found all ten drafts lacked screenshots; no new screenshots were
   uploaded in this continuation. Do not use the local previews showing
   purchases unavailable as evidence of working checkout.
6. Compare the prepared storefront images in
   `submission-assets/app-store/iphone-6.9/` with the intended iPhone build
   before uploading. Their manifest records rendered Flutter previews and
   `nativeDeviceVerified: false`.
7. Once these checks pass, add the seven current courses and two bundles to
   review with the app version, resolve any remaining validation errors, and
   submit. The legacy `binary_course_single` remains restore-only.

The October 19 report also records 27 EU regions excluded under the current
non-trader declaration. Regional declarations, legal agreements and account
permissions were not changed or freshly reverified today.

No app code, price, availability, billing plan, secrets, production rules,
functions, TestFlight build, or storefront screenshots changed in this pass.
Local source changes already present when this work resumed were left intact.
