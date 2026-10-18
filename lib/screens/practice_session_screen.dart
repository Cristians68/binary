import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'quiz_logic.dart';

/// A local practice copy. This screen never writes scores or review schedules.
class PracticeCard {
  PracticeCard.recall(Map<String, String> card)
      : prompt = card['term'] ?? '',
        explanation = card['definition'] ?? '',
        example = card['example'] ?? '',
        options = const [],
        correctIndex = -1;

  PracticeCard.question(Map<String, dynamic> question)
      : prompt = question['question'] as String,
        explanation = question['explanation'] as String? ?? '',
        example = '',
        options = List.unmodifiable(question['answers'] as List<String>),
        correctIndex = question['correct'] as int;

  final String prompt;
  final String explanation;
  final String example;
  final List<String> options;
  final int correctIndex;
  bool get isRecall => options.isEmpty;

  PracticeCard shuffled() => isRecall
      ? this
      : PracticeCard.question(shuffleQuizQuestions([
          {
            'question': prompt,
            'answers': options,
            'correct': correctIndex,
            'explanation': explanation,
          }
        ]).single);
}

/// Retrieval with feedback, followed by an optional round of difficult items.
/// Self-assessment and immediate retries are deliberately separate from mastery.
class PracticeSessionScreen extends StatefulWidget {
  const PracticeSessionScreen({
    super.key,
    required this.cards,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.returnLabel,
  });

  final List<PracticeCard> cards;
  final String title;
  final String subtitle;
  final Color color;
  final String returnLabel;

