import 'dart:async';

import 'package:binary/course_catalog.dart';
import 'package:binary/screens/app_theme.dart';
import 'package:binary/screens/trial_offer.dart';
import 'package:binary/screens/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    String? courseId,
    Future<TrialState> Function()? load,
    Future<bool> Function(String)? start,
    VoidCallback? activated,
  }) async {
    await tester.pumpWidget(MaterialApp(
        home: AppTheme(
      notifier: ThemeNotifier(),
      child: Scaffold(
          body: SingleChildScrollView(
              child: TrialOffer(
        courseId: courseId,
        color: Colors.blue,
        loadState: load ?? () async => const TrialState(),
        startTrial: start ?? (_) async => true,
        onActivated: activated ?? () {},
        onBusyChanged: (_) {},
      ))),
    )));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'generic entry requires an explicit course and submits that course once',
      (tester) async {
    final calls = <String>[];
    final pending = Completer<bool>();
    var activated = 0;
    await pump(tester,
        start: (id) {
          calls.add(id);
          return pending.future;
        },
        activated: () => activated++);
    final button = find.byKey(const ValueKey('start-trial'));
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('trial-course-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kCourseCatalog[2].title).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    expect(calls, [kCourseCatalog[2].id]);
    expect(activated, 0);
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(activated, 1);
  });

  testWidgets('a course paywall names and trials only that course',
      (tester) async {
    String? requested;
    await pump(tester, courseId: kCourseCatalog.first.id, start: (id) async {
      requested = id;
      return true;
    });
    expect(find.text(kCourseCatalog.first.title), findsOneWidget);
    expect(find.byKey(const ValueKey('trial-course-picker')), findsNothing);
    expect(find.textContaining('No card required. No automatic charge.'),
        findsOneWidget);
    final button = find.byKey(const ValueKey('start-trial'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(requested, kCourseCatalog.first.id);
  });

  testWidgets(
      'availability failure cannot offer an unverified trial and can retry',
      (tester) async {
    var attempts = 0;
    await pump(tester, load: () async {
      if (++attempts == 1) throw Exception('offline');
      return const TrialState();
    });
    expect(find.byKey(const ValueKey('start-trial')), findsNothing);
    await tester.tap(find.text('Retry trial check'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('start-trial')), findsOneWidget);
  });

  testWidgets('activation errors stay visible without granting access',
      (tester) async {
    var activated = false;
    await pump(tester,
        courseId: kCourseCatalog.first.id,
        start: (_) async =>
            throw const TrialFailure('Trial service unavailable.'),
        activated: () => activated = true);
    final button = find.byKey(const ValueKey('start-trial'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(activated, false);
    expect(find.text('Trial service unavailable.'), findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });

  testWidgets(
      'an active trial names its course but cannot unlock a different paywall',
      (tester) async {
    await pump(tester,
        courseId: kCourseCatalog[1].id,
        load: () async => TrialState(
            hasUsedTrial: true,
            courseId: kCourseCatalog.first.id,
            expiresAt: DateTime.now().add(const Duration(days: 7))));
    expect(find.text('Your free trial is active'), findsOneWidget);
    expect(find.textContaining(kCourseCatalog.first.title), findsOneWidget);
    expect(find.text('Continue with trial access'), findsNothing);
    expect(find.byKey(const ValueKey('start-trial')), findsNothing);
  });

  testWidgets('course picker and start action remain usable at doubled text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(tester);
    final picker = find.byKey(const ValueKey('trial-course-picker'));
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    final course = find.text(kCourseCatalog.first.title).last;
    await tester.ensureVisible(course);
    await tester.tap(course);
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('start-trial'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(button.hitTestable(), findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'expired trial keeps free previews and offers no second trial at large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(tester,
        load: () async => TrialState(
            hasUsedTrial: true,
            courseId: kCourseCatalog.first.id,
            expiresAt: DateTime.now().subtract(const Duration(seconds: 1))));
    expect(find.text('Your free trial has ended'), findsOneWidget);
    expect(find.textContaining('first module of every course is still free'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('start-trial')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
