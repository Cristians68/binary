import 'package:binary/screens/app_router.dart';
import 'package:binary/screens/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
    WidgetTester tester, Route<void> Function(Widget) route) async {
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) =>
        AppTheme(notifier: ThemeNotifier(), child: child!),
    home: _Landing(route: route),
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  expect(find.text('second page'), findsOneWidget);
}

class _Landing extends StatelessWidget {
  const _Landing({required this.route});

  /// Builds the route under test, so one landing page can exercise each of
  /// AppRouter's transitions.
  final Route<void> Function(Widget page) route;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.push(context, route(const _Second())),
          child: const Text('go'),
        ),
      ),
    );
  }
}

class _Second extends StatelessWidget {
  const _Second();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('second page')));
}

/// Drags in from the leading edge the way a thumb does.
Future<void> _swipeFromLeftEdge(
  WidgetTester tester, {
  double distance = 600,
}) async {
  final gesture = await tester.startGesture(const Offset(3, 300));
  for (var moved = 0.0; moved < distance; moved += 60) {
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('swipe back', () {
    testWidgets('AppRouter.push can be dismissed by dragging from the edge',
        (tester) async {
      await _pump(tester, (p) => AppRouter.push<void>(p));

      await _swipeFromLeftEdge(tester);

      expect(find.text('second page'), findsNothing,
          reason: 'an edge drag should have popped the route');
      expect(find.text('go'), findsOneWidget);
    });

    testWidgets('AppRouter.slide can be dismissed by dragging from the edge',
        (tester) async {
      await _pump(tester, (p) => AppRouter.slide<void>(p));

      await _swipeFromLeftEdge(tester);

      expect(find.text('second page'), findsNothing);
    });

    testWidgets('a short drag springs the page back instead of popping',
        (tester) async {
      await _pump(tester, (p) => AppRouter.push<void>(p));

      // Barely moved, and released without a flick: the page should stay.
      final gesture = await tester.startGesture(const Offset(3, 300));
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('second page'), findsOneWidget);
    });

    testWidgets('a drag from the middle of the page does nothing',
        (tester) async {
      await _pump(tester, (p) => AppRouter.push<void>(p));

      final gesture = await tester.startGesture(const Offset(400, 300));
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(60, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('second page'), findsOneWidget,
          reason: 'only the leading edge starts a back gesture');
    });

    testWidgets('AppRouter.fade stays put — it replaces the session',
        (tester) async {
      await _pump(tester, (p) => AppRouter.fade<void>(p));

      await _swipeFromLeftEdge(tester);

      expect(find.text('second page'), findsOneWidget,
          reason: 'sign-in and sign-out transitions must not be swipeable');
    });
  });
}
