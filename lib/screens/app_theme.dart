import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
      {super.key, required this.color, required this.size, required this.opacity});

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

// ── Web content bounds ───────────────────────────────────────────────────────
// Most screens were built mobile-first and never got a wide-screen pass, so
// on the web they stretch a mobile-width column edge-to-edge across a full
// desktop viewport -- content reads too wide, and forms end up pinned to one
// side with a large dead gap next to them. This is not "the web version
// working like a website" so much as "an app screen inside a browser tab."
//
// This wraps a screen's scrollable content so that on a wide web viewport it
// centers with a comfortable reading-width cap, and is a complete no-op on
// mobile (native or narrow web) so nothing changes there.
bool isWideWeb(BuildContext context) =>
    kIsWeb && MediaQuery.of(context).size.width >= 720;

class WebContentBounds extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const WebContentBounds({super.key, required this.child, this.maxWidth = 640});

  @override
  Widget build(BuildContext context) {
    if (!isWideWeb(context)) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
