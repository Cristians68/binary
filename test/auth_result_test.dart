/// A cancelled sign-in is not a failed one.
///
/// Every sign-in method used to return `UserCredential?` and swallow its
/// exception, so backing out of the Apple sheet and a misconfigured provider
/// were the same value: null. The UI showed "Apple sign-in failed. Please try
/// again." for both — which made the app look broken every time somebody
/// changed their mind, and gave no clue at all when it really was broken.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:binary/screens/auth_result.dart';

void main() {
  group('outcomes are distinguishable', () {
    test('success, cancelled and failed are all different', () {
      expect(const AuthResult.success().isSuccess, isTrue);
      expect(const AuthResult.success().isCancelled, isFalse);
      expect(const AuthResult.success().isFailure, isFalse);

      expect(const AuthResult.cancelled().isCancelled, isTrue);
      expect(const AuthResult.cancelled().isSuccess, isFalse);
      // The whole point: a cancellation must not read as a failure.
      expect(const AuthResult.cancelled().isFailure, isFalse);

      expect(const AuthResult.failed(code: 'x').isFailure, isTrue);
      expect(const AuthResult.failed(code: 'x').isSuccess, isFalse);
    });
  });

  group('displayMessage', () {
    test('carries the provider code so a screenshot is diagnosable', () {
      // This app ships through TestFlight, where debugPrint goes nowhere the
      // user can read. The code on screen is the only diagnostic available.
      final msg = const AuthResult.failed(
        code: 'operation-not-allowed',
        message: 'Apple sign-in is not enabled for this project.',
      ).displayMessage('Apple');

      expect(msg, contains('Apple'));
      expect(msg, contains('operation-not-allowed'));
      expect(msg, contains('email or as a guest'));
    });

    test('names the provider that failed', () {
      expect(
        const AuthResult.failed(code: 'network-error').displayMessage('Google'),
        startsWith('Google sign-in failed'),
      );
    });

    test('falls back to a plain sentence when there is no detail', () {
      expect(
        const AuthResult.failed().displayMessage('Apple'),
        'Apple sign-in failed. Please try again.',
      );
    });

    test('a message with no code still reaches the user', () {
      final msg = const AuthResult.failed(message: 'Network unreachable')
          .displayMessage('Google');
      expect(msg, contains('Network unreachable'));
    });

    test('an empty code is treated as absent, not printed as ()', () {
      final msg = const AuthResult.failed(code: '', message: '')
          .displayMessage('Apple');
      expect(msg, 'Apple sign-in failed. Please try again.');
      expect(msg, isNot(contains('()')));
    });
  });
}
