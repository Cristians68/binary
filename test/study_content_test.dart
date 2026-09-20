import 'package:binary/content_source.dart';
import 'package:binary/course_content.dart';
import 'package:binary/screens/content_service.dart';
import 'package:binary/screens/offline_service.dart';
import 'package:binary/screens/service_backend.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const question = {
    'question': 'What does DNS do?',
    'options': ['Resolves names', 'Assigns leases'],
    'correctIndex': 0
  };
  test('quiz parser preserves the correct answer and optional explanation', () {
    final parsed = parseQuizQuestions([question]).single;
    expect(parsed['answers'][parsed['correct']], 'Resolves names');
    expect(parsed['explanation'], '');
  });
  for (final invalid in <Map<String, dynamic>>[
    {...question, 'correctIndex': -1},
    {...question, 'correctIndex': 2},
    {...question, 'correctIndex': '0'},
    {
      ...question,
      'options': ['Only one']
    },
    {
      ...question,
      'options': ['Same', ' Same ']
    },
    {...question, 'question': ' '},
    {
      ...question,
      'options': ['Good', 42]
    },
  ]) {
    test('malformed quiz fails as a whole: $invalid', () {
      expect(
          () => parseQuizQuestions([question, invalid]), throwsFormatException);
    });
  }
  test('incomplete flashcards fail instead of appearing as empty lessons', () {
    expect(
        () => parseFlashcards([
              {'question': 'DNS'}
            ]),
        throwsFormatException);
  });
  test('only actual course content can earn progress', () {
    for (final origin in ContentOrigin.values) {
      expect(ContentResult(['item'], origin).canRecordProgress,
          origin == ContentOrigin.live || origin == ContentOrigin.cached);
      expect(ContentResult<String>([], origin).canRecordProgress, isFalse);
    }
  });

  group('content service', () {
    late FakeFirebaseFirestore db;
    setUp(() {
      db = FakeFirebaseFirestore();
      ServiceBackend.useFake(db, uid: 'learner');
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(ServiceBackend.reset);
    test('loads the real first-module quiz', () async {
      await db
          .doc('courses/network/modules/module-1/quiz/q1')
          .set({...question, 'order': 1});
      final result = await ContentService.quiz('network', 'module-1');
      expect(result.items.single['question'], question['question']);
      expect(result.origin, ContentOrigin.live);
    });
    test('a broken answer key does not silently shorten a quiz', () async {
      await db
          .doc('courses/network/modules/module-1/quiz/q1')
          .set({...question, 'order': 1});
      await db
          .doc('courses/network/modules/module-1/quiz/q2')
          .set({...question, 'order': 2, 'correctIndex': 7});
      final result = await ContentService.quiz('network', 'module-1');
      expect(result.origin, ContentOrigin.unavailable);
      expect(result.items, isEmpty);
    });
    test('missing lessons report unavailable', () async {
      final result = await ContentService.flashcards('network', 'module-1');
      expect(result.origin, ContentOrigin.unavailable);
    });
    test('downloaded paid lessons still require course access', () async {
      await db.doc('courses/network/modules/module-2/flashcards/card').set({
        'question': 'DNS',
        'answer': 'Resolves names',
        'order': 1,
      });
      await OfflineService.downloadCourse(courseId: 'network', modules: const [
        {'id': 'module-2', 'title': 'Names', 'order': 2},
      ]);
      expect(
          (await ContentService.flashcards('network', 'module-2',
                  downloadedOnly: true))
              .origin,
          ContentOrigin.unavailable);
      await db.doc('users/learner').set({
        'subscriptionPlan': 'single',
        'subscribedCourseId': 'network',
      });
      final result = await ContentService.flashcards('network', 'module-2',
          downloadedOnly: true);
      expect(result.origin, ContentOrigin.cached);
      expect(result.items.single['term'], 'DNS');
      await db.doc('users/learner').set({'subscriptionPlan': 'none'});
      expect(
          (await ContentService.flashcards('network', 'module-2',
                  downloadedOnly: true))
              .origin,
          ContentOrigin.unavailable);
    });
    test('progress status cannot unlock paid content', () async {
      await db.doc('users/learner').set({'subscriptionPlan': 'none'});
      await db
          .doc('users/learner/progress/network/modules/module-2')
          .set({'status': 'done'});
      await db
          .doc('courses/network/modules/module-2/quiz/q1')
          .set({...question, 'order': 1});
      final result = await ContentService.quiz('network', 'module-2');
      expect(result.origin, ContentOrigin.unavailable);
    });
  });
}
