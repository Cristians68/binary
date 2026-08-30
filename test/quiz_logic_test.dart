import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:binary/screens/quiz_logic.dart';

Map<String, dynamic> q({
  String question = 'Q',
  List<String> answers = const ['a', 'b', 'c', 'd'],
  dynamic correct = 0,
  String explanation = 'because',
}) =>
    {
      'question': question,
      'answers': answers,
      'correct': correct,
      'explanation': explanation,
    };

void main() {
  group('shuffleQuizQuestions', () {
    test('keeps the correct index pointing at the same answer text', () {
      // Run enough seeds that a permutation which moves the answer is certain.
      for (var seed = 0; seed < 200; seed++) {
        final input = [
          q(answers: ['alpha', 'bravo', 'charlie', 'delta'], correct: 2),
        ];
        final out = shuffleQuizQuestions(input, rng: Random(seed));
        final answers = List<String>.from(out.single['answers'] as List);
        expect(
          answers[out.single['correct'] as int],
          'charlie',
          reason: 'seed $seed moved the answer away from its index',
        );
      }
    });

    test('actually reorders answers rather than passing them through', () {
      var moved = 0;
      for (var seed = 0; seed < 50; seed++) {
        final out = shuffleQuizQuestions(
          [q(answers: ['a', 'b', 'c', 'd'], correct: 1)],
          rng: Random(seed),
        );
        if (out.single['correct'] != 1) moved++;
      }
      // If the shuffle were a no-op this would be 0. With four options the
      // answer stays put about a quarter of the time, so most seeds must move
      // it.
      expect(moved, greaterThan(20),
          reason: 'the answer position is barely changing - is it shuffling?');
    });

    test('preserves the full set of answers, losing and inventing none', () {
      final out = shuffleQuizQuestions(
        [q(answers: ['w', 'x', 'y', 'z'], correct: 3)],
        rng: Random(7),
      );
      final answers = List<String>.from(out.single['answers'] as List)..sort();
      expect(answers, ['w', 'x', 'y', 'z']);
    });

    test('a duplicated option does not steal the correct index', () {
      // The regression this guards: remembering the answer TEXT and then
      // calling indexOf() after the shuffle returns the first copy, so tapping
      // the second identical option is marked wrong.
      for (var seed = 0; seed < 200; seed++) {
        final out = shuffleQuizQuestions(
          // Index 2 is the correct one; index 0 holds the same text.
          [q(answers: ['same', 'other', 'same', 'more'], correct: 2)],
          rng: Random(seed),
        );
        final answers = List<String>.from(out.single['answers'] as List);
        final idx = out.single['correct'] as int;
        expect(answers[idx], 'same', reason: 'seed $seed');
      }
    });

    test('an out-of-range answer key yields no correct option, not a throw', () {
      final out = shuffleQuizQuestions(
        [q(answers: ['a', 'b', 'c', 'd'], correct: 9)],
        rng: Random(1),
      );
      expect(out.single['correct'], -1);
      // -1 matches no tapped index, so the question is unanswerable rather
      // than crashing the whole module into the fallback question set.
      expect(out.single['answers'], hasLength(4));
    });

    test('a non-numeric answer key yields no correct option, not a throw', () {
      final out = shuffleQuizQuestions(
        [q(answers: ['a', 'b'], correct: 'first')],
        rng: Random(1),
      );
      expect(out.single['correct'], -1);
    });

    test('handles a question with no answers at all', () {
      final out = shuffleQuizQuestions([q(answers: const [], correct: 0)]);
      expect(out.single['answers'], isEmpty);
      expect(out.single['correct'], -1);
    });

    test('carries question and explanation through unchanged', () {
      final out = shuffleQuizQuestions(
        [q(question: 'What is X?', explanation: 'X is Y')],
        rng: Random(3),
      );
      expect(out.single['question'], 'What is X?');
      expect(out.single['explanation'], 'X is Y');
    });

    test('substitutes an empty string for a missing explanation', () {
      final out = shuffleQuizQuestions([
        {
          'question': 'Q',
          'answers': ['a', 'b'],
          'correct': 0,
        },
      ]);
      expect(out.single['explanation'], '');
    });

    test('does not mutate the list it was given', () {
      final original = ['a', 'b', 'c', 'd'];
      shuffleQuizQuestions([q(answers: original, correct: 0)], rng: Random(5));
      expect(original, ['a', 'b', 'c', 'd']);
    });

    test('breaks up the answer-position bias in the authored content', () {
      // Every seeded question below has its answer at index 1, matching the
      // real content. After shuffling the answer must land across positions
      // rather than staying at 1 - otherwise "always pick B" passes the app.
      final questions = List.generate(
        400,
        (i) => q(answers: ['w', 'x', 'y', 'z'], correct: 1),
      );
      final out = shuffleQuizQuestions(questions, rng: Random(42));
      final counts = <int, int>{};
      for (final r in out) {
        counts.update(r['correct'] as int, (v) => v + 1, ifAbsent: () => 1);
      }
      expect(counts.keys.toSet(), {0, 1, 2, 3},
          reason: 'the answer never reached some positions');
      for (final entry in counts.entries) {
        expect(entry.value, greaterThan(400 ~/ 4 ~/ 2),
            reason: 'position ${entry.key} is badly under-represented');
      }
    });
  });

  group('quizPassMark', () {
    test('is 60% of the question count, rounded up', () {
      expect(quizPassMark(12), 8); // 7.2 -> 8
      expect(quizPassMark(10), 6); // 6.0 -> 6
      expect(quizPassMark(6), 4); // 3.6 -> 4
      expect(quizPassMark(1), 1); // 0.6 -> 1
    });

    test('is 0 for a quiz with no questions', () {
      expect(quizPassMark(0), 0);
      expect(quizPassMark(-3), 0);
    });
  });

  group('quizPassed', () {
    test('passes at exactly the pass mark and above', () {
      expect(quizPassed(8, 12), isTrue);
      expect(quizPassed(12, 12), isTrue);
    });

    test('fails one below the pass mark', () {
      expect(quizPassed(7, 12), isFalse);
      expect(quizPassed(0, 12), isFalse);
    });

    test('an empty quiz is never a pass', () {
      // Guarding `0 >= 0`, which would hand out a free module completion.
      expect(quizPassed(0, 0), isFalse);
    });
  });

  group('quizScorePercent', () {
    test('reports the score as a percentage', () {
      expect(quizScorePercent(12, 12), 100);
      expect(quizScorePercent(6, 12), 50);
      expect(quizScorePercent(0, 12), 0);
    });

    test('returns 0 for an empty quiz rather than throwing on NaN', () {
      // 0 / 0 is NaN and NaN.toInt() throws UnsupportedError.
      expect(quizScorePercent(0, 0), 0);
    });

    test('stays within 0..100', () {
      expect(quizScorePercent(20, 12), 100);
      expect(quizScorePercent(-5, 12), 0);
    });
  });
}
