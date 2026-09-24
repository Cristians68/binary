import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The display name Apple shared, or null when it shared nothing usable.
String? appleFullName(String? given, String? family) {
  final name = [given, family]
      .map((part) => part?.trim() ?? '')
      .where((part) => part.isNotEmpty)
      .join(' ');
  return name.isEmpty ? null : name;
}

/// Holds an Apple-supplied name until it has reached the Firebase profile.
///
/// Apple sends the name only on the first authorisation of an Apple ID for
/// this app, never again. It used to live only in a local variable, so if the
/// Firebase sign-in after the sheet failed, the name was lost for good and the
/// account greeted its owner as "there". Keyed by Apple's stable user id so one
/// Apple ID can never inherit another's name.
class AppleNameStore {
  static String _key(String appleUserId) => 'apple_pending_name_$appleUserId';

  static Future<void> remember(String appleUserId, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(appleUserId), name);
  }

  static Future<String?> recall(String appleUserId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(appleUserId));
  }

  static Future<void> forget(String appleUserId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(appleUserId));
  }
}

/// The credential to sign in with after linking it to a guest failed because
/// an account already owns it.
///
/// Firebase returns a fresh credential on that error, and for Apple it must be
/// used: the identity token is single-use, and retrying the one the failed
/// link consumed is rejected as a duplicate — the first tap fails, the second
/// (with a new token) works.
AuthCredential credentialForExistingAccount(
        FirebaseAuthException error, AuthCredential original) =>
    error.credential ?? original;
