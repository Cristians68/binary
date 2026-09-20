import 'package:flutter/material.dart';
import 'app_theme.dart';

class StudyLabel extends StatelessWidget {
  const StudyLabel(this.text,
      {super.key,
      this.color = AppColors.primary,
      this.icon,
      this.onDark = false});
  final String text;
  final Color color;
  final IconData? icon;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: onDark
                ? Colors.white.withValues(alpha: .10)
                : color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(9)),
        child: Text.rich(
            TextSpan(children: [
              if (icon != null)
                WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Icon(icon,
                            size: 14, color: onDark ? AppColors.mint : color))),
              TextSpan(text: text),
            ]),
            style: TextStyle(
                color: onDark ? Colors.white : color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.3)),
      );
}

class LearningHero extends StatelessWidget {
  const LearningHero({super.key, required this.child, this.padding = 24});
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.ink, Color(0xFF254B8C)]),
            boxShadow: [
              BoxShadow(
                  color: AppColors.ink.withValues(alpha: .12),
                  blurRadius: 24,
                  offset: const Offset(0, 10))
            ]),
        child: Stack(children: [
          Positioned(
              right: -64,
              top: -70,
              child: ExcludeSemantics(
                  child: IgnorePointer(
                      child: SizedBox(
                          width: 220,
                          height: 220,
                          child: CustomPaint(painter: _OrbitPainter()))))),
          Padding(padding: EdgeInsets.all(padding), child: child),
        ]),
      );
}

class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: .09);
    final center = size.center(Offset.zero);
    for (final radius in [48.0, 76.0, 104.0]) {
      canvas.drawCircle(center, radius, paint);
    }
    canvas.drawCircle(center + const Offset(-64, 40), 5,
        Paint()..color = AppColors.mint.withValues(alpha: .55));
  }

  @override
  bool shouldRepaint(_OrbitPainter oldDelegate) => false;
}
