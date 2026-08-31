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

## Blockers — must be fixed before resubmitting

| # | Issue | Guideline | Who |
|---|---|---|---|
| 1 | Demo account credentials do not work | 2.1 | You (I do not handle passwords) |
| 2 | Reviewer notes claim no sign-in is needed; there is no guest mode | 2.1 | Me, once you decide the approach |
| 3 | All three IAPs are Drafts, never submitted; each is missing its review screenshot | 2.1(b) | Screenshot from you, upload + Add for Review by me |
| 4 | Screenshots show **"ITIL V4 Foundation"** — a course title the app no longer uses | 2.3.3 | New screenshots needed |
| 5 | Description and keywords use certification marks as product names | 5.2.1 | Me — draft below |

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

> Binary is the fastest way to build the skills IT certification exams actually
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
