/// The intro carousel must be shown once per install, not once per uid.
///
/// It used to be stored under `onboardingComplete_$uid`, read with whatever
/// uid existed at the moment. At first launch there is no user, so the flag
/// was written under the bare key — and on the next cold start, once the user
/// had signed up, it was looked up under `onboardingComplete_<uid>`, which had
/// never been written. **The intro replayed after signing in.**
///
/// Two separate string literals in two files, agreeing only while nobody was
/// logged in. There is now one constant, and these tests pin the behaviour it
/// exists to guarantee.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:binary/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// What `_AppEntry._check` does: decide whether to show onboarding.
  Future<bool> shouldShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(kOnboardingCompleteKey) ?? false);
  }

  /// What `_completeOnboarding` and `OnboardingScreen._complete` both do.
  Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingCompleteKey, true);
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a fresh install sees the intro', () async {
    expect(await shouldShowOnboarding(), isTrue);
  });

  test('finishing it means it does not come back', () async {
    await markComplete();
    expect(await shouldShowOnboarding(), isFalse);
  });

  test('signing in afterwards does not replay it', () async {
    // The exact regression. Completing onboarding happens while signed OUT —
    // there is no user until the welcome screen — and the next cold start
    // happens while signed IN. If the key depended on the uid these two would
    // disagree and the intro would run again.
    await markComplete();

    // Simulate the later launch: same store, now with an account.
    expect(await shouldShowOnboarding(), isFalse);
  });

  test('the key is not namespaced by uid', () async {
    await markComplete();
    final prefs = await SharedPreferences.getInstance();

    expect(prefs.getKeys(), contains('onboardingComplete'));
    expect(
      prefs.getKeys().where((k) => k.startsWith('onboardingComplete_')),
      isEmpty,
      reason: 'a uid-suffixed key is the bug: it can never be found again '
          'once the uid changes',
    );
  });

  test('a legacy flag written before this fix is still honoured', () async {
    // Anyone who completed onboarding on the old build has the bare key set,
    // because at that point they were signed out. They must not see it again.
    SharedPreferences.setMockInitialValues({'onboardingComplete': true});
    expect(await shouldShowOnboarding(), isFalse);
  });
}
