import 'package:binary/screens/native_google_auth.dart';
import 'package:binary/firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

class _GooglePlatform extends GoogleSignInPlatform {
  final calls = <String>[];
  String? token = 'identity-token';
  GoogleSignInException? failure;
  bool supported = true;
  String? configuredClientId;

  @override
  Future<void> init(InitParameters params) async {
    calls.add('initialize');
    configuredClientId = params.clientId;
  }

  @override
  bool supportsAuthenticate() => supported;

  @override
  Future<void> signOut(SignOutParams params) async => calls.add('signOut');

  @override
  Future<AuthenticationResults> authenticate(
      AuthenticateParameters params) async {
    calls.add('authenticate');
    expect(params.scopeHint, isEmpty);
    if (failure != null) throw failure!;
    return AuthenticationResults(
      user: const GoogleSignInUserData(
          email: 'learner@example.com', id: 'learner'),
      authenticationTokens: AuthenticationTokenData(idToken: token),
    );
  }

  // Any unexpected authorization/revocation call fails the test.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GoogleSignInPlatform original;
  late _GooglePlatform platform;
  late NativeGoogleAuth auth;
  setUp(() {
    original = GoogleSignInPlatform.instance;
    platform = _GooglePlatform();
    GoogleSignInPlatform.instance = platform;
    auth = NativeGoogleAuth();
  });
  tearDown(() {
    GoogleSignInPlatform.instance = original;
    debugDefaultTargetPlatformOverride = null;
  });

  test('iOS uses Firebase OAuth client even if a bundled plist is stale',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await auth.credential();
    expect(platform.configuredClientId, DefaultFirebaseOptions.ios.iosClientId);
    expect(platform.configuredClientId, isNotNull);
  });

  test('Android does not receive the iOS client identifier', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await auth.credential();
    expect(platform.configuredClientId, isNull);
  });

  test('initializes once and opens a fresh account choice on each attempt',
      () async {
    final credential = await auth.credential();
    expect(credential.providerId, 'google.com');
    expect(credential.idToken, 'identity-token');
    expect(credential.accessToken, isNull);
    await auth.credential();
    expect(platform.calls, [
      'initialize',
      'signOut',
      'authenticate',
      'signOut',
      'authenticate',
    ]);
  });

  test('signing out an email-only session never initializes Google', () async {
    await auth.signOut();
    expect(platform.calls, isEmpty);
  });

  test('Google cleanup uses the initialized SDK', () async {
    await auth.credential();
    await auth.signOut();
    expect(
        platform.calls, ['initialize', 'signOut', 'authenticate', 'signOut']);
  });

  for (final token in <String?>[null, '']) {
    test('rejects a missing or empty identity token ($token)', () async {
      platform.token = token;
      await expectLater(
          auth.credential(),
          throwsA(isA<PlatformException>()
              .having((e) => e.code, 'code', 'missing-id-token')));
    });
  }

  test('cancellation does not open a second sign-in flow', () async {
    platform.failure =
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled);
    try {
      await auth.credential();
      fail('Expected cancellation');
    } on GoogleSignInException catch (error) {
      expect(googleAuthFailure(error).isCancelled, isTrue);
    }
    expect(
        platform.calls.where((call) => call == 'authenticate'), hasLength(1));
    platform.failure = null;
    expect((await auth.credential()).idToken, 'identity-token');
    expect(platform.calls.where((call) => call == 'initialize'), hasLength(1));
  });

  test('native configuration failure becomes an actionable result', () async {
    platform.failure = const GoogleSignInException(
      code: GoogleSignInExceptionCode.clientConfigurationError,
      description: 'Invalid OAuth configuration',
    );
    try {
      await auth.credential();
      fail('Expected configuration failure');
    } on GoogleSignInException catch (error) {
      final result = googleAuthFailure(error);
      expect(result.isFailure, isTrue);
      expect(result.code, 'invalid-oauth-client-id');
      expect(result.displayMessage('Google'), contains('email or as a guest'));
    }
  });

  test('unsupported platforms never attempt to present native UI', () async {
    platform.supported = false;
    await expectLater(
        auth.credential(),
        throwsA(isA<PlatformException>().having((e) => e.code, 'code',
            'operation-not-supported-in-this-environment')));
    expect(platform.calls, ['initialize']);
  });
}
