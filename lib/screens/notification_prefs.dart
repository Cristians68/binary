import 'dart:convert';

/// Which reminders a user wants, and when.
///
/// The notifications sheet in `profile_screen.dart` used to render one real
/// master switch above three rows that were passed a hardcoded `true`. They
/// looked like controls and were connected to nothing. This is the state those
/// rows now read and write.
///
/// Stored at `users/{uid}.notificationPrefs` as a nested map, and mirrored into
/// SharedPreferences so scheduling can run at app start before Firestore
/// resolves. The legacy `notificationsEnabled` boolean is still written
/// alongside it, because the Cloud Functions read that field.
class NotificationPrefs {
  /// Master switch. When false nothing is scheduled, whatever the rest say.
  final bool master;

  final bool streakReminder;
  final bool dailyGoal;
  final bool newContent;

  /// Local time of day for the daily reminders, 0–23 and 0–59.
  final int reminderHour;
  final int reminderMinute;

  const NotificationPrefs({
    this.master = true,
    this.streakReminder = true,
    this.dailyGoal = true,
    this.newContent = true,
    this.reminderHour = 20,
    this.reminderMinute = 0,
  });

  static const NotificationPrefs defaults = NotificationPrefs();

  /// True when at least one reminder would actually be scheduled.
  ///
  /// Used to decide whether to write the `usesLocalReminders` flag that stops
  /// the server sending a duplicate.
  bool get anySchedulable =>
      master && (streakReminder || dailyGoal || newContent);

  NotificationPrefs copyWith({
    bool? master,
    bool? streakReminder,
    bool? dailyGoal,
    bool? newContent,
    int? reminderHour,
    int? reminderMinute,
  }) =>
      NotificationPrefs(
        master: master ?? this.master,
        streakReminder: streakReminder ?? this.streakReminder,
        dailyGoal: dailyGoal ?? this.dailyGoal,
        newContent: newContent ?? this.newContent,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
      );

  /// Read preferences out of a user document.
  ///
  /// [legacyEnabled] is the old top-level `notificationsEnabled` boolean. It is
  /// used for [master] only when no `notificationPrefs` map exists yet, so a
  /// user who turned notifications off before this feature shipped stays off.
  factory NotificationPrefs.fromMap(
    Map<String, dynamic>? map, {
    bool? legacyEnabled,
  }) {
    if (map == null || map.isEmpty) {
      return NotificationPrefs(master: legacyEnabled ?? true);
    }
    bool flag(String key, bool fallback) {
      final v = map[key];
      return v is bool ? v : fallback;
    }

    return NotificationPrefs(
      master: flag('master', legacyEnabled ?? true),
      streakReminder: flag('streakReminder', true),
      dailyGoal: flag('dailyGoal', true),
      newContent: flag('newContent', true),
      reminderHour: _clamp(map['reminderHour'], 0, 23, 20),
      reminderMinute: _clamp(map['reminderMinute'], 0, 59, 0),
    );
  }

  Map<String, Object?> toMap() => {
        'master': master,
        'streakReminder': streakReminder,
        'dailyGoal': dailyGoal,
        'newContent': newContent,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
      };

  String toJson() => jsonEncode(toMap());

  factory NotificationPrefs.fromJson(String? source) {
    if (source == null || source.isEmpty) return defaults;
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) return defaults;
      return NotificationPrefs.fromMap(
        decoded.map((k, v) => MapEntry(k.toString(), v)),
      );
    } catch (_) {
      return defaults;
    }
  }

  /// Coerce a stored value into range.
  ///
  /// A corrupt or out-of-range hour would otherwise reach `zonedSchedule` and
  /// throw, taking every reminder down with it.
  static int _clamp(Object? value, int min, int max, int fallback) {
    final n = value is num ? value.toInt() : null;
    if (n == null) return fallback;
    if (n < min || n > max) return fallback;
    return n;
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationPrefs &&
      other.master == master &&
      other.streakReminder == streakReminder &&
      other.dailyGoal == dailyGoal &&
      other.newContent == newContent &&
      other.reminderHour == reminderHour &&
      other.reminderMinute == reminderMinute;

  @override
  int get hashCode => Object.hash(master, streakReminder, dailyGoal, newContent,
      reminderHour, reminderMinute);

  @override
  String toString() => 'NotificationPrefs(${toMap()})';
}
