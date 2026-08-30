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
