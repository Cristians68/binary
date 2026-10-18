# Binary Academy: market research and product direction

Research date: October 17, 2026. This is a feature and learning-experience
comparison using public product pages, not a market-share or efficacy ranking.
Competitor claims are not evidence of Binary Academy's outcomes. Prices and
paid-plan limits were not used because they change and vary by region.

## What the market teaches us

| Reference | Observed pattern | Implication for Binary Academy |
| --- | --- | --- |
| [Quizlet Learn](https://quizlet.com/features/learn) | Adaptive practice, several question formats, short targeted sessions | Give learners an immediate way to practice their weak areas. Longer term, vary tasks beyond multiple choice. |
| [Brilliant practice](https://brilliant.org/math/practice/) | Interactive problems with feedback and practice based on progress | Explanations should help repair a mistake; future IT lessons should include realistic troubleshooting tasks. |
| [Duolingo on spaced repetition](https://blog.duolingo.com/spaced-repetition-for-learning/) | Practice selected using spacing and accuracy | Preserve delayed review even when a learner successfully retries immediately. |
| [Khan Academy mastery](https://support.khanacademy.org/hc/en-us/articles/360007253831-Using-self-paced-practice-and-Mastery-in-the-classroom) | Skills and progress guide a learning path | Separate course completion, quiz scores, and evidence of retention; don't label a single successful retry as mastery. |
| [Coursera on mastery learning](https://blog.coursera.org/how-to-integrate-mastery-learning-into-course-design/) | Practice and feedback embedded in courses, with assessment retakes | Connect lessons, recall, feedback, and retakes into a coherent loop. This is an older pedagogy article, not a current feature inventory. |
| [Carnegie Mellon: retrieval practice](https://www.cmu.edu/teaching/resources/instructionalstrategies/activelearningstrategies/retrievalpractice/index.html) | Recall from memory with feedback supports learning | Add an answer-hidden recall step instead of relying entirely on reading flashcards. |

## Product decision for this iteration

Binary already has courses, explained quizzes, shuffled choices, local offline
flashcards, account-scoped spaced review, progress, and study reminders. The
largest actionable gaps were passive flashcards and a long route from quiz
mistakes to another useful attempt.

Implemented:

- **Recall practice from lessons:** definitions and examples stay hidden until
  Reveal answer. Learners self-assess with Got it / Needs practice, then can
  repeat only the difficult cards. Returning preserves the lesson position.
- **Focused practice from quiz results:** a new round contains only that
  attempt's missed questions, with shuffled answer positions, explicit feedback,
  and optional rounds for remaining mistakes. Returning keeps the original
  result. It never awards course completion or alters the review schedule.
- **Readable presentation:** finish the existing light-theme improvements;
  use real buttons, focus support, live announcements, and scrolling layouts.
- **Web parity:** the browser app shares the same Flutter implementation.
  The landing page now demonstrates recall, explains focused practice and
  delayed review, and accurately states offline limitations.

These are deliberate practice tools, not an adaptive psychometric model.
Recall ratings are self-reported and session-local. A completed round is not
proof of retention or certification readiness. Existing spaced review remains
the place for delayed retrieval.

## Next priorities, in order

1. **Release reliability:** resolve and verify production purchase/restore and
   deletion functions, then exercise the exact iOS build on a real device.
   See HANDOFF.md; these are existing release gates, not fixed by UI work.
2. **Content quality:** review question ambiguity, distractor plausibility,
   answer-length cues, scenario realism, and vendor-version accuracy. Shuffling
   fixes positional cues but cannot fix weak questions. Add per-item source,
   review date, skill tags, and correction history before expanding the bank.
3. **Continuity:** account-scoped resumable lesson/quiz sessions with content
   version checks; keep interrupted learning recoverable without stale answers.
4. **A useful daily plan:** a small next-session recommendation combining due
   review with the next lesson. Explain why it is recommended and let learners
   choose; do not equate streaks or points with competence.
5. **Broader assessment:** introduce scenario questions and safe simulated IT
   tasks, then an explicitly separate exam-practice mode with navigation,
   flags, delayed feedback, and optional timing. Validate scoring before launch.
6. **Retention evidence:** show skill-level progress based on delayed attempts
   and more than one question per skill. Avoid unsupported readiness percentages.
7. **Learner research:** observe first-time and returning learners on phones
   and desktop, including keyboard and screen-reader users. Use findings to
   choose the next change rather than accumulating dashboard features.

## Measure whether changes help

Proposed metrics, not currently collected by this patch:

- First useful session: guest entry to first lesson/quiz completed, with failure
  and abandonment points separated from purchase conversion.
- Learning loop: missed-answer review and focused-practice starts/completions.
- Retention: accuracy on later scheduled reviews, not immediate repeat accuracy.
- Continuity: sessions successfully resumed after interruption.
- Reliability: failed saves, app startup failures, blocked access after purchase,
  and content-load failures.
- Accessibility: task completion with large text, keyboard-only use, and native
  screen readers; automated layout checks alone do not establish conformance.

Collect only minimal event counts under a deliberate privacy decision; never
include answer text, course notes, names, email addresses, or authentication
data in analytics. No analytics SDK or production tracking was added here.
