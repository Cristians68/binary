import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'notification_prefs.dart';
import 'notification_prefs_service.dart';
import 'streak_service.dart';

/// Reminders and daily goal, as controls that actually do something.
///
/// The sheet this replaces had one real master switch above three rows that
/// rendered a static "On"/"Off" pill from a hardcoded literal. They looked
/// like settings and were connected to nothing — flipping the master switch
/// wrote `notificationsEnabled` to Firestore and never scheduled or cancelled
/// a single notification.
///
/// Every control here writes through [NotificationPrefsService.save], which
/// persists the preference and then calls `NotificationService.applyPrefs` to
/// make the device match.
class NotificationSettingsSheet extends StatefulWidget {
  const NotificationSettingsSheet({super.key, this.onChanged});

  /// Called with the new preferences after every change, so the caller can
  /// update the "On"/"Off" badge it shows next to the Notifications row.
  final ValueChanged<NotificationPrefs>? onChanged;

  static Future<void> show(
    BuildContext context, {
    ValueChanged<NotificationPrefs>? onChanged,
  }) {
    final theme = AppTheme.of(context);
    return showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => NotificationSettingsSheet(onChanged: onChanged),
    );
  }

  @override
  State<NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<NotificationSettingsSheet> {
  NotificationPrefs _prefs = NotificationPrefs.defaults;
  int _dailyTarget = 50;
  bool _loading = true;

  /// Daily goal targets, in points. A lesson is 10 and a passed quiz 20, so
  /// these read as roughly two, three, five, eight and ten activities a day.
  static const List<int> _targets = [20, 30, 50, 80, 100];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await NotificationPrefsService.load();
    final stats = await StreakService.fetchAll();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _dailyTarget = stats.goal.target;
      _loading = false;
    });
  }

  Future<void> _update(NotificationPrefs next) async {
    HapticFeedback.selectionClick();
    setState(() => _prefs = next);
    await NotificationPrefsService.save(next);
    widget.onChanged?.call(next);
  }

  Future<void> _setTarget(int target) async {
    HapticFeedback.selectionClick();
    setState(() => _dailyTarget = target);
    // setDailyTarget was dead code: nothing in the app called it, so the goal
    // ring was pinned to the 50-point default for every user.
    await StreakService.setDailyTarget(target);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _prefs.reminderHour,
        minute: _prefs.reminderMinute,
      ),
    );
    if (picked == null) return;
    await _update(_prefs.copyWith(
      reminderHour: picked.hour,
      reminderMinute: picked.minute,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final time = TimeOfDay(
      hour: _prefs.reminderHour,
      minute: _prefs.reminderMinute,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.subtext.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _master(theme),
                const SizedBox(height: 20),
                _card(theme, [
                  _switchRow(
                    theme,
                    '🔥',
                    'Daily streak reminder',
                    'One nudge a day so a streak never lapses',
                    _prefs.streakReminder,
                    (v) => _update(_prefs.copyWith(streakReminder: v)),
                  ),
                  _divider(theme),
                  _switchRow(
                    theme,
                    '🎯',
                    'Daily goal check-in',
                    'An earlier prompt if the goal is still unmet',
                    _prefs.dailyGoal,
                    (v) => _update(_prefs.copyWith(dailyGoal: v)),
                  ),
                  _divider(theme),
                  _switchRow(
                    theme,
                    '📚',
                    'New content available',
                    'Weekly, when new lessons land',
                    _prefs.newContent,
                    (v) => _update(_prefs.copyWith(newContent: v)),
                  ),
                ]),
                const SizedBox(height: 20),
                _card(theme, [
                  _tappableRow(
                    theme,
                    '⏰',
                    'Reminder time',
                    time.format(context),
                    _prefs.master ? _pickTime : null,
                  ),
                ]),
                const SizedBox(height: 20),
                _targetPicker(theme),
              ],
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: theme.border,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Done',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: theme.subtext,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _master(ThemeNotifier theme) => Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(CupertinoIcons.bell_fill,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reminders',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.text)),
                Text('Turn everything off in one place',
                    style: TextStyle(fontSize: 12, color: theme.subtext)),
              ],
            ),
          ),
          CupertinoSwitch(
            value: _prefs.master,
            activeTrackColor: AppColors.primary,
            onChanged: (v) => _update(_prefs.copyWith(master: v)),
          ),
        ],
      );

  Widget _card(ThemeNotifier theme, List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.border),
        ),
        child: Column(children: children),
      );

  Widget _divider(ThemeNotifier theme) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(height: 1, color: theme.border.withValues(alpha: 0.6)),
      );

  Widget _switchRow(
    ThemeNotifier theme,
    String emoji,
    String label,
    String detail,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    // Greyed out rather than hidden when the master is off, so it stays
    // obvious why nothing is arriving.
    final enabled = _prefs.master;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 14, color: theme.text)),
                const SizedBox(height: 2),
                Text(detail,
                    style: TextStyle(fontSize: 11.5, color: theme.subtext)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CupertinoSwitch(
            value: value && enabled,
            activeTrackColor: AppColors.primary,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }

  Widget _tappableRow(
    ThemeNotifier theme,
    String emoji,
    String label,
    String value,
    VoidCallback? onTap,
  ) =>
      Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 14, color: theme.text)),
              ),
              Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
              const SizedBox(width: 4),
              Icon(CupertinoIcons.chevron_right,
                  size: 14, color: theme.subtext),
            ],
          ),
        ),
      );

  Widget _targetPicker(ThemeNotifier theme) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Daily goal',
                      style: TextStyle(fontSize: 14, color: theme.text)),
                ),
                Text('$_dailyTarget pts',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 6),
            Text('A lesson is 10 points, a passed quiz is 20.',
                style: TextStyle(fontSize: 11.5, color: theme.subtext)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                for (final t in _targets)
                  GestureDetector(
                    onTap: () => _setTarget(t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: t == _dailyTarget
                            ? AppColors.primary
                            : theme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: t == _dailyTarget
                              ? AppColors.primary
                              : theme.border,
                        ),
                      ),
                      child: Text(
                        '$t',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              t == _dailyTarget ? Colors.white : theme.text,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
}
