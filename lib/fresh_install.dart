import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Set once this install has started with a clean session.
const String kInstallMarkerKey = 'installInitialised';

/// Signs out a session restored from the iOS Keychain on a fresh install.
///
/// Deleting an iOS app clears its preferences but NOT the Keychain, where
/// Firebase keeps the signed-in user. So a reinstall on a phone that was
/// ever signed in (the owner's test phone, a shared family iPad) skipped
/// onboarding and the welcome screen and opened the previous person's
/// account. Preferences being empty is how a fresh install is recognised.
///
/// An install that already finished onboarding predates this marker and is
/// just updating, so it is marked without signing anyone out.
Future<void> clearSessionRestoredFromKeychain({
  required Future<void> Function() signOut,
}) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(kInstallMarkerKey) ?? false) return;
  if (!(prefs.getBool('onboardingComplete') ?? false)) {
    try {
      await signOut();
    } catch (error) {
      // Leave the marker unset so the next launch tries again, and let the
      // app start rather than hang on a stuck Keychain.
      debugPrint('Fresh install sign-out failed: $error');
      return;
    }
  }
  await prefs.setBool(kInstallMarkerKey, true);
}
