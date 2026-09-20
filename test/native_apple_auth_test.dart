import 'package:binary/screens/native_apple_auth.dart';
import 'package:binary/screens/auth_result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('org.binaryapp/apple-auth');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('native bridge carries the hashed nonce and returns a full credential',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'signIn');
      expect(call.arguments, {'nonce': 'hashed-nonce', 'requestProfile': true});
      return {
        'identityToken': 'identity',
        'authorizationCode': 'code',
        'givenName': 'Ada'
      };
    });
    final credential = await NativeAppleAuth.getCredential(
        scopes: [AppleIDAuthorizationScopes.email], nonce: 'hashed-nonce');
    expect(credential.identityToken, 'identity');
    expect(credential.authorizationCode, 'code');
    expect(credential.givenName, 'Ada');
  });
  test('reauthentication does not ask Apple to share the profile again',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.arguments['requestProfile'], isFalse);
      return {'identityToken': 'identity', 'authorizationCode': 'code'};
    });
    await NativeAppleAuth.getCredential(scopes: [], nonce: 'hash');
  });
  test('missing identity tokens fail before Firebase receives a credential',
      () async {
    messenger.setMockMethodCallHandler(
        channel, (_) async => {'authorizationCode': 'code'});
    await expectLater(
        NativeAppleAuth.getCredential(scopes: [], nonce: 'hash'),
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'missing-identity-token')));
  });
  test('native cancellation remains distinguishable from provider failure',
      () async {
    messenger.setMockMethodCallHandler(
        channel, (_) async => throw PlatformException(code: 'canceled'));
    try {
      await NativeAppleAuth.getCredential(scopes: [], nonce: 'hash');
      fail('Expected cancellation');
    } on PlatformException catch (error) {
      expect(isCancellationCode(error.code), isTrue);
    }
    expect(isCancellationCode('sign_in_canceled'), isTrue);
    expect(isCancellationCode('apple-authorization-1000'), isFalse);
  });
}
