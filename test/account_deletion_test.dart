/// Tests for choosing how Delete account re-confirms who is asking.
///
/// The screen knew two cases: Google, and "everyone else types a password". A
/// guest has no password, and neither does an account made with Sign in with
/// Apple, so both were shown a password box they could never satisfy — a
/// deletion flow that cannot complete, which is Guideline 5.1.1(v). Guest is
/// also the exact route the App Review notes send the reviewer down.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:binary/screens/account_deletion.dart';

void main() {
  group('an account is never asked for a credential it does not have', () {
    test('a guest is not asked for a password', () {
      // An anonymous Firebase user has no linked providers at all.
      expect(deletionReauthFor(const []), DeletionReauth.none);
    });

    test('an Apple-only account confirms with Apple, not a password', () {
      expect(deletionReauthFor(const ['apple.com']), DeletionReauth.apple);
    });

    test('an unrecognised provider is not asked for a password', () {
      // Asking for a password that does not exist is the bug itself. The
      // deletion is still authorised by the verified ID token server-side.
      expect(deletionReauthFor(const ['phone']), DeletionReauth.none);
    });
  });

  group('each provider confirms with its own sign-in', () {
    test('Google', () {
      expect(deletionReauthFor(const ['google.com']), DeletionReauth.google);
    });

    test('email and password', () {
      expect(deletionReauthFor(const ['password']), DeletionReauth.password);
    });

    test('Google is preferred over typing a password', () {
      expect(deletionReauthFor(const ['password', 'google.com']),
          DeletionReauth.google);
    });
  });

  group('Apple wins whenever it is linked', () {
    // Deleting an account that uses Sign in with Apple must revoke its Apple
    // token, and the authorization code revocation needs only comes from
    // running Apple sign-in again. Any other re-confirmation would delete the
    // account but leave the app listed under the user's Apple ID.
    test('over a password', () {
      expect(deletionReauthFor(const ['password', 'apple.com']),
          DeletionReauth.apple);
    });

    test('over Google', () {
      expect(deletionReauthFor(const ['google.com', 'apple.com']),
          DeletionReauth.apple);
    });
  });
}
