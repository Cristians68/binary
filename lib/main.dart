import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/welcome_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/app_theme.dart';
import 'screens/subscription_service.dart';
import 'screens/notification_prefs_service.dart';
import 'screens/notification_service.dart';
import 'screens/main_navigation.dart';
import 'screens/service_backend.dart';
import 'security_service.dart';

void main() {
  // Last-resort handling for uncaught Dart/plugin futures. The binding and
  // runApp must share this zone. Account listeners are cancelled separately
  // before sign-out; a Dart zone cannot catch a native iOS process crash.
  runZonedGuarded(_bootstrap, (error, stack) {
    debugPrint('Uncaught async error: $error');
    debugPrint('$stack');
  });
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inter ships in the bundle (see pubspec `google_fonts/`), so no launch
  // should ever fetch a font. Left at its default, google_fonts downloads any
  // weight it cannot find locally from fonts.gstatic.com on first launch,
  // which hands the user's IP address to a third party before they have
  // agreed to anything, and leaves the app rendering fallback type until the
  // request returns. Turning fetching off makes a missing weight a loud,
  // local failure instead of a quiet network call.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Keep the user's email and uid out of the release device log.
  debugPrint = debugPrintFor(kReleaseMode);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // RevenueCat must be configured before any purchase / entitlement check.
  await SubscriptionService.configure();

  // Silently sync entitlements from RevenueCat → Firestore on launch.
  // Fixes cross-device race conditions: if a purchase was made on Device A,
  // Device B's Firestore catches up before the UI checks access.
  // Does NOT mark trial as used — purely a passive sync.
  await SubscriptionService.syncEntitlementsOnLaunch();

  await NotificationService.init();

  // ── Pre-load theme preference BEFORE runApp so there is zero flash ──
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkMode') ?? false;

  runApp(
    SecurityGate(
      child: BinaryApp(initialIsDark: isDark),
    ),
  );
}

// _ensureUserIdentity() used to live here and signed every launch in
// anonymously before the UI appeared. It was written long before guest mode
// existed and now actively fights it: an install was already an anonymous
// account by the time the welcome screen rendered, so "Continue as guest" was
// relabelling a session the user had never chosen, and every install that went
// on to create a real account left an orphan anonymous user behind.
//
// Anonymous sign-in now happens in exactly one place — AuthService.signInAsGuest,
// behind the button that says so.

/// Whether the intro carousel has been seen on this install.
///
/// Deliberately NOT keyed by uid. It used to be `onboardingComplete_$uid`,
/// read with whatever uid existed at the time — and at first launch there is
/// no user, so the flag was written under the bare key and then looked up
/// under `onboardingComplete_<uid>` on the next cold start, once the user had
/// signed up. It never matched, so **the intro replayed after signing in**,
/// every launch, until they happened to complete it while signed in.
///
/// Onboarding is a property of the install, not of the account. Someone who
/// signs out and back in, or switches accounts on their own phone, has already
/// seen it.
const String kOnboardingCompleteKey = 'onboardingComplete';

/// The `debugPrint` implementation to install for a given build mode.
///
/// Flutter does NOT strip `debugPrint` from a release build — the name only
/// describes where it is meant to be used, not where it runs. This app makes
/// around a hundred such calls, and they are not harmless: several name the
/// signed-in user, including `Google Sign-In: got user <email>` and
/// `uid=<uid>`. On a release iOS build those reach the device log, where
/// anything with the device attached, or any sysdiagnose the user is asked to
/// send to some other vendor's support desk, can read them.
///
/// Returns a no-op in release and the normal throttled printer otherwise.
/// This is a function rather than an `if` in `main()` so the choice can be
/// asserted in a test — `kReleaseMode` is false under `flutter test`, so the
/// release branch is unreachable there and would otherwise never be checked.
DebugPrintCallback debugPrintFor(bool releaseMode) =>
    releaseMode ? (String? message, {int? wrapWidth}) {} : debugPrintThrottled;

class BinaryApp extends StatefulWidget {
  final bool initialIsDark;
  const BinaryApp({super.key, required this.initialIsDark});

  @override
  State<BinaryApp> createState() => _BinaryAppState();
}

class _BinaryAppState extends State<BinaryApp> {
  late final ThemeNotifier _themeNotifier;

  @override
  void initState() {
    super.initState();
    // Pass the pre-loaded value — notifier starts correct with no flash
    _themeNotifier = ThemeNotifier(initialIsDark: widget.initialIsDark);
  }

  @override
  void dispose() {
    _themeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeNotifier,
      builder: (context, _) {
        final isDark = _themeNotifier.isDark;
        return MaterialApp(
          title: 'B1nary',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: isDark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor:
                isDark ? AppColors.darkBg : AppColors.lightBg,
            colorScheme: ColorScheme(
              brightness: isDark ? Brightness.dark : Brightness.light,
              primary: AppColors.primary,
              onPrimary: Colors.white,
              secondary: AppColors.primary,
              onSecondary: Colors.white,
              error: AppColors.red,
              onError: Colors.white,
              surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              onSurface: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            textTheme: GoogleFonts.interTextTheme(
              isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
            ).apply(
              bodyColor: isDark ? AppColors.darkText : AppColors.lightText,
              displayColor: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            // CupertinoPageTransitionsBuilder now lives in the cupertino
            // library, not material — hence the import above. Without it the
            // analyzer on an older Flutter was happy and the CI archive died
            // five minutes in, first with "Not a constant expression" and then
            // with "isn't defined for the type _BinaryAppState", which is the
            // front end failing to resolve the name at all.
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          builder: (context, child) =>
              AppTheme(notifier: _themeNotifier, child: child!),
          home: const _AppEntry(),
        );
      },
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();
  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    // Reminders are scheduled from the local mirror of the user's preferences,
    // so this does not wait on Firestore and works offline.
    unawaited(NotificationPrefsService.applyAtStartup());

    if (kIsWeb) {
      if (mounted) setState(() => _showOnboarding = false);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(kOnboardingCompleteKey) ?? false;
    if (mounted) setState(() => _showOnboarding = !done);
  }

  Future<void> _completeOnboarding() async {
    // OnboardingScreen persists completion before invoking this callback.
    if (mounted) setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding == null) {
      final theme = AppTheme.of(context);
      return Scaffold(backgroundColor: theme.bg);
    }
    if (_showOnboarding!) {
      return OnboardingScreen(onComplete: _completeOnboarding);
    }
    // Resume registered accounts. A restored anonymous session must still
    // choose a sign-in method or Continue as guest. Keep that session alive
    // so either choice can preserve its uid and learning progress.
    final user = ServiceBackend.auth.currentUser;
    if (user != null && !user.isAnonymous) {
      return const MainNavigation();
    }
    return const WelcomeScreen();
  }
}
