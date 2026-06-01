import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import 'courses_screen.dart';
import 'progress_screen.dart';
import 'profile_screen.dart';
import 'app_theme.dart';

// Desktop sidebar is shown when the viewport is at least this wide AND we're on web.
const double _kSidebarBreakpoint = 720;
const double _kSidebarWidth     = 240;

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  static const List<Widget> _screens = [
    HomeScreen(),
    CoursesScreen(),
    ProgressScreen(),
    ProfileScreen(),
  ];

  static const List<_TabItem> _tabs = [
    _TabItem(icon: Icons.home_rounded,      label: 'Home'),
    _TabItem(icon: Icons.book_rounded,      label: 'Courses'),
    _TabItem(icon: Icons.bar_chart_rounded, label: 'Progress'),
    _TabItem(icon: Icons.person_rounded,    label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    _controller.forward(from: 0).then((_) {
      if (mounted) setState(() => _currentIndex = index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final isWide = kIsWeb &&
        MediaQuery.of(context).size.width >= _kSidebarBreakpoint;

    if (isWide) {
      return _buildWideLayout(context, theme);
    }
    return _buildNarrowLayout(context, theme);
  }

  // ── Desktop: sidebar + content ───────────────────────────────────────────────

  Widget _buildWideLayout(BuildContext context, ThemeNotifier theme) {
    return Scaffold(
      backgroundColor: theme.bg,
      body: Row(
        children: [
          _SideNav(
            currentIndex: _currentIndex,
            tabs: _tabs,
            onTap: _onTabTapped,
            theme: theme,
          ),
          Container(width: 1, color: theme.border),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: IndexedStack(index: _currentIndex, children: _screens),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile: bottom nav bar ───────────────────────────────────────────────────

  Widget _buildNarrowLayout(BuildContext context, ThemeNotifier theme) {
    return Scaffold(
      backgroundColor: theme.bg,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: IndexedStack(index: _currentIndex, children: _screens),
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentIndex,
        tabs: _tabs,
        onTap: _onTabTapped,
      ),
    );
  }
}

// ── Shared tab item ───────────────────────────────────────────────────────────

class _TabItem {
  final IconData icon;
  final String   label;
  const _TabItem({required this.icon, required this.label});
}

// ─────────────────────────────────────────────────────────────────────────────
// DESKTOP SIDEBAR
// ─────────────────────────────────────────────────────────────────────────────

class _SideNav extends StatelessWidget {
  final int                  currentIndex;
  final List<_TabItem>       tabs;
  final ValueChanged<int>    onTap;
  final ThemeNotifier        theme;

  const _SideNav({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kSidebarWidth,
      color: theme.navBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Logo ──────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.30),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'B',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Binary.',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.text,
                          letterSpacing: -0.6,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'IT Cert Prep',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.subtext,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Section label ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Text(
                'NAVIGATION',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: theme.subtext.withValues(alpha: 0.6),
                  letterSpacing: 1.4,
                ),
              ),
            ),

            // ── Nav items ─────────────────────────────────────────────────────
            ...List.generate(tabs.length, (i) => _SideNavItem(
              icon:    tabs[i].icon,
              label:   tabs[i].label,
              active:  currentIndex == i,
              onTap:   () => onTap(i),
              theme:   theme,
            )),

            const Spacer(),

            // ── Footer ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 1, color: theme.border),
                  const SizedBox(height: 14),
                  Text(
                    'B1nary Academy',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.subtext,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Master IT. Get certified.',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.subtext.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Individual sidebar nav item with hover state ──────────────────────────────

class _SideNavItem extends StatefulWidget {
  final IconData      icon;
  final String        label;
  final bool          active;
  final VoidCallback  onTap;
  final ThemeNotifier theme;

  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.theme,
  });

  @override
  State<_SideNavItem> createState() => _SideNavItemState();
}

class _SideNavItemState extends State<_SideNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final theme  = widget.theme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: theme.isDark ? 0.14 : 0.08)
                : _hovered
                    ? theme.surface
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: active
                ? Border.all(
                    color: AppColors.primary.withValues(alpha: 0.20),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 19,
                color: active ? AppColors.primary : theme.subtext,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? AppColors.primary : theme.subtext,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (active)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
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
// MOBILE BOTTOM NAV BAR  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  final int                currentIndex;
  final List<_TabItem>     tabs;
  final ValueChanged<int>  onTap;

  @override
  Widget build(BuildContext context) {
    final theme         = AppTheme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        top:    12,
        bottom: bottomPadding > 0 ? bottomPadding : 12,
      ),
      decoration: BoxDecoration(
        color:  theme.navBg,
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(tabs.length, (i) => _NavTab(
          icon:   tabs[i].icon,
          label:  tabs[i].label,
          active: currentIndex == i,
          onTap:  () => onTap(i),
        )),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData     icon;
  final String       label;
  final bool         active;
  final VoidCallback onTap;

  static const _purple = AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? _purple.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? _purple : theme.subtext, size: 22),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize:   10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color:      active ? _purple : theme.subtext,
                letterSpacing: active ? 0.2 : 0,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
