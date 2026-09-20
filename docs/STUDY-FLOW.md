# Study flow and offline downloads

Updated 2026-09-19.

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

## Verification

Run `flutter analyze --no-pub` and `flutter test --no-pub`. The regression
coverage includes delayed save retries, account changes during a quiz,
failed-save recovery, incomplete downloads, saved lessons with an empty
catalogue, paid offline access, and onboarding at 320px with doubled text.

The 2026-09-19 local run passed all 489 Flutter tests with zero analyzer issues.
`flutter build web --release --no-pub` also succeeded. Its optional Wasm probe
reports an incompatibility in `purchases_flutter`; the JavaScript release
output in `build/web` built successfully.
These checks do not exercise Apple's native sign-in or StoreKit runtime;
those still need an iOS device or the configured TestFlight build.
