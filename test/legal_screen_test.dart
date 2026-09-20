import 'package:binary/screens/app_theme.dart';
import 'package:binary/screens/legal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) =>
        AppTheme(notifier: ThemeNotifier(), child: child!),
    home: const LegalScreen(),
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Certification Disclaimer'));
  await tester.pumpAndSettle();
}

void main() {
  group('certification disclaimer', () {
    // The sheet is built by showCupertinoModalPopup, which puts it in a route
    // of its own — outside the Scaffold, and so outside any Material. With no
    // Material there is no DefaultTextStyle from the theme, so text fell back
    // to WidgetsApp's error style, which carries a double YELLOW UNDERLINE.
    // Every style in the sheet sets colour and size but never `decoration`,
    // and an unset field is inherited, so every line came out underlined.
    // That is the "it highlights everything" report.
    testWidgets('its text does not inherit the error style underline',
        (tester) async {
      await _pump(tester);

      expect(find.text('Got it'), findsOneWidget);

      final style =
          DefaultTextStyle.of(tester.element(find.text('Got it'))).style;
      expect(
        style.decoration ?? TextDecoration.none,
        TextDecoration.none,
        reason: 'text inside the disclaimer sheet is falling back to '
            "WidgetsApp's error style, which underlines it in yellow",
      );
    });

    testWidgets('the sheet has a Material ancestor', (tester) async {
      await _pump(tester);

      expect(
        find.ancestor(
          of: find.text('Got it'),
          matching: find.byType(Material),
        ),
        findsWidgets,
      );
    });

    // Six trademark rows and two paragraphs do not fit a short screen, and fit
    // no screen at all once the reader has turned text size up. Unbounded, the
    // Column overflowed and clipped away its own dismiss button.
    testWidgets('it scrolls rather than overflowing on a short screen',
        (tester) async {
      tester.view.physicalSize = const Size(400, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester);

      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(find.text('Got it'), findsOneWidget);
    });
  });
}
