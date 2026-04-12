import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'subscription_service.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn(
    clientId:
        '221875967372-a08gr7ktvm54pijtu2q0b4vc0115rb13.apps.googleusercontent.com',
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

  static Future<void> _onSignInSuccess() async {
    await SubscriptionService.identifyUser();
    await NotificationService.requestPermissions();
  }
}
