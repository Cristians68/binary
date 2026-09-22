import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Reporting for the failures a Dart zone cannot see.
///
/// A Swift `fatalError`, an uncaught `NSException` or a signal terminates the
/// iOS process outright. `runZonedGuarded` in `main()` never runs, no Flutter
/// error handler fires, and the app simply closes to the home screen. The only
/// record is a `.ips` file the tester has to find under Settings → Privacy &
/// Security → Analytics & Improvements and export by hand.
///
/// That is exactly how a Google sign-in crash survived five release cycles
/// without ever being identified: every audit ended by asking for a crash
/// report that never arrived. Crashlytics installs a *native* handler, so the
/// next native termination uploads itself, symbolicated, with the breadcrumb
/// trail below attached — including the last stage the sign-in reached.
///
/// Nothing here runs on web: `firebase_crashlytics` has no web implementation,
/// and touching `FirebaseCrashlytics.instance` there throws.
class CrashReporting {
  const CrashReporting._();

  static bool _active = false;

  /// Whether reports are being collected. False on web, in debug, in tests,
  /// and before [install] has run — [trail] and [recordFatal] then no-op, so
  /// neither needs a Firebase app to exist.
  static bool get isActive => _active;

  /// Route Dart's error channels into the same report as native crashes.
  ///
  /// [collectionEnabled] defaults to "not a debug build" so a developer's
  /// laptop does not file reports, while TestFlight and the App Store do.
  static Future<void> install({bool? collectionEnabled}) async {
    if (kIsWeb) return;
    try {
      await _install(collectionEnabled ?? !kDebugMode);
    } catch (error) {
      // Diagnostics must never be the reason the app fails to start. If
      // Crashlytics cannot initialize, the app launches without it.
      _active = false;
      debugPrint('Crash reporting unavailable: $error');
    }
  }

  static Future<void> _install(bool enabled) async {
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(enabled);
    _active = enabled;
    if (!enabled) return;

    // Framework errors: keep the normal red-screen/console behaviour as well,
    // so nothing that was visible before becomes invisible now.
    final presentError = FlutterError.onError;
    FlutterError.onError = (details) {
      presentError?.call(details);
      crashlytics.recordFlutterError(details);
    };
    // Errors that escape to the engine, which no zone wraps.
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// Record an error that reached the last-resort zone handler in `main()`.
  static Future<void> recordFatal(Object error, StackTrace stack) async {
    if (!_active) return;
    try {
      await FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {
      // Swallowed deliberately. This runs from the last-resort zone handler in
      // main(); letting it throw would re-enter that same handler and loop.
    }
  }

  /// Leave a breadcrumb that survives a *native* termination.
  ///
  /// These are the only thing that distinguishes "died while presenting the
  /// Google sheet" from "died while exchanging the identity token" when the
  /// process is killed and no Dart code gets to run again.
  static void trail(String message) {
    if (!_active) return;
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (_) {
      // A breadcrumb is never worth failing the sign-in it is describing.
    }
  }
}
