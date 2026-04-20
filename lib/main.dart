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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Ensure every user has a Firebase identity so progress is always
  // scoped to a real UID — never shared across users.
  await _ensureUserIdentity();

  await SubscriptionService.configure();
  await NotificationService.init();
  runApp(const BinaryApp());
}

/// Signs in anonymously if no user is currently authenticated.
/// When a user later signs in with email/Google/etc., call
/// [FirebaseAuth.instance.currentUser?.linkWithCredential()] to
/// migrate their anonymous progress to a permanent account.
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
  const BinaryApp({super.key});

  @override
  State<BinaryApp> createState() => _BinaryAppState();
}

class _BinaryAppState extends State<BinaryApp> {
  final ThemeNotifier _themeNotifier = ThemeNotifier();

  @override
  void initState() {
    super.initState();
    _themeNotifier.addListener(_onThemeLoaded);
  }

  void _onThemeLoaded() {
    if (_themeNotifier.isLoaded && mounted) {
      setState(() {});
      _themeNotifier.removeListener(_onThemeLoaded);
    }
  }

  @override
  void dispose() {
    _themeNotifier.removeListener(_onThemeLoaded);
    _themeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeNotifier.isLoaded) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(backgroundColor: Colors.black, body: SizedBox.shrink()),
      );
    }

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
    // Web always skips onboarding — go straight to WelcomeScreen
    if (kIsWeb) {
      if (mounted) setState(() => _showOnboarding = false);
      return;
    }

    // Key onboarding flag to the current user's UID so each new user
    // always sees onboarding, regardless of device history.
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
