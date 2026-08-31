# Binary Academy — release runbook

Two independent pipelines. Neither blocks the other.

- **Part 1 — iOS → TestFlight.** Two Codemagic settings away from a green build.
- **App Store submission.** Three non-code rejection items remain — see
  "What still blocks the App Store". The License Agreement blocker is cleared.
- **Part 2 — Firebase functions + rules.** Blocked on RevenueCat dashboard steps.

Last updated: 2026-08-31.

---

## Part 1 — iOS → TestFlight

### Why the last build failed

The build fails at `Building iOS` with:

```
Provisioning profile "B1nary ios_app_store" doesn't include the
Sign In with Apple capability / com.apple.developer.applesignin entitlement.
```

`ios/Runner/Runner.entitlements` has declared `com.apple.developer.applesignin`
since commit `7434109` (2026-06-06, "Fix Apple Review issues: Sign in with
Apple"). The last successful build predates it by three months, so this was
simply the first build that ever tried to compile that entitlement. The App ID
never had the capability turned on.

**The entitlement cannot be removed to dodge this.** The app offers Google
Sign-In, so Guideline 4.8 requires Sign In with Apple, and Apple Review already
rejected the app once for its absence. `test/codemagic_config_test.dart` fails
if the entitlement is deleted, so this cannot be "fixed" by accident.

### One-time setup — only you can do these

1. ~~**Enable the capability.**~~ **DONE 2026-08-31.** Sign In with Apple is
   now enabled on App ID `com.cristians.b1nary` (verified after a page reload:
   checkbox checked, "Enable as a primary App ID", Save greyed out). Apple
   warned on save that this **invalidates every existing provisioning profile
   for this App ID** — they must be regenerated, which is exactly what
   automatic signing does on the next build.

2. **Match the Codemagic integration name.** The App Store Connect API key
   already exists and is already in use: name **"Codemagic"**, Key ID
   **`49ACZ234H8`**, access **App Manager**, last used **2026-08-30**. Keys do
   not expire. Check what that integration is called on the *Codemagic* side
   (Teams → Integrations → App Store Connect) and edit
   `integrations.app_store_connect` in `codemagic.yaml` to match it exactly.
   Do **not** reissue the key — the `.p8` private key can only be downloaded
   once, at creation.

3. **Point Codemagic at the yaml.** Codemagic → app settings → Build → switch
   the source from **Workflow Editor** to **codemagic.yaml**.
   *Until this is done the file in this repo is ignored and the web UI config
   still runs.*

4. ~~**Fill in the app id.**~~ **DONE** — `APP_STORE_APP_ID: 6762030524`.

### Then, per release

Push to `master` and run the `ios-testflight` workflow. Nothing to bump by
hand: the pipeline reads the latest TestFlight build number and increments it,
so a duplicate-build-number rejection can no longer waste a build.

### What changed and why

| Before | Now |
|---|---|
| Pipeline lived only in the Codemagic web UI | Lives in `codemagic.yaml`, in version control |
| `codemagic.yaml` built `--no-codesign` (unsigned, unshippable) | Builds a signed IPA and uploads it |
| Manual signing — a hand-uploaded `.mobileprovision` | Automatic signing via App Store Connect API key |
| Build number bumped by hand in `pubspec.yaml` | Derived from the latest TestFlight build |
| No tests ran before release | `flutter analyze` + `flutter test` gate the build |

Manual signing is the specific thing being removed. A hand-uploaded profile
goes stale between builds — and this project builds months apart — so every
capability change, profile regeneration, or certificate expiry became a build
failure fixable only by re-uploading a file to a web UI. Automatic signing
refreshes profiles on every run.

### Notes on the pipeline

- **`flutter analyze` is strict.** The tree is clean at **zero** issues, so
  any new lint fails the build instead of accumulating. The ten info-level
  lints it used to carry are fixed. One of them was not cosmetic: the file was
  named `certificate_Screen.dart` while `quiz_screen.dart` imported
  `'certificate_screen.dart'`. Windows and macOS have case-insensitive
  filesystems so it compiled locally, but the `verify` workflow runs on
  **Linux**, where that import would not have resolved at all.
- **`xcode: latest`.** Pin this to a specific version once a build is green, so
  a future Xcode major release cannot silently break a build months from now.
  Pinning to a version Codemagic has retired fails instantly — only pin what
  you have actually seen work.
- **No `ios/Podfile` is committed.** Flutter generates a default one during the
  build. The old yaml's `find . -name "Podfile" -execdir pod install \;` matched
  nothing and silently did nothing. Worth committing a Podfile *and* a
  `Podfile.lock` eventually, so pod versions stop floating between builds.

---

## What still blocks the App Store

**A green build is necessary but not sufficient.** iOS `1.0 (47)` is
**Rejected**, submitted 2026-05-31, status *Unresolved Issues*, with four
findings — and only one of them is a code change. Resubmitting uses the
**"Resubmit to App Review"** button on the submission detail page; all items
must be addressed before it will be accepted.

| Guideline | Issue | Type |
|---|---|---|
| **4.8** Login Services | No Sign In with Apple | Code — **already written** (commit `7434109`), never successfully built |
| **2.3.2** Accurate Metadata | The promoted In-App Purchase's promotional image is just a screenshot from the app, with text too small to read | **Asset work** — needs a purpose-made image |
| **2.1** Information Needed | Apple **could not sign in** with the demo account stored in App Store Connect (`chaoticfuji@gmail.com`) | **Account work** — verify or replace the demo credentials |
| **2.1(b)** Information Needed | Reviewers **could not locate the In-App Purchases** in the app | **Root cause found** — the IAPs were never submitted; plus the paywall bug, now fixed |

### 2.1(b) — root cause found (2026-08-31)

**All three In-App Purchases are still Drafts, status "Prepare for
Submission". They have never been submitted for review.** App Store Connect
says it plainly on each one:

> Your first non-consumable in-app purchase must be submitted with a new app
> version.

| Reference name | Product ID | Apple ID | Status |
|---|---|---|---|
| Single Course Access | `binary_course_single` | 6763423925 | Prepare for Submission |
| 4 Course Bundle | `binary_bundle_4` | 6763424858 | Prepare for Submission |
| All Courses Bundle | `binary_bundle_all` | — | Prepare for Submission |

The product IDs match `kProductSingle` / `kProductBundle4` /
`kProductBundleAll` in `subscription_service.dart` exactly, and each has US
pricing, all-countries availability, and an English (U.S.) localization. What
they are missing is the **Review Information → Screenshot**, which is blank on
every one, and then the **"Add for Review"** button, which attaches them to the
next version submission.

So 2.1(b) has two independent causes, and both are now understood:

1. The IAPs were never attached to a submission, so there was nothing for the
   reviewer to approve.
2. The paywall blanked itself whenever offerings failed to load — **fixed**,
   see the paywall commit.

**On 2.3.2:** the promotional `Image (Optional)` field is **empty on all three
products today**, so there is currently no promotional image to be rejected.
That finding appears to have been resolved by removal. Leave it empty unless
you actually want App Store Promotion for these purchases; if you do, the image
must be 1024×1024 and must **not** be a screenshot of the app.

Two further notes:

- The **Paid Apps Agreement is Active** (Apr 25 2026 – Apr 11 2027), bank
  account and W-9 both active — so the usual "IAPs don't work because the
  agreement wasn't signed" cause is **ruled out**.
- **The likely cause is in our own paywall code.** `SubscriptionService`
  `.getPackages()` catches *every* RevenueCat error and returns `[]`.
  `PaywallScreen._loadPackages` then sets `_loadError = packages.isEmpty`, and
  the build method branches on it: `_loadError ? _buildErrorState(theme) : ...`
  — so the plan cards, the prices and the purchase button are **never
  rendered at all**. A reviewer whose sandbox account loads no offerings sees
  an error screen where the In-App Purchases should be, which is exactly what
  they reported. Tapping through would also have shown the misleading
  "Products are still loading. Please wait a moment and try again."
  Reproduce this on a sandbox account before replying to Apple; it is probably
  a fix, not an explanation.

### ~~A blocker that gated everything above~~ — CLEARED 2026-08-31

App Store Connect → Business had been warning that the updated Apple Developer
Program License Agreement needed accepting, and that **no app could be
submitted or updated** until the Account Holder accepted it.

**Accepted by the account holder on 2026-08-31.** Verified: the warning banner
is gone and the Free Apps Agreement now reads **Aug 31, 2026 – Apr 11, 2027,
Active** (previously "Active (New Agreement Available)"). Paid Apps Agreement
remains Active. Submissions are unblocked.

---

## Part 2 — Firebase functions and rules

**Deploy order is load-bearing.** Rules and client code are a single change.
Deploying rules first breaks purchases and trials for every live user, because
the shipped client still writes those fields directly.

Hosting is already deployed and verified at `binary-6a372.web.app`, which
closed the free-paid-catalogue leak. Steps 1–5 below are what remain.

```
1. Generate and set the webhook secret (a long random string):
   firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET

2. Deploy functions FIRST — the webhook must exist before rules block the client:
   firebase deploy --only functions

3. RevenueCat dashboard → Integrations → Webhooks:
     URL:  https://<region>-binary-6a372.cloudfunctions.net/revenueCatWebhook
     Authorization header: the exact value from step 1
   Send a test event; confirm a 200 in `firebase functions:log`.

4. Ship the app update and wait for adoption. Users on the OLD build keep
   working at this point, because rules are not yet tightened.

5. Only once adoption is acceptable:
   firebase deploy --only firestore:rules,firestore:indexes
```

### Verified locally (2026-08-31)

- `account.js`, `entitlements.js`, `index.js` all pass `node --check`.
- `firestore.rules` reviewed: entitlement fields are server-only via
  `entitlementsUnchanged()` / `noEntitlementsOnCreate()`; content reads are
  gated by `hasCourseAccess()`; `trialExpiry` defaults to `request.time` so a
  missing expiry fails closed; catch-all denies everything else.
- The `safeUpdate` fix is rules-compatible: a write to a not-yet-existing user
  document becomes a **create**, which `noEntitlementsOnCreate()` permits
  because it carries no entitlement fields.

### Not verified — and cannot be, from here

- **Rules do not compile until deployed.** There is no offline validator.
  `firebase deploy --only firestore:rules` is the first real syntax check.
- **The webhook has never received a live event.** Step 3's test event is the
  first end-to-end proof.
- `npm run lint` in `functions/` is **broken** — ESLint 8 is installed and
  `eslint-config-google` is declared, but there is no `.eslintrc` file, so
  ESLint exits with "couldn't find a configuration file". Unrelated to deploy,
  but the lint script is currently a no-op that reports failure.

### Still open after this

- `refreshEntitlement` throws `unimplemented` — it needs a RevenueCat `sk_`
  secret key.
- No `admins/{uid}` documents exist, so `isAdmin()` is false for everyone and
  catalogue writes are effectively closed to all clients. That is safe, but it
  means the in-app admin path is inert.
