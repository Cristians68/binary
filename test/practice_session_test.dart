import 'package:binary/screens/app_theme.dart';
import 'package:binary/screens/practice_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> open(WidgetTester tester, List<PracticeCard> cards,
      {double scale = 1, bool dark = false}) async {
    final theme = ThemeNotifier(initialIsDark: dark);
    await tester.pumpWidget(MaterialApp(
      theme: appMaterialTheme(theme),
      builder: (context, child) => AppTheme(
        notifier: theme,
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
      home: PracticeSessionScreen(
        cards: cards,
        title: 'Recall practice',
        subtitle: 'Network basics',
        color: Colors.amber,
        returnLabel: 'Back to lesson',
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final target = find.text(label).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  final recall = [
    PracticeCard.recall({
      'term': 'Explain DNS',
      'definition': 'Resolves names',
      'example': 'Find a server'
    }),
    PracticeCard.recall(
        {'term': 'Explain DHCP', 'definition': 'Assigns addresses'}),
  ];
  final questions = [
    PracticeCard.question({
      'question': 'Choose DNS',
      'answers': ['DNS', 'DHCP'],
      'correct': 0,
      'explanation': 'DNS resolves names.'
    }),
    PracticeCard.question({
      'question': 'Choose TLS',
      'answers': ['TLS', 'Backup'],
      'correct': 0,
      'explanation': 'TLS protects data in transit.'
    }),
  ];

  testWidgets(
      'recall hides definitions and examples until revealed, then retries only difficult cards',
      (tester) async {
    await open(tester, recall);
    expect(find.text('Resolves names'), findsNothing);
    expect(find.text('Find a server'), findsNothing);
    expect(find.text('Got it'), findsNothing);
    await tap(tester, 'Reveal answer');
    expect(find.text('Resolves names'), findsOneWidget);
    expect(find.text('Find a server'), findsOneWidget);
    await tap(tester, 'Needs practice');
    expect(find.text('Explain DHCP'), findsOneWidget);
    expect(find.text('Assigns addresses'), findsNothing);
    await tap(tester, 'Reveal answer');
    await tap(tester, 'Got it');
    expect(find.text('1 of 2 cards marked Got it'), findsOneWidget);
    await tap(tester, 'Practice remaining (1)');
    expect(find.text('Round 2 · Card 1 of 1'), findsOneWidget);
    expect(find.text('Explain DNS'), findsOneWidget);
    expect(find.text('Resolves names'), findsNothing);
    await tap(tester, 'Reveal answer');
    await tap(tester, 'Got it');
    expect(find.text('1 of 1 cards marked Got it'), findsOneWidget);
    expect(find.textContaining('Practice remaining'), findsNothing);
  });

  testWidgets(
      'focused practice preserves answer mapping and locks an answer after selection',
      (tester) async {
    await open(tester, questions);
    await tap(tester, 'DHCP');
    expect(find.text('Correct answer: DNS'), findsOneWidget);
    await tap(tester, 'DNS');
    expect(find.text('Keep practicing'), findsOneWidget);
    await tap(tester, 'Next question');
    expect(find.text('DNS resolves names.'), findsNothing);
    await tap(tester, 'TLS');
    expect(find.text('Correct'), findsOneWidget);
    await tap(tester, 'Finish round');
    expect(find.text('1 of 2 correct this round'), findsOneWidget);
    await tap(tester, 'Practice remaining (1)');
    expect(find.text('Choose DNS'), findsOneWidget);
    expect(find.text('Round 2 · Question 1 of 1'), findsOneWidget);
    await tap(tester, 'DNS');
    expect(find.text('Correct'), findsOneWidget);
    await tap(tester, 'Finish round');
    expect(find.text('1 of 1 correct this round'), findsOneWidget);
  });

  testWidgets('answers expose a screen-reader action and feedback announcement',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await open(tester, [questions.first]);
      final node = tester.getSemantics(find.bySemanticsLabel('DNS'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget);
      expect(find.bySemanticsLabel('DNS. Correct answer'), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });

  for (final dark in [false, true]) {
    testWidgets('practice and summary fit 320px doubled text, dark=$dark',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(tester, [questions.first], scale: 2, dark: dark);
      await tap(tester, 'DHCP');
      await tap(tester, 'Finish round');
      await tap(tester, 'Practice remaining (1)');
      expect(
          find.text('Round 2 · Question 1 of 1').hitTestable(), findsOneWidget);
      await tap(tester, 'DNS');
      await tap(tester, 'Finish round');
      await tester.ensureVisible(find.text('Back to lesson'));
      expect(find.text('Back to lesson').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty practice has a usable return action', (tester) async {
    await open(tester, []);
    expect(find.text('Nothing to practice yet'), findsOneWidget);
    expect(find.text('Back to lesson'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
