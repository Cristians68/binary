/// Every Apple sign-in failure must say how far it got and which build it
/// came from.
///
/// The owner reported that the `token:` line never appeared. It only existed
/// after Firebase rejected a token Apple had returned, so a failure anywhere
/// earlier — or a build that predated the line — looked identical: no line.
/// These drive the real [AuthService.signInWithApple] through each stage.
library;

import 'dart:convert';
import 'dart:io';

import 'package:binary/firebase_options.dart';
import 'package:binary/screens/apple_sign_in_support.dart';
import 'package:binary/screens/auth_result.dart';
import 'package:binary/screens/auth_service.dart';
import 'package:binary/screens/build_identity.dart';
import 'package:binary/screens/service_backend.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _revision = '1f534b9d6c0a2e4f8b7a1c3d5e7f9a0b2c4d6e8f';

/// Rejects every credential the way Firebase rejected the owner's.
class _RejectingAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) =>
      throw FirebaseAuthException(
          code: 'invalid-credential',
          message: 'Invalid OAuth response from apple.com');
}

String _jwt(Map<String, dynamic> claims) {
  String part(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'RS256'})}.${part(claims)}.sig';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const apple = MethodChannel('org.binaryapp/apple-auth');
  const buildInfo = MethodChannel('org.binaryapp/build-info');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(buildInfo, (call) async {
      expect(call.method, 'read');
      return {'version': '1.0.3', 'build': '57', 'revision': _revision};
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(apple, null);
    messenger.setMockMethodCallHandler(buildInfo, null);
    ServiceBackend.reset();
  });

  group('signInWithApple support details', () {
    test('Apple refusing the request reports the sheet stage and the build',
        () async {
      messenger.setMockMethodCallHandler(
          apple,
          (_) async => throw PlatformException(
              code: 'apple-authorization-1000',
              message: 'The operation couldn’t be completed.',
              details: 'com.apple.AuthenticationServices.AuthorizationError '
                  '1000'));

      final result = await AuthService.signInWithApple();

      expect(result.isFailure, isTrue);
      final details = result.supportDetails!;
      expect(details, contains('stage: apple-sheet'));
      expect(details, contains('build: 1.0.3 (57) @ 1f534b9'));
      expect(details, contains('code: apple-authorization-1000'));
      expect(details, contains('AuthorizationError 1000'));
      expect(details, contains('token: none received'));
    });

    test('an incomplete Apple credential reports the token stage', () async {
      messenger.setMockMethodCallHandler(
          apple, (_) async => {'authorizationCode': 'code'});

      final result = await AuthService.signInWithApple();

      expect(result.supportDetails, contains('stage: apple-token'));
      expect(result.supportDetails, contains('code: missing-identity-token'));
      expect(result.supportDetails, contains('token: none received'));
    });

    test('a Firebase rejection reports the firebase stage with the token check',
        () async {
      ServiceBackend.useAuth(_RejectingAuth());
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      messenger.setMockMethodCallHandler(apple, (call) async {
        final hashedNonce = (call.arguments as Map)['nonce'] as String;
        return {
          'identityToken': _jwt({
            'aud': DefaultFirebaseOptions.ios.iosBundleId,
            'iss': 'https://appleid.apple.com',
            'exp': now + 600,
            'iat': now,
            'nonce': hashedNonce,
            'sub': 'apple-user-id',
            'email': 'someone@example.com',
          }),
          'authorizationCode': 'code',
          'userIdentifier': 'apple-user-id',
        };
      });

      final result = await AuthService.signInWithApple();

      expect(result.code, 'invalid-credential');
      final details = result.supportDetails!;
      expect(details, contains('stage: firebase'));
      expect(details, contains('build: 1.0.3 (57) @ 1f534b9'));
      expect(details, contains('token: aud ok, iss ok'));
      expect(details, contains('nonce ok'));
      // Never the Apple user id or email.
      expect(details, isNot(contains('apple-user-id')));
      expect(details, isNot(contains('someone@example.com')));
      // And it reaches the clipboard with the visible message.
      expect(result.supportText('Apple'),
          startsWith('Apple sign-in failed: Invalid OAuth response'));
      expect(result.supportText('Apple'), endsWith(details));
    });

    test('a cancellation carries no support details and is not a failure',
        () async {
      messenger.setMockMethodCallHandler(
          apple, (_) async => throw PlatformException(code: 'canceled'));

      final result = await AuthService.signInWithApple();

      expect(result.isCancelled, isTrue);
      expect(result.supportDetails, isNull);
    });
  });

  group('BuildIdentity', () {
    test('reads the stamped Info.plist values over the channel', () async {
      expect(
          await BuildIdentity.load(),
          const BuildIdentity(
              version: '1.0.3', build: '57', revision: _revision));
    });

    test('an unstamped build says so instead of dropping the revision', () {
      expect(BuildIdentity.fromMap({'version': '1.0.3', 'build': '9'})
          .describe(), '1.0.3 (9) @ unstamped');
      expect(BuildIdentity.unknown.describe(), '? (?) @ unstamped');
    });

    test('a broken bridge degrades to unknown rather than throwing', () async {
      messenger.setMockMethodCallHandler(
          buildInfo, (_) async => throw PlatformException(code: 'boom'));
      expect(await BuildIdentity.load(), BuildIdentity.unknown);
    });

    test('is not attempted off iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(await BuildIdentity.load(), BuildIdentity.unknown);
    });
  });

  test('support details without a token check name the missing token', () {
    final text = appleSupportDetails(
        stage: AppleSignInStage.starting, build: BuildIdentity.unknown);
    expect(text.split('\n'),
        ['stage: starting', 'build: ? (?) @ unstamped', 'token: none received']);
  });

  test('AuthResult.supportText is just the message when there are no details',
      () {
    const result = AuthResult.failed(code: 'x');
    expect(result.supportText('Apple'), result.displayMessage('Apple'));
  });

  /// No Swift runs on Windows, so the only check available is that both
  /// sides spell the channel, method and keys the same way — and that the key
  /// Runner reads is the one Codemagic actually stamps.
  test('Runner answers the build-info channel with the stamped revision', () {
    final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(swift, contains('"org.binaryapp/build-info"'));
    expect(swift, contains('call.method == "read"'));
    for (final key in ['version', 'build', 'revision']) {
      expect(swift, contains('values["$key"]'));
    }
    expect(swift, contains('info["BinarySourceRevision"]'));
    expect(File('tools/ios/verify_release.py').readAsStringSync(),
        contains('"BinarySourceRevision": revision'),
        reason: 'the release stamp must write the key Runner reads');
  });
}
