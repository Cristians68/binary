import 'dart:async';

import 'package:binary/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// `kReleaseMode` is false under `flutter test`, so the release branch of the
/// logging setup can never run here. Taking the mode as an argument is what
/// makes it reachable — without that, this file could only assert the debug
/// behaviour and would pass no matter what release did.
void main() {
  test('release gets a printer that emits nothing', () {
    final printed = <String?>[];
    final silent = debugPrintFor(true);

    // Capture whatever the returned callback writes. print() inside a zone is
    // the only thing debugPrintThrottled ultimately calls.
    runZoned(
      () => silent('Google Sign-In: got user someone@example.com'),
      zoneSpecification: ZoneSpecification(
        print: (_, __, ___, line) => printed.add(line),
      ),
    );

    expect(printed, isEmpty,
        reason: 'A release build must not write the signed-in user to the '
            'device log.');
  });

  test('debug keeps the real printer, so development still logs', () {
    expect(debugPrintFor(false), same(debugPrintThrottled));
  });

  test('the two modes do not get the same printer', () {
    // The failure this guards is debugPrintFor ignoring its argument, which
    // would leave both tests above passing against one shared implementation.
    expect(debugPrintFor(true), isNot(same(debugPrintFor(false))));
  });
}
