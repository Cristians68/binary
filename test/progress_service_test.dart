/// Tests for [ProgressService.completeModule] and the reads built on it.
///
/// Progress is per-user: it lives under `users/{uid}/progress/{courseId}` and
/// must never be written into the shared `courses/` collection, which every
/// user reads. Module unlock state is the one deliberate exception, being
/// course-level metadata. These tests pin that split as well as the arithmetic.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:binary/screens/progress_service.dart';
import 'package:binary/screens/service_backend.dart';

const uid = 'test-uid';
const courseId = 'net-pro';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    db = FakeFirebaseFirestore();
    ServiceBackend.useFake(db, uid: uid);
  });

  tearDown(ServiceBackend.reset);

  /// Seed a course with [count] modules, all locked except the first.
  Future<void> seedCourse({int count = 4}) async {
    final modules = db.collection('courses').doc(courseId).collection('modules');
    for (var i = 1; i <= count; i++) {
      await modules.doc('module-$i').set({
        'order': i,
        'title': 'Module $i',
        'status': i == 1 ? 'active' : 'locked',
      });
    }
  }

  Future<void> complete(String moduleId, {int score = 8, int total = 10}) =>
      ProgressService.completeModule(
        courseId: courseId,
        moduleId: moduleId,
        moduleTitle: 'Module $moduleId',
        courseTag: 'NET',
        score: score,
        total: total,
      );

  Future<Map<String, dynamic>> userData() async =>
      (await db.collection('users').doc(uid).get()).data() ?? {};

  Future<Map<String, dynamic>> courseProgress() async =>
      (await db
                  .collection('users')
                  .doc(uid)
                  .collection('progress')
                  .doc(courseId)
                  .get())
              .data() ??
          {};

  Future<String?> moduleStatus(String moduleId) async =>
      (await db
              .collection('courses')
              .doc(courseId)
              .collection('modules')
              .doc(moduleId)
              .get())
          .data()?['status'] as String?;

  group('completeModule', () {
    test('marks the module done for this user only', () async {
      await seedCourse();
      await complete('module-1');

      final module = await db
          .collection('users')
          .doc(uid)
          .collection('progress')
          .doc(courseId)
          .collection('modules')
          .doc('module-1')
          .get();
      expect(module.data()!['status'], 'done');
    });

    test('does not write progress into the shared course document', () async {
      await seedCourse();
      await complete('module-1');

      final shared = await db.collection('courses').doc(courseId).get();
      expect(shared.data()?['progress'], isNull);
      expect(shared.data()?['doneModules'], isNull);
    });

    test('computes the fraction of modules completed', () async {
      await seedCourse();
      await complete('module-1');

      final progress = await courseProgress();
      expect(progress['doneModules'], 1);
      expect(progress['totalModules'], 4);
      expect(progress['progress'], 0.25);
    });

    test('advances the fraction as more modules are done', () async {
      await seedCourse();
      await complete('module-1');
      await complete('module-2');
      await complete('module-3');

      final progress = await courseProgress();
      expect(progress['doneModules'], 3);
      expect(progress['progress'], closeTo(0.75, 1e-9));
    });

    test('re-completing a module does not inflate the count', () async {
      await seedCourse();
      await complete('module-1');
      await complete('module-1');

      expect((await courseProgress())['doneModules'], 1);
    });

    test('unlocks the next locked module', () async {
      await seedCourse();
      expect(await moduleStatus('module-2'), 'locked');

      await complete('module-1');
      expect(await moduleStatus('module-2'), 'active');
    });

    test('leaves modules further ahead locked', () async {
      await seedCourse();
      await complete('module-1');
      expect(await moduleStatus('module-3'), 'locked');
    });

    test('completing the last module unlocks nothing and does not crash',
        () async {
      await seedCourse(count: 2);
      await complete('module-1');
      await complete('module-2');
      expect(await moduleStatus('module-2'), 'active');
    });
  });

  group('the user record it writes', () {
    test('appends the lesson and counts it', () async {
      await seedCourse();
      await complete('module-1');

      final data = await userData();
      expect(data['lessonsCompleted'], 1);
      final lesson = (data['completedLessons'] as List).single;
      expect(lesson['moduleId'], 'module-1');
      expect(lesson['courseTag'], 'NET');
    });

    test('records the quiz score as a percentage', () async {
      await seedCourse();
      await complete('module-1', score: 7, total: 10);

      final quiz = ((await userData())['quizScores'] as List).single;
      expect(quiz['score'], 70);
      expect(quiz['course'], 'NET');
    });

    test('a zero-length quiz scores 0 rather than dividing by zero', () async {
      await seedCourse();
      await complete('module-1', score: 0, total: 0);

      final data = await userData();
      expect((data['completedLessons'] as List).single['percent'], 0);
      expect((data['quizScores'] as List).single['score'], 0);
    });

    test('starts the streak even though the document did not exist', () async {
      // completeModule can be the very first write for a user who signed in
      // with Google or Apple, since neither creates users/{uid}.
      await seedCourse();
      await complete('module-1');

      final streak = (await userData())['streak'] as Map;
      expect(streak['current'], 1);
      expect(streak['longest'], 1);
    });
  });

  group('finishing a course', () {
    test('marks it complete once every module is done', () async {
      await seedCourse(count: 2);
      await complete('module-1');
      expect((await courseProgress())['completed'], isNull);

      await complete('module-2');
      expect((await courseProgress())['completed'], isTrue);
    });

    test('records the course and awards the canonical course badge', () async {
      await seedCourse(count: 2);
      await complete('module-1');
      await complete('module-2');

      final data = await userData();
      expect(data['completedCourses'], contains(courseId));

      final keys = (data['badges'] as Map).keys;
      // course_first is a badge the grid can actually light up.
      expect(keys, contains('course_first'));
      // The orphan key this used to write is gone. It appeared in neither
      // badge list, so it inflated the "N / 9" counter while lighting nothing
      // up. Existing accounts keep credit because completedCourseIds still
      // reads the old keys; nothing writes new ones.
      expect(keys, isNot(contains('complete_$courseId')));
    });

    test('isCourseComplete reports it', () async {
      await seedCourse(count: 2);
      await complete('module-1');
      expect(await ProgressService.isCourseComplete(courseId), isFalse);

      await complete('module-2');
      expect(await ProgressService.isCourseComplete(courseId), isTrue);
    });
  });

  group('reads', () {
    test('getCourseProgress returns the stored fraction', () async {
      await seedCourse();
      await complete('module-1');
      expect(await ProgressService.getCourseProgress(courseId), 0.25);
    });

    test('getCourseProgress is 0 for a course never started', () async {
      expect(await ProgressService.getCourseProgress('unknown'), 0.0);
    });

    test('getAllCourseProgress covers every started course', () async {
      await seedCourse(count: 2);
      await complete('module-1');

      await db.collection('courses').doc('cloud').collection('modules')
          .doc('module-1').set({'order': 1, 'status': 'active'});
      await ProgressService.completeModule(
        courseId: 'cloud',
        moduleId: 'module-1',
        moduleTitle: 'Intro',
        courseTag: 'CLD',
        score: 10,
        total: 10,
      );

      final all = await ProgressService.getAllCourseProgress();
      expect(all[courseId], 0.5);
      expect(all['cloud'], 1.0);
    });

    test('getAllCourseProgress is empty for a new user', () async {
      expect(await ProgressService.getAllCourseProgress(), isEmpty);
    });
  });

  group('signed out', () {
    test('completeModule writes nothing', () async {
      await seedCourse();
      ServiceBackend.useFake(db, uid: null);
      await complete('module-1');

      expect((await db.collection('users').doc(uid).get()).exists, isFalse);
      expect(await moduleStatus('module-2'), 'locked');
    });

    test('reads return empty defaults', () async {
      ServiceBackend.useFake(db, uid: null);
      expect(await ProgressService.getCourseProgress(courseId), 0.0);
      expect(await ProgressService.getAllCourseProgress(), isEmpty);
      expect(await ProgressService.isCourseComplete(courseId), isFalse);
    });
  });
}
