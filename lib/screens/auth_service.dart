import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'subscription_service.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn(
    clientId:
        '221875967372-i0if4k8ec66okcb592vdeugf0j0oi10n.apps.googleusercontent.com',
  );

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      UserCredential? credential;

      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');
        try {
          credential = await _auth.signInWithPopup(provider);
        } catch (e) {
          await _auth.signInWithRedirect(provider);
          credential = await _auth.getRedirectResult();
        }
      } else {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;
        final googleAuth = await googleUser.authentication;
        final cred = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        credential = await _auth.signInWithCredential(cred);
      }

      if (credential != null) {
        await _onSignInSuccess();
      }

      return credential;
    } catch (e) {
      return null;
    }
  }

  /// Call this after any sign-in method succeeds (Google, Apple, email, etc.)
  static Future<void> _onSignInSuccess() async {
    // Link RevenueCat identity to Firebase UID
    await SubscriptionService.identifyUser();

    // Request notification permissions and schedule reminders
    await NotificationService.requestPermissions();
  }
}
