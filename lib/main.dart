import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'security_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
          title: 'B1nary Academy',
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();
    final key = uid != null ? 'onboardingComplete_$uid' : 'onboardingComplete';
    final done = prefs.getBool(key) ?? false;
    if (mounted) setState(() => _showOnboarding = !done);
  }

  Future<void> _completeOnboarding() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();
    final key = uid != null ? 'onboardingComplete_$uid' : 'onboardingComplete';
    await prefs.setBool(key, true);
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
    // A session that survived the last launch goes straight in. Without this
    // the welcome screen rendered on every cold start even for a signed-in
    // user, who then had to log in again — including a guest, who would have
    // been handed a brand new anonymous uid and silently lost their streak.
    if (FirebaseAuth.instance.currentUser != null) {
      return const MainNavigation();
    }
    return const WelcomeScreen();
  }
}