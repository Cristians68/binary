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
import 'apple_profile_name.dart';
import 'apple_sign_in_support.dart';
import 'apple_token_diagnostics.dart';
import 'build_identity.dart';
import '../firebase_options.dart';
import 'native_apple_auth.dart';
import 'native_google_auth.dart';
import 'service_backend.dart';
import '../crash_reporting.dart';

class AuthService {
  static FirebaseAuth get _auth => ServiceBackend.auth;

  static final _googleSignIn = NativeGoogleAuth();

  /// See [isCancellationCode] in auth_result.dart for why this matters to the
  /// fallback chains below.
  static bool _isCancellation(String? code) => isCancellationCode(code);

  static Future<void> signOut() async {
    await ServiceBackend.userStreams.transition(() async {
      if (!kIsWeb) {
        try {
          await _googleSignIn.signOut();
        } catch (e) {
          debugPrint('Google sign-out cleanup failed: $e');
        }
      }
      await _auth.signOut();
    });
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
        final result = await _signInOrLinkProvider(provider);
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

    // Firebase documents the native Google SDK + OAuth credential flow for
    // iOS and Android. The generic provider redirect added another sheet and
    // depended on different OAuth configuration.
    try {
      final credential = await _googleSignIn.credential();
      CrashReporting.trail('google: exchanging credential with Firebase');
      final userCredential = await _signInOrLink(credential);
      debugPrint(
          'Google Sign-In: Firebase success uid=${userCredential.user?.uid}');
      CrashReporting.trail('google: signed in, running post-sign-in work');
      await _onSignInSuccess();
      CrashReporting.trail('google: complete');
      return const AuthResult.success();
    } on GoogleSignInException catch (e) {
      return googleAuthFailure(e);
    } on PlatformException catch (e) {
      if (_isCancellation(e.code)) return const AuthResult.cancelled();
      debugPrint('Google Sign-In PlatformException: ${e.code} - ${e.message}');
      return AuthResult.failed(code: e.code, message: e.message);
    } on FirebaseAuthException catch (e) {
      if (_isCancellation(e.code)) return const AuthResult.cancelled();
      debugPrint(
          'Google Sign-In FirebaseAuthException: ${e.code} - ${e.message}');
      return AuthResult.failed(code: e.code, message: e.message);
    } catch (e, stack) {
      debugPrint('Google Sign-In ERROR: $e');
      debugPrint('Stack: $stack');
      return AuthResult.failed(message: e.toString());
    }
  }

