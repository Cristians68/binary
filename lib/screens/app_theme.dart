import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Shared brand mark ──────────────────────────────────────────────────────
// The real app icon, rendered from assets/icons/app_icon.png.
//
// This used to be a hand-painted blue "B" with two binary dots beneath it — a
// second, different mark from the one on the home screen. That was tolerable
// while both were blue Bs. It stopped being tolerable when the home screen
// icon became the neural-cap mark and this one did not: the icon a user
// tapped and the icon they then saw were unrelated images.
//
// One source now feeds both. The rounded-square clip matches iOS's own icon
// mask closely enough that it reads as the same object.
class AppIcon extends StatelessWidget {
  final double size;
  const AppIcon({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.225),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: size * 0.22,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.225),
        child: Image.asset(
          'assets/icons/app_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          // The asset is 256px; anything larger would be upscaled, and the
          // welcome screen renders it at 64-72. Cache at the size actually
          // drawn so a 256px decode is not held for a 64px box.
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

/// A soft, out-of-focus circle of colour used to add ambient depth behind a
/// form without competing with it — purely decorative, `IgnorePointer` so it
/// never intercepts taps meant for the content above it.
class GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const GlowOrb(
      {super.key,
      required this.color,
      required this.size,
      required this.opacity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Theme colours ─────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // ── Dark mode ──
  static const darkBg = Color(0xFF0E1422);
  static const darkSurface = Color(0xFF151E30);
  static const darkCard = Color(0xFF1B263B);
  static const darkBorder = Color(0xFF2D3950);
  static const darkText = Color(0xFFF5F7FF);
  static const darkSubtext = Color(0xFFA8B5CB);
  static const darkNavBg = Color(0xFF151E30);

  // Light surfaces stay distinct even when a display washes out pale shades.
  // Decorative dividers and interactive outlines have separate roles.
  static const lightBg = Color(0xFFF2F4F8);
  static const lightSurface = Color(0xFFE6EBF2);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFCBD3DF);
  static const lightOutline = Color(0xFF7C879A);
  static const lightText = Color(0xFF14213A);
  static const lightSubtext = Color(0xFF45536B);
  static const lightNavBg = Color(0xFFFFFFFF);

  // ── Accent colors ──
  static const primary = Color(0xFF325BE8);
  static const blue = Color(0xFF0077ED);
  static const green = Color(0xFF11865F);
  static const amber = Color(0xFFFF9500);
  static const red = Color(0xFFFF3B30);
  static const indigo = Color(0xFF5E5CE6);
  static const ink = Color(0xFF152645);
  static const mint = Color(0xFFB9F5DD);
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
  Color get outline => _isDark ? AppColors.darkBorder : AppColors.lightOutline;
  Color get text => _isDark ? AppColors.darkText : AppColors.lightText;
  Color get subtext => _isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
  Color get navBg => _isDark ? AppColors.darkNavBg : AppColors.lightNavBg;
  Color get primary => AppColors.primary;

  /// Course colors arrive from the catalogue, including bright cyan and amber.
  /// Keep their hue, but give foregrounds and white-text buttons enough depth.
  /// Decorative tints should still use the original course color.
  Color accent(Color color) {
    if (_isDark) return color;
    final opaque = color.withValues(alpha: 1);
    final background = AppColors.lightSurface.computeLuminance();
    for (var step = 0; step <= 20; step++) {
      final candidate = Color.lerp(opaque, AppColors.lightText, step / 20)!;
      if ((background + 0.05) / (candidate.computeLuminance() + 0.05) >= 4.5) {
        return candidate;
      }
    }
    return AppColors.lightText;
  }
}

/// Shared by the app and the screenshot fixture so previews use shipping colors.
ThemeData appMaterialTheme(ThemeNotifier theme, {TargetPlatform? platform}) {
  final brightness = theme.isDark ? Brightness.dark : Brightness.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.primary,
    onSecondary: Colors.white,
    error: AppColors.red,
    onError: Colors.white,
    surface: theme.surface,
    onSurface: theme.text,
  );
  final base = ThemeData(
    brightness: brightness,
    platform: platform,
    scaffoldBackgroundColor: theme.bg,
    colorScheme: scheme,
    textTheme: GoogleFonts.interTextTheme(
      theme.isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).apply(bodyColor: theme.text, displayColor: theme.text),
  );
  if (theme.isDark) return base;
  return base.copyWith(
    colorScheme: scheme.copyWith(
      surface: theme.card,
      surfaceContainer: theme.bg,
      surfaceContainerHighest: theme.surface,
      onSurfaceVariant: theme.subtext,
      outline: theme.outline,
      outlineVariant: theme.border,
      error: theme.accent(AppColors.red),
      surfaceTint: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: theme.card,
      hintStyle: TextStyle(color: theme.subtext),
      labelStyle: TextStyle(color: theme.subtext),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: theme.outline),
      ),
    ),
  );
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

// Reading and form widths follow the available space on every platform.
// Keep the wrapper tree stable when the window resizes: swapping between
// `child` and Align would recreate stateful descendants during a fold.
// The historical name remains for existing screen callers.
class WebContentBounds extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const WebContentBounds({super.key, required this.child, this.maxWidth = 640});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
