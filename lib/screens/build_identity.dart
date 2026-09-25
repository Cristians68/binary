import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Which build is actually installed.
///
/// A device report is worthless until you know the build it came from: builds
/// 50–55 were all cut from a stale `master`, and a "fix that didn't work" was
/// really a fix that was never installed. Codemagic stamps the full Git
/// revision into Info.plist as `BinarySourceRevision`
/// (`tools/ios/verify_release.py --stamp`); Runner reads it back over
/// [_channel] so a copied error names its own commit.
@immutable
class BuildIdentity {
  const BuildIdentity({this.version, this.build, this.revision});

  static const unknown = BuildIdentity();

  static const _channel = MethodChannel('org.binaryapp/build-info');

  final String? version;
  final String? build;

  /// Full 40-character Git revision, or null for a local/unstamped build.
  final String? revision;

  /// Never throws and never waits long: this runs inside error handling,
  /// where a second failure would hide the first.
  static Future<BuildIdentity> load() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return unknown;
    try {
      final info = await _channel
          .invokeMapMethod<String, dynamic>('read')
          .timeout(const Duration(seconds: 2));
      return fromMap(info);
    } catch (_) {
      return unknown;
    }
  }

  @visibleForTesting
  static BuildIdentity fromMap(Map<String, dynamic>? info) {
    String? text(String key) {
      final value = info?[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    return BuildIdentity(
      version: text('version'),
      build: text('build'),
      revision: text('revision'),
    );
  }

  /// `1.0.3 (57) @ 1f534b9`. Missing parts say so rather than being dropped,
  /// so "unstamped" is distinguishable from "didn't look".
  String describe() {
    final short = revision == null
        ? 'unstamped'
        : revision!.substring(0, revision!.length < 7 ? revision!.length : 7);
    return '${version ?? '?'} (${build ?? '?'}) @ $short';
  }

  @override
  bool operator ==(Object other) =>
      other is BuildIdentity &&
      other.version == version &&
      other.build == build &&
      other.revision == revision;

  @override
  int get hashCode => Object.hash(version, build, revision);
}
