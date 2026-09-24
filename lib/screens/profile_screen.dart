import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:image_picker/image_picker.dart';
import 'profile_avatar.dart';
import 'profile_photo.dart';
import 'app_lock.dart';
import 'auth_service.dart';
import 'sign_out.dart';
import 'badges_screen.dart';
import 'certificates_screen.dart';
import 'offline_downloads_screen.dart';
import 'delete_account_screen.dart';
import 'legal_screen.dart';
import 'restore_purchases_button.dart';
import 'paywall_screen.dart';
import 'app_router.dart';
import 'streak_service.dart';
import '../app_links.dart';
import 'app_theme.dart';
import 'notification_prefs_service.dart';
import 'notification_settings_sheet.dart';
import 'welcome_screen.dart';
import 'streak_logic.dart';

Map<String, dynamic> _toMap(dynamic value) {
  if (value == null) return {};
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return {};
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  int _lessonCount = 0;
  int _badgeCount = 0;
  int _streak = 0;
  String _avgScore = '-';
  bool _notificationsEnabled = true;
  bool _appLockOn = false;
  bool _loadingNotifPref = true;

  StreamSubscription<Map<String, dynamic>>? _statsSub;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    _listenToStats();
    _loadNotifPref();
    AppLockSettings.isEnabled().then((on) {
      if (mounted) setState(() => _appLockOn = on);
    });
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Stats for the header row.
  ///
  /// This was a one-shot getStats() in initState. MainNavigation builds every
  /// tab in an IndexedStack at launch, so it ran before the user had done
  /// anything and never ran again: finish a lesson, open Profile, and it still
  /// read 0. Home already listened to this same stream, which is how the two
  /// tabs came to show different numbers for one account.
  void _listenToStats() {
    _statsSub = StreakService.statsStream().listen(
      _onStatsUpdate,
      onError: (Object error) => debugPrint('Profile stats: $error'),
    );
  }

  void _onStatsUpdate(Map<String, dynamic> data) {
    if (!mounted) return;
    // Only ids the badges grid displays — see knownEarnedBadges.
    final badges = knownEarnedBadges(_toMap(data['badges']).keys).length;
    final lessons = (data['completedLessons'] as List<dynamic>?)?.length ?? 0;
    final rawScores = data['quizScores'];
    List<Map<String, dynamic>> scores = [];
    if (rawScores is List) {
      scores = rawScores
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    String avg = '-';
    if (scores.isNotEmpty) {
      final a = scores.fold<double>(
              0, (s, e) => s + ((e['score'] as num?) ?? 0).toDouble()) /
          scores.length;
      avg = '${a.toStringAsFixed(0)}%';
    }
    final streakMap = _toMap(data['streak']);
    setState(() {
      _lessonCount = lessons;
      _badgeCount = badges;
      _streak = (streakMap['current'] as num?)?.toInt() ?? 0;
      _avgScore = avg;
    });
  }

  Future<void> _loadNotifPref() async {
    // Reads notificationPrefs.master, falling back to the legacy
    // notificationsEnabled boolean for accounts that predate the sheet.
    final prefs = await NotificationPrefsService.load();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.master;
      _loadingNotifPref = false;
    });
  }

  String _getFullName() =>
      FirebaseAuth.instance.currentUser?.displayName ?? 'IT Learner';
  String _getEmail() => FirebaseAuth.instance.currentUser?.email ?? '';
  String _getInitials() {
    final name = _getFullName();
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  // ── Help Center — opens support page in Safari ────────────────────────────
  Future<void> _openHelpCenter() async {
    HapticFeedback.selectionClick();
    final uri = Uri.parse(kSupportUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) _showToast('Visit binaryapp.org/support for help.');
    }
  }

  // ── Feedback sheet ─────────────────────────────────────────────────────────
  void _showFeedbackSheet() {
    final theme = AppTheme.of(context);
    final controller = TextEditingController();
    int selectedStars = 0;
    bool submitted = false;
    bool loading = false;

    HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          if (submitted) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 56),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.checkmark_circle_fill,
                        color: AppColors.green, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text('Thanks for your feedback!',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.text,
                          letterSpacing: -0.4)),
                  const SizedBox(height: 8),
                  Text('We read every message and use it to improve B1nary.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, color: theme.subtext, height: 1.5)),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(16)),
                      child: const Text('Done',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
                24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: theme.subtext.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(CupertinoIcons.chat_bubble_text_fill,
                          color: AppColors.amber, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Send feedback',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: theme.text,
                                letterSpacing: -0.4)),
                        Text('We\'d love to hear from you',
                            style:
                                TextStyle(fontSize: 13, color: theme.subtext)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('How would you rate B1nary?',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.text)),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(5, (i) {
                    final filled = i < selectedStars;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setModal(() => selectedStars = i + 1);
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          filled
                              ? CupertinoIcons.star_fill
                              : CupertinoIcons.star,
                          color: filled
                              ? AppColors.amber
                              : theme.subtext.withValues(alpha: 0.4),
                          size: 32,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                Text('Your message',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.text)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.border),
                  ),
                  child: TextField(
                    controller: controller,
                    maxLines: 4,
                    style: TextStyle(color: theme.text, fontSize: 15),
                    decoration: InputDecoration(
                      hintText:
                          'Tell us what you love, what could be better, or anything else...',
                      hintStyle: TextStyle(
                          color: theme.subtext.withValues(alpha: 0.6),
                          fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: loading
                      ? null
                      : () async {
                          if (controller.text.trim().isEmpty &&
                              selectedStars == 0) {
                            _showToast('Please add a rating or message.');
                            return;
                          }
                          setModal(() => loading = true);
                          HapticFeedback.mediumImpact();
                          try {
                            final uid =
                                FirebaseAuth.instance.currentUser?.uid ?? '';
                            await FirebaseFirestore.instance
                                .collection('feedback')
                                .add({
                              'uid': uid,
                              'stars': selectedStars,
                              'message': controller.text.trim(),
                              'createdAt': FieldValue.serverTimestamp(),
                              'appVersion': '1.0.0',
                            });
                          } catch (_) {}
                          if (selectedStars >= 4) {
                            final inAppReview = InAppReview.instance;
                            if (await inAppReview.isAvailable()) {
                              await inAppReview.requestReview();
                            }
                          }
                          setModal(() {
                            loading = false;
                            submitted = true;
                          });
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: loading
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: loading
                        ? const Center(
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2)))
                        : const Text('Send feedback',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── App Lock ───────────────────────────────────────────────────────────────
  // Opt-in. Turning it on runs one Face ID/passcode check, which is also when
  // iOS asks to allow Face ID; a decline leaves it off.
  Future<void> _toggleAppLock() async {
    final want = !_appLockOn;
    final ok = await AppLockSettings.setEnabled(want);
    if (!mounted) return;
    if (ok) {
      setState(() => _appLockOn = want);
      _showToast(want ? 'App Lock is on.' : 'App Lock is off.');
    } else {
      _showToast('App Lock needs Face ID or a passcode set on this phone.');
    }
  }

  // ── Profile photo ──────────────────────────────────────────────────────────
  // Private to the learner: stored at users/{uid}/profile/photo, never shown
  // to anyone else. Library only — iOS's picker needs no permission prompt.
  Future<void> _editPhoto() async {
    HapticFeedback.selectionClick();
    final hasCustom = await ProfilePhotoService.watch().first != null;
    if (!mounted) return;
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Profile photo'),
        message: const Text('Only you can see your photo.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'choose'),
            child: const Text('Choose photo'),
          ),
          if (hasCustom)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, 'remove'),
              child: const Text('Remove photo'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
    try {
      if (choice == 'remove') {
        await ProfilePhotoService.remove();
      } else if (choice == 'choose') {
        final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 256,
          maxHeight: 256,
          imageQuality: 80,
          requestFullMetadata: false,
        );
        if (file == null) return; // cancelled
        final bytes = await file.readAsBytes();
        if (!isAcceptablePhoto(bytes)) {
          if (mounted) _showToast('That photo is too large. Try another one.');
          return;
        }
        await ProfilePhotoService.save(bytes);
      }
    } catch (e) {
      debugPrint('Profile photo update failed: $e');
      if (mounted) {
        _showToast('Could not update your photo. Check your connection.');
      }
    }
  }

  void _showEditProfile() {
    final theme = AppTheme.of(context);
    final nameController = TextEditingController(
        text: FirebaseAuth.instance.currentUser?.displayName ?? '');
    bool loading = false;
    String? error;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: theme.subtext.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              Text('Edit profile',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.text,
                      letterSpacing: -0.4)),
              const SizedBox(height: 6),
              Text('Update your display name',
                  style: TextStyle(fontSize: 13, color: theme.subtext)),
              const SizedBox(height: 20),
              _buildModalTextField(nameController, 'Your name', false, theme),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!,
                    style: const TextStyle(fontSize: 13, color: AppColors.red)),
              ],
              const SizedBox(height: 20),
              GestureDetector(
                onTap: loading
                    ? null
                    : () async {
                        setModal(() => loading = true);
                        try {
                          await FirebaseAuth.instance.currentUser
                              ?.updateDisplayName(nameController.text.trim());
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            setState(() {});
                          }
                        } catch (_) {
                          setModal(() {
                            error = 'Something went wrong. Try again.';
                            loading = false;
                          });
                        }
                      },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16)),
                  child: Center(
                    child: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Save changes',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Let a guest choose Google, Apple, or email without signing out first.
  ///
  /// The email path and AuthService._signInOrLink both link the new
  /// credential to the current anonymous user, so the uid — and with it the
  /// streak, badges and completed lessons — carries over rather than being
  /// replaced by a fresh one.
  Future<void> _upgradeGuest() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    );
    if (!mounted) return;
    setState(() {});
    // Resubscribe rather than re-read: statsStream() binds to the uid it saw
    // when it was created. The email path links the credential to the same
    // anonymous uid, but a path that signs in as a different account would
    // leave the old subscription feeding this screen someone else's stats.
    _statsSub?.cancel();
    _listenToStats();
  }

  void _showNotificationsSheet() {
    NotificationSettingsSheet.show(
      context,
      onChanged: (prefs) {
        if (!mounted) return;
        setState(() => _notificationsEnabled = prefs.master);
      },
    );
  }

  void _showMyStats() {
    final theme = AppTheme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: theme.subtext.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Text('My Stats',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.text,
                    letterSpacing: -0.4)),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildStatTile(theme, '$_lessonCount', 'Lessons',
                    CupertinoIcons.checkmark_seal_fill, AppColors.green),
                const SizedBox(width: 10),
                _buildStatTile(theme, '$_badgeCount', 'Badges',
                    CupertinoIcons.rosette, AppColors.amber),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStatTile(theme, '$_streak', 'Day streak',
                    CupertinoIcons.flame_fill, const Color(0xFFF97316)),
                const SizedBox(width: 10),
                _buildStatTile(theme, _avgScore, 'Avg score',
                    Icons.track_changes_rounded, AppColors.primary),
              ],
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                    color: theme.border,
                    borderRadius: BorderRadius.circular(16)),
                child: Text('Close',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: theme.subtext)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(ThemeNotifier theme, String value, String label,
      IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: theme.text,
                    letterSpacing: -0.8)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: theme.subtext)),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordSheet() {
    final theme = AppTheme.of(context);
    final currentController = TextEditingController();
    final newController = TextEditingController();
    bool loading = false;
    String? error;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: theme.subtext.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              Text('Change password',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.text,
                      letterSpacing: -0.4)),
              const SizedBox(height: 20),
              _buildModalTextField(
                  currentController, 'Current password', true, theme),
              const SizedBox(height: 12),
              _buildModalTextField(newController, 'New password', true, theme),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!,
                    style: const TextStyle(fontSize: 13, color: AppColors.red)),
              ],
              const SizedBox(height: 20),
              GestureDetector(
                onTap: loading
                    ? null
                    : () async {
                        setModal(() => loading = true);
                        final user = FirebaseAuth.instance.currentUser;
                        final email = user?.email;
                        // Defence in depth: the row above is hidden for these
                        // accounts, but `user!.email!` crashed rather than
                        // failing, so it does not get to rely on that.
                        if (user == null ||
                            email == null ||
                            !AuthService.hasPasswordProvider) {
                          setModal(() {
                            error = 'This account signs in without a password, '
                                'so there is nothing to change here.';
                            loading = false;
                          });
                          return;
                        }
                        try {
                          final cred = EmailAuthProvider.credential(
                            email: email,
                            password: currentController.text,
                          );
                          await user.reauthenticateWithCredential(cred);
                          await user.updatePassword(newController.text);
                          if (ctx.mounted) Navigator.pop(ctx);
                        } on FirebaseAuthException catch (e) {
                          setModal(() {
                            // The provider's own code is appended for the same
                            // reason AuthResult does it: nobody can read a
                            // debug log off a TestFlight build.
                            error = switch (e.code) {
                              'wrong-password' ||
                              'invalid-credential' =>
                                'Current password is incorrect.',
                              'weak-password' =>
                                'That new password is too weak. Use at least '
                                    '6 characters.',
                              'requires-recent-login' =>
                                'Please sign out and back in, then try again.',
                              _ =>
                                'Could not change your password. (${e.code})',
                            };
                            loading = false;
                          });
                        } catch (e) {
                          setModal(() {
                            error = 'Could not change your password. Please '
                                'try again.';
                            loading = false;
                          });
                        }
                      },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16)),
                  child: Center(
                    child: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Update password',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalTextField(TextEditingController controller, String hint,
      bool isPassword, ThemeNotifier theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.border.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: TextStyle(color: theme.text, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: theme.subtext, fontSize: 15),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      ),
    );
  }

  void _signOut() {
    final theme = AppTheme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: theme.subtext.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Text('Sign out of B1nary?',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.text,
                    letterSpacing: -0.4)),
            const SizedBox(height: 6),
            Text('You can sign back in anytime.',
                style: TextStyle(fontSize: 14, color: theme.subtext)),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () async {
                HapticFeedback.mediumImpact();
                Navigator.pop(sheetContext);
                await signOutToWelcome(context);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: AppColors.red.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.square_arrow_left,
                        color: AppColors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Sign out',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.red,
                            letterSpacing: -0.2)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.pop(sheetContext),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                    color: theme.border,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.border)),
                child: Text('Cancel',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: theme.subtext)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutSheet() {
    final theme = AppTheme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: theme.subtext.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 28),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20)),
              child: const Center(
                child: Text('01',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('B1nary',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: theme.text,
                    letterSpacing: -0.5)),
            const SizedBox(height: 6),
            Text('Version 1.0.0',
                style: TextStyle(fontSize: 13, color: theme.subtext)),
            const SizedBox(height: 8),
            Text('Master IT. Get certified.',
                style: TextStyle(fontSize: 14, color: theme.subtext)),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                    color: theme.border,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.border)),
                child: Text('Close',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: theme.subtext)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Scaffold(
      backgroundColor: theme.bg,
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: WebContentBounds(
            maxWidth: 720,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildHeader(theme),
                _buildStatsRow(theme),

                // ── Account ───────────────────────────────────────────────────
                _buildSection('Account', theme, [
                  // Guest mode shipped with no way out of it: `isGuest` existed
                  // but nothing in the UI read it, so a guest who studied for a
                  // week could never turn that into a real account, and losing
                  // the device lost the lot. Signing up from here links the
                  // credential to the same uid, so the streak and progress
                  // survive the upgrade.
                  if (AuthService.isGuest)
                    _buildItem(CupertinoIcons.person_badge_plus_fill,
                        'Sign in or create an account', AppColors.green, theme,
                        subtitle: 'Save your streak and progress',
                        onTap: _upgradeGuest),
                  if (!AuthService.isGuest)
                    _buildItem(CupertinoIcons.person_fill, 'Edit profile',
                        AppColors.primary, theme,
                        onTap: _showEditProfile),
                  _buildItem(CupertinoIcons.bell_fill, 'Notifications',
                      AppColors.primary, theme,
                      onTap: _showNotificationsSheet,
                      trailing: _loadingNotifPref
                          ? null
                          : _notificationsEnabled
                              ? _badge('On', AppColors.green)
                              : _badge('Off', theme.subtext)),
                  // Only for accounts that actually have a password. A guest
                  // has no email at all, and a Google/Apple account has no
                  // password credential to re-authenticate against — this row
                  // could not work for either, and crashed for the first.
                  if (AuthService.hasPasswordProvider)
                    _buildItem(CupertinoIcons.lock_fill, 'Change password',
                        AppColors.primary, theme,
                        onTap: _showChangePasswordSheet),
                  _buildItem(CupertinoIcons.lock_shield_fill, 'App Lock',
                      AppColors.primary, theme,
                      subtitle: 'Face ID or passcode after 2 minutes away',
                      onTap: _toggleAppLock,
                      trailing: _appLockOn
                          ? _badge('On', AppColors.green)
                          : _badge('Off', theme.subtext)),
                  _buildThemeToggle(theme),
                ]),

                // ── Learning ──────────────────────────────────────────────────
                _buildSection('Learning', theme, [
                  _buildItem(CupertinoIcons.graph_square_fill, 'My stats',
                      AppColors.green, theme,
                      onTap: _showMyStats),
                  _buildItem(
                      CupertinoIcons.rosette, 'Badges', AppColors.green, theme,
                      onTap: () => Navigator.push(
                          context, AppRouter.push(const BadgesScreen()))),
                  // A certificate used to exist only in the seconds after the
                  // final quiz. Backing out of that screen lost it for good.
                  _buildItem(CupertinoIcons.doc_text_fill, 'My certificates',
                      AppColors.green, theme,
                      subtitle: 'Every course you have completed',
                      onTap: () => Navigator.push(
                          context, AppRouter.push(const CertificatesScreen()))),
                  _buildItem(CupertinoIcons.arrow_down_circle_fill,
                      'Download for offline', AppColors.green, theme,
                      onTap: () => Navigator.push(context,
                          AppRouter.push(const OfflineDownloadsScreen())),
                      isLast: true),
                ]),

                // ── Support ───────────────────────────────────────────────────
                _buildSection('Support', theme, [
                  _buildItem(CupertinoIcons.question_circle_fill, 'Help center',
                      AppColors.amber, theme,
                      onTap: _openHelpCenter),
                  _buildItem(CupertinoIcons.chat_bubble_text_fill,
                      'Send feedback', AppColors.amber, theme,
                      onTap: _showFeedbackSheet),
                  _buildItem(CupertinoIcons.info_circle_fill, 'About B1nary',
                      AppColors.amber, theme,
                      onTap: _showAboutSheet, isLast: true),
                ]),

                // ── Legal & Purchases ─────────────────────────────────────────
                _buildSection('Legal & Purchases', theme, [
                  _buildItem(CupertinoIcons.rocket_fill, 'Plans & Pricing',
                      AppColors.primary, theme,
                      onTap: () => Navigator.push(
                            context,
                            AppRouter.push<void>(const PaywallScreen(
                              courseTitle: 'B1nary',
                              courseColor: AppColors.primary,
                              defaultToAllPlans: true,
                            )),
                          )),
                  _buildItem(CupertinoIcons.doc_text_fill,
                      'Privacy Policy & Terms', const Color(0xFF8B5CF6), theme,
                      onTap: () => Navigator.push(
                          context, AppRouter.push(const LegalScreen()))),
                  // Restore Purchases — REQUIRED by Apple App Review (3.1.1)
                  _buildRestorePurchasesItem(theme),
                ]),

                // ── Sign out ──────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: GestureDetector(
                      onTap: _signOut,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: AppColors.red.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.square_arrow_left,
                                color: AppColors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Sign out',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.red,
                                    letterSpacing: -0.2)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Delete account ────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                          context, AppRouter.push(const DeleteAccountScreen())),
                      child: Center(
                        child: Text(
                          'Delete account',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.subtext.withValues(alpha: 0.6),
                            decoration: TextDecoration.underline,
                            decorationColor:
                                theme.subtext.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Wraps the RestorePurchasesButton widget in a list-item style
  /// container that matches the rest of the profile section tiles.
  Widget _buildRestorePurchasesItem(ThemeNotifier theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: const RestorePurchasesButton(),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _buildHeader(ThemeNotifier theme) {
    return SliverToBoxAdapter(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            children: [
              Semantics(
                button: true,
                label: 'Change profile photo',
                child: GestureDetector(
                  onTap: _editPhoto,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ProfileAvatar(
                        radius: 44,
                        initials: _getInitials(),
                        fontSize: 26,
                        photoUrl: FirebaseAuth.instance.currentUser?.photoURL,
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.border),
                          ),
                          child: Icon(CupertinoIcons.camera_fill,
                              size: 14, color: theme.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(_getFullName(),
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: theme.text,
                      letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text(_getEmail(),
                  style: TextStyle(fontSize: 13, color: theme.subtext)),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: const Text('IT Learner · Level 1',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(ThemeNotifier theme) {
    final stats = [
      ('$_lessonCount', 'Lessons'),
      ('$_badgeCount', 'Badges'),
      ('$_streak', 'Streak'),
      (_avgScore, 'Avg score'),
    ];
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.border)),
          child: Row(
            children: stats.asMap().entries.map((entry) {
              final i = entry.key;
              final stat = entry.value;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(stat.$1,
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: theme.text,
                                  letterSpacing: -0.5)),
                          const SizedBox(height: 3),
                          Text(stat.$2,
                              style: TextStyle(
                                  fontSize: 11, color: theme.subtext)),
                        ],
                      ),
                    ),
                    if (i < stats.length - 1)
                      Container(width: 0.5, height: 30, color: theme.border),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, ThemeNotifier theme, List<Widget> items) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(title.toUpperCase(),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.subtext,
                      letterSpacing: 1.1)),
            ),
            Container(
              decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: theme.border)),
              child: Column(children: items),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle(ThemeNotifier theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(
              theme.isDark
                  ? CupertinoIcons.moon_fill
                  : CupertinoIcons.sun_max_fill,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(theme.isDark ? 'Dark mode' : 'Light mode',
                style: TextStyle(
                    fontSize: 14, color: theme.text, letterSpacing: -0.2)),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              theme.toggle();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: 46,
              height: 26,
              decoration: BoxDecoration(
                color: theme.isDark
                    ? AppColors.primary
                    : Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    left: theme.isDark ? 22 : 2,
                    top: 2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    IconData icon,
    String label,
    Color color,
    ThemeNotifier theme, {
    required VoidCallback onTap,
    bool isLast = false,
    Widget? trailing,
    String? subtitle,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border:
              isLast ? null : Border(bottom: BorderSide(color: theme.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          color: theme.text,
                          letterSpacing: -0.2)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(fontSize: 11.5, color: theme.subtext)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[trailing, const SizedBox(width: 8)],
            Icon(CupertinoIcons.chevron_right, size: 13, color: theme.subtext),
          ],
        ),
      ),
    );
  }
}
