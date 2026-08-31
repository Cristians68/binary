import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'notification_service.dart';
import 'subscription_service.dart';
import 'user_document.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  static final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  static Future<UserCredential?> signInWithGoogle() async {
    // ── Web — use popup (redirect requires handling result on page reload) ──
    if (kIsWeb) {
      try {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');
        final result = await _auth.signInWithPopup(provider);
        if (result.user != null) {
          await _onSignInSuccess();
        }
        return result;
      } on FirebaseAuthException catch (e) {
        // User closed the popup — not an error
        if (e.code == 'popup-closed-by-user' ||
            e.code == 'cancelled-popup-request') {
          debugPrint('Google Sign-In: popup closed by user');
          return null;
        }
        debugPrint('Web Google Sign-In FirebaseAuthException: ${e.code}');
        return null;
      } catch (e) {
        debugPrint('Web Google Sign-In ERROR: $e');
        return null;
      }
    }

    // ── iOS / Android ─────────────────────────────────────────────────────
    try {
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('Google Sign-In: cancelled by user');
        return null;
      }
      debugPrint('Google Sign-In: got user ${googleUser.email}');

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        debugPrint('Google Sign-In: idToken is null — aborting');
        return null;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final userCredential = await _signInOrLink(credential);
      debugPrint(
          'Google Sign-In: Firebase success uid=${userCredential.user?.uid}');
      await _onSignInSuccess();
      return userCredential;
    } on PlatformException catch (e) {
      debugPrint('Google Sign-In PlatformException: ${e.code} - ${e.message}');
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint(
          'Google Sign-In FirebaseAuthException: ${e.code} - ${e.message}');
      return null;
    } catch (e, stack) {
      debugPrint('Google Sign-In ERROR: $e');
      debugPrint('Stack: $stack');
      return null;
    }
  }

  /// Sign in with an OAuth credential, upgrading a guest session in place.
  ///
  /// If the current user is anonymous, linking keeps the SAME uid, so the
  /// streak, progress and any purchase they made as a guest survive. Plain
  /// signInWithCredential would mint a new uid and silently orphan all of it.
  static Future<UserCredential> _signInOrLink(AuthCredential credential) async {
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        return await current.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'credential-already-in-use' &&
            e.code != 'email-already-in-use') {
          rethrow;
        }
        // They already have a real account with this provider. Sign in to it;
        // the guest session's progress is left behind rather than merged,
        // because merging two histories is not something we can do safely.
        debugPrint('Guest link failed (${e.code}) - signing in to the '
            'existing account instead');
      }
    }
    return _auth.signInWithCredential(credential);
  }

  // ── Continue as a guest ───────────────────────────────────────────────────

  /// Sign in anonymously so the app can be used without an account.
  ///
  /// App Review rejected 1.0 under Guideline 2.1 partly because the demo
  /// credentials failed and there was no other way in: WelcomeScreen offered
  /// only sign up / log in / Apple / Google. Guideline 5.1.1(v) also says an
  /// app should not force account creation when an account is not core to the
  /// experience, and browsing courses is not.
  ///
  /// Anonymous auth is used rather than loosening firestore.rules. Every rule
  /// gates on `signedIn()` (`request.auth != null`), which an anonymous user
  /// satisfies, so a guest gets exactly what a signed-in free user gets: the
  /// free first module of every course. Paid content is still gated by
  /// `hasCourseAccess()`, and entitlement fields remain server-only.
  ///
  /// Returns null on failure. The most likely failure is `operation-not-allowed`,
  /// which means Anonymous sign-in is not enabled in the Firebase console under
  /// Authentication -> Sign-in method.
  static Future<UserCredential?> signInAsGuest() async {
    try {
      final credential = await _auth.signInAnonymously();
      debugPrint('Guest sign-in: uid=${credential.user?.uid}');
      await _onSignInSuccess();
      return credential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'operation-not-allowed') {
        debugPrint(
          'Guest sign-in failed: Anonymous auth is DISABLED in the Firebase '
          'console. Enable Authentication -> Sign-in method -> Anonymous.',
        );
      } else {
        debugPrint('Guest sign-in failed: ${e.code} - ${e.message}');
      }
      return null;
    } catch (e) {
      debugPrint('Guest sign-in ERROR: $e');
      return null;
    }
  }

  /// Whether the current session is a guest.
  static bool get isGuest => _auth.currentUser?.isAnonymous ?? false;

  // ── Sign in with Apple ────────────────────────────────────────────────────

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
        length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  static Future<UserCredential?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential = await _signInOrLink(oauthCredential);

      // Apple only sends name on the very first sign-in; save it if present.
      final given = appleCredential.givenName;
      final family = appleCredential.familyName;
      if (given != null || family != null) {
        final fullName = [given, family]
            .where((s) => s != null && s.isNotEmpty)
            .join(' ');
        if (fullName.isNotEmpty) {
          await userCredential.user?.updateDisplayName(fullName);
        }
      }

      await _onSignInSuccess();
      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        debugPrint('Apple Sign-In: cancelled by user');
        return null;
      }
      debugPrint('Apple Sign-In AuthorizationException: ${e.code}');
      return null;
    } catch (e) {
      debugPrint('Apple Sign-In ERROR: $e');
      return null;
    }
  }

  static Future<void> _onSignInSuccess() async {
    // FIRST: make sure users/{uid} exists. Only email/password signup created
    // it, so a Google or Apple user used to reach the home screen with no
    // document, and everything that writes to it had to survive that.
    try {
      await ensureUserDocument(
        displayName: _auth.currentUser?.displayName,
      );
    } catch (e) {
      debugPrint('ensureUserDocument error: $e');
    }
    try {
      await SubscriptionService.identifyUser();
    } catch (e) {
      debugPrint('identifyUser error: $e');
    }
    try {
      await NotificationService.requestPermissions();
    } catch (e) {
      debugPrint('requestPermissions error: $e');
    }
  }
}
