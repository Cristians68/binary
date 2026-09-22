import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_result.dart';
import '../crash_reporting.dart';
import '../firebase_options.dart';

/// Shared by sign-in and account reauthentication. Initialize the native SDK
/// once, on first use; web uses Firebase's popup and never enters this class.
class NativeGoogleAuth {
  final GoogleSignIn _signIn = GoogleSignIn.instance;
  Future<void>? _initialization;

  /// Initialize once, but only remember a *successful* initialization.
  ///
  /// The native SDK can fail transiently — no network on a first launch, a
  /// slow keychain, a scene that is not ready yet. Caching that rejected
  /// future turned a transient failure into a permanent one: every later tap
  /// awaited the same dead future, so Google stayed broken until the process
  /// was force-quit, while Apple and email kept working.
  Future<void> _ensureInitialized() {
    final pending = _initialization;
    if (pending != null) return pending;
    // Use the same iOS client for Firebase and the Google SDK. A stale
    // GoogleService-Info.plist must not silently select another OAuth client.
    final attempt = _signIn.initialize(
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? DefaultFirebaseOptions.ios.iosClientId
          : null,
    );
    _initialization = attempt;
    unawaited(attempt.catchError((Object _) {
      // Forget only this attempt, so a retry already in flight is not lost.
      if (identical(_initialization, attempt)) _initialization = null;
    }));
    return attempt;
  }

  Future<OAuthCredential> credential() async {
    // Breadcrumbs, not logs. If the native Google SDK terminates the process
    // these are the last thing written, and they say which stage it died in --
    // the one question five previous audits could not answer.
    CrashReporting.trail('google: initializing native SDK');
    await _ensureInitialized();
    if (!_signIn.supportsAuthenticate()) {
      throw PlatformException(
          code: 'operation-not-supported-in-this-environment');
    }
    // Clear the account selection without revoking the user's OAuth grant.
    CrashReporting.trail('google: clearing previous account selection');
    await _signIn.signOut();
    CrashReporting.trail('google: presenting the account chooser');
    final account = await _signIn.authenticate();
    CrashReporting.trail('google: account chosen, reading identity token');
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw PlatformException(code: 'missing-id-token');
    }
    // Firebase only needs the identity token. Requesting Google API scopes
    // would add an authorization prompt unrelated to signing into B1nary.
    CrashReporting.trail('google: identity token received');
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  Future<void> signOut() async {
    final initialization = _initialization;
    if (initialization == null) return;
    try {
      await initialization;
    } catch (_) {
      // Initialization never succeeded, so there is no native session to
      // clear — and sign-out must not surface that failure to the caller.
      return;
    }
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
