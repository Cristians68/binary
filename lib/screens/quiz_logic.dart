/// Pure scoring and answer-ordering logic for [QuizScreen].
///
/// WHY THIS IS ITS OWN FILE
/// ------------------------
/// This is the logic that decides whether a user passed, and which option is
/// the right one after the answers are reordered. Getting it wrong marks a
/// correct answer wrong, or hands out a module completion nobody earned.
/// Inside a StatefulWidget it could only be exercised by driving the whole
/// screen; here it is directly testable, and `test/quiz_logic_test.dart` does
/// exercise it.
library;

import 'dart:math';

/// Reorders each question's answers so the correct option is not always in the
/// same position.
///
/// The seed content is heavily biased — across the ~420 authored questions the
/// answer sits at index 1 about 92% of the time — so without this a user can
/// pass every quiz in the app by always picking the second option. Do not
/// remove this in the belief that the stored data is already varied.
///
/// Pass [rng] to make the ordering deterministic in tests.
List<Map<String, dynamic>> shuffleQuizQuestions(
  List<Map<String, dynamic>> questions, {
  Random? rng,
}) {
  final random = rng ?? Random();
  return questions.map((q) {
    final answers = List<String>.from(q['answers'] as List? ?? const []);
    final correct = q['correct'];

    // Shuffle a list of POSITIONS rather than the strings themselves, then read
    // the new index straight out of that permutation.
    //
    // The obvious implementation — remember the correct answer's text, shuffle
    // the strings, then indexOf() it — is subtly wrong. `indexOf` returns the
    // FIRST match, so if a question ever contains the same option text twice
    // and that text is the answer, a user who taps the second copy is marked
    // wrong for choosing a string that is character-for-character correct.
    // Positions are unique, so this cannot happen.
    final order = List<int>.generate(answers.length, (i) => i)..shuffle(random);
    final shuffled = [for (final i in order) answers[i]];

    // An out-of-range or non-numeric key would throw here and drop the whole
    // module into the fallback questions with nothing shown to the user.
    // Degrade to "no option is correct" (-1) instead: the quiz still renders
    // and the bad question simply cannot be answered correctly.
    final oldCorrect = correct is int ? correct : -1;
    final newCorrect =
        (oldCorrect >= 0 && oldCorrect < answers.length)
            ? order.indexOf(oldCorrect)
            : -1;

    return {
      'question': q['question'],
      'answers': shuffled,
      'correct': newCorrect,
      'explanation': q['explanation'] ?? '',
    };
  }).toList();
}

/// Number of correct answers needed to pass: 60% of the question count,
/// rounded up. 12 questions therefore needs 8, not 7.
int quizPassMark(int total) => total <= 0 ? 0 : (total * 0.6).ceil();

/// Whether [score] out of [total] is a pass.
///
/// A quiz with no questions is never a pass. Without the `total > 0` guard,
/// `0 >= 0` is true and an empty quiz would silently award module completion.
bool quizPassed(int score, int total) =>
    total > 0 && score >= quizPassMark(total);

/// Score as a whole-number percentage, 0 for an empty quiz.
///
/// Guards the `0 / 0` case: that is NaN, and `NaN.toInt()` throws
/// UnsupportedError rather than returning anything.
int quizScorePercent(int score, int total) =>
    total <= 0 ? 0 : (score / total * 100).round().clamp(0, 100);

/// Upper bound for the random half of an attempt id.
///
/// ⛔ THIS MUST STAY AT OR BELOW `1 << 31`, AND THE SHIFT MUST NOT BE 32.
///
/// `1 << 32` looks like the natural "full 32 bits of entropy" bound and is
/// correct on the VM, where it is 4294967296. On the web it is **0**:
/// dart2js compiles `<<` down to JavaScript's shift operator, which only reads
/// the low 5 bits of the shift amount, and `js_number.dart::_shlPositive`
/// returns 0 outright for any amount above 31. `Random().nextInt(0)` then
/// throws `RangeError: max must be in range 0 < max ≤ 2^32, was 0`.
///
/// Because the id was built in a field initialiser, that threw while the quiz
/// screen was being constructed — so every quiz on web died before painting,
/// while iOS and the `flutter test` VM were completely unaffected. A unit test
/// cannot reproduce it: the VM computes the bound correctly. That is why the
/// bound is a named constant with a test asserting its VALUE is web-safe,
/// rather than a literal expression at the call site.
const int kAttemptIdRandomBound = 1 << 31;

/// A fresh identifier for one quiz attempt.
///
/// Each attempt writes a receipt under `.../modules/{moduleId}/attempts/{id}`,
/// and retrying the same attempt must not be able to add a second score — so
/// the id has to change on every retake and never collide with a live one.
/// The microsecond timestamp gives ordering and the random suffix separates
/// two attempts that begin within the same microsecond.
///
/// Pass [rng] to make the id deterministic in tests.
String newAttemptId({Random? rng}) {
  final random = rng ?? Random();
  return '${DateTime.now().microsecondsSinceEpoch}-'
      '${random.nextInt(kAttemptIdRandomBound)}';
}
