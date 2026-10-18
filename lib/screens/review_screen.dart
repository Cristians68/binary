import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart';

import '../course_catalog.dart';
import 'app_theme.dart';
import 'learning_widgets.dart';
import 'quiz_logic.dart';
import 'review_logic.dart';
import 'review_service.dart';
import 'service_backend.dart';

/// A spaced-repetition session over questions the user previously got wrong.
///
/// Everything shown here comes from local storage — the full question text,
/// options and explanation were saved at the moment of the miss — so a session
/// runs with no network and no Firestore read. See [ReviewService] for why the
/// queue is local rather than synced.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final String? _learnerUid = ServiceBackend.uid;
  bool _loading = true;
  bool _accountChanged = false;
  String? _nextDueLabel;
  int _dueCount = 0;
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _items = [];
  int _index = 0;
  int _correct = 0;
  int? _selected;
  bool _answered = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final queue = await ReviewService.all();
    final now = DateTime.now();
    final allDue = dueReviewItems(queue, now);
    final due = allDue.take(ReviewService.maxSessionLength).toList();
    final dueCount = allDue.length;
    final nextDue = nextReviewDueLabel(queue, now);
    if (!mounted) return;
    if (_learnerUid == null || ServiceBackend.uid != _learnerUid) {
      setState(() {
        _accountChanged = true;
        _loading = false;
      });
      return;
    }

    // The stored `correct` index refers to the option order as it was when the
    // question was missed. Reuse the quiz shuffler so a review session does not
    // simply retrain the position of the answer.
    final prepared = shuffleQuizQuestions(
      due
          .map((i) => {
                'question': i['question'],
                'answers': List<String>.from(i['answers'] as List? ?? const []),
                'correct': i['correct'],
                'explanation': i['explanation'] ?? '',
              })
          .toList(),
      rng: Random(),
    );

    // Carry the identity and course across, since shuffleQuizQuestions returns
    // only the four presentation fields.
    for (var i = 0; i < prepared.length; i++) {
      prepared[i]['id'] = due[i]['id'];
      prepared[i]['courseId'] = due[i]['courseId'];
      prepared[i]['courseTag'] = due[i]['courseTag'];
      prepared[i]['box'] = due[i]['box'];
    }

    if (!mounted) return;
    setState(() {
      _items = prepared;
      _dueCount = dueCount;
      _nextDueLabel = nextDue;
      _loading = false;
    });
  }

  void _select(int index) {
    if (_answered) return;
    if (ServiceBackend.uid != _learnerUid) {
      setState(() => _accountChanged = true);
      return;
    }
    HapticFeedback.selectionClick();
    final item = _items[_index];
    final isRight = index == item['correct'];

    setState(() {
      _selected = index;
      _answered = true;
      if (isRight) _correct++;
    });

    ReviewService.submitResult(
        id: item['id'] as String, correct: isRight, userId: _learnerUid);
  }

  void _next() {
    if (ServiceBackend.uid != _learnerUid) {
      setState(() => _accountChanged = true);
      return;
    }
    HapticFeedback.selectionClick();
    if (_index < _items.length - 1) {
      setState(() {
        _index++;
        _selected = null;
        _answered = false;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } else {
      setState(() => _finished = true);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return CupertinoPageScaffold(
      backgroundColor: theme.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: theme.navBg,
        border: Border(bottom: BorderSide(color: theme.border, width: 0.5)),
        middle: Text('Review', style: TextStyle(color: theme.text)),
      ),
      child: DefaultTextStyle(
        style:
            Theme.of(context).textTheme.bodyMedium!.copyWith(color: theme.text),
        child: SafeArea(
          child: _loading
              ? const Center(child: CupertinoActivityIndicator())
              : _accountChanged
                  ? _EmptyState(theme: theme, accountChanged: true)
                  : _items.isEmpty
                      ? _EmptyState(theme: theme, nextDueLabel: _nextDueLabel)
                      : _finished
                          ? _Summary(
                              theme: theme,
                              correct: _correct,
                              total: _items.length,
                              remaining: (_dueCount - _items.length)
                                  .clamp(0, _dueCount),
                              onDone: () => Navigator.of(context).pop(),
                            )
                          : _questionView(theme),
        ),
      ),
    );
  }

  Widget _questionView(ThemeNotifier theme) {
    final item = _items[_index];
    final answers = List<String>.from(item['answers'] as List);
    final correctIndex = item['correct'] as int;
    final courseTag = (item['courseTag'] ?? '') as String;

    return WebContentBounds(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text(
                      courseTag.isEmpty ? 'Review' : displayTitle(courseTag),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.indigo,
                      ),
                    ),
                    Text(
                      'Question ${_index + 1} of ${_items.length}',
                      style: TextStyle(fontSize: 13, color: theme.subtext),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicatorLike(
                    value: (_index + 1) / _items.length,
                    background: theme.border,
                    foreground: AppColors.indigo,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                Text(
                  item['question'] as String,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: theme.text,
                  ),
                ),
                const SizedBox(height: 24),
                for (var i = 0; i < answers.length; i++)
                  _AnswerTile(
                    theme: theme,
                    label: answers[i],
                    state: !_answered
                        ? _TileState.idle
                        : i == correctIndex
                            ? _TileState.correct
                            : i == _selected
                                ? _TileState.wrong
                                : _TileState.idle,
                    selected: i == _selected,
                    onTap: _answered ? null : () => _select(i),
                  ),
                if (_answered) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.border),
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StudyLabel(
                            _selected == correctIndex
                                ? 'Correct'
                                : 'Keep practicing',
                            icon: _selected == correctIndex
                                ? CupertinoIcons.check_mark_circled
                                : CupertinoIcons.arrow_2_circlepath,
                            color: _selected == correctIndex
                                ? AppColors.green
                                : AppColors.indigo,
                          ),
                          const SizedBox(height: 10),
                          if (_selected != correctIndex) ...[
                            Text('Correct answer: ${answers[correctIndex]}',
                                style: TextStyle(
                                    color: theme.text,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4)),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            (item['explanation'] as String).isEmpty
                                ? 'Keep going — this one will come back until it sticks.'
                                : item['explanation'] as String,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: theme.subtext,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_answered)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: CupertinoButton.filled(
                borderRadius: BorderRadius.circular(14),
                onPressed: _next,
                child: Text(_index < _items.length - 1 ? 'Next' : 'Finish'),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Answer tile ─────────────────────────────────────────────────────────────

enum _TileState { idle, correct, wrong }

class _AnswerTile extends StatelessWidget {
  final ThemeNotifier theme;
  final String label;
  final _TileState state;
  final VoidCallback? onTap;
  final bool selected;

  const _AnswerTile({
    required this.theme,
    required this.label,
    required this.state,
    required this.onTap,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final (border, bg, icon) = switch (state) {
      _TileState.correct => (
          theme.accent(AppColors.green),
          AppColors.green.withValues(alpha: 0.12),
          CupertinoIcons.check_mark_circled_solid,
        ),
      _TileState.wrong => (
          theme.accent(AppColors.red),
          AppColors.red.withValues(alpha: 0.12),
          CupertinoIcons.xmark_circle_fill,
        ),
      _TileState.idle => (theme.outline, theme.card, null),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        enabled: onTap != null,
        excludeSemantics: true,
        onTap: onTap,
        selected: selected,
        label: state == _TileState.correct
            ? '$label. Correct answer'
            : state == _TileState.wrong
                ? '$label. Your answer, incorrect'
                : label,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: theme.text,
                    ),
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 12),
                  Icon(icon, color: border, size: 22),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Slim progress bar ───────────────────────────────────────────────────────

class LinearProgressIndicatorLike extends StatelessWidget {
  final double value;
  final Color background;
  final Color foreground;

  const LinearProgressIndicatorLike({
    super.key,
    required this.value,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      color: background,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(color: foreground),
      ),
    );
  }
}

// ── Empty and summary states ────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final ThemeNotifier theme;
  final String? nextDueLabel;
  final bool accountChanged;
  const _EmptyState(
      {required this.theme, this.nextDueLabel, this.accountChanged = false});

  @override
  Widget build(BuildContext context) {
    return WebContentBounds(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.checkmark_seal_fill,
                  size: 56, color: AppColors.green),
              const SizedBox(height: 20),
              Text(
                accountChanged
                    ? 'Your account changed'
                    : nextDueLabel != null
                        ? 'You’re all caught up'
                        : 'Nothing to review',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: theme.text,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                accountChanged
                    ? 'Reopen Review from Home to study with your current account.'
                    : nextDueLabel != null
                        ? 'Your saved questions are scheduled for later. $nextDueLabel. Keep learning while they settle in.'
                        : 'Take a course quiz first. Questions you miss come here for short practice sessions, with explanations to help them stick.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 15, height: 1.5, color: theme.subtext),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final ThemeNotifier theme;
  final int correct;
  final int total;
  final int remaining;
  final VoidCallback onDone;

  const _Summary({
    required this.theme,
    required this.correct,
    required this.total,
    required this.remaining,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final percent = quizScorePercent(correct, total);
    final strong = percent >= 80;

    return WebContentBounds(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                strong
                    ? CupertinoIcons.star_circle_fill
                    : CupertinoIcons.arrow_2_circlepath_circle_fill,
                size: 56,
                color: strong ? AppColors.green : AppColors.indigo,
              ),
              const SizedBox(height: 20),
              Text(
                strong ? 'Session complete' : 'Good progress',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: theme.text,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'You got $correct of $total right.',
                style: TextStyle(fontSize: 16, color: theme.subtext),
              ),
              const SizedBox(height: 8),
              Text(
                strong
                    ? 'The ones you cleared move further out. Anything you missed '
                        'comes back sooner.'
                    : 'Everything you missed returns shortly — that is the point.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 14, height: 1.5, color: theme.subtext),
              ),
              const SizedBox(height: 28),
              if (remaining > 0) ...[
                Text(
                    '$remaining more due question${remaining == 1 ? '' : 's'} waiting. Start another session from Home when you’re ready.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.subtext, height: 1.5)),
                const SizedBox(height: 20),
              ],
              Text('Review practice does not change course completion.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: theme.subtext, fontSize: 12, height: 1.5)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(14),
                  onPressed: onDone,
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
