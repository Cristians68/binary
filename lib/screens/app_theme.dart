import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Theme colours ─────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // ── Dark mode ──
  static const darkBg = Color(0xFF0B0B0F);
  static const darkSurface = Color(0xFF121217);
  static const darkCard = Color(0xFF1C1C22);
  static const darkBorder = Color(0x1FFFFFFF);
  static const darkText = Color(0xFFFFFFFF);
  static const darkSubtext = Color(0x99FFFFFF);
  static const darkNavBg = Color(0xFF0B0B0F);

  // ── Light mode — vibrant, Apple.com-inspired ──
  static const lightBg = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFF5F5F7);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFD2D2D7);
  static const lightText = Color(0xFF1D1D1F);
  static const lightSubtext = Color(0xFF6E6E73);
  static const lightNavBg = Color(0xFFF5F5F7);

  // ── Accent colors ──
  static const primary = Color(0xFF0071E3);
  static const blue = Color(0xFF0077ED);
  static const green = Color(0xFF1DB954);
  static const amber = Color(0xFFFF9500);
  static const red = Color(0xFFFF3B30);
  static const indigo = Color(0xFF5E5CE6);
}

// ── Theme notifier ────────────────────────────────────────────────────────────
class ThemeNotifier extends ChangeNotifier {
  bool _isDark;

  // ── Accept a pre-loaded value so the app starts in the right mode ──
  // This eliminates the dark flash on the login/welcome screen
  ThemeNotifier({bool initialIsDark = false}) : _isDark = initialIsDark;

  bool get isDark => _isDark;
  bool get isLoaded => true; // always loaded since we pre-load in main()

  Future<void> toggle() async {
    _isDark = !_isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDark);
    notifyListeners();
  }

  // ── Dynamic colour getters ──────────────────────────────────────────────────
  Color get bg => _isDark ? AppColors.darkBg : AppColors.lightBg;
  Color get surface => _isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get card => _isDark ? AppColors.darkCard : AppColors.lightCard;
  Color get border => _isDark ? AppColors.darkBorder : AppColors.lightBorder;
  Color get text => _isDark ? AppColors.darkText : AppColors.lightText;
  Color get subtext => _isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
  Color get navBg => _isDark ? AppColors.darkNavBg : AppColors.lightNavBg;
  Color get primary => AppColors.primary;
}

// ── Inherited widget ──────────────────────────────────────────────────────────
class AppTheme extends InheritedNotifier<ThemeNotifier> {
  const AppTheme({
    super.key,
    required ThemeNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ThemeNotifier of(BuildContext context) {
    final result =
        context.dependOnInheritedWidgetOfExactType<AppTheme>()?.notifier;
    assert(result != null, 'No AppTheme found in context');
    return result!;
  }
}
