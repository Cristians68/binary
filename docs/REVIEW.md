# Spaced-repetition review

Added 2026-08-30.

## What it does

A question the user gets wrong in a quiz is filed into a local review queue.
It comes back immediately in the next review session, and each time it is
answered correctly the wait before it returns grows. Answer it wrong again and
it goes straight back to the front.

Entry point is a card on the home screen, above **My courses**. It is hidden
entirely until the user has actually missed something, so a new account never
sees an empty feature.

## The model

A Leitner box system. Five boxes with expanding intervals:

| Box | Wait before it returns |
|---|---|
| 0 | immediately |
| 1 | 1 day |
| 2 | 3 days |
| 3 | 7 days |
| 4 | 21 days |

Clearing box 4 retires the question and **removes it from the queue** — the
stored queue does not grow without bound over months of use.

A wrong answer resets to box 0, not down one box. A question you have just
failed is one you do not know, whatever your history with it.

## Where the code lives

| File | Role |
|---|---|
| `lib/screens/review_logic.dart` | All scheduling. Pure functions over plain maps — no Firestore, no plugins, no widgets. |
| `lib/screens/review_service.dart` | Persistence only. Reads and writes SharedPreferences, delegates every decision to the logic file. |
| `lib/screens/review_screen.dart` | The session UI. |
| `test/review_logic_test.dart` | 40 tests over the scheduling rules. |

The split is the point: a scheduling bug means either questions that never come
back or a queue that never drains, and neither is visible from the outside.
Keeping the rules pure makes the whole algorithm testable with no fake and no
plugin. **Put new scheduling rules in `review_logic.dart`, not in the service or
the screen.**

## Why the queue is local, not in Firestore

Review history is per-device study state, not entitlement or billing data, so
nothing here needs to be server-authoritative.

Keeping it in SharedPreferences means the feature ships **without a Firebase
deploy**. The rules and functions changes in `docs/SECURITY.md` are still
undeployed; adding a new Firestore collection would have put this feature
behind that same blocked deploy.

The trade-off is real: the queue does not follow a user to a second device, and
clearing app data clears it. If it should sync, it belongs at
`users/{uid}/review/` with a matching rule — but that is a deploy, not a code
change.

Because the queue is local, `ReviewService.clear()` is called on account
deletion (`delete_account_screen.dart`). The server-side delete cannot reach
SharedPreferences, and without that call the next person to sign in on the
device would inherit the previous user's missed questions.

## Two things not to undo

**The session re-shuffles answer order.** `ReviewScreen._load` runs stored
questions back through `shuffleQuizQuestions`. The stored `correct` index
refers to the option order at the moment of the miss; without the reshuffle a
review session would just retrain the *position* of the answer rather than the
answer. See `docs/CONTENT.md` §3 for why answer position is load-bearing in
this app.

**Misses are recorded without `await`.** `QuizScreen._selectAnswer` fires
`ReviewService.recordMiss` and does not wait for it. Answer feedback must be
immediate, and the service swallows its own storage errors, so a failed write
can never block or break the quiz. Do not add an `await` there.

## Session cap

`ReviewService.maxSessionLength` caps a session at 20 questions so a long
backlog does not present an unfinishable wall. Anything over the cap stays due
and comes back next session.
