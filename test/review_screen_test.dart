import 'dart:convert';

import 'package:binary/screens/app_theme.dart';
import 'package:binary/screens/review_screen.dart';
import 'package:binary/screens/review_service.dart';
import 'package:binary/screens/service_backend.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late FakeFirebaseFirestore db;
  Future<void> miss() => ReviewService.recordMiss(
        courseId: 'itil-v4',
        moduleId: 'module-1',
        courseTag: 'ITIL V4',
        question: {
          'question': 'What helps a service improve?',
          'answers': ['Useful feedback', 'Ignoring outcomes'],
          'correct': 0,
          'explanation': 'Feedback helps teams learn and adapt.',
        },
      );

  setUp(() {
    ReviewService.resetForTesting();
    db = FakeFirebaseFirestore();
    ServiceBackend.useFake(db, uid: 'alice');
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(ServiceBackend.reset);

  // SharedPreferences and the serialized queue can cross the real/fake async
  // boundary. Drain both before a widget's test zone is torn down.
  Future<void> flushStorage(WidgetTester tester) async {
    var complete = false;
    ReviewService.all().then((_) => complete = true);
    for (var i = 0; i < 30 && !complete; i++) {
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
    }
    await tester.pump();
    expect(complete, isTrue, reason: 'Review storage should finish its writes');
  }

  Future<void> pump(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => AppTheme(
        notifier: ThemeNotifier(),
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
      home: const ReviewScreen(),
    ));
    await flushStorage(tester);
    await tester.pumpAndSettle();
  }

  test('corrupt entries do not hide healthy saved questions', () async {
    await miss();
    final healthy = (await ReviewService.all()).single;
    SharedPreferences.setMockInitialValues({
      'review_queue_v2_alice': jsonEncode([
        {
          ...healthy,
          'id': 'bad-options',
          'answers': [null, 12]
        },
        {...healthy, 'id': 'bad-key', 'correct': 9},
        {...healthy, 'id': 'bad-box', 'box': -1},
        {
          ...healthy,
          'id': 'ambiguous',
          'answers': ['DNS', 'dns']
        },
        healthy,
      ]),
    });
    expect(await ReviewService.trackedCount(), 1);
    expect(await ReviewService.dueCount(), 1);
  });

  test('malformed scheduling is repaired without losing a valid question',
      () async {
    await miss();
    final healthy = (await ReviewService.all()).single;
    SharedPreferences.setMockInitialValues({
      'review_queue_v2_alice': jsonEncode([
        {...healthy, 'dueAt': 'yesterday', 'misses': 'many'},
        {...healthy, 'id': 'second', 'dueAt': 9000000000000000},
      ]),
    });
    expect(await ReviewService.dueCount(), 2);
    expect(await ReviewService.nextDueLabel(), 'Ready now');
  });

  testWidgets('a review with a long course title fits at doubled text',
      (tester) async {
    await tester.runAsync(miss);
    await pump(tester, scale: 2);
    expect(tester.takeException(), isNull);
    final style = DefaultTextStyle.of(
            tester.element(find.text('What helps a service improve?')))
        .style;
    expect(style.decoration, isNot(TextDecoration.underline),
        reason: 'Review must use the app typography, not Flutter debug text');
    await tester.scrollUntilVisible(find.text('Useful feedback'), 200,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Useful feedback'));
    await flushStorage(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(find.text('You got 1 of 1 right.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty review state fits on a small screen at doubled text',
      (tester) async {
    await pump(tester, scale: 2);
    expect(find.text('Nothing to review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a scheduled queue explains when review returns', (tester) async {
    await tester.runAsync(() async {
      await miss();
      final item = (await ReviewService.all()).single;
      await ReviewService.submitResult(id: item['id'] as String, correct: true);
    });
    await pump(tester);
    expect(find.text('You’re all caught up'), findsOneWidget);
    expect(find.textContaining('scheduled for later'), findsOneWidget);
    expect(find.text('Nothing to review'), findsNothing);
  });

  testWidgets('a stale review session cannot advance another account queue',
      (tester) async {
    await tester.runAsync(miss);
    await pump(tester);
    ServiceBackend.useFake(db, uid: 'bob');
    await tester.runAsync(miss);
    await tester.tap(find.text('Useful feedback'));
    await tester.pumpAndSettle();
    final items = await tester.runAsync(ReviewService.all);
    expect(items!.single['box'], 0);
    expect(find.text('Your account changed'), findsOneWidget);
  });
}
