import 'dart:convert';

import 'package:binary/screens/offline_service.dart';
import 'package:binary/screens/review_service.dart';
import 'package:binary/screens/service_backend.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late FakeFirebaseFirestore db;
  void signIn(String? uid) => ServiceBackend.useFake(db, uid: uid);
  Future<void> miss(String text) => ReviewService.recordMiss(
          courseId: 'network',
          moduleId: 'module-1',
          courseTag: 'NET',
          question: {
            'question': text,
            'answers': ['A', 'B'],
            'correct': 0
          });

  setUp(() {
    db = FakeFirebaseFirestore();
    signIn('alice');
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(ServiceBackend.reset);

  test('review history belongs to the account, including after sign-out',
      () async {
    await miss('Alice question');
    signIn(null);
    expect(await ReviewService.all(), isEmpty);
    signIn('bob');
    expect(await ReviewService.all(), isEmpty);
    await miss('Bob question');
    signIn('alice');
    expect((await ReviewService.all()).single['question'], 'Alice question');
  });
  test('rapid quiz misses cannot overwrite each other', () async {
    await Future.wait(List.generate(15, (i) => miss('Question $i')));
    expect(await ReviewService.trackedCount(), 15);
    expect(await ReviewService.dueCount(), 15);
  });
  test('rapid repeats of the same question preserve its miss count', () async {
    await Future.wait(List.generate(10, (_) => miss('Same question')));
    expect((await ReviewService.all()).single['misses'], 10);
  });
  test('deleting an account clears its queue after auth has signed out',
      () async {
    await miss('Alice question');
    signIn('bob');
    await miss('Bob question');
    signIn(null);
    await ReviewService.clear(userId: 'alice');
    signIn('alice');
    expect(await ReviewService.all(), isEmpty);
    signIn('bob');
    expect(await ReviewService.trackedCount(), 1);
  });
  test('unowned legacy queues are never assigned to a new account', () async {
    SharedPreferences.setMockInitialValues({
      'review_queue_v1': jsonEncode([
        {'question': 'Private'}
      ])
    });
    expect(await ReviewService.all(), isEmpty);
  });
  test('signed-out misses do not persist', () async {
    signIn(null);
    await miss('No owner');
    signIn('alice');
    expect(await ReviewService.all(), isEmpty);
  });

  const modules = [
    {'id': 'module-1', 'title': 'Names', 'order': 1},
    {'id': 'module-2', 'title': 'Addresses', 'order': 2},
  ];
  Future<void> seed(String course, String module, {String term = 'DNS'}) =>
      db.doc('courses/$course/modules/$module/flashcards/card').set({
        'question': term,
        'answer': 'Resolves names',
        'order': 1,
      });
  Future<int> download(String course) =>
      OfflineService.downloadCourse(courseId: course, modules: modules);

  test('empty and partial downloads are never marked complete', () async {
    expect(await download('network'), 0);
    await seed('network', 'module-1');
    expect(await download('network'), 0);
    expect(await OfflineService.isCourseDownloaded('network'), isFalse);
    expect(await OfflineService.loadCachedFlashcards('network', 'module-1'),
        isNull);
  });
  test('an incomplete local manifest is not advertised as a download',
      () async {
    SharedPreferences.setMockInitialValues({
      'offline_course_v2_alice_network': jsonEncode({
        'modules': modules,
        'flashcards': {
          'module-1': [
            {'term': 'DNS', 'definition': 'Resolves names'}
          ],
          'module-2': [],
        },
      }),
    });
    expect(await OfflineService.isCourseDownloaded('network'), isFalse);
    expect(await OfflineService.getDownloadedCourses(), isEmpty);
    expect(await OfflineService.loadCachedModules('network'), isEmpty);
  });
  test('a successful download contains readable cards and module metadata',
      () async {
    await seed('network', 'module-1');
    await seed('network', 'module-2');
    expect(await download('network'), 2);
    expect(await OfflineService.isCourseDownloaded('network'), isTrue);
    expect(await OfflineService.getCachedCardCount('network'), 2);
    expect((await OfflineService.loadCachedModules('network')).length, 2);
    expect(
        (await OfflineService.loadCachedFlashcards('network', 'module-1'))!
            .single['term'],
        'DNS');
  });
  test('failed refresh preserves the existing complete download', () async {
    await seed('network', 'module-1');
    await seed('network', 'module-2');
    await download('network');
    await seed('network', 'module-1', term: 'Changed');
    await db.doc('courses/network/modules/module-2/flashcards/card').delete();
    expect(await download('network'), 0);
    expect(
        (await OfflineService.loadCachedFlashcards('network', 'module-1'))!
            .single['term'],
        'DNS');
  });
  test('downloads are account scoped and course deletion needs no module query',
      () async {
    await seed('network', 'module-1');
    await seed('network', 'module-2');
    await download('network');
    signIn('bob');
    expect(await OfflineService.getDownloadedCourses(), isEmpty);
    expect(await OfflineService.loadCachedFlashcards('network', 'module-1'),
        isNull);
    signIn('alice');
    await OfflineService.deleteCourse(courseId: 'network');
    expect(await OfflineService.getDownloadedCourses(), isEmpty);
  });
  test('course IDs that share a prefix do not share counts or deletion',
      () async {
    for (final course in ['cloud', 'cloud-pro']) {
      await seed(course, 'module-1');
      await seed(course, 'module-2');
      await download(course);
    }
    expect(await OfflineService.getCachedCardCount('cloud'), 2);
    await OfflineService.deleteCourse(courseId: 'cloud');
    expect(await OfflineService.getDownloadedCourses(), ['cloud-pro']);
  });
  test('switching accounts during a download discards the unfinished copy',
      () async {
    await seed('network', 'module-1');
    await seed('network', 'module-2');
    final saved = await OfflineService.downloadCourse(
        courseId: 'network',
        modules: modules,
        onProgress: (_, __) => signIn('bob'));
    expect(saved, 0);
    signIn('alice');
    expect(await OfflineService.getDownloadedCourses(), isEmpty);
  });
}
