import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Guards against the trap this file already fell into once.
///
/// The real iOS release pipeline lived only in the Codemagic web UI, while
/// `codemagic.yaml` in this repo described something else entirely: a
/// `flutter build ios --release --no-codesign` that produced an unsigned
/// `Runner.app`. An unsigned app can never reach TestFlight, so the committed
/// config was a decoy — reading it gave a confidently wrong picture of how the
/// app ships, and a release cycle was lost to acting on it.
///
/// These tests do not prove a build will succeed; only Codemagic can do that.
/// They prove the committed file still describes a *shippable* pipeline.
void main() {
  late YamlMap config;
  late YamlMap workflows;

  setUpAll(() {
    final file = File('codemagic.yaml');
    expect(file.existsSync(), isTrue,
        reason: 'codemagic.yaml must stay in version control');
    config = loadYaml(file.readAsStringSync()) as YamlMap;
    workflows = config['workflows'] as YamlMap;
  });

  /// Every shell line of a workflow, flattened, so a check cannot be dodged by
  /// moving a command into a different step.
  String scriptText(String workflowId) {
    final steps = (workflows[workflowId] as YamlMap)['scripts'] as YamlList;
    return steps.map((s) => (s as YamlMap)['script'].toString()).join('\n');
  }

  group('release workflow', () {
    const id = 'ios-testflight';

    test('exists', () {
      expect(workflows.keys, contains(id));
    });

    test('never builds unsigned — that is what made the old file a decoy', () {
      expect(scriptText(id), isNot(contains('--no-codesign')));
    });

    test('builds an IPA, not a bare .app', () {
      final text = scriptText(id);
      expect(text, contains('flutter build ipa'));
      expect(text, isNot(contains('flutter build ios ')));
    });

    test('names the signing assets stored in Codemagic', () {
      // The `distribution_type` / `bundle_identifier` form is documented to
      // fetch and create these from Apple per build, but on this account it
      // resolved nothing: two builds failed instantly with "No matching
      // profiles found", while Codemagic's own Fetch dialog listed the exact
      // profile using the same API key. Signing resolves from the stored
      // identities, so the yaml names them.
      final env = (workflows[id] as YamlMap)['environment'] as YamlMap;
      final signing = env['ios_signing'] as YamlMap;

      expect(
        (signing['provisioning_profiles'] as YamlList).toList(),
        ['binary_app_store'],
      );
      expect(
        (signing['certificates'] as YamlList).toList(),
        ['binary_distribution'],
      );
    });

    test('still authenticates to Apple through the integration', () {
      // The stored assets were fetched through this integration and the
      // TestFlight upload still authenticates with it, so losing it breaks
      // both refreshing the profile and publishing.
      final integrations = (workflows[id] as YamlMap)['integrations'] as YamlMap;
      expect(integrations['app_store_connect'], isNotNull);
      expect(scriptText(id), contains('xcode-project use-profiles'));
    });

    test('runs the test suite before building', () {
      final steps = (workflows[id] as YamlMap)['scripts'] as YamlList;
      final scripts = steps.map((s) => (s as YamlMap)['script'].toString()).toList();
      final testStep = scripts.indexWhere((s) => s.contains('flutter test'));
      final buildStep = scripts.indexWhere((s) => s.contains('flutter build ipa'));
      expect(testStep, isNonNegative, reason: 'the release must run its own tests');
      expect(buildStep, isNonNegative);
      expect(testStep, lessThan(buildStep),
          reason: 'a build that fails its tests must not reach a tester');
    });

    test('derives the build number instead of relying on a hand edit', () {
      // App Store Connect rejects a duplicate build number, so a forgotten
      // pubspec bump used to waste a whole build.
      expect(scriptText(id), contains('get-latest-testflight-build-number'));
    });

    test('publishes to TestFlight', () {
      final publishing = (workflows[id] as YamlMap)['publishing'] as YamlMap;
      final asc = publishing['app_store_connect'] as YamlMap;
      expect(asc['submit_to_testflight'], isTrue);
      expect(asc['auth'], 'integration');
    });

    test('keeps the IPA as an artifact', () {
      final artifacts = (workflows[id] as YamlMap)['artifacts'] as YamlList;
      expect(artifacts.any((a) => a.toString().endsWith('.ipa')), isTrue);
    });
  });

  group('verify workflow', () {
    test('analyzes and tests', () {
      final text = scriptText('verify');
      expect(text, contains('flutter analyze'));
      expect(text, contains('flutter test'));
    });

    test('the analyzer gate is strict', () {
      // The tree is clean at zero issues. --no-fatal-infos was a temporary
      // concession while ten info-level lints existed; reintroducing it would
      // let new lints accumulate silently again.
      for (final id in ['verify', 'ios-testflight']) {
        expect(scriptText(id), isNot(contains('--no-fatal-infos')),
            reason: '$id must fail on new lints');
      }
    });
  });

  test('the signed bundle id matches the Xcode project', () {
    // The provisioning profile is issued for one bundle id; Xcode builds
    // whatever PRODUCT_BUNDLE_IDENTIFIER says. If those drift apart the build
    // fails late, on the CI machine, with an unhelpful signing error.
    //
    // The id is no longer written in the yaml — it lives inside the stored
    // profile — so this asserts against the id that profile was fetched for.
    final pbxproj =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(
      pbxproj,
      contains('PRODUCT_BUNDLE_IDENTIFIER = com.cristians.b1nary;'),
    );

    // And the vars the build scripts read must agree with it.
    final env = (workflows['ios-testflight'] as YamlMap)['environment'] as YamlMap;
    expect((env['vars'] as YamlMap)['BUNDLE_ID'], 'com.cristians.b1nary');
  });

  test('the entitlements file still declares Sign In with Apple', () {
    // Guideline 4.8 requires it because the app offers Google Sign-In, and
    // Apple Review has already flagged its absence once. It is also the reason
    // the App ID must have the capability enabled — removing this file to make
    // a build pass would trade a build failure for a review rejection.
    final entitlements =
        File('ios/Runner/Runner.entitlements').readAsStringSync();
    expect(entitlements, contains('com.apple.developer.applesignin'));
  });
}
