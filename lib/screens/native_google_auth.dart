import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_result.dart';

/// Shared by sign-in and account reauthentication. Initialize the native SDK
/// once, on first use; web uses Firebase's popup and never enters this class.
class NativeGoogleAuth {
  final GoogleSignIn _signIn = GoogleSignIn.instance;
  Future<void>? _initialization;

  Future<OAuthCredential> credential() async {
    await (_initialization ??= _signIn.initialize());
    if (!_signIn.supportsAuthenticate()) {
      throw PlatformException(
          code: 'operation-not-supported-in-this-environment');
    }
    // Clear the account selection without revoking the user's OAuth grant.
    await _signIn.signOut();
    final account = await _signIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw PlatformException(code: 'missing-id-token');
    }
    // Firebase only needs the identity token. Requesting Google API scopes
    // would add an authorization prompt unrelated to signing into B1nary.
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  Future<void> signOut() async {
    final initialization = _initialization;
    if (initialization == null) return;
    await initialization;
    await _signIn.signOut();
  }
}

AuthResult googleAuthFailure(GoogleSignInException error) {
  if (error.code == GoogleSignInExceptionCode.canceled) {
    return const AuthResult.cancelled();
  }
  final code = switch (error.code) {
    GoogleSignInExceptionCode.clientConfigurationError =>
      'invalid-oauth-client-id',
    GoogleSignInExceptionCode.providerConfigurationError =>
      'operation-not-allowed',
    GoogleSignInExceptionCode.uiUnavailable => 'no-active-window',
    GoogleSignInExceptionCode.userMismatch => 'user-mismatch',
    _ => 'google-${error.code.name}',
  };
  return AuthResult.failed(code: code, message: error.description);
}
