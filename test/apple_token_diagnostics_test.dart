import 'dart:convert';

import 'package:binary/screens/apple_token_diagnostics.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

String _jwt(Map<String, Object?> claims) {
  String part(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'RS256'})}.${part(claims)}.signature';
}

void main() {
  final now = DateTime.utc(2026, 9, 23, 12);
  final nowSec = now.millisecondsSinceEpoch ~/ 1000;
  const raw = 'raw-nonce-123';
  final hashed = sha256.convert(utf8.encode(raw)).toString();

  Map<String, Object?> good() => {
        'iss': 'https://appleid.apple.com',
        'aud': 'com.cristians.b1nary',
        'exp': nowSec + 600,
        'iat': nowSec - 5,
        'nonce': hashed,
        'sub': '001234.secret-apple-user-id',
        'email': 'person@privaterelay.appleid.com',
      };

  String diag(Map<String, Object?> claims, {String nonce = raw}) =>
      appleTokenDiagnostics(
        idToken: _jwt(claims),
        rawNonce: nonce,
        expectedAudience: 'com.cristians.b1nary',
        now: now,
      );

  test('a healthy token reports every check ok', () {
    expect(diag(good()),
        'token: aud ok, iss ok, exp in 600s, iat 5s ago, nonce ok');
  });

  test('never includes the Apple user id or email', () {
    final out = diag(good());
    expect(out, isNot(contains('001234')));
    expect(out, isNot(contains('privaterelay')));
  });

  test('names a wrong audience', () {
    expect(diag({...good(), 'aud': 'com.example.binary'}),
        contains('aud MISMATCH (com.example.binary)'));
  });

  test('names a nonce that does not match what the app sent', () {
    expect(diag(good(), nonce: 'a-different-nonce'),
        contains('nonce MISMATCH'));
    expect(diag({...good()}..remove('nonce')), contains('nonce missing'));
  });

  test('names an expired token and a token from the future', () {
    expect(diag({...good(), 'exp': nowSec - 30}), contains('EXPIRED 30s ago'));
    expect(diag({...good(), 'iat': nowSec + 400}),
        contains('iat 400s in the FUTURE'));
  });

  test('an unreadable token says so instead of throwing', () {
    expect(
        appleTokenDiagnostics(
            idToken: 'not-a-jwt',
            rawNonce: raw,
            expectedAudience: 'x',
            now: now),
        'token: unreadable');
  });
}
