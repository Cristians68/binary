import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Wall-clock time anchored to the Firestore server rather than the device.
///
/// The streak used to be computed from `DateTime.now()`. That made every
/// streak and every streak badge farmable by moving the device clock forward,
/// and corrupted honest users' streaks when they travelled across timezones.
///
/// This calibrates once per session: it writes a `serverTimestamp()` sentinel,
/// reads back the value the server resolved it to, and keeps the difference
/// between that and the device clock. [now] is then device time plus that
/// offset, which costs nothing on subsequent calls.
///
/// **If calibration fails, [now] throws and callers must not write a streak.**
/// There is deliberately no fall back to `DateTime.now()`, because that
/// fallback is the exploit: anyone wanting to farm days need only break the
/// calibration read. [StreakService] treats an uncalibrated clock as "skip the
/// streak update this time" — the day is not lost, it is just not counted
/// until the app can reach the server.
///
/// The accepted cost is that advancing a streak requires connectivity. It
/// happens once per day, in an app that already cannot read its user document
/// offline.
class ServerClock {
  ServerClock._();

  static Duration? _offset;

  /// Whether [now] can be called.
  static bool get isCalibrated => _offset != null;

  /// The current time according to the server.
  ///
  /// Throws [StateError] when the clock has not been calibrated. Callers that
  /// can tolerate skipping should check [isCalibrated] first.
  static DateTime now() {
    final offset = _offset;
    if (offset == null) {
      throw StateError(
        'ServerClock.now() before calibrate(). Streak writes must be skipped '
        'rather than fall back to device time.',
      );
    }
    return DateTime.now().add(offset);
  }

  /// Measure the offset between the device clock and the server clock.
  ///
  /// Returns true when [now] is usable afterwards. Safe to call repeatedly;
  /// a later successful calibration replaces an earlier one.
  ///
  /// [doc] is written with a single non-entitlement field, so a write that
  /// creates the document still satisfies the `noEntitlementsOnCreate()`
  /// Firestore rule.
  static Future<bool> calibrate(
    DocumentReference<Map<String, dynamic>> doc,
  ) async {
    try {
      final before = DateTime.now();
      await doc.set(
        {'lastSeenAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      // Must come from the server: the local cache would hand back our own
      // unresolved sentinel, or a stale value, and calibrate against nothing.
      final snap = await doc.get(const GetOptions(source: Source.server));
      final after = DateTime.now();

      final resolved = snap.data()?['lastSeenAt'];
      if (resolved is! Timestamp) return false;

      // The server stamped the write at some instant between `before` and
      // `after`. The midpoint is the best estimate available and is accurate
      // to well under the round trip, which is far finer than the day
      // granularity anything here needs.
      final midpoint = before.add(
        Duration(
          microseconds: after.difference(before).inMicroseconds ~/ 2,
        ),
      );
      _offset = resolved.toDate().difference(midpoint);
      return true;
    } catch (e) {
      debugPrint('ServerClock.calibrate failed: $e');
      return false;
    }
  }

  /// Drive the clock directly. Tests only.
  @visibleForTesting
  static void useOffset(Duration offset) => _offset = offset;

  /// Forget any calibration, returning [isCalibrated] to false.
  @visibleForTesting
  static void reset() => _offset = null;
}
