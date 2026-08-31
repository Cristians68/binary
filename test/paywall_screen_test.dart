/// Regression tests for the paywall's behaviour when the store returns nothing.
///
/// App Review rejected iOS 1.0 under Guideline 2.1(b) — "we cannot locate the
/// In-App Purchases, such as Single Course Access, 4 Course Bundle, and All
/// Courses Bundle, within the app". The likely reason is here rather than in
/// App Store Connect: `SubscriptionService.getPackages()` catches every
/// RevenueCat error and returns `[]`, and the paywall used to render
/// `_loadError ? _buildErrorState(theme) : <the whole paywall>`. So a single
/// failed offerings load — or a sandbox account with no offerings attached —
/// replaced every plan, price and purchase button with a "Could not load
/// products" screen. There was nothing left on screen to locate.
///
/// In the test VM the RevenueCat platform channel has no implementation, so
/// `getPackages()` returns `[]` for real. These tests therefore run against
/// exactly the state the reviewer hit.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:binary/screens/app_theme.dart';
import 'package:binary/screens/paywall_screen.dart';

Future<void> pumpPaywall(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AppTheme(
        notifier: ThemeNotifier(),
        child: const PaywallScreen(
          courseId: 'net-pro',
          courseTitle: 'Network Professional',
          courseColor: Color(0xFF2F6BFF),
        ),
      ),
    ),
  );
  // Let _loadPackages actually resolve. Two traps here:
  //  * pumpAndSettle is unusable — the loading spinner animates forever until
  //    the future lands.
  //  * plain pump() is not enough either. getPackages() goes through the
  //    RevenueCat MethodChannel, which completes via the real event loop, so
  //    the future never lands inside fake-async time. Without runAsync the
  //    screen stays on the spinner and every "not present" assertion below
  //    passes for the wrong reason.
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump();

  // Guard: if the screen is still on the spinner, every "X is not present"
  // assertion below would pass for the wrong reason. Fail loudly instead.
  expect(
    find.byType(CircularProgressIndicator),
    findsNothing,
    reason: 'the paywall never finished loading, so nothing below is meaningful',
  );
}

void main() {
  testWidgets('every plan is still on screen when no packages load',
      (tester) async {
    await pumpPaywall(tester);

    expect(find.text('Network Professional'), findsWidgets,
        reason: 'the single-course plan must be visible');
    expect(find.text('Any 4 Courses'), findsOneWidget);
    expect(find.text('Everything'), findsOneWidget);
  });

  testWidgets('fallback prices are shown so the tiers are legible',
      (tester) async {
    await pumpPaywall(tester);

    expect(find.text(r'$14.99'), findsOneWidget);
    expect(find.text(r'$49.99'), findsOneWidget);
    expect(find.text(r'$99.99'), findsOneWidget);
  });

  testWidgets('the old full-screen error state is gone', (tester) async {
    await pumpPaywall(tester);

    expect(find.text('Could not load products'), findsNothing,
        reason: 'blanking the paywall is the bug this file exists to prevent');
  });

  testWidgets('the unavailability is explained inline, not by hiding the plans',
      (tester) async {
    await pumpPaywall(tester);

    expect(find.text('Purchases are unavailable right now'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('the CTA does not promise a purchase it cannot start',
      (tester) async {
    await pumpPaywall(tester);

    expect(find.text('Purchases unavailable'), findsOneWidget);
    expect(find.textContaining('Unlock for'), findsNothing);
  });

  testWidgets('restore purchases stays reachable', (tester) async {
    // A user who already owns the course must be able to recover it even when
    // the offerings endpoint is down.
    await pumpPaywall(tester);
    expect(find.text('Restore purchases'), findsOneWidget);
  });
}
