# App Store Connect copy and checklist — October 29, 2026

Prepared while the owner requested background-only work. **Not saved to App
Store Connect.** The live trial and anonymous-account deletion checks pass;
purchase backend setup and the exact native build still need verification.
Do not submit until those remaining checks pass.

App: B1nary Academy, `com.cristians.b1nary`, Apple ID `6762030524`.
Keep the existing **1.0.11** draft and manual release. The owner is building
source commit **bfe63c4** (local version 1.0.11+68) through Codemagic. The actual
build number comes from Codemagic; replace the older selected build 67 only
after the new build finishes processing and its source revision is verified.

## Promotional text draft

Build IT skills with flashcards, explained quizzes and recall practice. Try one full course free for 7 days. No card required or automatic charge.

## Release notes draft

- Try one full course of your choice free for seven days, with no automatic charge.
- Keep your study progress when moving between compact and wide layouts.
- Send feedback with clearer retry handling and improved keyboard accessibility.

## App Review notes draft

Paste only after verifying the final build and all described production paths:

```text
B1nary Academy is an independent IT study app. Its courses are study aids;
completion does not award an industry certification.

No demo-account credentials are required for the guest review route:
1. Open the app, skip or finish onboarding, then choose Continue as guest.
2. Open Courses and choose a course. The first module of every course is free.
3. Read its flashcards, take the quiz, and inspect the answer explanations.
   Quiz results also provide answer review and focused practice.

7-day free trial:
Open Profile > Legal & Purchases > Plans & Pricing. Choose a course in the
trial section and tap Start 7-day free trial. A paywall opened from a locked
course names that course. One trial unlocks all lessons and quizzes in one
chosen course for 168 hours from activation. The course cannot be switched.
There is no payment sheet, card requirement, renewal or automatic charge.
The paywall shows the active trial's local expiry date and time. After expiry,
progress remains and the first module of every course is still free.

In-app purchases:
The same Plans & Pricing screen offers Single course, Any 4 Courses, and
Everything. These are non-consumable, one-time purchases, not subscriptions.
Single course requires a named selection. Any 4 Courses requires exactly four
selections. Everything includes all current and future courses. Prices are
localized by the App Store. Restore purchases is on the same screen and in
Legal & Purchases. Restoration retains the original bundle course choices.
The legacy binary_course_single product is restore-only.

Profile includes Delete account. Registered users reauthenticate first;
account deletion removes the account and its stored study/profile data.
Private Send feedback and the public Rate B1nary action are separate.
```

Do not state that all purchase paths work until RevenueCat, secrets, functions,
matching rules and native sandbox checks have actually passed.

## Products to attach after screenshots and functional checks

| Product | Review route |
| --- | --- |
| `binary_course_itsm` | Single course: IT Service Management Foundations |
| `binary_course_scrm` | Single course: Agile & Scrum Foundations |
| `binary_course_netp` | Single course: Network Professional |
| `binary_course_secp` | Single course: Cybersecurity Professional |
| `binary_course_cldf` | Single course: Cloud Fundamentals |
| `binary_course_clda` | Single course: Cloud Architecture |
| `binary_course_aiml` | Single course: AI & Machine Learning Foundations |
| `binary_bundle_4` | Any 4 Courses; exactly four selections; Unlock 4 Courses |
| `binary_bundle_all` | Everything; Unlock Everything |

Capture the working purchase screen for each current product's Review
Information screenshot. A screen saying purchases are unavailable is not evidence
of functional checkout. Keep the legacy generic single product restore-only.

## Before submitting

1. Verify the new TestFlight build and source revision, guest entry, Apple and
   Google sign-in, full trial activation, purchases of two separate courses,
   both bundles, restore/reinstall, refunds and account deletion on an iPhone.
2. Compare the local storefront captures with that native build before uploading.
   `submission-assets/app-store/capture-manifest.json` still records rendered
   previews and `nativeDeviceVerified: false`. These files remain local.
3. Check Support URL, Privacy URL, privacy answers, age rating, agreements and
   product availability. Preserve existing regional settings unless the owner
   asks to change them. Do not make new legal declarations on their behalf.
4. Save the accurate review notes and attach the nine current IAPs after their
   screenshot slots and validation checks pass. Preserve manual release.

The last observed App Store state was the October 27 checkpoint; no browser
actions or fresh live-page claims are made by this background preparation.
