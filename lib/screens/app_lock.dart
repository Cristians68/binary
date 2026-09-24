import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How long the app may sit in the background before it locks.
const Duration kAppLockAfter = Duration(minutes: 2);

/// Opt-in flag. Off by default: the lock never prompts for Face ID until the
/// learner turns it on in Profile.
const String kAppLockEnabledKey = 'app_lock_enabled';

/// When the app last went to the background, kept on disk so a cold start
/// after the app was swiped away is judged the same way as a resume.
const String kAppLockBackgroundedAtKey = 'app_lock_backgrounded_at';

/// A clock that moved backwards locks rather than skipping the check: setting
/// the phone's time back must not be a way around the lock.
bool shouldLock({
  required bool signedIn,
  required DateTime? backgroundedAt,
  required DateTime now,
}) {
  if (!signedIn || backgroundedAt == null) return false;
  final away = now.difference(backgroundedAt);
  return away.isNegative || away >= kAppLockAfter;
}

abstract class LockAuthenticator {
  /// Whether the phone has Face ID, Touch ID or a passcode to check against.
  Future<bool> isAvailable();

  /// Asks for Face ID / Touch ID, falling back to the phone passcode.
  Future<bool> authenticate();
}

class DeviceLockAuthenticator implements LockAuthenticator {
  final _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock B1nary',
        persistAcrossBackgrounding: true,
      );
    } catch (error) {
      debugPrint('App lock authentication failed: $error');
      return false;
    }
  }
}

class AppLockSettings {
  AppLockSettings._();

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kAppLockEnabledKey) ?? false;
  }

  /// Turning the lock on needs one successful check, which is also when iOS
  /// asks the learner to allow Face ID. Returns whether the change took.
  static Future<bool> setEnabled(bool enabled,
      [LockAuthenticator? authenticator]) async {
    final auth = authenticator ?? DeviceLockAuthenticator();
    if (enabled) {
      if (!await auth.isAvailable()) return false;
      if (!await auth.authenticate()) return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kAppLockEnabledKey, enabled);
    if (!enabled) await prefs.remove(kAppLockBackgroundedAtKey);
    return true;
  }
}

/// Set once the first-open offer has been shown, whatever the answer.
const String kAppLockOfferedKey = 'app_lock_offered';

/// Asks once, the first time a signed-in learner reaches the app, whether to
/// turn App Lock on. Never shown again after any answer, and never on a
/// phone with nothing to unlock with. Profile keeps the switch afterwards.
class AppLockOffer {
  AppLockOffer._();

  static Future<void> maybeShow(BuildContext context,
      [LockAuthenticator? authenticator]) async {
    final auth = authenticator ?? DeviceLockAuthenticator();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(kAppLockOfferedKey) ?? false) return;
    if (prefs.getBool(kAppLockEnabledKey) ?? false) return;
    if (!await auth.isAvailable()) return;
    await prefs.setBool(kAppLockOfferedKey, true);
    if (!context.mounted) return;

    final turnOn = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Protect B1nary with Face ID?'),
        content: const Text(
            'If you leave the app for 2 minutes, it locks until you use '
            'Face ID or your passcode. You can change this any time in '
            'Profile.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Turn on'),
          ),
        ],
      ),
    );
    if (turnOn == true) await AppLockSettings.setEnabled(true, auth);
  }
}

/// Covers the whole app after [kAppLockAfter] in the background, when the
/// learner has opted in. The app underneath is kept alive (Offstage, not
/// removed), so unlocking returns them exactly where they were.
class AppLock extends StatefulWidget {
  AppLock({
    super.key,
    required this.child,
    LockAuthenticator? authenticator,
    DateTime Function()? now,
    bool Function()? isSignedIn,
  })  : authenticator = authenticator ?? DeviceLockAuthenticator(),
        now = now ?? DateTime.now,
        isSignedIn =
            isSignedIn ?? (() => FirebaseAuth.instance.currentUser != null);

  final Widget child;
  final LockAuthenticator authenticator;
  final DateTime Function() now;
  final bool Function() isSignedIn;

  static const lockScreenKey = ValueKey('app-lock-screen');

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  bool _locked = false;
  bool _prompting = false;
  bool _awayRecorded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _evaluate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _recordAway();
      case AppLifecycleState.resumed:
        _evaluate();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // `inactive` also fires while the Face ID sheet is up; it is not
        // "leaving the app" and must not start the clock.
        break;
    }
  }

  Future<void> _recordAway() async {
    if (_locked || _awayRecorded) return;
    _awayRecorded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        kAppLockBackgroundedAtKey, widget.now().millisecondsSinceEpoch);
  }

  Future<void> _evaluate() async {
    _awayRecorded = false;
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(kAppLockEnabledKey) ?? false;
    final at = prefs.getInt(kAppLockBackgroundedAtKey);
    final backgroundedAt =
        at == null ? null : DateTime.fromMillisecondsSinceEpoch(at);
    final lock = enabled &&
        shouldLock(
          signedIn: widget.isSignedIn(),
          backgroundedAt: backgroundedAt,
          now: widget.now(),
        ) &&
        await widget.authenticator.isAvailable();
    if (!lock) {
      // A short trip away: forget it, so a later cold start isn't judged
      // against a stale time.
      if (!_locked) await prefs.remove(kAppLockBackgroundedAtKey);
      return;
    }
    if (!mounted) return;
    setState(() => _locked = true);
    await _unlock();
  }

  Future<void> _unlock() async {
    if (_prompting) return;
    _prompting = true;
    try {
      final ok = await widget.authenticator.authenticate();
      if (!ok || !mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kAppLockBackgroundedAtKey);
      setState(() => _locked = false);
    } finally {
      _prompting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Offstage(
          offstage: _locked,
          child: TickerMode(enabled: !_locked, child: widget.child),
        ),
        if (_locked) _LockScreen(onUnlock: _unlock),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.onUnlock});
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: AppLock.lockScreenKey,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.lock_fill, size: 48, color: scheme.primary),
                const SizedBox(height: 20),
                Text('B1nary is locked',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface)),
                const SizedBox(height: 8),
                Text('Use Face ID or your passcode to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onUnlock,
                  icon: const Icon(CupertinoIcons.lock_open_fill),
                  label: const Text('Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
