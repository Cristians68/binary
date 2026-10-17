# Study flow and offline downloads

Updated 2026-10-16.

## Content and downloads

Lessons and quizzes identify published content, a saved copy, sample practice,
or unavailable content. Missing content offers a retry. Sample practice never
awards course progress or certificates.

Downloads save a complete set of flashcards and module metadata in one local
write, scoped to the signed-in account. A failed refresh preserves the old
copy. Incomplete or malformed saved copies are not listed as downloaded.

The downloads screen shows local copies immediately and keeps them visible
when the course lookup returns empty or fails. **Study lessons** opens the
saved module list and flashcards directly. Paid lessons still require a
matching entitlement in the account's Firestore cache; the existence of a
download does not grant access. Reconnect to refresh access, load new quizzes,
or save course progress. Removing a download uses only local storage.

## Saving quiz results

A passing quiz saves its module status, course progress, and quiz history in
one transaction. Each attempt has a receipt under
`users/{uid}/progress/{courseId}/modules/{moduleId}/attempts/{attemptId}`.
Retrying the same attempt cannot add another score, even after a later retake.
Receipts inherit the existing owner-only progress rules.

The quiz remembers the account that started it. Signing out or changing
accounts cannot silently save the result to a different account. A failed
save keeps the answers and offers **Retry save**; success is shown only after
the save completes.

## Quiz feedback and navigation

Results show the number of correct answers needed to pass. **Review mistakes**
lists the questions missed in this attempt, the selected answer, the correct
answer and its explanation. A perfect attempt offers **Review answers** instead.
This is read-only feedback: it cannot change the score, award a second
completion or move a question's spaced-repetition due date. **Try again** starts
a full new attempt, clears the feedback and reshuffles the answer options.

Questions and retakes start at the top of the scroll view. After an answer has
been selected, the Lesson button and system back ask before discarding the
attempt; the route's edge swipe is disabled while answers are in progress.
Exit is disabled during a save. Quiz options and result actions support focus
and expose button semantics. Result summaries and answer reviews scroll on
small screens with larger text.

Each answer shows a correctness message and names the correct answer after a
miss. The feedback is a screen-reader live region, and answer options identify
correct/incorrect choices in their accessibility labels. Answer text and
result actions stay legible in dark mode. System back from answer review
returns to the result summary without discarding the attempt.

## Verification

Run `flutter analyze --no-pub` and `flutter test --no-pub`. The regression
coverage includes delayed save retries, account changes during a quiz,
failed-save recovery, incomplete downloads, saved lessons with an empty
catalogue, paid offline access, and onboarding at 320px with doubled text.
`quiz_feedback_test.dart` also covers answer-review accuracy after shuffling,
read-only review behavior, fresh retakes, scroll reset, and confirmed exits.

The 2026-09-19 local run passed all 489 Flutter tests with zero analyzer issues.
`flutter build web --release --no-pub` also succeeded. Its optional Wasm probe
reports an incompatibility in `purchases_flutter`; the JavaScript release
output in `build/web` built successfully.
These checks do not exercise Apple's native sign-in or StoreKit runtime;
those still need an iOS device or the configured TestFlight build.
