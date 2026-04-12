import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'subscription_service.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  // On iOS, clientId is read automatically from GoogleService-Info.plist
  // Only pass clientId on web
  static final _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '221875967372-i0if4k8ec66okcb592vdeugf0j0oi10n.apps.googleusercontent.com'
        : null,
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

        final redirectResult = await _auth.getRedirectResult();
        if (redirectResult.user != null) {
          await _onSignInSuccess();
          return redirectResult;
        }

        await _auth.signInWithRedirect(provider);
        return null;
      } else {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          debugPrint('Google Sign-In: user cancelled or failed');
          return null;
        }
        debugPrint('Google Sign-In: got user ${googleUser.email}');
        final googleAuth = await googleUser.authentication;
        final cred = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        credential = await _auth.signInWithCredential(cred);
        debugPrint('Google Sign-In: Firebase success');
      }

      if (credential != null) {
        await _onSignInSuccess();
      }

      return credential;
    } catch (e) {
      debugPrint('Google Sign-In ERROR: $e');
      return null;
    }
  }

  static Future<void> _onSignInSuccess() async {
    await SubscriptionService.identifyUser();
    await NotificationService.requestPermissions();
  }
}
