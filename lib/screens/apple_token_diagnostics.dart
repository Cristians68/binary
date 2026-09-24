import 'dart:convert';

import 'package:crypto/crypto.dart';

/// A one-line, privacy-safe reading of an Apple identity token, attached to
/// an Apple sign-in failure so "Copy details for support" says WHY Firebase
/// rejected it.
///
/// Firebase answers every rejection with the same "Invalid OAuth response
/// from apple.com (invalid-credential)". The usual causes are all visible in
/// the token itself: the wrong audience (bundle id), a nonce that doesn't
/// match the one the app sent, or a device clock far enough off that the
/// token looks expired or not yet issued.
///
/// Reads only aud, iss, exp, iat and nonce. Never the Apple user id (`sub`)
/// or the email.
String appleTokenDiagnostics({
  required String idToken,
  required String rawNonce,
  required String expectedAudience,
  required DateTime now,
}) {
  final Map<String, dynamic> claims;
  try {
    final parts = idToken.split('.');
    if (parts.length != 3) return 'token: unreadable';
    claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
        as Map<String, dynamic>;
  } catch (_) {
    return 'token: unreadable';
  }

  final nowSec = now.millisecondsSinceEpoch ~/ 1000;
  final out = <String>[];

  final aud = claims['aud'];
  out.add(aud == expectedAudience ? 'aud ok' : 'aud MISMATCH ($aud)');

  final iss = claims['iss'];
  out.add(iss == 'https://appleid.apple.com' ? 'iss ok' : 'iss MISMATCH ($iss)');

  final exp = claims['exp'];
  if (exp is num) {
    final left = exp.toInt() - nowSec;
    out.add(left > 0 ? 'exp in ${left}s' : 'EXPIRED ${-left}s ago');
  } else {
    out.add('exp missing');
  }

  final iat = claims['iat'];
  if (iat is num) {
    final age = nowSec - iat.toInt();
    out.add(age >= 0 ? 'iat ${age}s ago' : 'iat ${-age}s in the FUTURE');
  } else {
    out.add('iat missing');
  }

  final nonce = claims['nonce'];
  if (nonce is! String) {
    out.add('nonce missing');
  } else {
    final expected = sha256.convert(utf8.encode(rawNonce)).toString();
    out.add(nonce == expected ? 'nonce ok' : 'nonce MISMATCH');
  }

  return 'token: ${out.join(', ')}';
}