  static Future<AuthResult> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) return const AuthResult.failed(code: 'no-current-user');
    try {
      if (kIsWeb) {
        await user.reauthenticateWithPopup(
          GoogleAuthProvider()
            ..setCustomParameters({'prompt': 'select_account'}),
        );
      } else {
        await user
            .reauthenticateWithCredential(await _googleSignIn.credential());
      }
      return const AuthResult.success();
    } on GoogleSignInException catch (e) {
      return googleAuthFailure(e);
    } on FirebaseAuthException catch (e) {
      if (_isCancellation(e.code)) return const AuthResult.cancelled();
      return AuthResult.failed(code: e.code, message: e.message);
    } on PlatformException catch (e) {
      if (_isCancellation(e.code)) return const AuthResult.cancelled();
      return AuthResult.failed(code: e.code, message: e.message);
    } catch (e) {
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
      debugPrint(
          'Apple provider FirebaseAuthException: ${e.code} ${e.message}');
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
        return kIsWeb
            ? await current.linkWithPopup(provider)
            : await current.linkWithProvider(provider);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'credential-already-in-use' &&
            e.code != 'email-already-in-use') {
          rethrow;
        }
        debugPrint('Guest link failed (${e.code}) - signing in to the '
            'existing account instead');
      }
    }
    Future<UserCredential> signIn() => kIsWeb
        ? _auth.signInWithPopup(provider)
        : _auth.signInWithProvider(provider);
    return current == null
        ? signIn()
        : ServiceBackend.userStreams.transition(signIn);
  }

  /// Sign in with an OAuth credential, upgrading a guest session in place.
  ///
  /// If the current user is anonymous, linking keeps the SAME uid, so the
  /// streak, progress and any purchase they made as a guest survive. Plain
  /// signInWithCredential would mint a new uid and silently orphan all of it.
  static Future<UserCredential> _signInOrLink(AuthCredential credential) async {
    final current = _auth.currentUser;
    var signInCredential = credential;
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
        signInCredential = credentialForExistingAccount(e, credential);
      }
    }
    return current == null
        ? _auth.signInWithCredential(signInCredential)
        : ServiceBackend.userStreams
            .transition(() => _auth.signInWithCredential(signInCredential));
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
  /// Returns a failed AuthResult on failure. The most likely code is `operation-not-allowed`,
  /// which means Anonymous sign-in is not enabled in the Firebase console under
  /// Authentication -> Sign-in method.
  static Future<AuthResult> signInAsGuest() async {
    try {
      // The welcome screen also serves restored guests. Reuse their identity
      // rather than replacing it, and never downgrade a registered session.
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }
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
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;

  // ── Sign in with Apple ────────────────────────────────────────────────────

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Apple uses Firebase popups on web, the provider flow on Android, and
  /// a scene-anchored native sheet on Apple platforms.
  static Future<AuthResult> signInWithApple() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
      return _appleViaFirebaseProvider();
    }
    return _appleViaNativeSdk();
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

    final native = kIsWeb || defaultTargetPlatform == TargetPlatform.android
        ? (
            result: const AuthResult.failed(code: 'provider-required'),
            authorizationCode: null
          )
        : await _appleReauthViaNativeSdk(user);
    if (native.result.isSuccess ||
        native.result.isCancelled ||
        native.result.code == 'user-mismatch') {
      return native;
    }

    debugPrint('Apple native re-auth failed (${native.result.code}) — trying '
        'the Firebase provider flow');
    final nativeCode = native.result.code ?? 'native-failed';
    try {
      final credential = kIsWeb
          ? await user.reauthenticateWithPopup(AppleAuthProvider())
          : await user.reauthenticateWithProvider(AppleAuthProvider());
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
      final appleCredential = await NativeAppleAuth.getCredential(
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
    // Kept outside the try so any failure can say how far it got, and a
    // Firebase rejection can be diagnosed from the token Apple actually
    // returned. See apple_sign_in_support.dart and apple_token_diagnostics.dart.
    var stage = AppleSignInStage.starting;
    String? diagToken;
    String? diagNonce;

    Future<AuthResult> fail(String? code, String? message,
        {Object? nativeDetails}) async {
      final tokenCheck = diagToken == null || diagNonce == null
          ? null
          : appleTokenDiagnostics(
              idToken: diagToken,
              rawNonce: diagNonce,
              expectedAudience:
                  DefaultFirebaseOptions.ios.iosBundleId ?? 'unknown',
              now: DateTime.now(),
            );
      return AuthResult.failed(
        code: code,
        message: message,
        supportDetails: appleSupportDetails(
          stage: stage,
          build: await BuildIdentity.load(),
          code: code,
          nativeDetails: nativeDetails,
          tokenCheck: tokenCheck,
        ),
      );
    }

    try {
      final rawNonce = _generateNonce();
      diagNonce = rawNonce;
      final nonce = _sha256ofString(rawNonce);

      stage = AppleSignInStage.appleSheet;
      final appleCredential = await NativeAppleAuth.getCredential(
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
      stage = AppleSignInStage.appleToken;
      final identityToken = appleCredential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        debugPrint('Apple Sign-In: identityToken is null — aborting');
        return await fail('missing-identity-token', null);
      }
      diagToken = identityToken;

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: identityToken,
        rawNonce: rawNonce,
      );

      // Apple only sends the name on the very first authorisation, so keep it
      // on the device BEFORE Firebase can fail — see [AppleNameStore].
      final appleUserId = appleCredential.userIdentifier;
      var fullName =
          appleFullName(appleCredential.givenName, appleCredential.familyName);
      if (fullName != null && appleUserId != null) {
        await AppleNameStore.remember(appleUserId, fullName);
      }

      stage = AppleSignInStage.firebase;
      final userCredential = await _signInOrLink(oauthCredential);

      stage = AppleSignInStage.profile;
      if (fullName == null && appleUserId != null) {
        fullName = await AppleNameStore.recall(appleUserId);
      }
      final user = userCredential.user;
      if (fullName != null &&
          user != null &&
          (user.displayName?.trim().isEmpty ?? true)) {
        try {
          await user
              .updateDisplayName(fullName)
              .timeout(const Duration(seconds: 8));
          if (appleUserId != null) await AppleNameStore.forget(appleUserId);
        } catch (error) {
          debugPrint('Apple profile name update deferred: $error');
        }
      }

      await _onSignInSuccess(displayName: fullName);
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
      debugPrint(
          'Apple Sign-In AuthorizationException: ${e.code} ${e.message}');
      return fail(e.code.name, e.message);
    } on FirebaseAuthException catch (e) {
      // operation-not-allowed means Apple is not enabled in the Firebase
      // console, which the App ID capability alone does not cover.
      debugPrint('Apple Sign-In FirebaseAuthException: ${e.code} ${e.message}');
      return fail(e.code, e.message);
    } on PlatformException catch (e) {
      if (_isCancellation(e.code)) return const AuthResult.cancelled();
      // The bridge rejects an incomplete credential itself, before this
      // method's own token check can run; report it at the same stage.
      if (e.code == 'missing-identity-token') {
        stage = AppleSignInStage.appleToken;
      }
      // The Google path has caught this since it was written; this one fell
      // through to the generic handler below, which reports
      // `PlatformException(code, message, ...)` as one unsplittable blob.
      // A bare code is what the person holding the device can actually read
      // back off a screenshot.
      debugPrint('Apple Sign-In PlatformException: ${e.code} - ${e.message}');
      return fail(e.code, e.message, nativeDetails: e.details);
    } catch (e) {
      debugPrint('Apple Sign-In ERROR: $e');
      return fail(null, e.toString());
    }
  }

  static Future<void> _onSignInSuccess({String? displayName}) async {
    // FIRST: make sure users/{uid} exists. Only email/password signup created
    // it, so a Google or Apple user used to reach the home screen with no
    // document, and everything that writes to it had to survive that.
    try {
      await ensureUserDocument(
        displayName: _auth.currentUser?.displayName ?? displayName,
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('ensureUserDocument error: $e');
    }
    try {
      await SubscriptionService.identifyUser()
          .timeout(const Duration(seconds: 8));
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
