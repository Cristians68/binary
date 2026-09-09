/// Tests for telling "the user backed out" apart from "it broke".
///
/// This became load-bearing when the sign-in paths grew fallbacks. Google on
/// iOS now tries Firebase's OAuth flow first (the only way to send
/// `prompt=select_account`, which is what makes the account chooser appear)
/// and falls back to the native SDK. Apple tries the native SDK first and falls
/// back to Firebase's flow, which needs no Sign In with Apple entitlement.
///
/// Both chains advance on failure. Firebase's web-context flow reports a
/// cancellation as an *error*, so if a cancellation were read as a failure,
/// backing out of the first sheet would immediately raise a second one the user
/// never asked for. A cancellation has to stop the chain.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:binary/screens/auth_result.dart';

void main() {
  group('a cancellation stops the fallback chain', () {
    test('recognises the codes Firebase iOS uses when a sheet is dismissed', () {
      // Both spellings: Firebase is inconsistent between platforms and
      // versions, and guessing wrong here re-prompts a real user.
      for (final code in [
        'web-context-canceled',
        'web-context-cancelled',
        'user-canceled',
        'user-cancelled',
        'canceled',
        'cancelled',
      ]) {
        expect(isCancellationCode(code), isTrue, reason: code);
      }
    });

    test('recognises the web popup codes', () {
      expect(isCancellationCode('popup-closed-by-user'), isTrue);
      expect(isCancellationCode('cancelled-popup-request'), isTrue);
    });

    test('recognises the Android abort code', () {
      expect(isCancellationCode('ERROR_ABORTED_BY_USER'), isTrue);
    });
  });

  group('a real failure does NOT stop the chain', () {
    test('configuration failures are not cancellations', () {
      // If any of these were treated as a cancellation, the fallback would
      // never run and the user would be stuck with the broken flow — which is
      // the situation the fallbacks exist to escape.
      for (final code in [
        'operation-not-allowed',
        'invalid-credential',
        'missing-identity-token',
        'account-exists-with-different-credential',
        'network-request-failed',
        'internal-error',
        'unknown',
      ]) {
        expect(isCancellationCode(code), isFalse, reason: code);
      }
    });

    test('an unknown code is treated as a failure, not a cancellation', () {
      // Failing over is recoverable; silently swallowing a real error is not.
      expect(isCancellationCode('some-code-nobody-has-seen'), isFalse);
    });

    test('null and empty are not cancellations', () {
      expect(isCancellationCode(null), isFalse);
      expect(isCancellationCode(''), isFalse);
    });

    test('matching is exact, not substring', () {
      // 'cancelled' is a substring of several unrelated codes.
      expect(isCancellationCode('operation-cancelled-by-server'), isFalse);
      expect(isCancellationCode('CANCELLED'), isFalse,
          reason: 'codes are case-sensitive; a loose match risks false hits');
    });
  });

  group('AuthResult routes the outcomes the chains branch on', () {
    test('a cancelled result is not a failure', () {
      const result = AuthResult.cancelled();
      expect(result.isCancelled, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.isSuccess, isFalse);
    });

    test('a failure carries the code the fallback logs and reports', () {
      const result = AuthResult.failed(code: 'operation-not-allowed');
      expect(result.isFailure, isTrue);
      expect(result.code, 'operation-not-allowed');
      expect(result.displayMessage('Apple'), contains('operation-not-allowed'));
    });

    test('a two-stage failure can report both codes at once', () {
      // When the native Apple flow AND the provider fallback both fail, which
      // code matters depends on which layer actually broke, so both ship.
      const result = AuthResult.failed(code: 'unknown then invalid-credential');
      final shown = result.displayMessage('Apple');
      expect(shown, contains('unknown'));
      expect(shown, contains('invalid-credential'));
    });
  });
}
