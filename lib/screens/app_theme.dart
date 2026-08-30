import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Shared brand mark ──────────────────────────────────────────────────────
// A custom-painted "B" with two small binary dots (0 · 1) beneath, inside a
// rounded-square shape. Used anywhere the app needs to reassert its identity
// (welcome, login, signup) rather than each screen keeping its own copy.
class AppIcon extends StatelessWidget {
  final double size;
  const AppIcon({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.265),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: size * 0.28,
            offset: Offset(0, size * 0.10),
          ),
        ],
      ),
      child: CustomPaint(painter: _AppIconPainter()),
    );
  }
}

class _AppIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final tp = TextPainter(
      text: const TextSpan(
        text: 'B',
        style: TextStyle(
          color: Colors.white,
          fontSize: 38,
          fontWeight: FontWeight.w800,
          height: 1.0,
          letterSpacing: -1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bX = (w - tp.width) / 2 - 1;
    final bY = (h - tp.height) / 2 - 5;
    tp.paint(canvas, Offset(bX, bY));

    final dotY = h * 0.73;
    final dotR = w * 0.055;
    final spacing = w * 0.18;
    final centerX = w / 2;

    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.042;
    canvas.drawCircle(Offset(centerX - spacing, dotY), dotR, ringPaint);

    paint.color = Colors.white.withValues(alpha: 0.45);
    canvas.drawCircle(Offset(centerX, dotY), dotR * 0.38, paint);

    paint.color = Colors.white.withValues(alpha: 0.75);
    canvas.drawCircle(Offset(centerX + spacing, dotY), dotR, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
