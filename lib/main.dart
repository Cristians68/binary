import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
import 'screens/notification_service.dart';
import 'security_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await _ensureUserIdentity();
  await SubscriptionService.configure();
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

Future<void> _ensureUserIdentity() async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    try {
      await auth.signInAnonymously();
      debugPrint('Anonymous user created: ${auth.currentUser?.uid}');
    } catch (e) {
      debugPrint('Failed to sign in anonymously: $e');
    }
  } else {
    debugPrint('Existing user: ${auth.currentUser?.uid}');
  }
}

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
          title: 'Binary',
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
            pageTransitionsTheme: PageTransitionsTheme(
              builders: {
                TargetPlatform.android: const CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
                TargetPlatform.windows: const CupertinoPageTransitionsBuilder(),
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
    return const WelcomeScreen();
  }
}
