import 'package:flutter/foundation.dart';

import 'notification_schedule.dart';

/// The seam between [NotificationService] and `flutter_local_notifications`.
///
/// Mirrors [ServiceBackend] in `service_backend.dart`. The plugin talks to the
/// platform over a method channel, so every call throws
/// `MissingPluginException` in a unit test and nothing about scheduling could
/// be asserted. Routing the four operations the app actually uses through this
/// interface lets a test record them instead.
///
/// Production behaviour is unchanged: with no override installed,
/// [NotificationService] drives the real plugin exactly as before.
abstract class NotificationBackend {
  /// Schedule [reminder] to repeat, replacing any notification with its id.
  Future<void> schedule(ScheduledReminder reminder);

  /// Cancel the notification with [id], whether or not one exists.
  Future<void> cancel(int id);

  /// Show a notification immediately.
  Future<void> show(int id, String title, String body, {String? payload});
}

/// Records calls instead of making them. Tests only.
@visibleForTesting
class FakeNotificationBackend implements NotificationBackend {
  final List<ScheduledReminder> scheduled = [];
  final List<int> cancelled = [];
  final List<({int id, String title, String body, String? payload})> shown = [];

  /// What the device would actually be holding, replayed in call order.
  ///
  /// Order matters and a set difference cannot express it: `applyPrefs`
  /// cancels every managed id and then re-schedules the enabled ones, so an id
  /// that appears in both [cancelled] and [scheduled] is live or dead purely
  /// according to which call came last.
  final Map<int, ScheduledReminder> live = {};

  /// Ids currently scheduled on the device.
  Set<int> get liveIds => live.keys.toSet();

  @override
  Future<void> schedule(ScheduledReminder reminder) async {
    scheduled.add(reminder);
    live[reminder.id] = reminder;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    live.remove(id);
  }

  @override
  Future<void> show(int id, String title, String body, {String? payload}) async {
    shown.add((id: id, title: title, body: body, payload: payload));
  }

  void clear() {
    scheduled.clear();
    cancelled.clear();
    shown.clear();
    live.clear();
  }
}

/// Holds the backend [NotificationService] writes through.
class NotificationBackendHolder {
  NotificationBackendHolder._();

  static NotificationBackend? _override;

  /// The installed fake, or null in production.
  static NotificationBackend? get current => _override;

  @visibleForTesting
  static void useFake(NotificationBackend backend) => _override = backend;

  @visibleForTesting
  static void reset() => _override = null;
}
