import 'package:binary/screens/app_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth implements LockAuthenticator {
  _FakeAuth({this.available = true, this.result = true});
  bool available;
  bool result;
  int prompts = 0;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<bool> authenticate() async {
    prompts++;
    return result;
  }
}

void main() {
  final t0 = DateTime(2026, 9, 23, 12);

  group('shouldLock', () {
    test('never locks a signed-out user', () {
      expect(
          shouldLock(
              signedIn: false,
              backgroundedAt: t0,
              now: t0.add(const Duration(hours: 1))),
          isFalse);
    });
    test('does not lock without a recorded background time', () {
      expect(shouldLock(signedIn: true, backgroundedAt: null, now: t0), isFalse);
    });
    test('locks at exactly two minutes, not before', () {
      expect(
          shouldLock(
              signedIn: true,
              backgroundedAt: t0,
              now: t0.add(const Duration(seconds: 119))),
          isFalse);
      expect(
          shouldLock(
              signedIn: true, backgroundedAt: t0, now: t0.add(kAppLockAfter)),
          isTrue);
    });
    test('a clock moved backwards locks rather than skipping the check', () {
      expect(
          shouldLock(
              signedIn: true,
              backgroundedAt: t0,
              now: t0.subtract(const Duration(minutes: 5))),
          isTrue);
    });
  });

  group('AppLock widget', () {
    late DateTime now;
    late _FakeAuth auth;

    Widget app({bool signedIn = true}) => MaterialApp(
          home: AppLock(
            authenticator: auth,
            now: () => now,
            isSignedIn: () => signedIn,
            child: const Text('SECRET PROGRESS'),
          ),
        );

    setUp(() {
      // The user has opted in; the opt-in itself is tested below.
      SharedPreferences.setMockInitialValues({kAppLockEnabledKey: true});
      now = t0;
      auth = _FakeAuth();
    });

    Future<void> leaveFor(WidgetTester tester, Duration away) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      now = now.add(away);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }

    testWidgets('a short trip away does not lock', (tester) async {
      auth.result = false;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await leaveFor(tester, const Duration(seconds: 30));
      expect(find.text('SECRET PROGRESS'), findsOneWidget);
      expect(find.byKey(AppLock.lockScreenKey), findsNothing);
    });

    testWidgets('two minutes away hides the app until unlocked',
        (tester) async {
      auth.result = false; // first prompt fails: stays locked
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await leaveFor(tester, const Duration(minutes: 3));
      expect(find.byKey(AppLock.lockScreenKey), findsOneWidget);
      expect(find.text('SECRET PROGRESS'), findsNothing,
          reason: 'content must not be visible behind the lock');
      expect(auth.prompts, 1, reason: 'prompts automatically on return');

      auth.result = true;
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(find.byKey(AppLock.lockScreenKey), findsNothing);
      expect(find.text('SECRET PROGRESS'), findsOneWidget);
    });

    testWidgets('a cold start after two minutes away is locked too',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        kAppLockEnabledKey: true,
        kAppLockBackgroundedAtKey:
            t0.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch,
      });
      auth.result = false;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byKey(AppLock.lockScreenKey), findsOneWidget);
      expect(find.text('SECRET PROGRESS'), findsNothing);
    });

    testWidgets('no lock when the phone has no passcode or biometrics',
        (tester) async {
      auth.available = false;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await leaveFor(tester, const Duration(minutes: 10));
      expect(find.byKey(AppLock.lockScreenKey), findsNothing);
      expect(find.text('SECRET PROGRESS'), findsOneWidget);
    });

    testWidgets('off by default: never locks until the user opts in',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await leaveFor(tester, const Duration(minutes: 10));
      expect(find.byKey(AppLock.lockScreenKey), findsNothing);
      expect(auth.prompts, 0, reason: 'no Face ID prompt without consent');
    });

    testWidgets('signed-out users are never locked', (tester) async {
      await tester.pumpWidget(app(signedIn: false));
      await tester.pumpAndSettle();
      await leaveFor(tester, const Duration(minutes: 10));
      expect(find.byKey(AppLock.lockScreenKey), findsNothing);
    });
  });

  group('opting in', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('turning the lock on requires one successful check', () async {
      final auth = _FakeAuth(result: true);
      expect(await AppLockSettings.setEnabled(true, auth), isTrue);
      expect(await AppLockSettings.isEnabled(), isTrue);
      expect(auth.prompts, 1);
    });
    test('a declined or failed check leaves it off', () async {
      final auth = _FakeAuth(result: false);
      expect(await AppLockSettings.setEnabled(true, auth), isFalse);
      expect(await AppLockSettings.isEnabled(), isFalse);
    });
    test('cannot be turned on without a passcode or biometrics', () async {
      final auth = _FakeAuth(available: false);
      expect(await AppLockSettings.setEnabled(true, auth), isFalse);
      expect(auth.prompts, 0);
    });
    test('turning it off needs no check', () async {
      SharedPreferences.setMockInitialValues({kAppLockEnabledKey: true});
      final auth = _FakeAuth(result: false);
      expect(await AppLockSettings.setEnabled(false, auth), isTrue);
      expect(await AppLockSettings.isEnabled(), isFalse);
      expect(auth.prompts, 0);
    });
  });

  group('first-open offer', () {
    Widget host(_FakeAuth auth) => MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => AppLockOffer.maybeShow(context, auth),
                child: const Text('open'),
              ),
            ),
          ),
        );

    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('Turn on enables the lock after one check', (tester) async {
      final auth = _FakeAuth(result: true);
      await tester.pumpWidget(host(auth));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Protect B1nary with Face ID?'), findsOneWidget);
      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();
      expect(await AppLockSettings.isEnabled(), isTrue);
      expect(auth.prompts, 1);
    });

    testWidgets('Not now leaves it off and never asks again', (tester) async {
      final auth = _FakeAuth();
      await tester.pumpWidget(host(auth));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(await AppLockSettings.isEnabled(), isFalse);
      expect(auth.prompts, 0);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Protect B1nary with Face ID?'), findsNothing);
    });

    testWidgets('not offered on a phone with no passcode or biometrics',
        (tester) async {
      final auth = _FakeAuth(available: false);
      await tester.pumpWidget(host(auth));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Protect B1nary with Face ID?'), findsNothing);
    });
  });
}
