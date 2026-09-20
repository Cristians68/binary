import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'app_theme.dart';
import 'learning_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _revealed = false;
  int? _answer;
  bool _finishing = false;

  static const _titles = [
    'Big ideas.\nSmall lessons.',
    'A little practice.\nA lot more clarity.',
    'Your next chapter\nstarts here.',
  ];
  static const _descriptions = [
    'Build your IT knowledge one clear, useful idea at a time. Try your first flashcard.',
    'Put the idea to work. Every question comes with an explanation, so each attempt teaches you something.',
    'Find your course, build a rhythm, and turn what you learn into lasting confidence.',
  ];

  void _move(int page) {
    HapticFeedback.selectionClick();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(page,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic);
    }
  }

  Future<void> _complete() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool(kOnboardingCompleteKey, true)) {
        throw StateError('Could not save onboarding');
      }
      if (mounted) widget.onComplete();
    } catch (_) {
      if (!mounted) return;
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Could not save your preferences. Please try again.')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
              child: Row(children: [
                const AppIcon(size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('B1nary',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: theme.text,
                          fontSize: 19,
                          letterSpacing: -.7,
                          fontWeight: FontWeight.w800)),
                ),
                TextButton(
                    onPressed: _finishing ? null : _complete,
                    child: const Text('Skip')),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: 3,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, page) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StudyLabel('0${page + 1}  /  ${[
                          'LEARN',
                          'PRACTICE',
                          'GROW'
                        ][page]}'),
                        const SizedBox(height: 18),
                        Text(_titles[page],
                            style: TextStyle(
                                color: theme.text,
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                height: 1.12,
                                letterSpacing: -1.5)),
                        const SizedBox(height: 14),
                        Text(_descriptions[page],
                            style: TextStyle(
                                color: theme.subtext,
                                fontSize: 15,
                                height: 1.65)),
                        const SizedBox(height: 28),
                        _demo(page, theme),
                        const SizedBox(height: 18),
                        Text(
                            page == 2
                                ? 'First module free. No card needed.'
                                : 'A quick preview of how you’ll learn.',
                            style: TextStyle(
                                color: theme.subtext,
                                fontSize: 12,
                                height: 1.5)),
                      ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(children: [
                Semantics(
                  label: 'Step ${_page + 1} of 3',
                  child: Row(
                      children: List.generate(
                          3,
                          (i) => Expanded(
                                child: Container(
                                  height: 4,
                                  margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                                  decoration: BoxDecoration(
                                    color: i <= _page
                                        ? AppColors.primary
                                        : theme.border,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ))),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  if (_page > 0) ...[
                    IconButton(
                      onPressed: _finishing ? null : () => _move(_page - 1),
                      tooltip: 'Previous step',
                      icon: Icon(Icons.arrow_back_rounded, color: theme.text),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                      child: FilledButton(
                    onPressed: _finishing
                        ? null
                        : () => _page == 2 ? _complete() : _move(_page + 1),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                        _finishing
                            ? 'Getting ready…'
                            : _page == 2
                                ? 'Explore free lessons'
                                : 'Continue',
                        textAlign: TextAlign.center),
                  )),
                ]),
              ]),
            ),
          ]),
        )),
      ),
    );
  }

  Widget _demo(int page, ThemeNotifier theme) {
    if (page == 0) return _flashcardDemo();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.border),
      ),
      child: switch (page) {
        1 => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const StudyLabel('KNOWLEDGE CHECK', icon: Icons.bolt_rounded),
            const SizedBox(height: 20),
            Text('Which service translates a domain name into an IP address?',
                style: TextStyle(
                    color: theme.text,
                    fontSize: 21,
                    height: 1.35,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            for (final entry in ['DNS', 'DHCP'].asMap().entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: () => setState(() => _answer = entry.key),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    backgroundColor: _answer == entry.key
                        ? AppColors.primary.withValues(alpha: .08)
                        : theme.card,
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor:
                        _answer == entry.key ? AppColors.primary : theme.text,
                    side: BorderSide(
                        color: _answer == entry.key
                            ? AppColors.primary
                            : theme.border),
                  ),
                  child: Row(children: [
                    Icon(
                        _answer == entry.key
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 21),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(entry.value,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600))),
                  ]),
                ),
              ),
            if (_answer != null)
              Semantics(
                  liveRegion: true,
                  child: Text(
                      _answer == 0
                          ? 'Exactly. DNS finds the address; DHCP assigns addresses to devices.'
                          : 'Good try. DHCP assigns addresses to devices. DNS translates domain names.',
                      style: TextStyle(color: theme.subtext, height: 1.5))),
          ]),
        _ => Column(children: [
            const Align(
                alignment: Alignment.centerLeft,
                child:
                    StudyLabel('YOUR STUDY LOOP', icon: Icons.route_rounded)),
            const SizedBox(height: 24),
            _benefit(theme, CupertinoIcons.book, 'Try before you choose',
                'The first module of every course is free. No card needed.'),
            const SizedBox(height: 22),
            _benefit(
                theme,
                CupertinoIcons.arrow_2_circlepath,
                'Review what needs practice',
                'Missed quiz questions return in short review sessions.'),
            const SizedBox(height: 22),
            _benefit(theme, CupertinoIcons.checkmark_seal, 'See your progress',
                'Finish a course to earn a B1nary completion certificate.'),
          ]),
      },
    );
  }

  Widget _flashcardDemo() => LearningHero(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const StudyLabel('NETWORKING • FLASHCARD 01',
            onDark: true, icon: Icons.layers_outlined),
        const SizedBox(height: 30),
        const Text('What does\nDNS do?',
            style: TextStyle(
                color: Colors.white,
                fontSize: 29,
                fontWeight: FontWeight.w700,
                height: 1.2,
                letterSpacing: -.7)),
        const SizedBox(height: 20),
        // NOT AnimatedSize, though the growing card is what it is for.
        //
        // This sits inside LearningHero, whose Stack takes its size from this
        // subtree. A RenderAnimatedSize re-dirties itself from inside its own
        // performLayout when the child's size changes, which is only legal
        // when it is a relayout boundary — and it cannot be one while an
        // ancestor is measuring itself against it. The capture pipeline
        // caught it as four "RenderAnimatedSize was mutated in its own
        // performLayout implementation" assertions on the first onboarding
        // frame, before any tap. Reveal therefore resizes instantly.
        Align(
            alignment: Alignment.topLeft,
            child: _revealed
                ? Semantics(
                    liveRegion: true,
                    child: const Text(
                        'DNS translates domain names, such as example.com, into IP addresses that computers use.',
                        style: TextStyle(
                            color: AppColors.mint, fontSize: 15, height: 1.6)))
                : const Text('Think of it as the internet’s address book.',
                    style: TextStyle(
                        color: Color(0xFFC4D3EB), fontSize: 14, height: 1.5))),
        const SizedBox(height: 24),
        SizedBox(
            width: double.infinity,
            child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.mint,
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _revealed = !_revealed);
                },
                child: Text(
                    _revealed ? 'Hide explanation' : 'Reveal explanation',
                    textAlign: TextAlign.center))),
      ]));

  Widget _benefit(
          ThemeNotifier theme, IconData icon, String title, String body) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(color: theme.text, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(body,
              style:
                  TextStyle(color: theme.subtext, fontSize: 13, height: 1.5)),
        ])),
      ]);
}
