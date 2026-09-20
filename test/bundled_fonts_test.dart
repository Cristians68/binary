import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every Inter weight the UI asks for must ship in the bundle.
///
/// `GoogleFonts.config.allowRuntimeFetching = false` in main.dart means a
/// weight that is not bundled no longer quietly downloads itself from
/// fonts.gstatic.com — it fails, and the text renders in the fallback face.
/// That trade is only safe while the bundle actually covers what the code
/// uses, and nothing about adding `FontWeight.w300` to a widget would tell
/// anyone it had stopped being covered.
///
/// So this reads the real weights out of `lib/` and the real files out of
/// `google_fonts/`. It is deliberately not a list of weights written down by
/// hand, because a hand-written list drifts from the UI the moment someone
/// styles a heading.
void main() {
  // google_fonts resolves a bundled asset by matching the end of its path
  // against '<Family>-<WeightName>', so these names are a contract with the
  // package, not a preference. See google_fonts_variant.dart.
  const weightFileNames = <String, String>{
    'w100': 'Thin',
    'w200': 'ExtraLight',
    'w300': 'Light',
    'w400': 'Regular',
    'w500': 'Medium',
    'w600': 'SemiBold',
    'w700': 'Bold',
    'w800': 'ExtraBold',
    'w900': 'Black',
  };

  Set<String> weightsUsedInLib() {
    final used = <String>{};
    final pattern = RegExp(r'FontWeight\.(w[1-9]00|bold|normal)');
    for (final entry in Directory('lib').listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      for (final match in pattern.allMatches(entry.readAsStringSync())) {
        final name = match.group(1)!;
        used.add(switch (name) {
          'bold' => 'w700',
          'normal' => 'w400',
          _ => name,
        });
      }
    }
    return used;
  }

  test('every weight the UI uses is bundled as an Inter file', () {
    final bundled = Directory('google_fonts')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toSet();

    final missing = <String>[];
    for (final weight in weightsUsedInLib()) {
      final suffix = weightFileNames[weight]!;
      final present = bundled.any(
          (f) => f == 'Inter-$suffix.otf' || f == 'Inter-$suffix.ttf');
      if (!present) missing.add('FontWeight.$weight -> Inter-$suffix');
    }

    expect(
      missing,
      isEmpty,
      reason: 'These weights are used in lib/ but are not in google_fonts/. '
          'With allowRuntimeFetching off they will render in the fallback '
          'font rather than downloading. Add the file, or stop using the '
          'weight.',
    );
  });

  test('the UI uses at least one weight, so the check above can fail', () {
    // Guards the case that makes the first test meaningless: if the scan ever
    // returns nothing — a moved lib/, a changed constructor spelling — then
    // "no weight is missing" is true for the wrong reason.
    expect(weightsUsedInLib(), isNotEmpty);
  });

  test('pubspec ships the font folder', () {
    // The files existing on disk proves nothing if they are not an asset.
    expect(File('pubspec.yaml').readAsStringSync(), contains('google_fonts/'));
  });
}
