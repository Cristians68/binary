import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn(
    clientId: '221875967372-i0if4k8ec66okcb592vdeugf0j0oi10n.apps.googleusercontent.com',
  );

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // Use redirect on mobile web, popup on desktop
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');

        try {
          // Try popup first (works on desktop)
          return await _auth.signInWithPopup(provider);
        } catch (e) {
          // Fall back to redirect (works on mobile)
          await _auth.signInWithRedirect(provider);
          return await _auth.getRedirectResult();
        }
      } else {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      print('Google sign-in error: $e');
      return null;
    }
  }
}