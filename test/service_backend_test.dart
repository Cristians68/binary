import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:binary/screens/service_backend.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// A FIDELITY GAP IN fake_cloud_firestore — READ BEFORE ADDING TESTS HERE
///
/// Real Firestore treats dot-notation differently in the two write methods:
///
///   update({'streak.current': 1})            → sets `current` INSIDE `streak`
///   set({'streak.current': 1}, merge: true)  → creates a TOP-LEVEL field
///                                               whose name contains a dot
///
/// `fake_cloud_firestore` routes both `set()` and `update()` through the same
/// `_setRawData`, which splits composite keys. In the fake, both forms produce
/// a nested map — so a test written against the fake CANNOT tell a correct
/// dot-notation write from the broken one, and will pass either way.
///
/// That is why the correctness of the expansion is tested here, against
/// [expandDotNotation] directly, rather than by asserting on documents the
/// fake wrote. Assertions of the form "the stored doc has a nested map, not a
/// literal 'a.b' key" are tautological against this fake — do not add them and
/// do not trust them if you find one.
/// ─────────────────────────────────────────────────────────────────────────
void main() {
  group('expandDotNotation', () {
    test('passes plain keys through untouched', () {
      expect(
        expandDotNotation({'lessonsCompleted': 3, 'name': 'Ada'}),
        {'lessonsCompleted': 3, 'name': 'Ada'},
      );
    });

    test('nests a single dotted key', () {
      expect(
        expandDotNotation({'streak.current': 5}),
        {
          'streak': {'current': 5},
        },
      );
    });

    test('merges siblings into one map rather than overwriting', () {
      expect(
        expandDotNotation({
          'streak.current': 5,
          'streak.longest': 9,
        }),
        {
          'streak': {'current': 5, 'longest': 9},
        },
      );
    });

    test('nests arbitrarily deep', () {
      expect(
        expandDotNotation({'a.b.c.d': 1}),
        {
          'a': {
            'b': {
              'c': {'d': 1},
            },
          },
        },
      );
    });

    test('keeps dotted and plain keys side by side', () {
      expect(
        expandDotNotation({
          'quizzesPassed': 2,
          'badges.quiz_first': 'ts',
          'badges.quiz_10': 'ts2',
          'dailyGoal.todayPoints': 20,
        }),
        {
          'quizzesPassed': 2,
          'badges': {'quiz_first': 'ts', 'quiz_10': 'ts2'},
          'dailyGoal': {'todayPoints': 20},
        },
      );
    });

    test('passes FieldValue sentinels through as values', () {
      // arrayUnion/increment/serverTimestamp must survive untouched, or the
      // fallback write silently stores a broken object instead of a sentinel.
      final union = FieldValue.arrayUnion(['c1']);
      final result = expandDotNotation({
        'completedCourses': union,
        'badges.course_first': FieldValue.serverTimestamp(),
      });
      expect(identical(result['completedCourses'], union), isTrue);
      expect((result['badges'] as Map)['course_first'], isA<FieldValue>());
    });

    test('the deeper key wins when a scalar and a path collide', () {
      // Ambiguous input either way; this pins the behaviour so it cannot
      // change silently.
      expect(
        expandDotNotation({'a': 1, 'a.b': 2}),
        {
          'a': {'b': 2},
        },
      );
    });

    test('handles an empty map', () {
      expect(expandDotNotation({}), isEmpty);
    });

    test('does not mutate the map it was given', () {
      final input = <String, Object?>{'streak.current': 1};
      expandDotNotation(input);
      expect(input, {'streak.current': 1});
    });
  });

  group('safeUpdate', () {
    late FakeFirebaseFirestore db;
    late DocumentReference<Map<String, dynamic>> doc;

    setUp(() {
      db = FakeFirebaseFirestore();
      doc = db.collection('users').doc('u1');
    });

    test('updates a document that already exists', () async {
      await doc.set({
        'streak': {'current': 1, 'longest': 1},
      });
      await safeUpdate(doc, {'streak.current': 2});

      final data = (await doc.get()).data()!;
      expect(data['streak']['current'], 2);
      expect(data['streak']['longest'], 1, reason: 'siblings must survive');
    });

    // Note: this exercises the FALLBACK BRANCH (update() throws not-found, so
    // set() runs). It proves the branch is reached and does not throw. It does
    // NOT prove the expansion is correct — see the fidelity note above.
    test('creates a document that does not exist yet', () async {
      expect((await doc.get()).exists, isFalse);
      await safeUpdate(doc, {'streak.current': 1, 'name': 'Ada'});

      final snap = await doc.get();
      expect(snap.exists, isTrue);
      expect(snap.data()!['name'], 'Ada');
    });

    test('leaves unrelated fields alone', () async {
      await doc.set({'name': 'Ada', 'quizzesPassed': 4});
      await safeUpdate(doc, {'quizzesPassed': 5});
      expect((await doc.get()).data()!['name'], 'Ada');
    });
  });

  group('ServiceBackend', () {
    tearDown(ServiceBackend.reset);

    test('useFake supplies the injected uid', () {
      ServiceBackend.useFake(FakeFirebaseFirestore(), uid: 'abc');
      expect(ServiceBackend.uid, 'abc');
    });

    test('useFake can represent a signed-out user', () {
      ServiceBackend.useFake(FakeFirebaseFirestore(), uid: null);
      expect(ServiceBackend.uid, isNull);
    });

    test('useFake supplies the injected Firestore', () {
      final fake = FakeFirebaseFirestore();
      ServiceBackend.useFake(fake, uid: 'abc');
      expect(identical(ServiceBackend.db, fake), isTrue);
    });
  });
}
