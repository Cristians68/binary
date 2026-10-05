import 'dart:async';
import 'package:binary/app_startup.dart';
import 'package:binary/fresh_install.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'launch paints while initialization is pending, then opens the app',
      (tester) async {
    final initialized = Completer<Widget>();
    await tester.pumpWidget(AppStartup(initialize: () => initialized.future));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('B1nary'), findsOneWidget);
    initialized.complete(const MaterialApp(home: Text('Study home')));
    await tester.pumpAndSettle();
    expect(find.text('Study home'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
      'a startup failure can be retried without exposing internal errors',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(AppStartup(initialize: () async {
      if (++attempts == 1) throw StateError('internal service detail');
      return const MaterialApp(home: Text('Study home'));
    }));
    await tester.pumpAndSettle();
    expect(find.text('Let’s try again'), findsOneWidget);
    expect(find.textContaining('internal service detail'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Study home'), findsOneWidget);
  });

  testWidgets('retry replaces the error with loading and ignores repeat taps',
      (tester) async {
    final initialized = Completer<Widget>();
    var attempts = 0;
    await tester.pumpWidget(AppStartup(initialize: () {
      if (++attempts == 1) throw StateError('offline');
      return initialized.future;
    }));
    await tester.pumpAndSettle();
    final retry =
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!;
    retry();
    retry();
    await tester.pump();
    expect(attempts, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Let’s try again'), findsNothing);
    expect(find.text('Try again'), findsNothing);
    initialized.complete(const MaterialApp(home: Text('Study home')));
    await tester.pumpAndSettle();
    expect(find.text('Study home'), findsOneWidget);
  });

  testWidgets('a repeated immediate failure stays recoverable', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(AppStartup(initialize: () {
      attempts++;
      throw StateError('still offline');
    }));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a stalled launch times out and retry shares its pending work',
      (tester) async {
    final initialized = Completer<Widget>();
    var attempts = 0;
    await tester.pumpWidget(AppStartup(
      timeout: const Duration(seconds: 1),
      initialize: () {
        attempts++;
        return initialized.future;
      },
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(attempts, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    initialized.complete(const MaterialApp(home: Text('Study home')));
    await tester.pumpAndSettle();
    expect(find.text('Study home'), findsOneWidget);
  });

  testWidgets('a late launch failure can start a fresh attempt',
      (tester) async {
    final initialized = Completer<Widget>();
    var attempts = 0;
    await tester.pumpWidget(AppStartup(
      timeout: const Duration(seconds: 1),
      initialize: () {
        if (++attempts == 1) return initialized.future;
        return Future.value(const MaterialApp(home: Text('Study home')));
      },
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    initialized.completeError(StateError('late native failure'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Study home'), findsOneWidget);
  });

  testWidgets('failed reinstall cleanup never opens the previous study space',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    var cleanupAttempts = 0;
    var previousAccountSignedIn = true;
    await tester.pumpWidget(AppStartup(initialize: () async {
      await clearSessionRestoredFromKeychain(signOut: () async {
        if (++cleanupAttempts == 1) throw StateError('keychain busy');
        previousAccountSignedIn = false;
      });
      return MaterialApp(
          home: Text(previousAccountSignedIn ? 'Previous account' : 'Welcome'));
    }));
    await tester.pumpAndSettle();
    expect(find.text('Previous account'), findsNothing);
    expect(find.text('Welcome'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(cleanupAttempts, 2);
    expect(find.text('Welcome'), findsOneWidget);
    expect(previousAccountSignedIn, isFalse);
  });

  testWidgets('recovery is usable with large text on a small phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester
        .pumpWidget(AppStartup(initialize: () => throw StateError('offline')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Try again'));
    expect(tester.takeException(), isNull);
  });

  test('optional SDK failures do not abort startup', () async {
    await runOptionalStartupTask(
        'Test SDK', () => throw StateError('unavailable'));
  });

  test('completed startup work is reused after a later step needs retry',
      () async {
    var calls = 0;
    final task = StartupTask(() async => ++calls);
    expect(await task.run(), 1);
    expect(await task.run(), 1);
    expect(calls, 1);
  });

  test('a stalled optional SDK does not hold launch indefinitely', () async {
    final pending = Completer<void>();
    await runOptionalStartupTask('Test SDK', () => pending.future,
        timeout: const Duration(milliseconds: 10));
    // A late failure also stays handled after the timeout has released launch.
    pending.completeError(StateError('late failure'));
    await Future<void>.delayed(Duration.zero);
  });
}
