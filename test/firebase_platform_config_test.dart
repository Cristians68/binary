import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the per-platform Firebase/Google configuration that no Dart test
/// otherwise touches, because it lives in native build files.
///
/// `google-services.json` shipped for months naming `com.example.binary` — the
/// Flutter template default — while the app has shipped as
/// `com.cristians.b1nary` since before the first TestFlight build. The
/// `com.google.gms.google-services` Gradle plugin is applied, and it fails the
/// build outright with "No matching client found for package name" when the
/// two disagree. Nothing caught it because Android is not built in CI.
///
/// These tests read the real files. They prove the committed configuration is
/// self-consistent; they cannot prove the Firebase console agrees with it.
void main() {
  String readFile(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path must stay in the repo');
    return file.readAsStringSync();
  }

  test('google-services.json names the package the app actually ships as', () {
    final gradle = readFile('android/app/build.gradle.kts');
    final applicationId =
        RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(gradle)?.group(1);
    expect(applicationId, isNotNull,
        reason: 'applicationId must stay readable in build.gradle.kts');

    final services =
        jsonDecode(readFile('android/app/google-services.json')) as Map;
    final packages = [
      for (final client in services['client'] as List)
        ((client as Map)['client_info'] as Map)['android_client_info']
            ['package_name'] as String,
    ];
    expect(packages, contains(applicationId),
        reason: 'The google-services Gradle plugin fails the Android build '
            'when no client matches applicationId $applicationId');
  });

  test('the Android Firebase app id matches firebase_options.dart', () {
    final services =
        jsonDecode(readFile('android/app/google-services.json')) as Map;
    final appIds = [
      for (final client in services['client'] as List)
        ((client as Map)['client_info'] as Map)['mobilesdk_app_id'] as String,
    ];
    final options = readFile('lib/firebase_options.dart');
    final android = RegExp(
            r'static const FirebaseOptions android = FirebaseOptions\(([\s\S]*?)\);')
        .firstMatch(options)
        ?.group(1);
    expect(android, isNotNull);
    final appId =
        RegExp(r"appId:\s*'([^']+)'").firstMatch(android!)?.group(1);
    expect(appIds, contains(appId));
  });

  test('the iOS OAuth client is registered as a callback URL scheme', () {
    // A callback scheme the native Google SDK expects but Info.plist does not
    // register is a native, uncatchable termination on iOS — not a Dart error.
    final options = readFile('lib/firebase_options.dart');
    final ios = RegExp(
            r'static const FirebaseOptions ios = FirebaseOptions\(([\s\S]*?)\);')
        .firstMatch(options)!
        .group(1)!;
    final clientId =
        RegExp(r"iosClientId:\s*'([^']+)'").firstMatch(ios)!.group(1)!;
    final appId = RegExp(r"appId:\s*'([^']+)'").firstMatch(ios)!.group(1)!;

    final info = readFile('ios/Runner/Info.plist');
    final reversed = clientId.split('.').reversed.join('.');
    expect(info, contains('<string>$reversed</string>'),
        reason: 'Google callback scheme missing from Info.plist');
    expect(info, contains('<string>app-${appId.replaceAll(':', '-')}</string>'),
        reason: 'Firebase fallback callback scheme missing from Info.plist');
    expect(info, contains('<string>$clientId</string>'),
        reason: 'GIDClientID must match the Firebase iOS OAuth client');
  });
}
