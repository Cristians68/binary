# Course content — accuracy pass and seeding

Last updated: 2026-08-30

## 1. What was reviewed

The four `admin/seed/create-*.js` scripts and the two `expand-*.js` scripts
hold roughly 1,000 hand-authored flashcard and quiz items. Three of the four
new courses had previously been spot-checked only:

| Course | Seed script | Items |
|---|---|---|
| Network Professional | `create-network-pro.js` | 84 flashcards + 84 quiz |
| Cloud Fundamentals | `create-cloud.js` | 84 flashcards + 84 quiz |
| Cloud Architecture | `create-cloud-pro.js` | 84 flashcards + 84 quiz |
| Cybersecurity Professional | `create-cyber-pro.js` | 84 + 84 (previously verified) |

All 252 quiz questions across the three unverified courses were read against
their answer keys and explanations.

**No factual errors were found.** Answer keys, explanations and distractors are
correct throughout. Subnetting arithmetic (`/28` → 14 usable), OSI layer and
PDU naming, private address ranges, port numbers, WiFi band trade-offs, DNS
record semantics, and the cloud service/deployment model definitions all check
out.

## 2. Structural validation

Reading for facts does not catch structural faults, so
`admin/seed/validate-content.js` checks every item mechanically. It stubs
`firebase-admin`, needs no credentials, and **writes nothing**.

```bash
node admin/seed/validate-content.js       # exits non-zero on any ERROR
```

It reports:

- an answer key outside the options array, or one that is not a number
- two identical option strings in one question (an error when one of them is
  the answer, a warning otherwise)
- empty question, answer, or option text
- a duplicate `order` value within a module, which the quiz screen sorts by
- a missing explanation (warning — the score screen shows a blank rationale)

Current status: **0 errors, 0 warnings** across all six scripts.

A validator nobody has watched fail is not evidence of anything, so
`validate-content.selftest.js` injects each fault class into a temporary copy
of a real seed script and asserts the validator both fails and says why:

```bash
node admin/seed/validate-content.selftest.js
```

If you add a check to the validator, add a mutation here too. A check with no
mutation behind it may already be dead.

## 3. The answer-position bias

Across the ~420 authored quiz questions, the correct answer sits at
`correctIndex: 1` about **92%** of the time — in `create-cloud-pro.js` it is 83
of 84.

This is **not** fixed in the data. It is neutralised at runtime by
`shuffleQuizQuestions` in `lib/screens/quiz_logic.dart`, which reorders the
options every time a quiz loads.

That makes the shuffle load-bearing, not cosmetic. **Removing it, or
"simplifying" it away, makes every quiz in the app passable by always tapping
the second option.** `test/quiz_logic_test.dart` has a test named *breaks up
the answer-position bias in the authored content* that fails if it stops
distributing answers across positions.

The shuffle also must not be rewritten as *remember the answer text → shuffle →
`indexOf`*. `indexOf` returns the first match, so a question containing the
same option text twice would mark a correct tap wrong. It shuffles positions
instead, and there is a test for that too.

## 4. Trademark handling in content

Course *titles* come from `lib/course_catalog.dart` and never contain a
certification mark — that is enforced by `test/course_catalog_test.dart`.

Inside lesson and quiz content, marks **are** used, and that is intentional.
Every occurrence reviewed is nominative and factual: teaching *about* ITIL,
Scrum, or a vendor-neutral networking certification, not naming a product after
one. That matches the `preparesFor` doctrine in `course_catalog.dart`. Keep new
content on the same side of that line: describe what the material covers, never
imply accreditation or endorsement.

## 5. Before running any seed script

The `create-*.js` scripts write directly to production Firestore.

`create-network-pro.js` carries a quarantine notice at the top and **is not
safe to run as-is**. It was written assuming `binary-network-pro` was an empty
course. The real id is `binary-network-professional`, and it already holds 20
modules of live content. The module ids here (`module-1`..`module-7`) are
guesses and may collide with real ones.

The same caution applies to the others: `createModule()` skips a module that
already has a title, but it does not verify that the module ids it writes match
the course's real structure.

Each script now ends by printing the course id it **actually wrote to**, plus
which modules were written and which were skipped. Previously all four printed
a different id than they wrote to — `create-network-pro.js` wrote to
`binary-network-professional` and announced "binary-network-pro created fresh"
— which is the exact wrong-id confusion that got the script quarantined in the
first place. Read that final summary; do not assume.

Pull the live module documents and compare before running anything.
