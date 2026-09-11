import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'auth_result.dart';
import 'subscription_service.dart';
import 'user_document.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  static final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  /// See [isCancellationCode] in auth_result.dart for why this matters to the
  /// fallback chains below.
  static bool _isCancellation(String? code) => isCancellationCode(code);

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  static Future<AuthResult> signInWithGoogle() async {
    // ── Web — use popup (redirect requires handling result on page reload) ──
    if (kIsWeb) {
      try {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile')
          // Forces the account chooser instead of silently reusing whichever
          // Google account the browser last used.
          ..setCustomParameters({'prompt': 'select_account'});
        final result = await _auth.signInWithPopup(provider);
        if (result.user != null) {
          await _onSignInSuccess();
        }
        return const AuthResult.success();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' ||
            e.code == 'cancelled-popup-request') {
          debugPrint('Google Sign-In: popup closed by user');
          return const AuthResult.cancelled();
        }
        debugPrint('Web Google Sign-In FirebaseAuthException: ${e.code}');
        return AuthResult.failed(code: e.code, message: e.message);
      } catch (e) {
        debugPrint('Web Google Sign-In ERROR: $e');
        return AuthResult.failed(message: e.toString());
      }
    }

    // ── iOS — Firebase provider flow, so the account chooser appears ──────
    //
    // The native Google SDK cannot ask for one. `google_sign_in` 6.3.0 exposes
    // `hostedDomain`, `forceAccountName` and `forceCodeForRefreshToken` and
    // nothing else — there is no way to send `prompt=select_account` through
    // it. On iOS it signs in through a session that shares Safari's cookies,
    // so when exactly one Google account is signed in to the browser, Google's
    // OAuth endpoint picks it and never shows a chooser. Somebody signed in to
    // a work account in Safari therefore gets that work account every single
    // time, with no way to choose.
    //
    // `_googleSignIn.signOut()` does not help, and the comment below claiming
    // it does was wrong for iOS: it clears the PLUGIN's cached user, not the
    // browser's cookie jar, so the next sign-in sails straight through on the
    // same browser session.
    //
    // `signInWithProvider` does send custom parameters — verified in the
    // plugin's own iOS source, which calls `[FIROAuthProvider
    // setCustomParameters:]` before requesting the credential.
    //
    // Android is deliberately left on the native SDK: there the plugin shows a
    // real system account picker, so it does not have this problem.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final viaProvider = await _googleViaFirebaseProvider();
      if (viaProvider.isSuccess || viaProvider.isCancelled) return viaProvider;
      // Fall through rather than fail. The worst case is then exactly the
      // behaviour that shipped before this: sign-in works, on the wrong
      // account. Being unable to sign in at all would be a regression.
      debugPrint('Google provider flow failed (${viaProvider.code}) — '
          'falling back to the native sheet');
    }

    // ── Android, and the iOS fallback ─────────────────────────────────────
    try {
      // signOut, NOT disconnect.
      //
      // disconnect() REVOKES the OAuth grant, and it throws when nobody is
      // signed in — which was swallowed here. The plugin then kept its cached
      // account and signIn() completed silently against it, so there was no
      // way to pick a different Google account: the chooser never appeared.
      // signOut() clears the cached selection without revoking, which is
      // exactly what makes the next signIn() present the account list.
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('Google signOut before sign-in failed (ignored): $e');
      }

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('Google Sign-In: cancelled by user');
        return const AuthResult.cancelled();
      }
      debugPrint('Google Sign-In: got user ${googleUser.email}');

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        debugPrint('Google Sign-In: idToken is null — aborting');
        return const AuthResult.failed(code: 'missing-id-token');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final userCredential = await _signInOrLink(credential);
      debugPrint(
          'Google Sign-In: Firebase success uid=${userCredential.user?.uid}');
      await _onSignInSuccess();
      return const AuthResult.success();
    } on PlatformException catch (e) {
      debugPrint('Google Sign-In PlatformException: ${e.code} - ${e.message}');
      return AuthResult.failed(code: e.code, message: e.message);
    } on FirebaseAuthException catch (e) {
      debugPrint(
          'Google Sign-In FirebaseAuthException: ${e.code} - ${e.message}');
      return AuthResult.failed(code: e.code, message: e.message);
    } catch (e, stack) {
      debugPrint('Google Sign-In ERROR: $e');
      debugPrint('Stack: $stack');
      return AuthResult.failed(message: e.toString());
    }
  }

  /// Google through Firebase's own OAuth flow, asking for the account chooser.
  ///
  /// Returns a cancellation when the user backs out, so the caller knows not to
  /// fall back and re-prompt.
  static Future<AuthResult> _googleViaFirebaseProvider() async {
    try {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile')
        // The entire reason this path exists.
        ..setCustomParameters({'prompt': 'select_account'});

      final userCredential = await _signInOrLinkProvider(provider);
      debugPrint('Google provider flow: uid=${userCredential.user?.uid}');
      await _onSignInSuccess();
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      if (_isCancellation(e.code)) {
        debugPrint('Google provider flow: cancelled by user');
        return const AuthResult.cancelled();
      }
      debugPrint('Google provider FirebaseAuthException: ${e.code} ${e.message}');
      return AuthResult.failed(code: e.code, message: e.message);
    } on PlatformException catch (e) {
      if (_isCancellation(e.code)) return const AuthResult.cancelled();
      debugPrint('Google provider PlatformException: ${e.code} ${e.message}');
      return AuthResult.failed(code: e.code, message: e.message);
    } catch (e) {
      debugPrint('Google provider ERROR: $e');
      return AuthResult.failed(message: e.toString());
    }
  }

  /// Apple through FlutterFire's own `signInWithProvider`.
  ///
  /// This does NOT avoid ASAuthorizationAppleIDProvider, and so does NOT avoid
  /// the entitlement. FlutterFire's iOS plugin special-cases `apple.com`
  /// (FLTFirebaseAuthPlugin.m: `signInWithProviderApp` calls
  /// `launchAppleSignInRequest`) and raises the same native Apple sheet, so a
  /// missing entitlement or profile capability breaks this path as well.
  ///
  /// What differs is everything after the sheet: FlutterFire generates the
  /// nonce and builds the Firebase credential itself. So this routes around a
  /// mistake in our own nonce or credential handling, and when both paths
  /// fail, the second code still says which layer broke.
  static Future<AuthResult> _appleViaFirebaseProvider() async {
    try {
      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');

      final userCredential = await _signInOrLinkProvider(provider);
      debugPrint('Apple provider flow: uid=${userCredential.user?.uid}');
      await _onSignInSuccess();
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      if (_isCancellation(e.code)) {
        debugPrint('Apple provider flow: cancelled by user');
        return const AuthResult.cancelled();
      }
      debugPrint('Apple provider FirebaseAuthException: ${e.code} ${e.message}');
      return AuthResult.failed(code: e.code, message: e.message);
    } on PlatformException catch (e) {
      if (_isCancellation(e.code)) return const AuthResult.cancelled();
      debugPrint('Apple provider PlatformException: ${e.code} ${e.message}');
      return AuthResult.failed(code: e.code, message: e.message);
    } catch (e) {
      debugPrint('Apple provider ERROR: $e');
      return AuthResult.failed(message: e.toString());
    }
  }

  /// [_signInOrLink] for the provider flows, which take an [AuthProvider]
  /// rather than an [AuthCredential].
  ///
  /// Same rule: a guest is upgraded in place so the uid — and with it the
  /// streak, the progress and anything they bought — survives.
  static Future<UserCredential> _signInOrLinkProvider(
      AuthProvider provider) async {
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        return await current.linkWithProvider(provider);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'credential-already-in-use' &&
            e.code != 'email-already-in-use') {
          rethrow;
        }
        debugPrint('Guest link failed (${e.code}) - signing in to the '
            'existing account instead');
      }
    }
    return _auth.signInWithProvider(provider);
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
  static Future<AuthResult> signInAsGuest() async {
    try {
      final credential = await _auth.signInAnonymously();
      debugPrint('Guest sign-in: uid=${credential.user?.uid}');
      await _onSignInSuccess();
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'operation-not-allowed') {
        debugPrint(
          'Guest sign-in failed: Anonymous auth is DISABLED in the Firebase '
          'console. Enable Authentication -> Sign-in method -> Anonymous.',
        );
      } else {
        debugPrint('Guest sign-in failed: ${e.code} - ${e.message}');
      }
      return AuthResult.failed(code: e.code, message: e.message);
    } catch (e) {
      debugPrint('Guest sign-in ERROR: $e');
      return AuthResult.failed(message: e.toString());
    }
  }

  /// Whether the current session is a guest.
  static bool get isGuest => _auth.currentUser?.isAnonymous ?? false;

  /// Whether this account actually has an email/password credential.
  ///
  /// Profile offered "Change password" to everyone. For a guest that reached
  /// `EmailAuthProvider.credential(email: user!.email!, ...)` with a null
  /// email and crashed on the null check — which is not a
  /// FirebaseAuthException, so the screen's `on FirebaseAuthException` handler
  /// never saw it. For a Google- or Apple-only account it failed differently
  /// and reported "Current password is incorrect", which is not what happened
  /// and sends the user looking for a password they never set.
  ///
  /// There is only one honest answer to "can this account change its
  /// password", and it is this.
  static bool get hasPasswordProvider =>
      _auth.currentUser?.providerData
          .any((p) => p.providerId == 'password') ??
      false;

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

  /// Sign in with Apple.
  ///
  /// Native flow first, because it is the better experience — Face ID, no
  /// password, no browser. If it fails for anything other than the user backing
  /// out, [_appleViaFirebaseProvider] runs instead.
  ///
  /// That fallback exists because the native flow's failure has resisted
  /// diagnosis: every inspectable piece of configuration is correct (Apple
  /// enabled in Firebase, the entitlement declared in all three build
  /// configurations, the capability present on a regenerated provisioning
  /// profile, the nonce hashed correctly). It is NOT an independent route:
  /// FlutterFire raises the same ASAuthorization sheet (see
  /// [_appleViaFirebaseProvider]), so it only helps if the fault is in our own
  /// nonce or credential handling. An entitlement or profile fault fails both.
  ///
  /// When both fail, BOTH codes are reported, because which one matters
  /// depends on which layer actually broke.
  static Future<AuthResult> signInWithApple() async {
    final native = await _appleViaNativeSdk();
    if (native.isSuccess || native.isCancelled) return native;

    debugPrint('Apple native flow failed (${native.code}) — trying the '
        'Firebase provider flow');
    final viaProvider = await _appleViaFirebaseProvider();
    if (viaProvider.isSuccess || viaProvider.isCancelled) return viaProvider;

    return AuthResult.failed(
      code: '${native.code ?? 'native-failed'} then '
          '${viaProvider.code ?? 'provider-failed'}',
      message: viaProvider.message ?? native.message,
    );
  }

  /// Re-confirms an Apple account before it is deleted, and returns the
  /// authorization code that revoking its Apple token needs.
  ///
  /// Apple requires an app offering Sign in with Apple to revoke the user's
  /// token when their account is deleted. Revocation takes an authorization
  /// code, and only a fresh Apple sign-in produces one, so this doubles as the
  /// re-authentication step.
  ///
  /// Same chain as [signInWithApple]: the native sheet first, then Firebase's
  /// own Apple flow if that fails for anything other than the user backing
  /// out. `user-mismatch` also ends the chain — the sheet worked and the
  /// person chose a different Apple ID, which a second sheet would not change.
  static Future<({AuthResult result, String? authorizationCode})>
      reauthenticateWithApple() async {
    final user = _auth.currentUser;
    if (user == null) {
      return (
        result: const AuthResult.failed(code: 'no-current-user'),
        authorizationCode: null,
      );
    }

    final native = await _appleReauthViaNativeSdk(user);
    if (native.result.isSuccess ||
        native.result.isCancelled ||
        native.result.code == 'user-mismatch') {
      return native;
    }

    debugPrint('Apple native re-auth failed (${native.result.code}) — trying '
        'the Firebase provider flow');
    final nativeCode = native.result.code ?? 'native-failed';
    try {
      final credential =
          await user.reauthenticateWithProvider(AppleAuthProvider());
      return (
        result: const AuthResult.success(),
        authorizationCode: credential.additionalUserInfo?.authorizationCode,
      );
    } on FirebaseAuthException catch (e) {
      if (_isCancellation(e.code)) {
        return (result: const AuthResult.cancelled(), authorizationCode: null);
      }
      return (
        result: AuthResult.failed(
            code: '$nativeCode then ${e.code}', message: e.message),
        authorizationCode: null,
      );
    } on PlatformException catch (e) {
      if (_isCancellation(e.code)) {
        return (result: const AuthResult.cancelled(), authorizationCode: null);
      }
      return (
        result: AuthResult.failed(
            code: '$nativeCode then ${e.code}', message: e.message),
        authorizationCode: null,
      );
    } catch (e) {
      return (
        result: AuthResult.failed(
            code: '$nativeCode then provider-failed', message: e.toString()),
        authorizationCode: null,
      );
    }
  }

  static Future<({AuthResult result, String? authorizationCode})>
      _appleReauthViaNativeSdk(User user) async {
    try {
      final rawNonce = _generateNonce();
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        // No scopes: Apple only sends name and email on the first
        // authorisation, and confirming identity needs neither.
        scopes: const [],
        nonce: _sha256ofString(rawNonce),
      );
      final identityToken = appleCredential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        return (
          result: const AuthResult.failed(code: 'missing-identity-token'),
          authorizationCode: null,
        );
      }
      await user.reauthenticateWithCredential(
        OAuthProvider('apple.com').credential(
          idToken: identityToken,
          rawNonce: rawNonce,
        ),
      );
      return (
        result: const AuthResult.success(),
        authorizationCode: appleCredential.authorizationCode,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return (result: const AuthResult.cancelled(), authorizationCode: null);
      }
      return (
        result: AuthResult.failed(code: e.code.name, message: e.message),
        authorizationCode: null,
      );
    } on FirebaseAuthException catch (e) {
      return (
        result: AuthResult.failed(code: e.code, message: e.message),
        authorizationCode: null,
      );
    } on PlatformException catch (e) {
      if (_isCancellation(e.code)) {
        return (result: const AuthResult.cancelled(), authorizationCode: null);
      }
      return (
        result: AuthResult.failed(code: e.code, message: e.message),
        authorizationCode: null,
      );
    } catch (e) {
      return (
        result: AuthResult.failed(message: e.toString()),
        authorizationCode: null,
      );
    }
  }

  static Future<AuthResult> _appleViaNativeSdk() async {
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

      // Apple can return a credential with no identity token. Passing that
      // straight to Firebase produces an opaque `invalid-credential` (or, in a
      // release build, the obfuscated "Error: Error") several frames later,
      // with nothing pointing back at the real cause. The Google path has
      // guarded its idToken since it was written; this one never did.
      final identityToken = appleCredential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        debugPrint('Apple Sign-In: identityToken is null — aborting');
        return const AuthResult.failed(code: 'missing-identity-token');
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: identityToken,
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
      return const AuthResult.success();
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        debugPrint('Apple Sign-In: cancelled by user');
        return const AuthResult.cancelled();
      }
      // `unknown` here is usually the app's own configuration, not the user:
      // a missing com.apple.developer.applesignin entitlement in the signed
      // build, or a provisioning profile issued before the capability was
      // enabled on the App ID.
      debugPrint('Apple Sign-In AuthorizationException: ${e.code} ${e.message}');
      return AuthResult.failed(
        code: e.code.name,
        message: e.message,
      );
    } on FirebaseAuthException catch (e) {
      // operation-not-allowed means Apple is not enabled in the Firebase
      // console, which the App ID capability alone does not cover.
      debugPrint('Apple Sign-In FirebaseAuthException: ${e.code} ${e.message}');
      return AuthResult.failed(code: e.code, message: e.message);
    } on PlatformException catch (e) {
      // The Google path has caught this since it was written; this one fell
      // through to the generic handler below, which reports
      // `PlatformException(code, message, ...)` as one unsplittable blob.
      // A bare code is what the person holding the device can actually read
      // back off a screenshot.
      debugPrint('Apple Sign-In PlatformException: ${e.code} - ${e.message}');
      return AuthResult.failed(code: e.code, message: e.message);
    } catch (e) {
      debugPrint('Apple Sign-In ERROR: $e');
      return AuthResult.failed(message: e.toString());
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
    // Deliberately does NOT request notification permission here.
    //
    // iOS shows that prompt exactly once per install. Firing it the instant
    // someone signs in spends it before they have seen a single lesson, and a
    // decline can never be undone from inside the app. It now lives behind
    // NotificationPrimingScreen, shown after the first completed lesson.
  }
}
