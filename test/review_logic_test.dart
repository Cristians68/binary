import 'package:flutter_test/flutter_test.dart';
import 'package:binary/screens/review_logic.dart';

final _now = DateTime.utc(2026, 8, 30, 12);

Map<String, dynamic> question({
  String text = 'What is a VPC?',
  List<String> answers = const ['a', 'b', 'c', 'd'],
  int correct = 1,
  String explanation = 'because',
}) =>
    {
      'question': text,
      'answers': answers,
      'correct': correct,
      'explanation': explanation,
    };

List<Map<String, dynamic>> _withOneMiss({DateTime? at}) =>
    recordMissedQuestion(
      const [],
      courseId: 'c1',
      moduleId: 'm1',
      courseTag: 'Tag',
      question: question(),
      now: at ?? _now,
    );

void main() {
  group('reviewItemId', () {
    test('is stable for the same question', () {
      expect(reviewItemId('c', 'm', 'Q?'), reviewItemId('c', 'm', 'Q?'));
    });

    test('ignores surrounding whitespace', () {
      expect(reviewItemId('c', 'm', '  Q?  '), reviewItemId('c', 'm', 'Q?'));
    });

    test('differs across courses and modules', () {
      expect(reviewItemId('c1', 'm', 'Q?'), isNot(reviewItemId('c2', 'm', 'Q?')));
      expect(reviewItemId('c', 'm1', 'Q?'), isNot(reviewItemId('c', 'm2', 'Q?')));
    });

    test('differs when the question is reworded', () {
      // A genuinely different question should start its own history.
      expect(reviewItemId('c', 'm', 'Q1?'), isNot(reviewItemId('c', 'm', 'Q2?')));
    });
  });

  group('nextReviewBox', () {
    test('promotes one box on a correct answer', () {
      expect(nextReviewBox(0, correct: true), 1);
      expect(nextReviewBox(3, correct: true), 4);
    });

    test('retires after clearing the final box', () {
      expect(nextReviewBox(4, correct: true), kRetiredBox);
    });

    test('never climbs past retired', () {
      expect(nextReviewBox(kRetiredBox, correct: true), kRetiredBox);
    });

    test('a wrong answer goes all the way back to box 0, not down one', () {
      // A question just failed is one the user does not know, whatever their
      // history with it.
      expect(nextReviewBox(4, correct: false), 0);
      expect(nextReviewBox(1, correct: false), 0);
      expect(nextReviewBox(0, correct: false), 0);
    });
  });

  group('dueAtForBox', () {
    test('box 0 is due immediately', () {
      expect(dueAtForBox(0, _now), _now);
    });

    test('intervals expand as the box rises', () {
      final gaps = [
        for (var b = 0; b < kReviewIntervals.length; b++)
          dueAtForBox(b, _now).difference(_now),
      ];
      for (var i = 1; i < gaps.length; i++) {
        expect(gaps[i], greaterThan(gaps[i - 1]),
            reason: 'box $i does not wait longer than box ${i - 1}');
      }
    });

    test('a retired box is pushed far out rather than coming due', () {
      expect(dueAtForBox(kRetiredBox, _now).difference(_now).inDays,
          greaterThan(365));
    });
  });

  group('isReviewDue', () {
    test('is true once the due time has passed', () {
      final item = {
        'box': 1,
        'dueAt': _now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
      };
      expect(isReviewDue(item, _now), isTrue);
    });

    test('is true exactly at the due time', () {
      final item = {'box': 1, 'dueAt': _now.millisecondsSinceEpoch};
      expect(isReviewDue(item, _now), isTrue);
    });

    test('is false while still scheduled in the future', () {
      final item = {
        'box': 1,
        'dueAt': _now.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      };
      expect(isReviewDue(item, _now), isFalse);
    });

    test('a retired item is never due', () {
      final item = {'box': kRetiredBox, 'dueAt': 0};
      expect(isReviewDue(item, _now), isFalse);
    });

    test('an item with no schedule is shown rather than lost', () {
      expect(isReviewDue({'box': 0}, _now), isTrue);
    });
  });

  group('recordMissedQuestion', () {
    test('adds a missed question due immediately at box 0', () {
      final items = _withOneMiss();
      expect(items, hasLength(1));
      expect(items.single['box'], 0);
      expect(items.single['misses'], 1);
      expect(isReviewDue(items.single, _now), isTrue);
    });

    test('stores the full question so review needs no network', () {
      final item = _withOneMiss().single;
      expect(item['question'], 'What is a VPC?');
      expect(item['answers'], ['a', 'b', 'c', 'd']);
      expect(item['correct'], 1);
      expect(item['explanation'], 'because');
      expect(item['courseTag'], 'Tag');
    });

    test('missing the same question again does not duplicate it', () {
      var items = _withOneMiss();
      items = recordMissedQuestion(
        items,
        courseId: 'c1',
        moduleId: 'm1',
        courseTag: 'Tag',
        question: question(),
        now: _now,
      );
      expect(items, hasLength(1));
      expect(items.single['misses'], 2);
    });

    test('a repeat miss knocks a promoted question back to box 0', () {
      var items = _withOneMiss();
      items = applyReviewResult(
        items,
        id: items.single['id'] as String,
        correct: true,
        now: _now,
      );
      expect(items.single['box'], 1);

      items = recordMissedQuestion(
        items,
        courseId: 'c1',
        moduleId: 'm1',
        courseTag: 'Tag',
        question: question(),
        now: _now,
      );
      expect(items.single['box'], 0);
      expect(isReviewDue(items.single, _now), isTrue);
    });

    test('refreshes the stored copy when the wording of options changes', () {
      var items = _withOneMiss();
      items = recordMissedQuestion(
        items,
        courseId: 'c1',
        moduleId: 'm1',
        courseTag: 'Tag',
        question: question(answers: ['w', 'x', 'y', 'z'], correct: 3),
        now: _now,
      );
      expect(items.single['answers'], ['w', 'x', 'y', 'z']);
      expect(items.single['correct'], 3);
    });

    test('distinct questions are tracked separately', () {
      var items = _withOneMiss();
      items = recordMissedQuestion(
        items,
        courseId: 'c1',
        moduleId: 'm1',
        courseTag: 'Tag',
        question: question(text: 'A different question?'),
        now: _now,
      );
      expect(items, hasLength(2));
    });

    test('a question with no text is ignored rather than stored unidentifiably',
        () {
      final items = recordMissedQuestion(
        const [],
        courseId: 'c1',
        moduleId: 'm1',
        courseTag: 'Tag',
        question: question(text: '   '),
        now: _now,
      );
      expect(items, isEmpty);
    });

    test('does not mutate the list it was given', () {
      final original = <Map<String, dynamic>>[];
      recordMissedQuestion(
        original,
        courseId: 'c1',
        moduleId: 'm1',
        courseTag: 'Tag',
        question: question(),
        now: _now,
      );
      expect(original, isEmpty);
    });
  });

  group('applyReviewResult', () {
    test('a correct answer promotes and pushes the next showing out', () {
      var items = _withOneMiss();
      final id = items.single['id'] as String;
      items = applyReviewResult(items, id: id, correct: true, now: _now);

      expect(items.single['box'], 1);
      expect(isReviewDue(items.single, _now), isFalse,
          reason: 'a promoted question should not still be due');
      expect(isReviewDue(items.single, _now.add(const Duration(days: 2))),
          isTrue);
    });

    test('a wrong answer resets to box 0, due immediately', () {
      var items = _withOneMiss();
      final id = items.single['id'] as String;
      items = applyReviewResult(items, id: id, correct: true, now: _now);
      items = applyReviewResult(items, id: id, correct: false, now: _now);

      expect(items.single['box'], 0);
      expect(items.single['misses'], 2);
      expect(isReviewDue(items.single, _now), isTrue);
    });

    test('clearing every box removes the question from the queue', () {
      var items = _withOneMiss();
      final id = items.single['id'] as String;
      for (var i = 0; i < kReviewIntervals.length; i++) {
        expect(items, hasLength(1), reason: 'retired too early at box $i');
        items = applyReviewResult(items, id: id, correct: true, now: _now);
      }
      expect(items, isEmpty, reason: 'a learned question should leave the queue');
    });

    test('leaves other questions untouched', () {
      var items = _withOneMiss();
      items = recordMissedQuestion(
        items,
        courseId: 'c1',
        moduleId: 'm1',
        courseTag: 'Tag',
        question: question(text: 'Another?'),
        now: _now,
      );
      final target = items.first['id'] as String;
      items = applyReviewResult(items, id: target, correct: true, now: _now);

      expect(items, hasLength(2));
      expect(items.firstWhere((i) => i['id'] != target)['box'], 0);
    });

    test('an unknown id changes nothing', () {
      final items = _withOneMiss();
      final after =
          applyReviewResult(items, id: 'no-such-id', correct: true, now: _now);
      expect(after, hasLength(1));
      expect(after.single['box'], 0);
    });
  });

  group('dueReviewItems', () {
    test('returns only what is actually due', () {
      final items = [
        {'id': 'a', 'box': 0, 'dueAt': _now.millisecondsSinceEpoch},
        {
          'id': 'b',
          'box': 2,
          'dueAt': _now.add(const Duration(days: 3)).millisecondsSinceEpoch,
        },
      ];
      expect(dueReviewItems(items, _now).map((i) => i['id']), ['a']);
    });

    test('orders by due time, soonest first', () {
      final items = [
        {'id': 'later', 'box': 0, 'dueAt': _now.millisecondsSinceEpoch},
        {
          'id': 'earlier',
          'box': 0,
          'dueAt': _now.subtract(const Duration(days: 2)).millisecondsSinceEpoch,
        },
      ];
      expect(dueReviewItems(items, _now).map((i) => i['id']),
          ['earlier', 'later']);
    });

    test('puts the most-missed question first when due times tie', () {
      final at = _now.millisecondsSinceEpoch;
      final items = [
        {'id': 'few', 'box': 0, 'dueAt': at, 'misses': 1},
        {'id': 'many', 'box': 0, 'dueAt': at, 'misses': 5},
      ];
      expect(dueReviewItems(items, _now).first['id'], 'many');
    });

    test('is empty for an empty queue', () {
      expect(dueReviewItems(const [], _now), isEmpty);
    });
  });

  group('nextReviewDueLabel', () {
    test('is null when nothing is tracked', () {
      expect(nextReviewDueLabel(const [], _now), isNull);
    });

    test('says ready now when something is already due', () {
      expect(nextReviewDueLabel(_withOneMiss(), _now), 'Ready now');
    });

    test('counts down in hours within a day', () {
      final items = [
        {
          'box': 1,
          'dueAt': _now.add(const Duration(hours: 5)).millisecondsSinceEpoch,
        },
      ];
      expect(nextReviewDueLabel(items, _now), 'Ready in 5 h');
    });

    test('says tomorrow at roughly a day out', () {
      final items = [
        {
          'box': 1,
          'dueAt': _now.add(const Duration(days: 1)).millisecondsSinceEpoch,
        },
      ];
      expect(nextReviewDueLabel(items, _now), 'Ready tomorrow');
    });

    test('counts down in days beyond that', () {
      final items = [
        {
          'box': 2,
          'dueAt': _now.add(const Duration(days: 3)).millisecondsSinceEpoch,
        },
      ];
      expect(nextReviewDueLabel(items, _now), 'Ready in 3 days');
    });

    test('ignores retired items when reporting the next due time', () {
      final items = [
        {'box': kRetiredBox, 'dueAt': _now.millisecondsSinceEpoch},
      ];
      expect(nextReviewDueLabel(items, _now), isNull);
    });
  });

  group('the queue drains', () {
    test('a question answered right every time leaves in a bounded number of sessions',
        () {
      // Guards the failure where a scheduling bug means review never ends.
      var items = _withOneMiss();
      final id = items.single['id'] as String;
      var clock = _now;
      var sessions = 0;

      while (items.isNotEmpty && sessions < 50) {
        final due = dueReviewItems(items, clock);
        if (due.isEmpty) {
          clock = clock.add(const Duration(days: 1));
          continue;
        }
        items = applyReviewResult(items, id: id, correct: true, now: clock);
        sessions++;
      }

      expect(items, isEmpty, reason: 'the review queue never drained');
      expect(sessions, kReviewIntervals.length);
    });
  });
}
