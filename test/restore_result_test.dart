/// Tests for the four outcomes a "Restore purchases" tap can have.
///
/// `SubscriptionService.restore()` used to return a bare bool, so three
/// distinct situations collapsed into `false` — a store error, a network
/// failure, and an Apple ID that genuinely owns nothing — and all three were
/// reported as "No previous purchases found on this Apple ID". That is a
/// factual claim the app had not established, and it sends a paying customer
/// to support believing their receipt is gone.
///
/// The fourth state could not be expressed at all: entitlements are written to
/// Firestore by the RevenueCat webhook, never by the client, so the store can
/// confirm an active purchase while the account still has no plan. The old code
/// returned `true` for that, closed the paywall, and dropped the user back onto
/// content they still could not open.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:binary/screens/restore_result.dart';

void main() {
  group('isApplied is the only gate that may close a paywall', () {
    test('is true for a restore that actually granted access', () {
      expect(const RestoreResult.applied().isApplied, isTrue);
    });

    test('is false for a purchase found but not yet activated', () {
      // This is the regression. Closing on this outcome is what left the user
      // staring at locked content with no explanation.
      expect(const RestoreResult.pending().isApplied, isFalse);
    });

    test('is false when there was nothing to restore', () {
      expect(const RestoreResult.nothing().isApplied, isFalse);
    });

    test('is false when the restore call itself failed', () {
      expect(const RestoreResult.failed().isApplied, isFalse);
    });
  });

  group('each outcome says something different', () {
    test('no two outcomes share a message', () {
      final messages = [
        const RestoreResult.applied().displayMessage,
        const RestoreResult.pending().displayMessage,
        const RestoreResult.nothing().displayMessage,
        const RestoreResult.failed().displayMessage,
      ];
      expect(messages.toSet().length, messages.length,
          reason: 'two outcomes reading identically is the bug being fixed');
    });

    test('only "nothing to restore" claims no purchase exists', () {
      // The specific false claim the old code made on every failure.
      const phrase = 'No previous purchases were found';
      expect(const RestoreResult.nothing().displayMessage, contains(phrase));
      for (final other in [
        const RestoreResult.applied(),
        const RestoreResult.pending(),
        const RestoreResult.failed(),
      ]) {
        expect(other.displayMessage, isNot(contains(phrase)),
            reason: '${other.outcome} must not tell the user their purchase '
                'does not exist — it has not established that');
      }
    });

    test('a pending activation is not phrased as a failure', () {
      final result = const RestoreResult.pending();
      expect(result.title, 'Purchase Found');
      expect(result.displayMessage, contains('found your purchase'));
      expect(result.title.toLowerCase(), isNot(contains('fail')));
    });

    test('every outcome has a distinct title', () {
      final titles = [
        const RestoreResult.applied().title,
        const RestoreResult.pending().title,
        const RestoreResult.nothing().title,
        const RestoreResult.failed().title,
      ];
      expect(titles.toSet().length, titles.length);
    });
  });

  group('a failure carries the store\'s own code to the screen', () {
    // Same reasoning as AuthResult: the person hitting the bug ships no logs,
    // so a screenshot of the dialog has to be enough to diagnose it.
    test('the code is shown when there is one', () {
      const result = RestoreResult.failed(
        code: 'STORE_PROBLEM',
        message: 'The App Store could not be reached',
      );
      expect(result.displayMessage, contains('STORE_PROBLEM'));
      expect(result.displayMessage, contains('The App Store could not be reached'));
    });

    test('a bare failure still reads as a sentence', () {
      final message = const RestoreResult.failed().displayMessage;
      expect(message, isNotEmpty);
      expect(message, contains('Could not reach the App Store'));
      expect(message, isNot(contains('()')),
          reason: 'an empty code must not leave stray brackets on screen');
    });

    test('a code with no message still surfaces the code', () {
      const result = RestoreResult.failed(code: 'PURCHASE_INVALID');
      expect(result.displayMessage, contains('PURCHASE_INVALID'));
    });
  });

  group('outcome predicates', () {
    test('each result reports exactly one of the four states', () {
      final results = {
        const RestoreResult.applied(): [true, false, false, false],
        const RestoreResult.pending(): [false, true, false, false],
        const RestoreResult.nothing(): [false, false, true, false],
        const RestoreResult.failed(): [false, false, false, true],
      };
      results.forEach((result, expected) {
        expect(
          [
            result.isApplied,
            result.isPending,
            result.foundNothing,
            result.isFailure,
          ],
          expected,
          reason: '${result.outcome} reported the wrong predicate set',
        );
      });
    });
  });
}
