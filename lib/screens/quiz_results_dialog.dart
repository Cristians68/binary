import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'quiz_logic.dart';

/// A snapshot of the answer as displayed, before a retake shuffles options.
class QuizAnswer {
  const QuizAnswer({
    required this.number,
    required this.question,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.explanation,
  });

  final int number;
  final String question;
  final String selectedAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final String explanation;
}

/// Read-only feedback for a completed attempt. Reviewing never submits a new
/// score or changes the separate spaced-repetition schedule.
class QuizResultsDialog extends StatefulWidget {
  const QuizResultsDialog({
    super.key,
    required this.answers,
    required this.practiceOnly,
    required this.color,
    this.celebration,
    this.onPracticeMistakes,
  });

  final List<QuizAnswer> answers;
  final bool practiceOnly;
  final Color color;
  final Widget? celebration;
  final VoidCallback? onPracticeMistakes;

  @override
  State<QuizResultsDialog> createState() => _QuizResultsDialogState();
}

class _QuizResultsDialogState extends State<QuizResultsDialog> {
  bool _reviewing = false;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final successColor = theme.isDark ? AppColors.mint : AppColors.green;
    final outlineStyle = OutlinedButton.styleFrom(
      foregroundColor: theme.text,
      side: BorderSide(color: theme.subtext),
    );
    final score = widget.answers.where((answer) => answer.isCorrect).length;
    final total = widget.answers.length;
    final passed = quizPassed(score, total);
    final missed = widget.answers.where((answer) => !answer.isCorrect).toList();
    final review = missed.isEmpty ? widget.answers : missed;
    final heading = _reviewing
        ? missed.isEmpty
            ? 'Your answers'
            : 'Learn from your mistakes'
        : widget.practiceOnly
            ? 'Practice complete'
            : passed
                ? 'Great work!'
                : 'Keep studying!';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _reviewing) setState(() => _reviewing = false);
      },
      child: Dialog(
        backgroundColor: theme.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              SingleChildScrollView(
                // Summary and review each start at the top, even at large text.
                key: ValueKey(_reviewing),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      _reviewing
                          ? Icons.menu_book_rounded
                          : passed
                              ? Icons.verified_rounded
                              : Icons.school_rounded,
                      color: passed ? successColor : widget.color,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text(heading,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: theme.text)),
                    ),
                    const SizedBox(height: 12),
                    if (_reviewing) ...[
                      Text(
                        missed.isEmpty
                            ? 'Every answer was correct. Revisit the explanations below.'
                            : '${missed.length} ${missed.length == 1 ? 'question' : 'questions'} to revisit before your next attempt.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.subtext, height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      for (final answer in review) _answerCard(answer, theme),
                      OutlinedButton(
                        style: outlineStyle,
                        onPressed: () => setState(() => _reviewing = false),
                        child: const Text('Back to results'),
                      ),
                    ] else ...[
                      if (widget.practiceOnly) ...[
                        Text('Sample results do not count toward your course.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.subtext)),
                        const SizedBox(height: 8),
                      ],
                      Text('You scored $score out of $total',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.subtext, fontSize: 15)),
                      Text('${quizScorePercent(score, total)}%',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: passed ? successColor : theme.text,
                              fontSize: 40,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                          'Pass mark: ${quizPassMark(total)} of $total correct',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.subtext)),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        style: outlineStyle,
                        onPressed: () => setState(() => _reviewing = true),
                        icon: const Icon(Icons.menu_book_rounded, size: 18),
                        label: Text(
                          missed.isEmpty
                              ? 'Review answers'
                              : 'Review mistakes (${missed.length})',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    if (missed.isNotEmpty &&
                        widget.onPracticeMistakes != null) ...[
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                        onPressed: widget.onPracticeMistakes,
                        icon: const Icon(Icons.psychology_outlined),
                        label: Text(
                            'Practice missed questions (${missed.length})',
                            textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 8),
                      Text('A focused round. Your quiz score stays the same.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.subtext, fontSize: 12)),
                    ],
                    const SizedBox(height: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16)),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Back to course',
                          textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: theme.text),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
              if (!_reviewing && widget.celebration != null)
                IgnorePointer(child: widget.celebration!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _answerCard(QuizAnswer answer, ThemeNotifier theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Question ${answer.number}',
              style: TextStyle(color: theme.subtext, fontSize: 12)),
          const SizedBox(height: 6),
          Text(answer.question,
              style: TextStyle(
                  color: theme.text, fontWeight: FontWeight.w600, height: 1.4)),
          const SizedBox(height: 12),
          if (!answer.isCorrect) ...[
            Text('Your answer',
                style: TextStyle(color: theme.subtext, fontSize: 12)),
            Text(answer.selectedAnswer, style: TextStyle(color: theme.text)),
            const SizedBox(height: 10),
          ],
          Text('Correct answer',
              style: TextStyle(
                  color: theme.isDark ? AppColors.mint : AppColors.green,
                  fontWeight: FontWeight.w600)),
          Text(answer.correctAnswer, style: TextStyle(color: theme.text)),
          if (answer.explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(answer.explanation,
                style: TextStyle(color: theme.subtext, height: 1.5)),
          ],
        ],
      ),
    );
  }
}
