import 'package:binary/course_catalog.dart';
import 'package:binary/screens/app_theme.dart';
import 'package:binary/screens/courses_screen.dart';
import 'package:binary/screens/home_screen.dart';
import 'package:binary/screens/onboarding_screen.dart';
import 'package:binary/screens/service_backend.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late FakeFirebaseFirestore db;
  const network = 'binary-network-professional';
  const cloud = 'binary-cloud-fundamentals';
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    ServiceBackend.useFake(db, uid: 'learner');
    for (final id in [network, cloud]) {
      await db.doc('courses/$id').set({
        'order': id == network ? 1 : 2,
        'tag': courseInfo(id)!.tag,
        'totalModules': 8,
        'progress': .99,
      });
    }
  });
  tearDown(ServiceBackend.reset);

  Future<void> pump(WidgetTester tester, Widget screen,
      {double scale = 1, bool dark = false}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
        builder: (context, child) => AppTheme(
            notifier: ThemeNotifier(initialIsDark: dark),
            child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!)),
        home: screen));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    if (find.text(text).evaluate().isEmpty) {
      await tester.scrollUntilVisible(find.text(text), 300,
          scrollable: find.byType(Scrollable).first);
    }
    await tester.ensureVisible(find.text(text).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets('search and subject filters work together and can be cleared',
      (tester) async {
    await pump(tester, const CoursesScreen());
    await tester.enterText(find.byType(TextField), 'cloud');
    await tester.pumpAndSettle();
    expect(find.text('Cloud Fundamentals'), findsOneWidget);
    expect(find.text('Network Professional'), findsNothing);
    await tap(tester, 'Networking');
    expect(find.text('Room for something new'), findsOneWidget);
    await tap(tester, 'Explore all courses');
    expect(find.text('Network Professional'), findsOneWidget);
    expect(find.text('2 courses to explore'), findsOneWidget);
  });

  testWidgets('enrolling updates My courses without replacing account data',
      (tester) async {
    await db.doc('users/learner').set({
      'subscriptionPlan': 'all',
      'enrolments': {cloud: true},
      'displayName': 'Alex'
    });
    await pump(tester, const CoursesScreen());
    await tester.enterText(find.byType(TextField), 'network');
    await tester.pumpAndSettle();
    await tap(tester, 'Enroll');
    await tap(tester, 'My courses');
    expect(find.text('Network Professional'), findsOneWidget);
    final data = (await db.doc('users/learner').get()).data()!;
    expect(data['enrolments'], {network: true, cloud: true});
    expect(data['subscriptionPlan'], 'all');
    expect(data['displayName'], 'Alex');
  });

  testWidgets('continue learning follows live personal course progress',
      (tester) async {
    await db.doc('users/learner').set({
      'enrolments': {network: true, cloud: true}
    });
    await db.doc('users/learner/progress/$network').set({'progress': .75});
    await db.doc('users/learner/progress/$cloud').set({'progress': .25});
    await pump(tester, const HomeScreen(learnerName: 'Alex'));
    expect(find.text('75% of course completed'), findsOneWidget);
    await db.doc('users/learner/progress/$network').update({'progress': 1});
    await tester.pumpAndSettle();
    expect(find.text('25% of course completed'), findsOneWidget);
    expect(find.text('99% of course completed'), findsNothing);
  });

  testWidgets('all onboarding steps remain usable with doubled text',
      (tester) async {
    var completed = false;
    await pump(tester, OnboardingScreen(onComplete: () => completed = true),
        scale: 2, dark: true);
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpAndSettle();
    await tap(tester, 'Reveal explanation');
    await tap(tester, 'Continue');
    await tap(tester, 'DNS');
    await tap(tester, 'Continue');
    await tap(tester, 'Explore free lessons');
    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('library cards remain actionable with doubled text',
      (tester) async {
    await pump(tester, const CoursesScreen(), scale: 2, dark: true);
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'network');
    await tester.pumpAndSettle();
    await tap(tester, 'Enroll');
    expect((await db.doc('users/learner').get()).data()?['enrolments'],
        {network: true});
    expect(tester.takeException(), isNull);
  });
}
