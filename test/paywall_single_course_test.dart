/// Regression tests for WHICH course a single-course purchase buys.
///
/// The bug: `PaywallScreen.courseId` was non-nullable, and the three generic
/// entry points — the Courses upgrade banner, the home upgrade card, and
/// Profile → Plans & Pricing — each passed the literal `'itil-v4'` to satisfy
/// it. Selecting the Single plan from any of them therefore bought IT Service
/// Management Foundations no matter which course the user wanted, with no
/// picker on screen and nothing naming the course being charged for. The
/// bundle-4 plan had a picker; the single plan simply did not.
///
/// These tests pin both halves of the fix: a picker exists, and nothing is
/// pre-selected when the paywall was opened without a course.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:binary/course_catalog.dart';
import 'package:binary/screens/app_theme.dart';
import 'package:binary/screens/paywall_screen.dart';

/// Pump a paywall and wait for `_loadPackages` to settle.
///
/// getPackages() goes through the RevenueCat MethodChannel, which has no
/// implementation in the test VM and completes on the real event loop — so
/// runAsync is required or the screen stays on its spinner and every
/// "not present" assertion below passes for the wrong reason.
Future<void> _pump(WidgetTester tester, {String? courseId}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AppTheme(
        notifier: ThemeNotifier(),
        child: PaywallScreen(
          courseId: courseId,
          courseTitle: courseId == null ? 'ByteStack' : 'A Course',
          courseColor: const Color(0xFF2F6BFF),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump();

  expect(
    find.byType(CircularProgressIndicator),
    findsNothing,
    reason: 'the paywall never finished loading, so nothing below is meaningful',
  );
}

void main() {
  group('opened from a generic entry point (no course)', () {
    testWidgets('asks which course instead of silently choosing one',
        (tester) async {
      await _pump(tester);

      expect(find.text('WHICH COURSE?'), findsOneWidget,
          reason: 'the single plan must offer a picker, as bundle-4 does');
      expect(find.text('Pick one'), findsOneWidget);
      expect(find.text('Selected ✓'), findsNothing,
          reason: 'nothing may be pre-selected when no course was passed in');
    });

    testWidgets('every catalogued course is offered', (tester) async {
      await _pump(tester);

      for (final c in kCourseCatalog) {
        expect(find.text(c.title), findsWidgets,
            reason: '${c.id} is missing from the single-course picker');
      }
    });

    testWidgets('the notice tells the user to choose rather than naming a course',
        (tester) async {
      // The CTA itself reads "Purchases unavailable" in the test VM, because
      // the RevenueCat channel has no implementation here and no packages
      // load. The notice box renders either way, so it is the observable that
      // can actually distinguish the two states.
      await _pump(tester);

      expect(find.textContaining('Choose the course you want below'),
          findsOneWidget);
      expect(find.textContaining('Lifetime access to IT Service Management'),
          findsNothing,
          reason: 'this is the exact purchase the bug used to make silently');
    });

    testWidgets('the plan tile does not name a course nobody picked',
        (tester) async {
      await _pump(tester);

      expect(find.text('Single course'), findsOneWidget);
      // 'IT Service Management Foundations' may still appear as a row in the
      // picker; what must not happen is it being presented as the selection.
      expect(find.text('Selected ✓'), findsNothing);
    });

    testWidgets('choosing a course updates the tile and the notice',
        (tester) async {
      await _pump(tester);

      const target = 'Cybersecurity Professional';
      final row = find.text(target);
      expect(row, findsOneWidget);
      await tester.ensureVisible(row);
      await tester.pump();
      await tester.tap(row);
      await tester.pump();

      expect(find.text('Selected ✓'), findsOneWidget);
      expect(find.text(target), findsWidgets,
          reason: 'the chosen course now names the plan tile as well as its row');
      expect(find.textContaining('Choose the course you want below'),
          findsNothing);
      expect(find.textContaining('Lifetime access to $target'), findsOneWidget);
    });
  });

  group('opened from a specific locked course', () {
    testWidgets('that course is pre-selected', (tester) async {
      await _pump(tester, courseId: 'binary-network-professional');

      expect(find.text('Selected ✓'), findsOneWidget);
      expect(find.text('Choose a course'), findsNothing);
    });

    testWidgets('the picker is still shown so the choice can be changed',
        (tester) async {
      await _pump(tester, courseId: 'binary-network-professional');

      expect(find.text('WHICH COURSE?'), findsOneWidget);

      const other = 'Cloud Architecture';
      final row = find.text(other);
      await tester.ensureVisible(row);
      await tester.pump();
      await tester.tap(row);
      await tester.pump();

      expect(find.textContaining('Lifetime access to $other'), findsOneWidget,
          reason: 'the user must be able to change their mind before paying');
    });

    testWidgets('an uncatalogued id falls back to the title it was given',
        (tester) async {
      // displayTitle() returns the raw id for an unknown course. Showing
      // "net-pro" as the thing being purchased would be worse than useless.
      await _pump(tester, courseId: 'not-in-the-catalogue');

      expect(find.textContaining('Lifetime access to A Course'), findsOneWidget);
      expect(find.textContaining('not-in-the-catalogue'), findsNothing);
    });
  });
}
