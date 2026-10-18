# Binary Academy review readiness — 2026-10-16

Version: **1.0.9+63**. Local code is ready for review. App Store submission still
requires production and physical-device verification. Codemagic determines the
actual TestFlight build number and stamps the source revision.

## Changes to review

- Quiz results show the pass mark and offer mistake review with the selected
  answer, correct answer and explanation. Perfect attempts offer all-answer
  review. Retakes clear old answers and reshuffle options; reviewing
  does not resubmit scores or change spaced-repetition schedules.
- Quiz feedback announces correctness and identifies the correct answer without
  relying on color. Dark-mode answer text and result actions have clearer
  contrast. Results and review scroll at doubled text on small phones.
- Questions and retakes reset scrolling. Leaving an answered quiz requires
  confirmation, and back navigation is blocked while saving. System back from
  mistake review returns to the summary with the results intact.
- Courses show three concrete skills each. Search matches skill summaries,
  descriptions and multiple words; subject filters use canonical metadata even
  when a stored course tag is outdated. Onboarding previews those skills.
- Review recovers healthy saved questions independently, rejects invalid answer
  keys and ambiguous options, repairs unusable schedules, and deduplicates IDs.
  A session uses one queue snapshot and cannot update another account after a
  sign-in change.
- Review uses the app typography instead of Flutter's underlined fallback.
  Long course titles wrap, empty/results pages scroll at doubled text, feedback
  announces correctness and names the correct answer, and each next question
  starts at the top. Scheduled questions have an informative caught-up state.
- Published quiz parsing rejects case-only duplicate answers. The seed validator
  now rejects fractional/non-finite keys, invalid ordering, non-string answers,
  duplicate distractors/document writes, missing explanations and empty scripts.
  Both Codemagic workflows run the validator and its mutation self-tests.
- Sample content and relevant seed material clarify private cloud subnet access,
  Product Owner delegation, Scrum release timing/timeboxes, and IPv4 host counts.

## Verification

| Check | Result |
| --- | --- |
| Flutter analyzer | Zero issues |
| Full Flutter suite | 682 passing |
| Backend suite | 49 passing on October 15; backend unchanged |
| Firestore emulator | 16 passing on October 15; rules unchanged |
| iOS archive verifier tests | 9 passing on October 15; native files unchanged |
| Offline seed validation | October 15: 7 scripts, 504 flashcards and 504 questions; zero errors/warnings |
| Validator mutation self-tests | October 15: 14 fault classes detected; clean control passes |
| UI preview gate | 9 targeted quiz captures; zero runtime exceptions or overflows |
| JavaScript release web build | Success |

Visual evidence is local under `.dart_tool/ui-review/`. Chrome uses actual
Flutter widgets, fake Firestore and fictional learner data. It checks runtime
exceptions and overflow, including onboarding, course cards, review feedback,
review results and empty states at 320px with doubled text. The 32 earlier
captures passed on October 13; this pass refreshes nine quiz feedback, results,
review and action captures, including dark mode and 320px doubled text. This
does not prove VoiceOver behavior, StoreKit, Face ID or iOS-native authentication.

The JavaScript web release is the supported web build. The existing optional
Wasm probe warning comes from `purchases_flutter`; no Wasm release is claimed.

## Content accuracy and publishing scope

The structural audit covers the checked-in seeds, not every paid document in
production. Factual checks in this pass were targeted spot-checks, not a claim
of comprehensive exam alignment. Corrected explanations were checked against:

- [RFC 3021](https://www.rfc-editor.org/rfc/rfc3021.html): /31 point-to-point
  links use both addresses as endpoints; the usual subtract-two rule has limits.
- [AWS VPC subnet documentation](https://docs.aws.amazon.com/vpc/latest/userguide/configure-subnets.html):
  private subnets can have outbound internet access through NAT.
- [The Scrum Guide](https://scrumguides.org/scrum-guide.html): backlog work may
  be delegated while Product Owner accountability remains; a finished Increment
  need not wait for Sprint Review; shorter-event timing has no fixed ratio.

No production content was modified. Updated seed wording is staged for an
administrator to compare against live module/question IDs before publishing.
Do not run the quarantined networking seed over the existing 20-module course.
Use targeted updates that preserve document IDs and learner progress, following
[CONTENT.md](CONTENT.md). The built-in sample questions remain practice-only.

## Remaining submission gates

The production audit on **2026-10-18** confirmed Firebase billing disabled,
zero deployed Cloud Functions, Secret Manager disabled, and older deployed
Firestore rules lacking multiple-course purchase authorization. See
[PAYMENT-AUDIT-2026-10-18.md](PAYMENT-AUDIT-2026-10-18.md). Purchases, restores
and account deletion must work end to end before submission.

1. Confirm Blaze billing, store agreements/products, RevenueCat configuration,
   secrets and any legacy receipt bindings. Follow [PURCHASES.md](PURCHASES.md)
   and [SECURITY.md](SECURITY.md) for functions-before-rules deployment order.
2. Build the committed revision in Codemagic. On an actual iPhone, test guest
   entry, native Apple/Google sign-in, purchases of two separate courses,
   bundle selections, restores/refunds, account deletion, session expiry and
   Face ID. The owner confirmed Apple sign-in on October 7; verify the new build.
3. Replace or compare rendered screenshot previews with the exact TestFlight
   build, update App Privacy answers and current IAP review assets, and confirm
   App Store Connect metadata and review notes describe the submitted revision.

## Reviewer walkthrough

For the build containing these changes, a reviewer can skip onboarding and use
**Continue as guest**, then open **Courses**, select a course, and study its
free first module. Reveal flashcards, take its quiz, and read the explanations.
On the result screen, open **Review mistakes** (or **Review answers** after a
perfect attempt), return to the summary, and try again. After answering one
question, use **Lesson** and **Keep going** to verify that answers are retained.
Missed published questions become available in **Review** from Home. Review
practice does not award course completion.

In **Courses**, search `subnetting dns`, clear the search, and try subject or
**My courses** filters. Enrollment bookmarks a course; it does not purchase it.
Open **View plans** or a locked module to inspect the purchase screen. The
current catalogue has seven course-specific non-consumables plus two bundles;
the legacy generic single-course product is restore-only. Product IDs and
production setup are listed in [PURCHASES.md](PURCHASES.md).

No Firebase deployment, production seed run, TestFlight upload or App Store
submission was performed by this local review pass.
