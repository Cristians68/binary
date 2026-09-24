import 'package:binary/screens/apple_profile_name.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('appleFullName', () {
    test('joins the parts Apple sent', () {
      expect(appleFullName('Ada', 'Lovelace'), 'Ada Lovelace');
      expect(appleFullName('Ada', null), 'Ada');
      expect(appleFullName(null, 'Lovelace'), 'Lovelace');
    });
    test('is null when Apple sent nothing usable', () {
      expect(appleFullName(null, null), isNull);
      expect(appleFullName('  ', ''), isNull);
    });
  });

  group('AppleNameStore', () {
    // Apple sends the name exactly once per Apple ID per app. If the Firebase
    // step after it fails, the name must survive to the next attempt, or the
    // account is named "there" forever.
    test('a name remembered before a failed attempt is recalled on the next',
        () async {
      await AppleNameStore.remember('apple-user-1', 'Ada Lovelace');
      expect(await AppleNameStore.recall('apple-user-1'), 'Ada Lovelace');
    });
    test('never hands one Apple ID the name of another', () async {
      await AppleNameStore.remember('apple-user-1', 'Ada Lovelace');
      expect(await AppleNameStore.recall('apple-user-2'), isNull);
    });
    test('is gone once the name has been applied', () async {
      await AppleNameStore.remember('apple-user-1', 'Ada Lovelace');
      await AppleNameStore.forget('apple-user-1');
      expect(await AppleNameStore.recall('apple-user-1'), isNull);
    });
  });

  group('credentialForExistingAccount', () {
    final original = OAuthProvider('apple.com')
        .credential(idToken: 'used-token', rawNonce: 'nonce');

    // An Apple identity token is single-use: Firebase rejects the one the
    // failed link already consumed with "Duplicate credential received".
    test('uses the replacement credential Firebase returns', () {
      final replacement =
          OAuthProvider('apple.com').credential(idToken: 'fresh-token');
      final error = FirebaseAuthException(
          code: 'credential-already-in-use', credential: replacement);
      expect(credentialForExistingAccount(error, original),
          same(replacement));
    });
    test('falls back to the original when none is supplied', () {
      final error = FirebaseAuthException(code: 'email-already-in-use');
      expect(credentialForExistingAccount(error, original), same(original));
    });
  });
}
