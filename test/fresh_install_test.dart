import 'package:binary/fresh_install.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// iOS keeps Firebase's session in the Keychain, which survives deleting the
/// app. Without this, reinstalling on a phone that was ever signed in drops
/// the new user straight into the previous person's account.
void main() {
  test('a fresh install clears a restored session', () async {
    SharedPreferences.setMockInitialValues({});
    var signedOut = 0;
    await clearSessionRestoredFromKeychain(signOut: () async => signedOut++);
    expect(signedOut, 1);
  });

  test('only once: the second launch keeps the session', () async {
    SharedPreferences.setMockInitialValues({});
    var signedOut = 0;
    await clearSessionRestoredFromKeychain(signOut: () async => signedOut++);
    await clearSessionRestoredFromKeychain(signOut: () async => signedOut++);
    expect(signedOut, 1);
  });

  test('an existing install updating to this version is not signed out',
      () async {
    // Installs from before the marker existed have finished onboarding.
    SharedPreferences.setMockInitialValues({'onboardingComplete': true});
    var signedOut = 0;
    await clearSessionRestoredFromKeychain(signOut: () async => signedOut++);
    expect(signedOut, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kInstallMarkerKey), isTrue);
  });

  test('a failed sign-out blocks account entry and can be retried', () async {
    SharedPreferences.setMockInitialValues({});
    await expectLater(
        clearSessionRestoredFromKeychain(
            signOut: () async => throw StateError('keychain busy')),
        throwsStateError);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kInstallMarkerKey), isNot(true),
        reason: 'the marker is only set once the session is really cleared');
    var signedOut = false;
    await clearSessionRestoredFromKeychain(
        signOut: () async => signedOut = true);
    expect(signedOut, isTrue);
    expect(prefs.getBool(kInstallMarkerKey), isTrue);
  });
}
