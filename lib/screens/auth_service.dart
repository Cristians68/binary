import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'notification_service.dart';
import 'subscription_service.dart';

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

      final userCredential = await _auth.signInWithCredential(credential);
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

  static Future<void> _onSignInSuccess() async {
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
