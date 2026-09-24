import 'package:binary/course_catalog.dart';
import 'package:binary/screens/course_picker.dart';
import 'package:binary/screens/service_backend.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late FakeFirebaseFirestore db;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    ServiceBackend.useFake(db, uid: 'new-learner');
  });
  tearDown(ServiceBackend.reset);

  group('shouldShow', () {
    test('a new account with no courses is asked', () async {
      await db.doc('users/new-learner').set({'enrolments': {}});
      expect(await CoursePicker.shouldShow(), isTrue);
    });
    test('an account that already has courses is not asked', () async {
      await db.doc('users/new-learner').set({
        'enrolments': {'csm': true}
      });
      expect(await CoursePicker.shouldShow(), isFalse);
    });
    test('unenrolled-only entries count as no courses', () async {
      await db.doc('users/new-learner').set({
        'enrolments': {'csm': false}
      });
      expect(await CoursePicker.shouldShow(), isTrue);
    });
    test('never asked twice on the same account, even after skipping',
        () async {
      await db.doc('users/new-learner').set({'enrolments': {}});
      await CoursePicker.markDone();
      expect(await CoursePicker.shouldShow(), isFalse);
    });
    test('a different account on the same phone is still asked', () async {
      await CoursePicker.markDone();
      ServiceBackend.useFake(db, uid: 'second-learner');
      await db.doc('users/second-learner').set({'enrolments': {}});
      expect(await CoursePicker.shouldShow(), isTrue);
    });
    test('nobody signed in: not asked', () async {
      ServiceBackend.useFake(db, uid: null);
      expect(await CoursePicker.shouldShow(), isFalse);
    });
  });

  test('save enrols exactly the picked courses and marks it done', () async {
    await db.doc('users/new-learner').set({'enrolments': {}});
    await CoursePicker.save({'csm', 'binary-ai-fundamentals'});
    final data = (await db.doc('users/new-learner').get()).data()!;
    expect(data['enrolments'], {'csm': true, 'binary-ai-fundamentals': true});
    expect(await CoursePicker.shouldShow(), isFalse);
  });

  testWidgets('Continue stays disabled until a course is picked',
      (tester) async {
    Set<String>? saved;
    // Tall enough that the lazily built list shows every course at once.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: CoursePickerScreen(onSave: (ids) async => saved = ids),
    ));
    await tester.pumpAndSettle();
    expect(find.text('What do you want to learn?'), findsOneWidget);
    for (final course in kCourseCatalog) {
      expect(find.text(course.title), findsOneWidget);
    }

    final continueButton = find.widgetWithText(FilledButton, 'Continue');
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

    await tester.tap(find.text(kCourseCatalog.first.title));
    await tester.pump();
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);

    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(saved, {kCourseCatalog.first.id});
  });
}
