# App Store Connect submission audit

Full sweep of every App Store Connect section, 2026-08-31, against
`com.cristians.b1nary` / app id 6762030524, iOS 1.0 build 47 (Rejected).

## The single most important finding

**App Review almost certainly never got into the app at all.**

* App Review Information has **"Sign-in required" ticked** with the demo
  account `chaoticfuji@gmail.com`, and Apple reported under Guideline 2.1 that
  those credentials did not work.
* The reviewer notes say: *"reviewers can try a complete lesson and quiz
  without signing in or making any purchase."* **This is not true.**
  `main.dart` routes an unauthenticated user to `WelcomeScreen`, which offers
  only Sign Up, Log In, Sign in with Apple and Sign in with Google. There is no
  guest or browse-only path anywhere in the app.

So the reviewer had broken credentials and a note telling them they did not
need any. That explains Guideline 2.1 **and** 2.1(b) — "we cannot locate the
In-App Purchases" is what you would report if you never got past the welcome
screen.

This supersedes the earlier theory that the paywall's blank-on-error state
caused 2.1(b). That bug was real and is fixed, but the reviewer probably never
reached the paywall.

Fix one of these, and correct the notes either way:

* **Fastest:** confirm a working demo account, put real credentials in App
  Review Information, and rewrite the notes to say sign-in **is** required.
* **Most durable:** add a genuine guest mode so the free first module really is
  reachable without an account. `firestore.rules` gates all content on
  `signedIn()`, so this means **Firebase Anonymous Auth** rather than opening
  the rules. It makes the note true and permanently removes the "we could not
  sign in" class of rejection.

## TWO NEW BLOCKERS FOUND IN THE FIREBASE CONSOLE (2026-08-31)

Both are invisible from App Store Connect and both are fatal on their own.

### 1. Sign in with Apple is NOT enabled in Firebase Authentication

Authentication -> Sign-in method lists **Email/Password, Google and Anonymous**
as enabled. The provider picker confirms it: those three carry checkmarks,
**Apple does not**.

So `OAuthProvider('apple.com')` + `signInWithCredential` will fail at runtime
with `operation-not-allowed`. Enabling the capability on the App ID (done) and
regenerating the profile is **not enough** — the button will appear and then
fail. That is Guideline 4.8 rejected a second time.

Fix: Firebase console -> Authentication -> Sign-in method -> Add new provider ->
Apple -> Enable. For native iOS only, no Services ID or key is required; those
are only needed for web and Android sign-in.

### 2. The Firebase project is on the Spark (free) plan

Cloud Functions cannot be deployed on Spark. Every function in `functions/` --
`revenueCatWebhook`, `startTrial`, `setPendingPurchase`, `refreshEntitlement`,
`deleteAccount`, and the three scheduled reminders -- is therefore
**undeployable today**. `firebase deploy --only functions` will refuse.

This matters far more than it looks. `SubscriptionService._syncToFirestore` was
deliberately removed, so the client no longer writes entitlements at all; only
the webhook does. **In the current build, a completed purchase grants nothing.**
A reviewer who buys an in-app purchase in the sandbox would pay and stay locked
out, which is a guaranteed rejection under 2.1.

