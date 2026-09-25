import 'package:binary/screens/app_theme.dart';
import 'package:binary/screens/paywall_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class _Package extends Fake implements Package {
  _Package(String id, double price)
      : storeProduct = StoreProduct(id, 'Course', 'Course', price,
            '€${price.toStringAsFixed(2)}', 'EUR');
  @override
  final StoreProduct storeProduct;
}

void main() {
  Future<void> pump(WidgetTester tester, List<Package> packages,
      {bool generic = false}) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: AppTheme(
      notifier: ThemeNotifier(),
      child: PaywallScreen(
        courseId: generic ? null : 'itil-v4',
        courseTitle: 'B1nary',
        courseColor: Colors.blue,
        defaultToAllPlans: generic,
        loadPackages: () async => packages,
      ),
    )));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'selecting another course selects its own localized product price',
      (tester) async {
    await pump(tester, [
      _Package('binary_course_itsm', 12),
      _Package('binary_course_scrm', 18)
    ]);
    expect(
        find.textContaining(
            'Unlock IT Service Management Foundations · €12.00'),
        findsOneWidget);
    final other = find.text('Agile & Scrum Foundations');
    await tester.ensureVisible(other);
    await tester.tap(other);
    await tester.pumpAndSettle();
    expect(find.textContaining('Unlock Agile & Scrum Foundations · €18.00'),
        findsOneWidget);
  });

  testWidgets(
      'a missing selected product cannot use a different product or the legacy single SKU',
      (tester) async {
    await pump(tester, [
      _Package('binary_course_single', 14),
      _Package('binary_course_scrm', 18)
    ]);
    expect(
        find.text('This selection is unavailable right now'), findsOneWidget);
    final cta = find.text('Purchases unavailable');
    expect(cta, findsOneWidget);
    final detector = tester.widget<GestureDetector>(
        find.ancestor(of: cta, matching: find.byType(GestureDetector)).first);
    expect(detector.onTap, isNull);
  });

  testWidgets(
      'generic paywall lets the learner switch to Single before choosing a course',
      (tester) async {
    await pump(tester,
        [_Package('binary_bundle_all', 90), _Package('binary_course_scrm', 18)],
        generic: true);
    final single = find.text('Single course');
    await tester.ensureVisible(single);
    await tester.tap(single);
    await tester.pumpAndSettle();
    expect(find.text('WHICH COURSE?'), findsOneWidget);
    expect(find.text('Choose a course'), findsOneWidget);
    final course = find.text('Agile & Scrum Foundations');
    await tester.ensureVisible(course);
    await tester.tap(course);
    await tester.pumpAndSettle();
    expect(find.textContaining('Unlock Agile & Scrum Foundations · €18.00'),
        findsOneWidget);
  });
}
