import 'dart:math' as math;

import 'package:binary/screens/app_theme.dart';
import 'package:binary/screens/login_screen.dart';
import 'package:binary/screens/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

double contrast(Color foreground, Color background) {
  final painted = Color.alphaBlend(foreground, background).computeLuminance();
  final behind = background.computeLuminance();
  return (math.max(painted, behind) + .05) / (math.min(painted, behind) + .05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final light = ThemeNotifier();
  final dark = ThemeNotifier(initialIsDark: true);
  final surfaces = [light.bg, light.surface, light.card, light.navBg];

  test('light primary and secondary text remain readable on every surface', () {
    for (final surface in surfaces) {
      for (final text in [light.text, light.subtext]) {
        expect(contrast(text, surface), greaterThanOrEqualTo(4.5));
      }
      expect(contrast(light.outline, surface), greaterThanOrEqualTo(3));
    }
  });

  test('catalogue accents support text, tinted labels and white button text',
      () {
    // Include extreme colors and a range wider than today's catalogue: the
    // next published course must not reintroduce unreadable cyan/yellow labels.
    final colors = [
      Colors.white,
      Colors.black,
      Colors.transparent,
      AppColors.primary,
      AppColors.green,
      AppColors.amber,
      AppColors.red,
      for (var hue = 0; hue < 360; hue += 15)
        for (final value in [.3, .6, 1.0])
          HSVColor.fromAHSV(1, hue.toDouble(), .8, value).toColor(),
    ];
    for (final source in colors) {
      final accent = light.accent(source);
      for (final surface in surfaces) {
        expect(contrast(accent, surface), greaterThanOrEqualTo(4.5),
            reason: 'Foreground $source on $surface');
      }
      expect(contrast(Colors.white, accent), greaterThanOrEqualTo(4.5));
      final label = Color.alphaBlend(source.withValues(alpha: .12), light.card);
      expect(contrast(accent, label), greaterThanOrEqualTo(4.5),
          reason: 'Tinted badge for $source');
      expect(dark.accent(source), source,
          reason: 'Dark mode keeps the original catalogue color');
    }
  });

  for (final isDark in [false, true]) {
    testWidgets('login footer wraps at 320px with doubled text (dark=$isDark)',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final theme = ThemeNotifier(initialIsDark: isDark);
      await tester.pumpWidget(MaterialApp(
        theme: appMaterialTheme(theme),
        builder: (context, child) => AppTheme(
          notifier: theme,
          child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
        ),
        home: const LoginScreen(),
      ));
      await tester.pumpAndSettle();
      final footer =
          find.text('Your progress is saved securely to your account');
      await tester.ensureVisible(footer);
      expect(footer.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    for (final entry in {
      'login': const LoginScreen(),
      'signup': const SignupScreen()
    }.entries) {
      testWidgets(
          '${entry.key} fields have one outline and a visible focus state (dark=$isDark)',
          (tester) async {
        final theme = ThemeNotifier(initialIsDark: isDark);
        await tester.pumpWidget(MaterialApp(
          theme: appMaterialTheme(theme),
          builder: (context, child) => AppTheme(notifier: theme, child: child!),
          home: entry.value,
        ));
        await tester.pumpAndSettle();
        final field = find.byType(TextField).first;
        await tester.ensureVisible(field);
        final decoratorFinder =
            find.descendant(of: field, matching: find.byType(InputDecorator));
        var decorator = tester.widget<InputDecorator>(decoratorFinder);
        if (isDark) {
          expect(decorator.decoration.border, InputBorder.none);
          expect(decorator.decoration.enabledBorder, isNull);
          expect(decorator.decoration.focusedBorder, isNull);
        } else {
          final decoration = decorator.decoration;
          expect(contrast(decoration.hintStyle!.color!, decoration.fillColor!),
              greaterThanOrEqualTo(4.5));
          expect(
              contrast(decoration.enabledBorder!.borderSide.color,
                  decoration.fillColor!),
              greaterThanOrEqualTo(3));
          // The old outer Container would draw an extra rectangle around the
          // theme's outline, especially noticeable when keyboard focus moves.
          final wrappers = tester.widgetList<Container>(
              find.ancestor(of: field, matching: find.byType(Container)));
          expect(
              wrappers.where((w) =>
                  w.decoration is BoxDecoration &&
                  (w.decoration! as BoxDecoration).border != null),
              isEmpty);
        }
        await tester.tap(field);
        await tester.pumpAndSettle();
        decorator = tester.widget<InputDecorator>(decoratorFinder);
        expect(decorator.isFocused, isTrue);
        if (!isDark) {
          expect(
              contrast(decorator.decoration.focusedBorder!.borderSide.color,
                  decorator.decoration.fillColor!),
              greaterThanOrEqualTo(3));
          expect(
              decorator.decoration.focusedBorder!.borderSide.width,
              greaterThan(
                  decorator.decoration.enabledBorder!.borderSide.width));
        }
        await tester.enterText(field, 'Alex');
        expect(find.text('Alex'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