Fix: upgrade to Blaze (pay-as-you-go, with a free monthly allowance that this
app's volume sits well inside), then follow the deploy order in
`docs/RELEASE.md` Part 2. **Do not submit until the webhook is live and a test
event has returned 200.**

## Blockers — must be fixed before resubmitting

| # | Issue | Guideline | Who |
|---|---|---|---|
| 1 | Demo account credentials do not work | 2.1 | You (I do not handle passwords) |
| 2 | Reviewer notes claim no sign-in is needed; there is no guest mode | 2.1 | Me, once you decide the approach |
| 3 | All three IAPs are Drafts, never submitted; each is missing its review screenshot | 2.1(b) | Screenshot from you, upload + Add for Review by me |
| 4 | Screenshots show **"ITIL V4 Foundation"** — a course title the app no longer uses | 2.3.3 | New screenshots needed |
| 5 | Description and keywords use certification marks as product names | 5.2.1 | **DONE — rewritten and saved 2026-08-31** |
| 6 | Sign in with Apple not enabled in Firebase Auth | 4.8 | You — one toggle in the Firebase console |
| 7 | Spark plan blocks Cloud Functions, so purchases grant nothing | 2.1 | You — upgrade to Blaze, then deploy |

### On 4 and 5 — the trademark scrub never reached the storefront

`lib/course_catalog.dart` exists specifically because using certification marks
as product names implies an affiliation that does not exist. In the app,
`itil-v4` now displays as **"IT Service Management Foundations"**.

The App Store listing still does the thing the code stopped doing:

* Screenshots (iPhone **and** iPad) show the old **"ITIL V4 Foundation"** title.
  They are from a pre-scrub build, so they no longer match the app — which is
  independently a 2.3.3 problem regardless of trademarks.
* Description opens *"Master ITIL V4, Cloud, Cybersecurity, Scrum..."*
* Keywords are `itil,cloud,certification,aws,scrum,exam,flashcards,cyber,network,quiz`
  — `itil`, `aws` and `scrum` are third-party marks.

Follow the same nominative model the catalogue already uses: sell the skill,
reference the exam factually with attribution.

**Suggested description opening**

> B1nary is the fastest way to build the skills IT certification exams actually
> test. Study IT service management, cloud, cybersecurity, networking and agile
> delivery through flashcard lessons and quizzes built around real exam
> objectives.

with a trailing attribution line:

> ITIL is a registered trademark of PeopleCert. CompTIA is a registered
> trademark of CompTIA, Inc. Certified ScrumMaster and CSM are registered
> trademarks of Scrum Alliance. This app is not affiliated with, endorsed by,
> or sponsored by any of these organisations.

**Suggested keywords** (100 character limit, drop the bare marks):

> `it certification,exam prep,flashcards,quiz,cloud,cybersecurity,networking,service management,agile`

## Non-blocking, but worth fixing now

**Digital Services Act — 27 countries are already unavailable.** App
Information says *"This developer has identified itself as a non-trader for
this app."* Pricing and Availability then shows **148 available, 27 not
available**. Selling paid in-app purchases makes you a trader under the DSA, so
the non-trader declaration is both inaccurate and costing you the entire EU.
Fixing it requires submitting verifiable trader contact details to Apple.

**New age-rating questions.** A banner warns of new social media questions in
App Information: *"Answers aren't required until September 7, 2026, unless you
are submitting a new app or updating other answers in that section."* You are
submitting, so answer them. The app has no social features, so the answers
should be straightforward.

**iPad.** `TARGETED_DEVICE_FAMILY = "1,2"` — the app ships universal, which is
why review tested on an iPad Air. `Info.plist` also enables **all four
orientations on iPad** while iPhone is portrait-only, and the code's own
`WebContentBounds` comment says most screens "were built mobile-first and never
got a wide-screen pass". An untested landscape iPad layout is a 2.1 / 4.0 risk.
Either give iPad a real pass, or set `TARGETED_DEVICE_FAMILY = "1"` and ship
iPhone-only — which also drops the iPad screenshot requirement.

**App Accessibility** is untouched ("Get Started"). These labels are **opt-in**
and are not a submission requirement, but they display on the product page.

## What I changed in App Store Connect (2026-08-31)

All three saved and re-read after a full page reload to confirm they persisted.

* **Description** — rewritten (1,540 chars). No longer opens with "Master ITIL
  V4, Cloud, Cybersecurity, Scrum". Leads with the skills, lists the courses
  under their real in-app names, and closes with a trademark attribution and a
  clear non-affiliation statement.
* **Keywords** — now
  `it certification,exam prep,flashcards,quiz,cloud,cybersecurity,networking,service management,agile`
  (98 of 100 chars). The bare marks `itil`, `aws` and `scrum` are gone.
* **App Review notes** — rewritten (1,962 chars). The previous notes claimed
  the app worked without signing in, which was false. They now lead with
  "Continue as guest", give two exact routes to the paywall, list all three
  product IDs, and state the trademark position. They also acknowledge the
  earlier incorrect note.

**These notes describe the build with guest mode, not build 47.** They are only
accurate once a build containing the guest option is uploaded.

## Still outstanding, and only you can do them

* A working **demo account** (I do not handle passwords). Guest mode makes this
  a backup rather than the only way in, but the credentials on file should
  either work or be removed.
* **Screenshots** — the current ones show "ITIL V4 Foundation" and must be
  replaced from a build that matches the shipping app.
* **IAP review screenshots**, then "Add for Review" on all three products.
* **Digital Services Act trader status**, if you want the EU back.
* The **new age-rating social media questions** in App Information.

## Verified healthy — no action needed

* **App Privacy**: published, 6 data types (Crash Data, Email, Name, Product
  Interaction, Purchase History, User ID), consistent with the live policy.
* **Privacy Policy URL** `https://binaryapp.org/privacy` — live, thorough,
  dated 2026-04-24, covers Firebase/RevenueCat/Apple, deletion rights, under-13.
* **Support URL** `https://binaryapp.org/support` — live, real FAQ, contact
  `support@binaryapp.org`. **Marketing URL** `https://binaryapp.org` — live.
* **Age rating** 4+ across 172 regions.
* **Export compliance**: `ITSAppUsesNonExemptEncryption = false` is already in
  `Info.plist`, so no upload prompt and no documentation needed.
* **Build 47 (1.0.0)** is attached to the version.
* **Contact information** complete. **Content Rights**, **tax category**, and
  **price schedule** (175 regions, USD base) all set.
* **IAP configuration** itself is correct: product IDs match `kProductSingle` /
  `kProductBundle4` / `kProductBundleAll` exactly, all-countries availability,
  US pricing, English (U.S.) localizations present.