  @override
  State<PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends State<PracticeSessionScreen> {
  final _scroll = ScrollController();
  late List<PracticeCard> _round;
  final _difficult = <PracticeCard>[];
  int _index = 0;
  int _roundNumber = 1;
  int? _selected;
  bool _revealed = false;
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    _round = widget.cards.map((card) => card.shuffled()).toList();
    _complete = _round.isEmpty;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _advance(bool recalled) {
    if (_complete || !_revealed) return;
    setState(() {
      if (!recalled) _difficult.add(_round[_index]);
      if (_index == _round.length - 1) {
        _complete = true;
      } else {
        _index++;
      }
      _revealed = false;
      _selected = null;
    });
    _scroll.jumpTo(0);
  }

  void _retry() {
    setState(() {
      _round = _difficult.map((card) => card.shuffled()).toList()..shuffle();
      _difficult.clear();
      _index = 0;
      _roundNumber++;
      _complete = false;
      _revealed = false;
      _selected = null;
    });
    _scroll.jumpTo(0);
  }

  void _choose(int index) {
    if (_revealed) return;
    setState(() {
      _selected = index;
      _revealed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final accent = theme.accent(widget.color);
    final card = _complete ? null : _round[_index];
    final filledStyle = FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
    final outlineStyle = OutlinedButton.styleFrom(
      foregroundColor: theme.text,
      side: BorderSide(color: theme.subtext),
    );
    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        backgroundColor: theme.bg,
        foregroundColor: theme.text,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.title, style: const TextStyle(fontSize: 18)),
        leading: IconButton(
          tooltip: widget.returnLabel,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: WebContentBounds(
          maxWidth: 720,
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.subtitle,
                    style: TextStyle(color: theme.subtext, height: 1.5)),
                const SizedBox(height: 20),
                if (card != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      'Round $_roundNumber · ${card.isRecall ? 'Card' : 'Question'} ${_index + 1} of ${_round.length}',
                      style: TextStyle(
                          color: theme.text, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _index / _round.length,
                    color: accent,
                    backgroundColor: theme.border,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(8),
                    semanticsLabel:
                        'Practice progress: $_index of ${_round.length} complete',
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: theme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            card.isRecall
                                ? 'RECALL BEFORE YOU REVEAL'
                                : 'ANOTHER CHANCE TO LEARN',
                            style: TextStyle(
                                color: theme.subtext,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1)),
                        const SizedBox(height: 14),
                        Semantics(
                          header: true,
                          child: Text(card.prompt,
                              style: TextStyle(
                                  color: theme.text,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35)),
                        ),
                        const SizedBox(height: 20),
                        if (card.isRecall && !_revealed)
                          Text(
                              'Explain this in your own words. Then reveal the answer and check what you remembered.',
                              style:
                                  TextStyle(color: theme.subtext, height: 1.6)),
                        if (!card.isRecall)
                          for (var i = 0; i < card.options.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Semantics(
                                button: true,
                                selected: _selected == i,
                                enabled: !_revealed,
                                onTap: _revealed ? null : () => _choose(i),
                                label:
                                    '${card.options[i]}${_revealed && i == card.correctIndex ? '. Correct answer' : _selected == i ? '. Your answer, incorrect' : ''}',
                                excludeSemantics: true,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: theme.text,
                                    disabledForegroundColor: theme.text,
                                    backgroundColor:
                                        _revealed && i == card.correctIndex
                                            ? theme.surface
                                            : null,
                                    side: BorderSide(
                                        color:
                                            _revealed && i == card.correctIndex
                                                ? accent
                                                : theme.subtext,
                                        width:
                                            _revealed && i == card.correctIndex
                                                ? 2
                                                : 1),
                                    padding: const EdgeInsets.all(16),
                                    alignment: Alignment.centerLeft,
                                  ),
                                  onPressed:
                                      _revealed ? null : () => _choose(i),
                                  child: Text(card.options[i],
                                      style: const TextStyle(height: 1.5)),
                                ),
                              ),
                            ),
                        if (_revealed)
                          Semantics(
                            liveRegion: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    card.isRecall
                                        ? 'Check your recall'
                                        : _selected == card.correctIndex
                                            ? 'Correct'
                                            : 'Keep practicing',
                                    style: TextStyle(
                                        color: theme.text,
                                        fontWeight: FontWeight.w700)),
                                if (!card.isRecall &&
                                    _selected != card.correctIndex) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                      'Correct answer: ${card.options[card.correctIndex]}',
                                      style: TextStyle(color: theme.text)),
                                ],
                                const SizedBox(height: 12),
                                Text(card.explanation,
                                    style: TextStyle(
                                        color: theme.text, height: 1.65)),
                                if (card.example.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Text(card.example,
                                      style: TextStyle(
                                          color: theme.subtext, height: 1.6)),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (card.isRecall && !_revealed)
                    FilledButton(
                      style: filledStyle,
                      onPressed: () => setState(() => _revealed = true),
                      child: const Text('Reveal answer'),
                    ),
                  if (card.isRecall && _revealed) ...[
                    Text('How well did you remember?',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.subtext)),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: filledStyle,
                      onPressed: () => _advance(true),
                      child: const Text('Got it'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: outlineStyle,
                      onPressed: () => _advance(false),
                      child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Needs practice')),
                    ),
                  ],
                  if (!card.isRecall && _revealed)
                    FilledButton(
                      style: filledStyle,
                      onPressed: () => _advance(_selected == card.correctIndex),
                      child: Text(_index == _round.length - 1
                          ? 'Finish round'
                          : 'Next question'),
                    ),
                ] else ...[
                  Icon(
                      _difficult.isEmpty
                          ? Icons.check_circle_outline_rounded
                          : Icons.school_outlined,
                      size: 56,
                      color: accent),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    header: true,
                    child: Text(
                        _round.isEmpty
                            ? 'Nothing to practice yet'
                            : 'Round $_roundNumber complete',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: theme.text,
                            fontSize: 26,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 16),
                  if (_round.isNotEmpty)
                    Text(
                        _round.first.isRecall
                            ? '${_round.length - _difficult.length} of ${_round.length} cards marked Got it'
                            : '${_round.length - _difficult.length} of ${_round.length} correct this round',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: theme.text, fontSize: 18, height: 1.5)),
                  const SizedBox(height: 12),
                  Text(
                      _difficult.isEmpty
                          ? 'Come back another day to check what stays with you. Practice does not change your course score or scheduled reviews.'
                          : 'Give the difficult items another try, or come back later. Your course score and scheduled reviews stay the same.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.subtext, height: 1.6)),
                  const SizedBox(height: 28),
                  if (_difficult.isNotEmpty) ...[
                    FilledButton(
                      style: filledStyle,
                      onPressed: _retry,
                      child: Text('Practice remaining (${_difficult.length})',
                          textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton(
                    style: outlineStyle,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(widget.returnLabel,
                            textAlign: TextAlign.center)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
