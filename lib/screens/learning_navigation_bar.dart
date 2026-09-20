import 'package:flutter/material.dart';
import 'app_theme.dart';

class LearningNavigationBar extends StatelessWidget {
  const LearningNavigationBar(
      {super.key, required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return DecoratedBox(
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: theme.border))),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: theme.navBg,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.primary.withValues(alpha: .12),
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? (theme.isDark ? const Color(0xFF9BB6FF) : AppColors.primary)
                  : theme.subtext)),
        ),
        child: NavigationBar(
          height: 76,
          selectedIndex: currentIndex,
          onDestinationSelected: onTap,
          animationDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          destinations: const [
            (icon: Icons.home_rounded, label: 'Home'),
            (icon: Icons.book_rounded, label: 'Courses'),
            (icon: Icons.bar_chart_rounded, label: 'Progress'),
            (icon: Icons.person_rounded, label: 'Profile'),
          ]
              .map((tab) => NavigationDestination(
                    icon: Icon(tab.icon, color: theme.subtext, size: 23),
                    selectedIcon: Icon(tab.icon,
                        color: theme.isDark
                            ? const Color(0xFF9BB6FF)
                            : AppColors.primary,
                        size: 23),
                    label: tab.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}
