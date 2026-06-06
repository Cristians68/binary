import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'auth_service.dart';
import 'main_navigation.dart';
import 'app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  bool _googleLoading = false;
  bool _appleLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateTo(Widget screen) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => screen,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity:
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 450),
      ),
    );
  }

  void _goToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const MainNavigation(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity:
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
      (route) => false,
    );
  }

  Future<void> _handleApple() async {
    HapticFeedback.selectionClick();
    setState(() => _appleLoading = true);
    final result = await AuthService.signInWithApple();
    if (!mounted) return;
    setState(() => _appleLoading = false);
    if (result != null) {
      _goToHome();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Apple sign-in failed. Please try again.'),
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _handleGoogle() async {
    HapticFeedback.selectionClick();
    setState(() => _googleLoading = true);
    final result = await AuthService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _googleLoading = false);
    if (result != null) {
      _goToHome();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Google sign-in failed. Please try again.'),
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final isWide = kIsWeb &&
        MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: isWide
                ? _buildWideLayout(theme)
                : _buildNarrowLayout(theme),
          ),
        ),
      ),
    );
  }

  // ── Desktop two-column landing layout ──────────────────────────────────────

  Widget _buildWideLayout(ThemeNotifier theme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 48),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left — hero + buttons
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _AppIcon(size: 64),
                    const SizedBox(height: 28),
                    Text(
                      'Binary.',
                      style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w700,
                        color: theme.text,
                        letterSpacing: -3.5,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Master IT. Get certified.',
                      style: TextStyle(
                        fontSize: 22,
                        color: theme.subtext,
                        letterSpacing: -0.4,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 48),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: _buildButtons(theme),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 80),
              // Right — feature list in a card
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Everything you need to pass',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.text,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildFeatures(theme),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.checkmark_seal_fill,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'ITIL V4 · CSM · CompTIA Security+ · Networking · Cloud',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mobile single-column layout (unchanged) ─────────────────────────────────

  Widget _buildNarrowLayout(ThemeNotifier theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          _buildLogo(theme),
          const SizedBox(height: 48),
          _buildFeatures(theme),
          const Spacer(flex: 3),
          _buildButtons(theme),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOGO
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLogo(ThemeNotifier theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // App icon — custom painted binary/circuit mark
        const _AppIcon(size: 72),
        const SizedBox(height: 20),
        Text(
          'Binary.',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: theme.text,
            letterSpacing: -2.0,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Master IT. Get certified.',
          style: TextStyle(
            fontSize: 18,
            color: theme.subtext,
            letterSpacing: -0.4,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FEATURES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFeatures(ThemeNotifier theme) {
    final features = [
      (
        CupertinoIcons.doc_text_fill,
        'Structured courses',
        'ITIL V4, CSM, Networking & more',
        AppColors.primary,
      ),
      (
        CupertinoIcons.rectangle_stack_fill,
        'Flashcard learning',
        'Learn concepts fast and effectively',
        AppColors.green,
      ),
      (
        Icons.track_changes_rounded,
        'Quizzes & tracking',
        'Test yourself and track progress',
        AppColors.amber,
      ),
    ];

    return Column(
      children: features.asMap().entries.map((entry) {
        final i = entry.key;
        final f = entry.value;
        return _AnimatedFeature(
          delay: Duration(milliseconds: 200 + (i * 100)),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: f.$4.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: f.$4.withValues(alpha: 0.2)),
                  ),
                  child: Icon(f.$1, color: f.$4, size: 20),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.$2,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.text,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      f.$3,
                      style: TextStyle(fontSize: 13, color: theme.subtext),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUTTONS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildButtons(ThemeNotifier theme) {
    return Column(
      children: [
        _PressableButton(
          onTap: () => _navigateTo(const SignupScreen()),
          color: AppColors.primary,
          label: 'Get started',
          textColor: Colors.white,
        ),
        const SizedBox(height: 12),
        _PressableButton(
          onTap: () => _navigateTo(const LoginScreen()),
          color: theme.surface,
          label: 'I already have an account',
          textColor: theme.text,
          border: Border.all(color: theme.border),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Divider(color: theme.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'or continue with',
                style: TextStyle(fontSize: 12, color: theme.subtext),
              ),
            ),
            Expanded(child: Divider(color: theme.border)),
          ],
        ),
        const SizedBox(height: 20),
        // Sign in with Apple — must appear at least as prominently as
        // other third-party sign-in options (Apple guideline 4.8).
        _appleLoading
            ? _AppleLoadingButton(isDark: theme.isDark)
            : SignInWithAppleButton(
                onPressed: _handleApple,
                style: theme.isDark
                    ? SignInWithAppleButtonStyle.white
                    : SignInWithAppleButtonStyle.black,
                borderRadius:
                    const BorderRadius.all(Radius.circular(18)),
                height: 54,
              ),
        const SizedBox(height: 12),
        _GoogleButton(
          isLoading: _googleLoading,
          onTap: _handleGoogle,
          theme: theme,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP ICON
// A custom-painted mark: bold "B" with two small binary dots (0 · 1) beneath,
// all inside the same rounded-square shape. Clean, branded, techy.
// ─────────────────────────────────────────────────────────────────────────────

class _AppIcon extends StatelessWidget {
  final double size;
  const _AppIcon({this.size = 72});

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
      child: CustomPaint(
        painter: _AppIconPainter(),
      ),
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

    // ── Bold "B" using a TextPainter ──────────────────────────────────────
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

    // Centre the B, shifted slightly upward to make room for dots
    final bX = (w - tp.width) / 2 - 1;
    final bY = (h - tp.height) / 2 - 5;
    tp.paint(canvas, Offset(bX, bY));

    // ── Binary dots "0  1" beneath the B ─────────────────────────────────
    // "0" = small open circle, "1" = small filled circle
    final dotY = h * 0.73;
    final dotR = w * 0.055;
    final spacing = w * 0.18;
    final centerX = w / 2;

    // "0" — left of centre (open ring)
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.042;
    canvas.drawCircle(Offset(centerX - spacing, dotY), dotR, ringPaint);

    // separator dot (·)
    paint.color = Colors.white.withValues(alpha: 0.45);
    canvas.drawCircle(Offset(centerX, dotY), dotR * 0.38, paint);

    // "1" — right of centre (filled)
    paint.color = Colors.white.withValues(alpha: 0.75);
    canvas.drawCircle(Offset(centerX + spacing, dotY), dotR, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED FEATURE ROW
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedFeature extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _AnimatedFeature({required this.child, required this.delay});

  @override
  State<_AnimatedFeature> createState() => _AnimatedFeatureState();
}

class _AnimatedFeatureState extends State<_AnimatedFeature>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// PRESSABLE BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _PressableButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color color;
  final String label;
  final Color textColor;
  final BoxBorder? border;

  const _PressableButton({
    required this.onTap,
    required this.color,
    required this.label,
    required this.textColor,
    this.border,
  });

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(18),
            border: widget.border,
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: widget.textColor,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APPLE LOADING BUTTON  (shown while Apple sign-in is in progress)
// ─────────────────────────────────────────────────────────────────────────────

class _AppleLoadingButton extends StatelessWidget {
  final bool isDark;
  const _AppleLoadingButton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        color: isDark ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: isDark ? Colors.black : Colors.white,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GOOGLE BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _GoogleButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onTap;
  final ThemeNotifier theme;

  const _GoogleButton({
    required this.isLoading,
    required this.onTap,
    required this.theme,
  });

  @override
  State<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<_GoogleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isLoading ? null : (_) => _controller.forward(),
      onTapUp: widget.isLoading
          ? null
          : (_) {
              _controller.reverse();
              widget.onTap();
            },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: widget.theme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: widget.theme.border),
          ),
          child: widget.isLoading
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _GoogleLogo(size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: widget.theme.text,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GOOGLE LOGO
// ─────────────────────────────────────────────────────────────────────────────

class _GoogleLogo extends StatelessWidget {
  final double size;
  const _GoogleLogo({this.size = 24});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _GoogleLogoPainter()),
      );
}

class _GoogleLogoPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = w / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r, paint);
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
    );

    final strokeW = w * 0.22;
    final innerR = r * 0.62;
    final arcRect = Rect.fromCircle(center: Offset(cx, cy), radius: innerR);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;

    arcPaint.color = _blue;
    canvas.drawArc(arcRect, -0.52, 1.74, false, arcPaint);
    arcPaint.color = _green;
    canvas.drawArc(arcRect, 1.22, 1.05, false, arcPaint);
    arcPaint.color = _yellow;
    canvas.drawArc(arcRect, 2.27, 0.79, false, arcPaint);
    arcPaint.color = _red;
    canvas.drawArc(arcRect, 3.06, 1.14, false, arcPaint);

    paint.color = _blue;
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - strokeW / 2, r * 0.88, strokeW),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}