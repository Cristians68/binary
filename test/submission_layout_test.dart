import 'package:binary/screens/app_theme.dart';
import 'package:binary/screens/paywall_screen.dart';
import 'package:binary/screens/progress_screen.dart';
import 'package:binary/screens/service_backend.dart';
import 'package:binary/screens/welcome_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ServiceBackend.useFake(FakeFirebaseFirestore(), uid: 'learner');
  });
  tearDown(ServiceBackend.reset);

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => AppTheme(
        notifier: ThemeNotifier(),
        child: MediaQuery(
          data:
              MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
      ),
      home: screen,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('all welcome sign-in options remain reachable with large text',
      (tester) async {
    await pump(tester, const WelcomeScreen());
    for (final label in [
      'Continue as guest',
      'Continue with Google',
      'Create an account',
      'Already learning with us? Log in'
    ]) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
  });

  testWidgets('large-text paywall can reach plans, restore and legal links',
      (tester) async {
    await pump(
        tester,
        PaywallScreen(
          courseId: 'binary-network-professional',
          courseTitle: 'Network Professional',
          courseColor: Colors.blue,
          loadPackages: () async => [],
        ));
    for (final label in [
      'Any 4 Courses',
      'Everything',
      'Restore purchases',
      'Terms of Service',
      'Privacy Policy'
    ]) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress statistics fit a small phone at double text size',
      (tester) async {
    await ServiceBackend.db.doc('users/learner').set({
      'lessonsCompleted': 123,
      'badges': {'quiz_first': DateTime(2026)},
      'streak': {'current': 17, 'longest': 17, 'lastLogin': DateTime.now()},
    });
    await pump(tester, const ProgressScreen());
    expect(find.text('Overall progress'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
