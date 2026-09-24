import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Guards against native iOS terminations that no Dart handler can see.
///
/// A Swift trap — a force-unwrapped nil, `try!`, `as!`, `fatalError` — is not
/// an NSException and not a Dart error. The process simply dies, and before
/// Crashlytics it died without a trace. That is how the Google sign-in crash
/// survived five audits: google_sign_in_ios 6.3.3 handed a nil presenter to a
/// Swift API that cannot take one. These tests read the real files.
void main() {
  test('google_sign_in_ios cannot resolve below the nil-presenter fix', () {
    final lock = loadYaml(File('pubspec.lock').readAsStringSync()) as YamlMap;
    final resolved =
        (lock['packages'] as YamlMap)['google_sign_in_ios']['version'] as String;
    expect(_atLeast(resolved, const [6, 3, 5]), isTrue,
        reason: '6.3.3 traps on a nil presenter; 6.3.5 returns an error');

    // The lock is honoured by `pub get`, but the constraint is what a
    // `pub downgrade` or a regenerated lock falls back to.
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final constraint =
        (pubspec['dependencies'] as YamlMap)['google_sign_in_ios'] as String;
    final floor = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(constraint)!;
    expect(_atLeast(floor.group(0)!, const [6, 3, 5]), isTrue,
        reason: 'pubspec.yaml still allows the crashing $constraint');
  });

  test('Runner Swift sources contain no trapping operations', () {
    final sources = Directory('ios/Runner')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.swift'))
        .toList();
    expect(sources, isNotEmpty, reason: 'the scan must actually read Swift');

    final traps = <String>[];
    for (final file in sources) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        // `x!` / `x)!` / `x]!` but not `!=` and not prefix negation `!x`.
        if (RegExp(r'[\w\)\]]!(?!=)').hasMatch(code) ||
            RegExp(r'\btry!|\bas!|\bfatalError\(').hasMatch(code)) {
          traps.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(traps, isEmpty,
        reason: 'A Swift trap terminates the app with no catchable error');
  });

  test('Info.plist explains every protected API the photo picker links', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    for (final key in [
      'NSPhotoLibraryUsageDescription',
      'NSCameraUsageDescription',
      // local_auth: using Face ID without this string terminates the app.
      'NSFaceIDUsageDescription',
    ]) {
      final value = RegExp('<key>$key</key>\\s*<string>([^<]*)</string>')
          .firstMatch(plist)
          ?.group(1);
      expect(value?.trim(), isNotEmpty,
          reason: '$key missing: App Store upload is rejected (ITMS-90683) '
              'and a permission request without it terminates the app');
    }
  });
}

bool _atLeast(String version, List<int> minimum) {
  final parts = version.split('.').map(int.parse).toList();
  for (var i = 0; i < minimum.length; i++) {
    if (parts[i] != minimum[i]) return parts[i] > minimum[i];
  }
  return true;
}
