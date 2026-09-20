import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// iOS needs a presentation anchor from the active scene. The pinned Apple
/// plugin does not supply one; Runner's coordinator owns that responsibility.
class NativeAppleAuth {
  static const _channel = MethodChannel('org.binaryapp/apple-auth');

  static Future<AuthorizationCredentialAppleID> getCredential({
    required List<AppleIDAuthorizationScopes> scopes,
    required String nonce,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return SignInWithApple.getAppleIDCredential(scopes: scopes, nonce: nonce);
    }
    final result = await _channel.invokeMapMethod<String, dynamic>('signIn', {
      'nonce': nonce,
      'requestProfile': scopes.isNotEmpty,
    });
    final token = result?['identityToken'];
    final code = result?['authorizationCode'];
    if (token is! String || token.isEmpty || code is! String || code.isEmpty) {
      throw PlatformException(
          code: 'missing-identity-token',
          message:
              'Apple did not return a complete credential. Please try again.');
    }
    return AuthorizationCredentialAppleID(
      userIdentifier: result?['userIdentifier'] as String?,
      givenName: result?['givenName'] as String?,
      familyName: result?['familyName'] as String?,
      email: result?['email'] as String?,
      identityToken: token,
      authorizationCode: code,
      state: null,
    );
  }
}
