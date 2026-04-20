import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'progress_service.dart';
import 'notification_service.dart';
import 'certificate_screen.dart';

class QuizScreen extends StatefulWidget {
  final String moduleTitle;
  final String courseTag;
  final Color color;
  final String moduleId;
  final String courseId;

  const QuizScreen({
    super.key,
    required this.moduleTitle,
    required this.courseTag,
    required this.color,
    required this.moduleId,
    required this.courseId,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestion = 0;
  int? _selectedAnswer;
  bool _answered = false;
  int _score = 0;
  bool _loading = true;
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  List<Map<String, dynamic>> _shuffleQuestions(
    List<Map<String, dynamic>> questions,
  ) {
    final rng = Random();
    return questions.map((q) {
      final answers = List<String>.from(q['answers'] as List);
      final correctAnswer = answers[q['correct'] as int];
      answers.shuffle(rng);
      final newCorrectIndex = answers.indexOf(correctAnswer);
      return {
        'question': q['question'],
        'answers': answers,
        'correct': newCorrectIndex,
        'explanation': q['explanation'] ?? '',
      };
    }).toList();
  }

  Future<void> _loadQuestions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('modules')
          .doc(widget.moduleId)
          .collection('quiz')
          .orderBy('order')
          .get();

      final questions = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'question': data['question'] ?? '',
          'answers': List<String>.from(data['options'] ?? []),
          'correct': data['correctIndex'] ?? 0,
          'explanation': data['explanation'] ?? '',
        };
      }).toList();

      if (mounted) {
        setState(() {
          final raw = questions.isNotEmpty
              ? questions
              : _getHardcodedQuestions(widget.courseTag, widget.moduleId);
          _questions = _shuffleQuestions(raw);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _questions = _shuffleQuestions(
            _getHardcodedQuestions(widget.courseTag, widget.moduleId),
          );
          _loading = false;
        });
      }
    }
  }

  void _selectAnswer(int index) {
    if (_answered) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedAnswer = index;
      _answered = true;
      if (index == _questions[_currentQuestion]['correct']) _score++;
    });
  }

  void _nextQuestion() {
    if (_currentQuestion < _questions.length - 1) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentQuestion++;
        _selectedAnswer = null;
        _answered = false;
      });
    } else {
      _showResults();
    }
  }

  // ── FIXED: navigator captured before any async gap ─────────────────────────
  void _showResults() {
    if (!mounted) return;
    final theme = AppTheme.of(context);
    // Capture navigator BEFORE any async work or dialog dismissal
    final navigator = Navigator.of(context);
    final percent = (_score / _questions.length * 100).toInt();
    final passed = _score >= (_questions.length * 0.6).ceil();

    if (passed) {
      ProgressService.completeModule(
        courseId: widget.courseId,
        moduleId: widget.moduleId,
        moduleTitle: widget.moduleTitle,
        courseTag: widget.courseTag,
        score: _score,
        total: _questions.length,
      ).then((_) async {
        final courseComplete =
            await ProgressService.isCourseComplete(widget.courseId);
        if (courseComplete && mounted) {
          NotificationService.showCourseCompleteNotification(widget.courseTag);
        }
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: theme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: passed
                      ? AppColors.green.withValues(alpha: 0.15)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  passed
                      ? CupertinoIcons.checkmark_seal_fill
                      : CupertinoIcons.book_fill,
                  color: passed ? AppColors.green : const Color(0xFFF59E0B),
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                passed ? 'Great work!' : 'Keep studying!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: theme.text,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You scored $_score out of ${_questions.length}',
                style: TextStyle(fontSize: 15, color: theme.subtext),
              ),
              const SizedBox(height: 8),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: passed ? AppColors.green : const Color(0xFFF59E0B),
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 24),
              // ── Back to course ────────────────────────────────────────────
              GestureDetector(
                onTap: () async {
                  HapticFeedback.selectionClick();
                  // Pop dialog — synchronous, navigator still valid
                  navigator.pop();

                  if (passed) {
                    final courseComplete =
                        await ProgressService.isCourseComplete(widget.courseId);
                    // Guard after async gap
                    if (!mounted) return;
                    // Now pop the quiz screen
                    navigator.pop();
                    if (courseComplete) {
                      navigator.push(
                        PageRouteBuilder(
                          pageBuilder: (_, animation, __) => CertificateScreen(
                            courseTitle: widget.courseTag,
                            courseTag: widget.courseTag,
                            color: widget.color,
                            courseId: widget.courseId,
                          ),
                          transitionsBuilder: (_, animation, __, child) =>
                              FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                          transitionDuration: const Duration(milliseconds: 500),
                        ),
                      );
                    }
                  } else {
                    if (!mounted) return;
                    navigator.pop();
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Back to course',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // ── Try again ─────────────────────────────────────────────────
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  navigator.pop(); // pop dialog only
                  if (!mounted) return;
                  setState(() {
                    _currentQuestion = 0;
                    _selectedAnswer = null;
                    _answered = false;
                    _score = 0;
                    _questions = _shuffleQuestions(
                      _getHardcodedQuestions(widget.courseTag, widget.moduleId),
                    );
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.border),
                  ),
                  child: Text(
                    'Try again',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.subtext,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.bg,
        body: Center(
          child: CircularProgressIndicator(color: widget.color, strokeWidth: 2),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: theme.bg,
        body: Center(
          child: Text(
            'No questions found.',
            style: TextStyle(color: theme.subtext, fontSize: 15),
          ),
        ),
      );
    }

    final q = _questions[_currentQuestion];
    final correct = q['correct'] as int;
    final answers = q['answers'] as List<String>;

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: widget.color.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 13,
                            color: widget.color,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Lesson',
                            style: TextStyle(
                              fontSize: 14,
                              color: widget.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    'Question ${_currentQuestion + 1} of ${_questions.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.subtext,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentQuestion + 1) / _questions.length,
                  backgroundColor: theme.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.lightBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.20),
                  ),
                ),
                child: Text(
                  '${widget.courseTag} · ${widget.moduleTitle}',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                q['question'],
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.text,
                  height: 1.4,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 24),
              ...List.generate(answers.length, (i) {
                Color borderColor = theme.border;
                Color bgColor = theme.surface;
                Color textColor = theme.subtext;
                Widget? trailingIcon;

                if (_answered) {
                  if (i == correct) {
                    borderColor = AppColors.green.withValues(alpha: 0.5);
                    bgColor = AppColors.green.withValues(alpha: 0.10);
                    textColor = AppColors.green;
                    trailingIcon = Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: AppColors.green,
                      size: 18,
                    );
                  } else if (i == _selectedAnswer && i != correct) {
                    borderColor = AppColors.red.withValues(alpha: 0.5);
                    bgColor = AppColors.red.withValues(alpha: 0.10);
                    textColor = AppColors.red;
                    trailingIcon = Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: AppColors.red,
                      size: 18,
                    );
                  }
                } else if (_selectedAnswer == i) {
                  borderColor = widget.color.withValues(alpha: 0.5);
                  bgColor = widget.color.withValues(alpha: 0.10);
                  textColor = widget.color;
                }

                return GestureDetector(
                  onTap: () => _selectAnswer(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                      boxShadow: theme.isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            answers[i],
                            style: TextStyle(
                              fontSize: 14,
                              color: textColor,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        if (trailingIcon != null) ...[
                          const SizedBox(width: 8),
                          trailingIcon,
                        ],
                      ],
                    ),
                  ),
                );
              }),
              if (_answered &&
                  q['explanation'] != null &&
                  (q['explanation'] as String).isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        CupertinoIcons.lightbulb_fill,
                        size: 14,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          q['explanation'],
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.subtext,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              if (_answered)
                GestureDetector(
                  onTap: _nextQuestion,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _currentQuestion < _questions.length - 1
                          ? 'Next question →'
                          : 'See results',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HARDCODED QUESTIONS — router
  // ═══════════════════════════════════════════════════════════════════════════
  List<Map<String, dynamic>> _getHardcodedQuestions(
    String tag,
    String moduleId,
  ) {
    if (tag == 'ITIL V4') return _itilQuestions(moduleId);
    if (tag == 'CSM') return _csmQuestions(moduleId);
    if (tag == 'Binary Cloud') return _cloudFundamentalsQuestions(moduleId);
    if (tag == 'Binary Cloud Pro') return _cloudProQuestions(moduleId);
    if (tag == 'Binary Cyber Pro') return _cyberProQuestions(moduleId);
    return _networkProQuestions(moduleId);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ITIL V4 — 8 modules
  // ═══════════════════════════════════════════════════════════════════════════
  List<Map<String, dynamic>> _itilQuestions(String moduleId) {
    switch (moduleId) {
      case 'module-01':
        return [
          {
            'question':
                'Which ITIL V4 term describes a means of enabling value co-creation by facilitating outcomes customers want, without them managing specific costs and risks?',
            'answers': ['A product', 'A service', 'A process', 'A practice'],
            'correct': 1,
            'explanation':
                'A service enables value co-creation by facilitating outcomes customers want without them managing specific costs and risks. This is the precise ITIL V4 definition — "co-creation" is key.',
          },
          {
            'question':
                'A payroll app calculates salaries correctly but crashes every Friday. What is TRUE?',
            'answers': [
              'It has warranty but lacks utility',
              'It has utility but lacks warranty',
              'It has both utility and warranty',
              'It has neither',
            ],
            'correct': 1,
            'explanation':
                'Utility = fit for purpose (calculates correctly ✓). Warranty = fit for use (crashes every Friday ✗). Both are required for value. One without the other = no value.',
          },
          {
            'question':
                'Who is responsible for defining the requirements and owning the outcomes of a service?',
            'answers': [
              'The user',
              'The sponsor',
              'The customer',
              'The service provider',
            ],
            'correct': 2,
            'explanation':
                'Customer = defines requirements and owns outcomes. User = interacts with the service. Sponsor = authorises budget. Three distinct roles — one person can hold multiple.',
          },
          {
            'question':
                'What does ITIL V4 mean when it says value is "co-created"?',
            'answers': [
              'The IT team creates all value independently',
              'Value is created by meeting SLA targets',
              'Value emerges from the provider and consumer working together',
              'Value is defined purely by cost reduction',
            ],
            'correct': 2,
            'explanation':
                'ITIL V4 explicitly states value is co-created — not delivered TO the customer but WITH them. This is a foundational shift. "Delivers value" is wrong language in V4.',
          },
          {
            'question':
                'A CTO approves budget. The HR Director specifies requirements. HR Staff use the system daily. Which correctly identifies the roles?',
            'answers': [
              'CTO=Customer, HR Director=Sponsor, Staff=Users',
              'CTO=Sponsor, HR Director=Customer, Staff=Users',
              'CTO=User, HR Director=Sponsor, Staff=Customers',
              'All three are customers',
            ],
            'correct': 1,
            'explanation':
                'Sponsor = authorises budget (CTO). Customer = defines requirements and owns outcomes (HR Director). Users = interact with the service daily (HR Staff).',
          },
          {
            'question':
                'What is the key difference between ITIL V4 and a mandatory IT standard?',
            'answers': [
              'ITIL V4 is more expensive to implement',
              'ITIL V4 is guidance to adopt and adapt — not a certifiable compliance standard',
              'ITIL V4 only applies to large enterprises',
              'ITIL V4 replaces all other frameworks',
            ],
            'correct': 1,
            'explanation':
                'ITIL V4 is guidance — "adopt and adapt." ISO/IEC 20000 is the certifiable ITSM standard. Treating ITIL as mandatory compliance is a classic exam trap.',
          },
          {
            'question':
                'Which statement is correct about utility and warranty?',
            'answers': [
              'Utility is more important than warranty',
              'Warranty can compensate for a lack of utility',
              'Both must be present for a service to deliver value',
              'Utility and warranty are the same concept',
            ],
            'correct': 2,
            'explanation':
                'Both are required — AND relationship, not OR. Utility without warranty = unreliable. Warranty without utility = useless. Neither alone creates value.',
          },
          {
            'question':
                'ITIL V4 has 34 practices. What replaced the 26 processes from ITIL v3?',
            'answers': [
              'Service lifecycle stages',
              'Management practices',
              'Value streams',
              'Governance frameworks',
            ],
            'correct': 1,
            'explanation':
                'ITIL V4 replaced v3\'s 26 processes with 34 practices. Practices are broader — they include people, technology, information, and process steps.',
          },
          {
            'question':
                'An IT department delivers services to its own business units. What type of service provider is this?',
            'answers': [
              'External service provider',
              'Internal service provider',
              'Third-party service integrator',
              'Managed service provider',
            ],
            'correct': 1,
            'explanation':
                'Internal service provider = serves its own organisation. External = serves other organisations. ITIL applies equally to both.',
          },
          {
            'question':
                'Which statement about ITIL V4 and Agile/DevOps is correct?',
            'answers': [
              'ITIL V4 replaces Agile in regulated industries',
              'ITIL V4 conflicts with DevOps due to change boards',
              'ITIL V4 is designed to complement Agile and DevOps',
              'DevOps teams never need ITIL',
            ],
            'correct': 2,
            'explanation':
                'ITIL V4 was redesigned specifically to integrate with Agile, DevOps, and Lean. They are complementary, not competing.',
          },
        ];

      case 'module-02':
        return [
          {
            'question':
                'How many components does the ITIL V4 Service Value System have?',
            'answers': ['Three', 'Four', 'Five', 'Six'],
            'correct': 2,
            'explanation':
                'Exactly five SVS components: Guiding Principles, Governance, Service Value Chain, Practices, and Continual Improvement.',
          },
          {
            'question': 'What are the inputs to the Service Value System?',
            'answers': [
              'Processes and procedures',
              'Opportunity and demand',
              'Services and products',
              'Budgets and resources',
            ],
            'correct': 1,
            'explanation':
                'SVS inputs: Opportunity (possibilities to add value) + Demand (need for services). Output: Value.',
          },
          {
            'question':
                'Senior leadership sets strategic direction and oversees IT performance. Which SVS component is this?',
            'answers': [
              'Continual Improvement',
              'Service Value Chain',
              'Governance',
              'Guiding Principles',
            ],
            'correct': 2,
            'explanation':
                'Governance directs, evaluates, and monitors. It is NOT management. Setting strategic direction = Governance.',
          },
          {
            'question':
                'Which SVS component applies to ALL other SVS components — not just services?',
            'answers': [
              'The Service Value Chain',
              'Governance',
              'Continual Improvement',
              'Guiding Principles',
            ],
            'correct': 2,
            'explanation':
                'Continual Improvement applies to everything: the SVS, SVC, practices, governance, and guiding principles. Key exam trap — not just services.',
          },
          {
            'question':
                'An IT team optimises their ticketing process but causes problems for the billing team. Which guiding principle was most violated?',
            'answers': [
              'Focus on Value',
              'Start Where You Are',
              'Think and Work Holistically',
              'Keep It Simple and Practical',
            ],
            'correct': 2,
            'explanation':
                'Think and Work Holistically = consider end-to-end impact. Optimising one area without considering effects on others violates this principle.',
          },
          {
            'question':
                'A team wants to automate incident logging. What should they do FIRST according to ITIL V4?',
            'answers': [
              'Get budget approval',
              'Optimise (fix and simplify) the process before automating it',
              'Test automation in production',
              'Consult the Change Advisory Board',
            ],
            'correct': 1,
            'explanation':
                '"Optimise and Automate" — optimise FIRST, then automate. Automating a broken process makes it fail faster at scale.',
          },
          {
            'question':
                'A new monitoring tool was deployed without informing affected teams. Which guiding principle was violated?',
            'answers': [
              'Progress Iteratively with Feedback',
              'Collaborate and Promote Visibility',
              'Keep It Simple and Practical',
              'Start Where You Are',
            ],
            'correct': 1,
            'explanation':
                'Collaborate and Promote Visibility = make work visible to relevant stakeholders. Deploying without informing affected teams violates this directly.',
          },
          {
            'question':
                'Which guiding principle directly supports Agile sprint delivery?',
            'answers': [
              'Focus on Value',
              'Optimise and Automate',
              'Progress Iteratively with Feedback',
              'Think and Work Holistically',
            ],
            'correct': 2,
            'explanation':
                'Progress Iteratively with Feedback mirrors Agile\'s sprint model — work in small increments, gather feedback, adjust. Explicitly designed to align V4 with Agile.',
          },
          {
            'question': 'How many guiding principles does ITIL V4 define?',
            'answers': ['Five', 'Six', 'Seven', 'Eight'],
            'correct': 2,
            'explanation':
                'Exactly seven guiding principles. Universal, apply to every initiative, no fixed hierarchy. Knowing all seven by name is exam-critical.',
          },
          {
            'question':
                'A new manager scraps all existing ITSM processes and rebuilds from scratch. Which principle does this violate?',
            'answers': [
              'Focus on Value',
              'Start Where You Are',
              'Keep It Simple and Practical',
              'Think and Work Holistically',
            ],
            'correct': 1,
            'explanation':
                '"Start Where You Are" = objectively assess what exists and build on what works. Discarding all existing capabilities without assessment violates this.',
          },
        ];

      case 'module-03':
        return [
          {
            'question':
                'How many activities does the Service Value Chain contain?',
            'answers': ['Four', 'Five', 'Six', 'Seven'],
            'correct': 2,
            'explanation':
                'Exactly six SVC activities: Plan, Improve, Engage, Design & Transition, Obtain/Build, Deliver & Support.',
          },
          {
            'question':
                'Email is down. The service desk logs the issue and restores it in 30 minutes. Which SVC activities are PRIMARY?',
            'answers': [
              'Plan and Improve',
              'Design & Transition and Obtain/Build',
              'Engage and Deliver & Support',
              'All six equally',
            ],
            'correct': 2,
            'explanation':
                'Routine incident: Engage (user contacts service desk) + Deliver & Support (incident resolved). Not every value stream needs all six activities.',
          },
          {
            'question':
                'What is the key difference between the ITIL V4 SVC and the ITIL v3 Service Lifecycle?',
            'answers': [
              'The SVC has more stages',
              'SVC activities combine in any order; v3 was sequential',
              'v3 lifecycle is more flexible',
              'They are identical with different names',
            ],
            'correct': 1,
            'explanation':
                'SVC = flexible, activities combine in different ways. v3 = linear sequence (Strategy → Design → Transition → Operation → CSI). Flexibility is the core V4 improvement.',
          },
          {
            'question':
                'A team buys a monitoring tool from an external vendor. Which SVC activity is this?',
            'answers': [
              'Plan',
              'Design & Transition',
              'Obtain/Build',
              'Deliver & Support',
            ],
            'correct': 2,
            'explanation':
                'Obtain/Build = acquiring from external suppliers (Obtain) or building internally (Build). Buying vendor tool = Obtain.',
          },
          {
            'question':
                'Which SVC activity converts demand into requirements and manages stakeholder relationships?',
            'answers': ['Plan', 'Improve', 'Engage', 'Deliver & Support'],
            'correct': 2,
            'explanation':
                'Engage = primary interface with customers/stakeholders. Captures demand, translates to requirements, manages ongoing relationships.',
          },
          {
            'question':
                'Which SVC activity is present in EVERY value stream, not just at the end?',
            'answers': ['Plan', 'Engage', 'Improve', 'Design & Transition'],
            'correct': 2,
            'explanation':
                'Improve runs throughout ALL SVC activities continuously — not just at the end. This is a critical distinction from ITIL v3 CSI.',
          },
          {
            'question':
                'A value stream for deploying a new mobile app would MOST LIKELY include:',
            'answers': [
              'Engage only',
              'Deliver & Support and Improve only',
              'All six SVC activities',
              'Only activities the dev team owns',
            ],
            'correct': 2,
            'explanation':
                'New service deployment typically involves all six: Plan (architecture/budget), Engage (requirements), Design & Transition (design/release), Obtain/Build (development), Deliver & Support (operations), Improve (post-launch).',
          },
          {
            'question': 'In ITIL V4, what is a value stream?',
            'answers': [
              'A financial report showing service revenue',
              'A specific combination of SVC activities designed to create a product or respond to demand',
              'A single SVC activity applied to all services',
              'The six SVC activities listed in sequence',
            ],
            'correct': 1,
            'explanation':
                'A value stream is a specific combination of SVC activities for a particular scenario. Different situations produce different value streams — not fixed sequences.',
          },
          {
            'question':
                'Why was Design & Transition combined into one SVC activity in V4?',
            'answers': [
              'To reduce the lifecycle from five stages to four',
              'Because design and transition work is iterative and overlapping in Agile/DevOps environments',
              'To align with ISO 20000',
              'Because transition was removed from ITIL V4',
            ],
            'correct': 1,
            'explanation':
                'Combining reflects modern Agile/DevOps practice where design and release are iterative and continuous — not sequential phases.',
          },
          {
            'question':
                'Which SVC activity feeds policies and plans to ALL other activities?',
            'answers': ['Engage', 'Plan', 'Improve', 'Govern'],
            'correct': 1,
            'explanation':
                'Plan produces policies, portfolios, architectures, and plans consumed by all other SVC activities — it sets strategic direction for the entire chain.',
          },
        ];

      case 'module-04':
        return [
          {
            'question':
                'How many dimensions of service management does ITIL V4 define?',
            'answers': ['Three', 'Four', 'Five', 'Six'],
            'correct': 1,
            'explanation':
                'Exactly four dimensions: Organisations & People, Information & Technology, Partners & Suppliers, and Value Streams & Processes.',
          },
          {
            'question':
                'Staff lack training and a blame culture suppresses incident reporting. Which dimension is the primary concern?',
            'answers': [
              'Information & Technology',
              'Partners & Suppliers',
              'Value Streams & Processes',
              'Organisations & People',
            ],
            'correct': 3,
            'explanation':
                'Culture, skills, and org structure = Organisations & People. A blame culture is a People & Culture failure in this dimension.',
          },
          {
            'question':
                'A company is selecting an ITSM platform and defining its data architecture. Which dimension is this?',
            'answers': [
              'Organisations & People',
              'Information & Technology',
              'Partners & Suppliers',
              'Value Streams & Processes',
            ],
            'correct': 1,
            'explanation':
                'Information & Technology covers both the information managed AND the technology used — tools, platforms, data architecture, and AI.',
          },
          {
            'question':
                'An organisation uses three managed service providers for networking, security, and hosting. Which dimension?',
            'answers': [
              'Organisations & People',
              'Information & Technology',
              'Partners & Suppliers',
              'Value Streams & Processes',
            ],
            'correct': 2,
            'explanation':
                'Partners & Suppliers covers all external organisations — vendors, outsourced providers, contractors, and cloud platforms.',
          },
          {
            'question':
                'New GDPR legislation requires changes to how customer data is stored. Which dimension is MOST directly affected?',
            'answers': [
              'Value Streams & Processes',
              'Partners & Suppliers',
              'Information & Technology',
              'Organisations & People',
            ],
            'correct': 2,
            'explanation':
                'GDPR affects data management and technology controls — core to Information & Technology. PESTLE factors affect all four dimensions but I&T is most directly impacted.',
          },
          {
            'question':
                'What is SIAM and which dimension is it most associated with?',
            'answers': [
              'Service Integration and Management — Partners & Suppliers',
              'Systems Integration — Information & Technology',
              'Supplier Integration — Value Streams & Processes',
              'Service Implementation — Organisations & People',
            ],
            'correct': 0,
            'explanation':
                'SIAM (Service Integration and Management) coordinates multiple suppliers. Directly linked to the Partners & Suppliers dimension.',
          },
          {
            'question':
                'What does PESTLE represent in relation to the four dimensions?',
            'answers': [
              'A fifth dimension added in V4',
              'External factors (Political, Economic, Social, Technological, Legal, Environmental) that affect all four dimensions',
              'A compliance framework for ITSM',
              'A risk assessment methodology',
            ],
            'correct': 1,
            'explanation':
                'PESTLE = external context around the four dimensions. NOT a fifth dimension — it is the outer world affecting how all four dimensions operate.',
          },
          {
            'question':
                'An incident management process has clear inputs, outputs, and steps. Which dimension does this represent?',
            'answers': [
              'Organisations & People',
              'Information & Technology',
              'Partners & Suppliers',
              'Value Streams & Processes',
            ],
            'correct': 3,
            'explanation':
                'Value Streams & Processes covers how work is organised — including internal processes (incident management) within end-to-end value streams.',
          },
          {
            'question':
                'Why must all four dimensions be considered when designing any service?',
            'answers': [
              'ITIL V4 certification requires it',
              'Decisions in one dimension always affect the others — they are interdependent',
              'Each dimension has a separate budget line',
              'Each dimension has a separate responsible team',
            ],
            'correct': 1,
            'explanation':
                'The four dimensions are interdependent. A new tool affects skills (O&P), contracts (P&S), and workflows (VS&P). Neglecting any dimension risks service failure.',
          },
          {
            'question':
                'The old "people, process, technology" model had three factors. What did ITIL V4 add?',
            'answers': [
              'Governance as the fourth element',
              'Partners & Suppliers and Value Streams as explicit dimensions',
              'Data as a separate dimension',
              'Information replacing Technology',
            ],
            'correct': 1,
            'explanation':
                'ITIL V4 separated Partners & Suppliers and added Value Streams & Processes — reflecting modern realities of outsourcing and end-to-end thinking missing from the old PPT model.',
          },
        ];

      case 'module-05':
        return [
          {
            'question':
                'A user\'s laptop stops connecting to Wi-Fi. What is this?',
            'answers': [
              'A service request',
              'A problem',
              'An incident',
              'A known error',
            ],
            'correct': 2,
            'explanation':
                'An incident = unplanned interruption to a service. A service request = pre-defined entitlement (requesting a new laptop). Wi-Fi failure = unplanned interruption = Incident.',
          },
          {
            'question':
                'The same network switch caused five incidents this month. The team investigates why. Which practice?',
            'answers': [
              'Incident Management',
              'Change Enablement',
              'Problem Management',
              'Service Level Management',
            ],
            'correct': 2,
            'explanation':
                'Incident Management restores service. Problem Management identifies root cause of recurring incidents. Investigating the underlying cause = Problem Management.',
          },
          {
            'question':
                'Root cause identified, workaround documented. What has been created?',
            'answers': [
              'An incident record',
              'A change request',
              'A known error',
              'A service request',
            ],
            'correct': 2,
            'explanation':
                'Known Error = problem with diagnosed root cause AND documented workaround. Stored in the KEDB. Not yet permanently fixed but workaround is available.',
          },
          {
            'question':
                'A developer requests a software licence they are entitled to. What type of request?',
            'answers': [
              'An incident',
              'A service request',
              'A normal change',
              'A problem',
            ],
            'correct': 1,
            'explanation':
                'Service request = formal request for something the user is entitled to, pre-defined and pre-approved. No risk assessment required. Different from an incident.',
          },
          {
            'question':
                'A routine monthly server restart during a scheduled maintenance window needs no individual approval. Change type?',
            'answers': [
              'Normal change',
              'Emergency change',
              'Standard change',
              'Unauthorised change',
            ],
            'correct': 2,
            'explanation':
                'Standard changes are pre-authorised, low-risk, well-understood. No CAB approval needed. Scheduled maintenance restarts = textbook standard change.',
          },
          {
            'question':
                'A zero-day exploit is actively being used. An urgent patch must be deployed now. Change type?',
            'answers': [
              'Standard change',
              'Normal change',
              'Emergency change',
              'Unauthorised change',
            ],
            'correct': 2,
            'explanation':
                'Emergency changes have expedited but still documented approval. Used for urgent situations where normal approval timelines cannot be followed.',
          },
          {
            'question': 'What is the primary goal of Incident Management?',
            'answers': [
              'Identify the root cause of failures',
              'Restore normal service operation as quickly as possible',
              'Prevent incidents from recurring',
              'Document all configuration changes',
            ],
            'correct': 1,
            'explanation':
                'Incident Management\'s goal = speed of restoration. Root cause = Problem Management. This distinction is the most tested topic in the ITIL V4 Foundation exam.',
          },
          {
            'question':
                'An agreement between the service desk team and the infrastructure team defining support response times is called:',
            'answers': [
              'A Service Level Agreement (SLA)',
              'An Operational Level Agreement (OLA)',
              'An Underpinning Contract (UC)',
              'A Memorandum of Understanding',
            ],
            'correct': 1,
            'explanation':
                'OLA = INTERNAL agreement between IT teams. SLA = with the customer. UC = with external supplier. Service desk ↔ infrastructure team = OLA.',
          },
          {
            'question':
                'A monitoring tool detects server CPU at 92% and sends an alert. What event type?',
            'answers': [
              'Informational event',
              'Warning event',
              'Exception event',
              'Incident',
            ],
            'correct': 1,
            'explanation':
                'Warning = threshold approaching — action may be needed. Informational = normal. Exception = failure or threshold breached. 92% approaching limit = Warning.',
          },
          {
            'question': 'How is incident priority calculated?',
            'answers': [
              'Priority = Severity × Frequency',
              'Priority = Impact × Urgency',
              'Priority = Risk × Cost',
              'Priority = Duration × Affected Users',
            ],
            'correct': 1,
            'explanation':
                'Priority = Impact × Urgency. Impact = breadth of effect on business. Urgency = speed of resolution needed. High impact + high urgency = Priority 1.',
          },
        ];

      case 'module-06':
        return [
          {
            'question':
                'What is the primary difference between Release Management and Deployment Management?',
            'answers': [
              'They are the same practice',
              'Release Management decides what/when; Deployment Management physically moves components into environments',
              'Deployment Management controls approvals; Release executes',
              'Release is for software only; Deployment covers hardware',
            ],
            'correct': 1,
            'explanation':
                'Release Management = WHAT/WHEN. Deployment Management = technical execution of moving components. They work together but are distinct practices.',
          },
          {
            'question': 'The Continual Improvement Model has how many steps?',
            'answers': ['Five', 'Six', 'Seven', 'Eight'],
            'correct': 2,
            'explanation':
                'Exactly seven steps. Forgetting Step 7 ("How do we keep the momentum going?") is the most common candidate mistake.',
          },
          {
            'question':
                'An improvement initiative achieved positive results. Which CI Model step sustains the gains?',
            'answers': [
              'Step 4 — How do we get there?',
              'Step 5 — Take action',
              'Step 6 — Did we get there?',
              'Step 7 — How do we keep the momentum going?',
            ],
            'correct': 3,
            'explanation':
                'Step 7 embeds improvements and identifies the next cycle. Without Step 7, organisations celebrate then stagnate — improvement is not sustained.',
          },
          {
            'question':
                'A knowledge article reduces incident resolution from 45 minutes to 3 minutes. Which practice created this?',
            'answers': [
              'Incident Management',
              'Problem Management',
              'Knowledge Management',
              'Service Catalogue Management',
            ],
            'correct': 2,
            'explanation':
                'Knowledge Management maintains knowledge bases so the right people have the right knowledge at the right time. Creating and curating resolution articles = Knowledge Management.',
          },
          {
            'question':
                'In DIKW, what is the difference between Knowledge and Wisdom?',
            'answers': [
              'Knowledge = raw data; Wisdom = processed information',
              'Knowledge = understanding how; Wisdom = sound decision-making about why',
              'They are the same concept',
              'Wisdom = raw facts; Knowledge = contextualised data',
            ],
            'correct': 1,
            'explanation':
                'DIKW: Data → Information → Knowledge (how) → Wisdom (why/decisions). Know the sequence and what each level means.',
          },
          {
            'question':
                'A contract between an IT organisation and an external cloud provider is called:',
            'answers': [
              'An OLA',
              'An SLA',
              'A UC (Underpinning Contract)',
              'A BPA',
            ],
            'correct': 2,
            'explanation':
                'UC = agreement with EXTERNAL supplier. OLA = INTERNAL between IT teams. SLA = with customer. External cloud provider = UC.',
          },
          {
            'question':
                'The service catalogue shows available services. What does the broader service portfolio additionally include?',
            'answers': [
              'Only retired services',
              'Pipeline services (not yet live) and retired services — plus the live catalogue',
              'SLA targets for all services',
              'Supplier contract details',
            ],
            'correct': 1,
            'explanation':
                'Service Portfolio = pipeline (in development) + catalogue (live) + retired. The catalogue is only the live, customer-facing portion.',
          },
          {
            'question':
                'Which practice manages external supplier relationships, contracts, and performance?',
            'answers': [
              'Relationship Management',
              'Supplier Management',
              'Service Level Management',
              'IT Asset Management',
            ],
            'correct': 1,
            'explanation':
                'Supplier Management governs external supplier relationships. Relationship Management is about broader stakeholder trust — a different practice.',
          },
          {
            'question':
                'An IT asset is being used past its end-of-life date, creating a security risk. Which practice should have prevented this?',
            'answers': [
              'Service Configuration Management',
              'IT Asset Management',
              'Change Enablement',
              'Risk Management',
            ],
            'correct': 1,
            'explanation':
                'IT Asset Management tracks the full lifecycle including end-of-life dates. Failing to track lifecycle means assets run past supported dates, creating vulnerabilities.',
          },
          {
            'question':
                'Step 2 of the CI Model requires an objective baseline. What makes an assessment "objective"?',
            'answers': [
              'It is conducted by an external consultant',
              'It is based on measured data rather than assumptions or perceptions',
              'It involves all stakeholders',
              'It is documented in the improvement register',
            ],
            'correct': 1,
            'explanation':
                'Step 2 ("Where are we now?") must use actual measured data — not opinions. Without an objective baseline, you cannot prove improvement occurred.',
          },
        ];

      case 'module-07':
        return [
          {
            'question':
                'What term did ITIL V4 use to replace "Continual Service Improvement"?',
            'answers': [
              'Continuous Service Management',
              'Service Optimisation',
              'Continual Improvement',
              'Iterative Development',
            ],
            'correct': 2,
            'explanation':
                '"Continual Improvement" replaces v3\'s "Continual Service Improvement" because V4\'s version applies to ALL SVS components — not just services.',
          },
          {
            'question':
                'A team achieves 100% SLA compliance but CSAT drops to 58%. What does this illustrate?',
            'answers': [
              'SLAs are more important than satisfaction',
              'SLA targets are too low',
              'Measuring only SLA compliance misses the full picture — balanced measurement is needed',
              'Customers do not understand the service',
            ],
            'correct': 2,
            'explanation':
                'Metric fixation — hitting one KPI while missing real value. ITIL V4 requires balanced measurement: financial, customer satisfaction, process efficiency, and capability.',
          },
          {
            'question': 'What is a CSF and how does it relate to a KPI?',
            'answers': [
              'CSF measures performance; KPI defines the target',
              'CSF defines WHAT must happen for success; KPI measures HOW WELL the CSF is being achieved',
              'They are interchangeable terms',
              'CSF is technical; KPI is for business',
            ],
            'correct': 1,
            'explanation':
                'CSF = critical condition for success. KPI = how well it is being met. Every CSF needs at least one KPI.',
          },
          {
            'question':
                'Which CI Model step requires SMART targets to be defined?',
            'answers': [
              'Step 1 — What is the vision?',
              'Step 2 — Where are we now?',
              'Step 3 — Where do we want to be?',
              'Step 4 — How do we get there?',
            ],
            'correct': 2,
            'explanation':
                'Step 3 defines the desired future state with measurable, time-bound targets. Vague targets are insufficient.',
          },
          {
            'question':
                'Which type of metric enables action BEFORE a failure occurs?',
            'answers': [
              'Lagging indicator',
              'Historical trend analysis',
              'Leading indicator',
              'Incident frequency metric',
            ],
            'correct': 2,
            'explanation':
                'Leading indicators predict future failures (e.g. unpatched vulnerabilities, config drift) — enabling proactive action. Lagging indicators measure what already happened.',
          },
          {
            'question':
                'What is the purpose of a Continual Improvement Register (CIR)?',
            'answers': [
              'Track SLA compliance over time',
              'Record, prioritise, and track improvement opportunities across the organisation',
              'Document incident resolutions',
              'Manage the service catalogue',
            ],
            'correct': 1,
            'explanation':
                'The CIR is where improvement ideas are logged, assessed, prioritised, and assigned. Ensures no opportunity is lost after being identified.',
          },
          {
            'question':
                'Step 5 of the CI Model says "Take action." What approach does ITIL V4 recommend?',
            'answers': [
              'Implement all changes simultaneously for maximum impact',
              'Implement iteratively in phases with feedback loops at each stage',
              'Delegate all actions to operations',
              'Wait for all approvals before starting',
            ],
            'correct': 1,
            'explanation':
                'ITIL V4 recommends iterative implementation — pilot, measure, adjust, scale. Big-bang implementations increase risk.',
          },
          {
            'question':
                'An organisation completes an improvement, achieves targets, then stops improving. Which CI step was skipped?',
            'answers': ['Step 4', 'Step 5', 'Step 6', 'Step 7'],
            'correct': 3,
            'explanation':
                'Step 7 ("Keep the momentum going") embeds improvements and identifies the next cycle. Stopping after Step 6 = momentum lost. The model is circular, not linear.',
          },
          {
            'question':
                'A KPI of "calls answered per hour" causes staff to close tickets prematurely. What does this illustrate?',
            'answers': [
              'The service desk is understaffed',
              'Metric fixation — a KPI being gamed at the expense of real performance',
              'The KPI requires expensive monitoring tools',
              'This violates Change Enablement practice',
            ],
            'correct': 1,
            'explanation':
                'ITIL V4 warns: metrics must measure VALUE outcomes, not just operational activity. Gaming a metric while real performance degrades = metric fixation.',
          },
          {
            'question':
                'Which CI Model step establishes the objective baseline using measured data?',
            'answers': [
              'Step 1 — What is the vision?',
              'Step 2 — Where are we now?',
              'Step 3 — Where do we want to be?',
              'Step 6 — Did we get there?',
            ],
            'correct': 1,
            'explanation':
                'Step 2 ("Where are we now?") establishes the baseline using measured data. Directly applies "Start Where You Are" — assess before acting.',
          },
        ];

      case 'module-08':
        return [
          {
            'question':
                'ITIL V4 Foundation exam: how many questions and what is the pass mark?',
            'answers': [
              '50 questions, 70%',
              '40 questions, 65% (26/40)',
              '60 questions, 60%',
              '40 questions, 70% (28/40)',
            ],
            'correct': 1,
            'explanation':
                '40 questions, 60 minutes, 65% pass mark = 26 correct. No negative marking — always answer every question.',
          },
          {
            'question': 'Which scenario maps to Incident Management?',
            'answers': [
              'Engineer investigates why database crashes every Monday',
              'User requests a new keyboard via service portal',
              'Service desk restores a user\'s internet access that suddenly stopped',
              'New application deployed to production',
            ],
            'correct': 2,
            'explanation':
                'Incident = restore service after unplanned interruption. Restoring internet access = Incident. Root cause investigation = Problem. Keyboard request = Service Request. Deployment = Change/Release.',
          },
          {
            'question':
                'Which SVS component is responsible for directing, evaluating, and monitoring?',
            'answers': [
              'Guiding Principles',
              'Continual Improvement',
              'Governance',
              'Service Value Chain',
            ],
            'correct': 2,
            'explanation':
                'Governance evaluates, directs, and monitors. NOT management (which executes). Classic exam distinction.',
          },
          {
            'question':
                'An exam option states "the service provider delivers value to the customer." Why is this INCORRECT in V4?',
            'answers': [
              'It should say "IT department" not "provider"',
              'Value is co-created — not delivered one-directionally',
              'Only customers can create value',
              '"Delivers value" is correct V4 language',
            ],
            'correct': 1,
            'explanation':
                'ITIL V4: value is CO-CREATED, not delivered. "Delivers value" = wrong exam language trap. "Enables value co-creation" = correct.',
          },
          {
            'question': 'Which is a General Management Practice in ITIL V4?',
            'answers': [
              'Incident Management',
              'Release Management',
              'Risk Management',
              'Deployment Management',
            ],
            'correct': 2,
            'explanation':
                'Risk Management = General Management Practice (14 total). Incident and Release = Service Management Practices. Deployment = Technical Management Practice.',
          },
          {
            'question':
                'An organisation adapts ITIL V4 significantly to fit their Agile model. Is this acceptable?',
            'answers': [
              'No — ITIL V4 must be implemented exactly as described',
              'Yes — ITIL V4 is guidance to adopt and adapt to context',
              'Only with AXELOS exception',
              'No — Agile and ITIL V4 cannot coexist',
            ],
            'correct': 1,
            'explanation':
                '"Adopt and adapt" is central to ITIL V4. It is guidance, not a standard. Adapting to Agile is exactly what V4 was designed to support.',
          },
          {
            'question':
                'Which answer pattern is a common distractor trap on the ITIL V4 Foundation exam?',
            'answers': [
              'Options using correct V4 terminology',
              'Options using "Continual Service Improvement," "Change Management," or v3 lifecycle stage names',
              'Options that mention the SVC',
              'Options referencing the four dimensions',
            ],
            'correct': 1,
            'explanation':
                'V3 language in V4 options = classic distractor. "Continual Service Improvement" (→ Continual Improvement), "Change Management" (→ Change Enablement), lifecycle stage names → almost always wrong.',
          },
          {
            'question':
                'An organisation immediately begins the next improvement after completing one, without pausing. Which demonstrates this?',
            'answers': [
              'Keep It Simple and Practical; Step 5',
              'Progress Iteratively; Step 3',
              'Focus on Value; Step 7',
              'Continual Improvement culture; Step 7',
            ],
            'correct': 3,
            'explanation':
                'Step 7 and Continual Improvement culture describe an organisation that treats improvement as ongoing practice — not a one-time project.',
          },
          {
            'question':
                'What is the minimum score to pass the ITIL V4 Foundation exam?',
            'answers': [
              '24 out of 40',
              '25 out of 40',
              '26 out of 40',
              '28 out of 40',
            ],
            'correct': 2,
            'explanation':
                '26/40 = 65% is the pass mark. No negative marking — always guess if unsure.',
          },
          {
            'question': 'Which combination is at the absolute core of ITIL V4?',
            'answers': [
              'Processes, tools, and people',
              'Value co-creation, the SVS, and the four dimensions',
              'SLAs, OLAs, and UCs',
              'Incidents, changes, and requests',
            ],
            'correct': 1,
            'explanation':
                'ITIL V4 is built on: value co-creation (why), the SVS (how everything connects), and the four dimensions (what to consider). Everything else supports these.',
          },
        ];

      default:
        return [
          {
            'question': 'What does the SVS describe?',
            'answers': [
              'A list of approved IT tools',
              'How all SVS components work together to enable value creation',
              'The billing process for IT services',
              'Network security protocols',
            ],
            'correct': 1,
            'explanation':
                'The SVS shows how Guiding Principles, Governance, SVC, Practices, and Continual Improvement work together to produce value.',
          },
        ];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CSM — 8 modules, Certified ScrumMaster exam depth
  // ═══════════════════════════════════════════════════════════════════════════
  List<Map<String, dynamic>> _csmQuestions(String moduleId) {
    switch (moduleId) {
      case 'module-01':
        return [
          {
            'question': 'Which is the first value of the Agile Manifesto?',
            'answers': [
              'Processes and tools over individuals',
              'Individuals and interactions over processes and tools',
              'Comprehensive documentation over working software',
              'Following a plan over responding to change',
            ],
            'correct': 1,
            'explanation':
                'First Agile value: Individuals and interactions OVER processes and tools. The Manifesto values both sides but prioritises the left-hand values.',
          },
          {
            'question': 'How many values are in the Agile Manifesto?',
            'answers': ['Three', 'Four', 'Five', 'Twelve'],
            'correct': 1,
            'explanation':
                'Exactly four values and twelve principles. Confusing the counts is a common mistake.',
          },
          {
            'question': 'Which is NOT one of the four Agile Manifesto values?',
            'answers': [
              'Working software over comprehensive documentation',
              'Customer collaboration over contract negotiation',
              'Continuous delivery over iterative development',
              'Responding to change over following a plan',
            ],
            'correct': 2,
            'explanation':
                '"Continuous delivery over iterative development" is not a Manifesto value — it is a distractor. The four values are: Individuals & interactions, Working software, Customer collaboration, Responding to change.',
          },
          {
            'question': 'Scrum is best described as:',
            'answers': [
              'A project management methodology with fixed processes',
              'A lightweight framework for addressing complex adaptive problems',
              'A software development programming technique',
              'A risk management approach for large enterprises',
            ],
            'correct': 1,
            'explanation':
                'Scrum is a framework — not a methodology. It provides structure (roles, events, artifacts) and leaves room for teams to determine specific practices.',
          },
          {
            'question':
                'What are the three pillars of Scrum\'s empirical process?',
            'answers': [
              'Planning, Execution, Review',
              'Transparency, Inspection, Adaptation',
              'Vision, Sprint, Retrospective',
              'Commitment, Courage, Respect',
            ],
            'correct': 1,
            'explanation':
                'Transparency, Inspection, and Adaptation are the three empirical pillars. Must be memorised for the CSM exam.',
          },
          {
            'question': 'What is empiricism in Scrum?',
            'answers': [
              'Making decisions based on theoretical planning',
              'Using data, observation, and experience to make decisions — learn by doing',
              'Following a predefined process without deviation',
              'Gathering all requirements before starting work',
            ],
            'correct': 1,
            'explanation':
                'Scrum is founded on empiricism — knowledge comes from experience and observation. The three pillars are Transparency, Inspection, and Adaptation.',
          },
          {
            'question': 'What distinguishes Scrum from waterfall?',
            'answers': [
              'Scrum requires more documentation',
              'Scrum delivers value in short iterative cycles with continuous feedback; waterfall delivers at project end',
              'Waterfall involves more team collaboration',
              'Scrum has more defined processes',
            ],
            'correct': 1,
            'explanation':
                'Waterfall delivers at project completion after a long sequential process. Scrum delivers incrementally every Sprint, enabling early value and mid-course correction.',
          },
          {
            'question':
                'Which Scrum value means team members commit to team goals rather than individual agendas?',
            'answers': ['Courage', 'Commitment', 'Focus', 'Openness'],
            'correct': 1,
            'explanation':
                'Commitment = the team commits to Sprint Goals and team objectives. One of the five Scrum values: Commitment, Courage, Focus, Openness, Respect.',
          },
          {
            'question': 'How many principles does the Agile Manifesto contain?',
            'answers': ['Four', 'Eight', 'Ten', 'Twelve'],
            'correct': 3,
            'explanation':
                'The Agile Manifesto has 4 values and 12 principles. The count (12) is directly tested on CSM exams.',
          },
          {
            'question':
                'Which Agile principle directly supports Sprint-based delivery?',
            'answers': [
              'Welcome changing requirements even late',
              'Deliver working software frequently, from weeks to months',
              'Business people and developers work together daily',
              'Best architectures emerge from self-organising teams',
            ],
            'correct': 1,
            'explanation':
                'The second Agile principle specifies delivering working software frequently — directly underpinning Scrum\'s Sprint model.',
          },
        ];

      case 'module-02':
        return [
          {
            'question': 'What is the Scrum Master\'s primary responsibility?',
            'answers': [
              'Writing code for the team',
              'Serving as servant-leader helping the team understand and enact Scrum',
              'Setting product vision and managing stakeholders',
              'Approving all product changes',
            ],
            'correct': 1,
            'explanation':
                'The Scrum Master is a servant-leader — facilitating Scrum, removing impediments, and coaching on Scrum theory. Not a project manager.',
          },
          {
            'question':
                'A developer is blocked by an external dependency. Who resolves this?',
            'answers': [
              'The Product Owner',
              'The Scrum Master',
              'The developer themselves',
              'The project manager',
            ],
            'correct': 1,
            'explanation':
                'Removing impediments the team cannot resolve themselves is a core Scrum Master responsibility.',
          },
          {
            'question':
                'The PO pressures the team to add work mid-Sprint. What should the Scrum Master do?',
            'answers': [
              'Approve additions if the PO insists',
              'Protect the team by coaching the PO on Sprint integrity',
              'Ask team to work overtime',
              'Cancel the Sprint immediately',
            ],
            'correct': 1,
            'explanation':
                'The SM protects Sprint scope integrity. Scope changes should wait for next Sprint. SM coaches the PO on this.',
          },
          {
            'question': 'What is the Scrum Master NOT responsible for?',
            'answers': [
              'Facilitating Scrum events',
              'Coaching the organisation on Scrum',
              'Deciding Product Backlog priority',
              'Removing impediments',
            ],
            'correct': 2,
            'explanation':
                'Prioritising the Product Backlog is the Product Owner\'s sole responsibility. The SM may coach on techniques but does not own ordering.',
          },
          {
            'question':
                'A manager wants to assign specific tasks to each developer daily. How should the SM respond?',
            'answers': [
              'Support the manager — they have authority',
              'Coach the manager that development teams are self-organising',
              'Escalate to HR',
              'Allow it during transition',
            ],
            'correct': 1,
            'explanation':
                'Development teams are self-organising — they decide how to accomplish work. Management assigning daily tasks undermines this. The SM coaches toward the Scrum model.',
          },
          {
            'question':
                'Which role is accountable for maximising the value of the product?',
            'answers': [
              'Scrum Master',
              'Development Team',
              'Product Owner',
              'Stakeholders',
            ],
            'correct': 2,
            'explanation':
                'The Product Owner is solely accountable for the Product Backlog and maximising product value. Cannot be delegated.',
          },
          {
            'question':
                'The Daily Scrum is becoming a status report to management. What should the SM do?',
            'answers': [
              'Allow it — transparency is a Scrum pillar',
              'Facilitate the team back to inspecting Sprint Goal progress and adapting the plan',
              'Cancel the Daily Scrum',
              'Report to the Product Owner',
            ],
            'correct': 1,
            'explanation':
                'Daily Scrum = planning event for the dev team, not a status meeting for management. The SM coaches the team and protects the event\'s purpose.',
          },
          {
            'question': 'How many official roles exist in Scrum?',
            'answers': ['Two', 'Three', 'Four', 'Five'],
            'correct': 1,
            'explanation':
                'Exactly three roles: Product Owner, Scrum Master, and Development Team.',
          },
          {
            'question':
                'A Scrum Master is asked to also be the Product Owner. What is the concern?',
            'answers': [
              'No concern — it saves resources',
              'Conflict of interest — SM optimises for team process; PO optimises for product value',
              'The PO role is less important and can be absorbed',
              'Recommended for small teams',
            ],
            'correct': 1,
            'explanation':
                'Combining SM and PO creates conflict of interest. These priorities can directly conflict, compromising both roles.',
          },
          {
            'question': 'Which best describes a "servant-leader"?',
            'answers': [
              'A leader who assigns tasks to team members',
              'A leader who serves others first — removing obstacles and enabling the team rather than directing their work',
              'A leader who reports team performance to management',
              'A leader who makes all technical decisions',
            ],
            'correct': 1,
            'explanation':
                'A servant-leader puts the team\'s needs first — facilitating, coaching, and unblocking rather than commanding.',
          },
        ];

      case 'module-03':
        return [
          {
            'question': 'What is the purpose of a Sprint Goal?',
            'answers': [
              'To list every task the team will complete',
              'To provide a single objective giving the team focus and flexibility within the Sprint',
              'To track individual developer productivity',
              'To document stakeholder requirements',
            ],
            'correct': 1,
            'explanation':
                'Sprint Goal = single objective for the Sprint. Gives focus while allowing flexibility on how to achieve it.',
          },
          {
            'question': 'What is the maximum length of a Sprint?',
            'answers': ['Two weeks', 'Three weeks', 'One month', 'Six weeks'],
            'correct': 2,
            'explanation':
                'A Sprint is time-boxed to one month or less. Most teams use 1–2 weeks. Sprints cannot be extended.',
          },
          {
            'question':
                'What happens to incomplete Sprint Backlog items at Sprint end?',
            'answers': [
              'Automatically added to next Sprint',
              'Deleted and re-estimated',
              'Return to Product Backlog for PO to re-prioritise',
              'Sprint is extended until complete',
            ],
            'correct': 2,
            'explanation':
                'Incomplete items return to the Product Backlog. PO decides whether to reprioritise. Sprints are NEVER extended.',
          },
          {
            'question': 'Who attends the Sprint Review?',
            'answers': [
              'Scrum Team only',
              'Dev Team and SM only',
              'Scrum Team and key stakeholders',
              'Only PO and stakeholders',
            ],
            'correct': 2,
            'explanation':
                'Sprint Review = entire Scrum Team (PO, SM, Dev Team) AND key stakeholders. Collaborative session to inspect the Increment.',
          },
          {
            'question':
                'What is the primary purpose of the Sprint Retrospective?',
            'answers': [
              'Review the product with stakeholders',
              'Plan the next Sprint\'s work',
              'Inspect the team\'s process and create an improvement plan',
              'Update the Product Backlog',
            ],
            'correct': 2,
            'explanation':
                'Retrospective inspects people, relationships, process, and tools — creates concrete improvement plan. About the HOW (process), not the WHAT (product).',
          },
          {
            'question': 'What is the purpose of Sprint Planning?',
            'answers': [
              'Report progress to management',
              'Define the entire project roadmap',
              'Define the Sprint Goal and select PBIs the team can deliver',
              'Assign tasks to individual developers',
            ],
            'correct': 2,
            'explanation':
                'Sprint Planning creates the Sprint Goal and Sprint Backlog. Team selects PBIs they believe they can deliver and defines HOW.',
          },
          {
            'question': 'What is the Daily Scrum time-box?',
            'answers': [
              'As long as needed',
              '15 minutes',
              '30 minutes',
              '1 hour',
            ],
            'correct': 1,
            'explanation':
                'Daily Scrum is time-boxed to 15 minutes. Same time and place daily. For the development team — not a management status meeting.',
          },
          {
            'question':
                'Which Scrum event inspects and adapts the TEAM\'S PROCESS?',
            'answers': [
              'Sprint Review',
              'Sprint Planning',
              'Daily Scrum',
              'Sprint Retrospective',
            ],
            'correct': 3,
            'explanation':
                'Retrospective = inspect and adapt PROCESS. Sprint Review = inspect and adapt PRODUCT. Different events, different purposes — common exam confusion.',
          },
          {
            'question':
                'The team discovers mid-Sprint the Sprint Goal cannot be met. What should happen?',
            'answers': [
              'SM cancels the Sprint automatically',
              'Team delivers what they can and discusses in Retrospective',
              'Team negotiates with PO to adjust scope while preserving the Sprint Goal if possible',
              'Sprint is extended',
            ],
            'correct': 2,
            'explanation':
                'Team should negotiate with PO to adjust Sprint Backlog scope while trying to preserve the Sprint Goal. Only the PO can cancel a Sprint if the Goal is obsolete.',
          },
          {
            'question': 'How many Scrum events are there?',
            'answers': ['Three', 'Four', 'Five', 'Six'],
            'correct': 2,
            'explanation':
                'Five Scrum events: The Sprint (container), Sprint Planning, Daily Scrum, Sprint Review, Sprint Retrospective.',
          },
        ];

      case 'module-04':
        return [
          {
            'question': 'Who is responsible for ordering the Product Backlog?',
            'answers': [
              'The Scrum Master',
              'The Development Team',
              'The Product Owner',
              'Stakeholders by vote',
            ],
            'correct': 2,
            'explanation':
                'The Product Owner is solely responsible for ordering the Product Backlog. Cannot be delegated. PO may take input but owns the final ordering.',
          },
          {
            'question': 'What is the Sprint Backlog?',
            'answers': [
              'All requirements for the entire product',
              'PBIs selected for the Sprint plus the plan for delivering them',
              'A list of bugs from previous Sprints',
              'The PO\'s wish list',
            ],
            'correct': 1,
            'explanation':
                'Sprint Backlog = selected PBIs + plan for delivering the Sprint Goal. Belongs to the development team, updated throughout the Sprint.',
          },
          {
            'question': 'What is the Definition of Done (DoD)?',
            'answers': [
              'Acceptance criteria for a single user story',
              'A shared understanding of quality standards an Increment must meet to be considered complete',
              'The PBI acceptance criteria',
              'Management\'s sign-off checklist',
            ],
            'correct': 1,
            'explanation':
                'DoD is a shared quality standard applied to ALL Increments — not one story. Ensures consistency about what "complete" means.',
          },
          {
            'question':
                'A PBI is at the top of the backlog. What should be true about it?',
            'answers': [
              'It should be the largest item',
              'It should be more refined, detailed, and estimated than lower-priority items',
              'It was added most recently',
              'It was requested by the most senior stakeholder',
            ],
            'correct': 1,
            'explanation':
                'Items near the top are refined through backlog refinement. Items lower may be vague — refined as they move up in priority.',
          },
          {
            'question': 'What does backlog refinement involve?',
            'answers': [
              'Team deleting outdated items',
              'Adding detail, estimates, and order to PBIs so they are ready for future Sprints',
              'Converting user stories to technical tasks',
              'PO presenting backlog to stakeholders for approval',
            ],
            'correct': 1,
            'explanation':
                'Backlog refinement is ongoing — adding detail and estimates to PBIs, reordering. Ensures backlog is always ready for upcoming Sprint Planning.',
          },
          {
            'question': 'How does DoD differ from Acceptance Criteria?',
            'answers': [
              'They are the same thing',
              'DoD applies to all Increments (team quality standard); AC is specific to one PBI (customer requirements)',
              'AC is set by the team; DoD by the PO',
              'DoD is optional; AC is mandatory',
            ],
            'correct': 1,
            'explanation':
                'DoD = quality standard for ALL Increments (e.g. tested, reviewed, documented). AC = conditions for ONE story (e.g. user can log in with email). Both must be met.',
          },
          {
            'question': 'What is an Increment in Scrum?',
            'answers': [
              'Features planned for the next release',
              'The sum of all completed PBIs in a Sprint plus all previous Increments',
              'A progress report for stakeholders',
              'A single completed user story',
            ],
            'correct': 1,
            'explanation':
                'The Increment is the cumulative, usable, potentially releasable output at Sprint end. Always additive to all previous Increments.',
          },
          {
            'question':
                'A stakeholder approaches the dev team to add a new requirement to the current Sprint. What happens?',
            'answers': [
              'Team adds it if it seems small',
              'SM adds it to the Sprint Backlog',
              'Stakeholder must go through the PO, who decides whether and when to address it',
              'Team votes on whether to include it',
            ],
            'correct': 2,
            'explanation':
                'All new work must go through the PO. Stakeholders cannot add items directly to the Sprint.',
          },
          {
            'question': 'Who can modify the Sprint Backlog during a Sprint?',
            'answers': [
              'The Product Owner',
              'The Scrum Master',
              'The Development Team',
              'Any Scrum Team member',
            ],
            'correct': 2,
            'explanation':
                'Sprint Backlog belongs to the Development Team. Only they can add or modify tasks. PO owns the Product Backlog; Dev Team owns the Sprint Backlog.',
          },
          {
            'question': 'What is the Product Backlog?',
            'answers': [
              'A fixed list of all features created at project start',
              'An ordered, emergent list of everything needed to improve the product, owned by the PO',
              'The team\'s capacity plan for next quarter',
              'A record of completed features',
            ],
            'correct': 1,
            'explanation':
                'Product Backlog = ordered, emergent, owned by PO. Never fixed — always evolves as understanding and requirements change.',
          },
        ];

      case 'module-05':
        return [
          {
            'question': 'What does "velocity" measure in Scrum?',
            'answers': [
              'How fast individual developers write code',
              'The number of story points completed on average per Sprint',
              'The team\'s deployment frequency',
              'How quickly the PO refines the backlog',
            ],
            'correct': 1,
            'explanation':
                'Velocity = average story points completed per Sprint. Used for forecasting — NOT evaluating individual performance.',
          },
          {
            'question': 'What is a user story?',
            'answers': [
              'A detailed technical specification',
              'A short description of a feature from the perspective of the person who wants it',
              'A bug report',
              'A stakeholder interview transcript',
            ],
            'correct': 1,
            'explanation':
                'User story: "As a [role], I want [goal], so that [benefit]." Focuses on value — not technical implementation.',
          },
          {
            'question': 'What does INVEST describe?',
            'answers': [
              'Six criteria for quality user stories: Independent, Negotiable, Valuable, Estimable, Small, Testable',
              'An Agile investment framework',
              'A sprint planning technique',
              'Backlog prioritisation criteria',
            ],
            'correct': 0,
            'explanation':
                'INVEST = Independent, Negotiable, Valuable, Estimable, Small, Testable. Six quality criteria for well-formed user stories.',
          },
          {
            'question': 'What is Planning Poker used for?',
            'answers': [
              'Prioritising the Product Backlog by business value',
              'Estimating effort of PBIs using consensus-based relative sizing',
              'Allocating team members to tasks',
              'Measuring Sprint velocity',
            ],
            'correct': 1,
            'explanation':
                'Planning Poker: team simultaneously reveals estimates to prevent anchoring bias. Discussion follows divergence.',
          },
          {
            'question': 'Why should velocity NOT be compared between teams?',
            'answers': [
              'Different teams use different tools',
              'Story points are relative to each team — one team\'s 5 is not another team\'s 5',
              'Velocity changes too frequently',
              'Management shouldn\'t access velocity data',
            ],
            'correct': 1,
            'explanation':
                'Story points are relative within a team. Comparing velocities across teams is meaningless and drives dysfunctional behaviour.',
          },
          {
            'question':
                'What is the Fibonacci sequence used for in Scrum estimation?',
            'answers': [
              'Calculating Sprint duration',
              'Providing non-linear values reflecting increasing uncertainty of larger estimates',
              'Ranking stakeholder priorities',
              'Measuring code quality',
            ],
            'correct': 1,
            'explanation':
                'Fibonacci numbers grow non-linearly — reflecting that larger items have more uncertainty. Gaps force choosing between sizes rather than adding false precision.',
          },
          {
            'question': 'What is a burndown chart?',
            'answers': [
              'Tracking team member performance',
              'Visualising remaining work over time to inspect progress toward the Sprint Goal',
              'Recording defects found during testing',
              'Planning future Sprints',
            ],
            'correct': 1,
            'explanation':
                'Sprint Burndown shows remaining work (Y-axis) vs days of Sprint (X-axis). Helps the team inspect whether they are on track to meet the Sprint Goal.',
          },
          {
            'question':
                'A team consistently underestimates capacity. Most likely cause?',
            'answers': [
              'PO is adding too many items',
              'Team is not accounting for meetings, holidays, and support tasks',
              'SM is assigning too many story points',
              'DoD is too strict',
            ],
            'correct': 1,
            'explanation':
                'Consistently missing commitments usually means capacity is overestimated by not accounting for interruptions, meetings, leave, and BAU tasks.',
          },
          {
            'question': 'What does "relative estimation" mean?',
            'answers': [
              'Estimating in calendar days relative to the deadline',
              'Estimating size by comparing items to each other rather than absolute time',
              'Asking stakeholders to estimate by budget',
              'Using previous Sprint velocity as next Sprint estimate',
            ],
            'correct': 1,
            'explanation':
                'Relative estimation compares items to each other ("this is twice as complex as that"). Story points are the most common unit.',
          },
          {
            'question': 'When should a PBI be broken into smaller stories?',
            'answers': [
              'Only during Sprint Retrospectives',
              'When it is too large to complete in a single Sprint and needs to move up in priority',
              'After the Sprint starts',
              'Only when the team requests it',
            ],
            'correct': 1,
            'explanation':
                'Large items (epics) are split during backlog refinement when approaching the top of the backlog. Stories should be small enough to complete within a Sprint.',
          },
        ];

      case 'module-06':
        return [
          {
            'question':
                'What is the PO\'s primary responsibility regarding the Product Backlog?',
            'answers': [
              'Writing technical acceptance criteria',
              'Ensuring the backlog is visible, transparent, and ordered to maximise product value',
              'Estimating story points',
              'Approving team Sprint commitments',
            ],
            'correct': 1,
            'explanation':
                'PO ensures backlog is visible and ordered for maximum value. Owns the WHAT — not the HOW.',
          },
          {
            'question':
                'A PO frequently changes Sprint priorities mid-Sprint. Best response?',
            'answers': [
              'Team should comply — PO has authority',
              'SM coaches PO on Sprint integrity and directs changes to next Sprint',
              'Cancel the Sprint',
              'Team votes on accepting changes',
            ],
            'correct': 1,
            'explanation':
                'Sprint stability enables the team to deliver the Sprint Goal. SM coaches the PO that mid-Sprint scope changes disrupt the team.',
          },
          {
            'question':
                'Best way for a PO to communicate requirements to the team?',
            'answers': [
              'Through detailed written specifications',
              'Through ongoing conversation, collaboration, and refinement — not just documentation',
              'Via weekly email updates',
              'By creating comprehensive test scripts',
            ],
            'correct': 1,
            'explanation':
                'Agile values "individuals and interactions over documentation." PO should collaborate daily, clarifying and refining.',
          },
          {
            'question': 'Who should the Product Owner represent?',
            'answers': [
              'Only the paying customer',
              'The dev team\'s technical preferences',
              'All stakeholders — balancing competing needs while optimising for product value',
              'Senior management\'s budget priorities only',
            ],
            'correct': 2,
            'explanation':
                'PO represents ALL stakeholders and must balance their needs while maximising the product\'s overall value.',
          },
          {
            'question': 'Can the PO delegate backlog prioritisation?',
            'answers': [
              'Yes, to the Scrum Master',
              'Yes, to the most senior developer',
              'No — the PO is solely accountable for Product Backlog ordering',
              'Yes, to any team member the PO chooses',
            ],
            'correct': 2,
            'explanation':
                'PO may take input from others but cannot delegate accountability for backlog ordering.',
          },
          {
            'question':
                'A stakeholder complains after 3 months that the product doesn\'t meet their needs. What should PO have done?',
            'answers': [
              'Built more features before showing the stakeholder',
              'Engaged stakeholders regularly at Sprint Reviews to inspect and adapt direction continuously',
              'Documented requirements more thoroughly upfront',
              'Given the stakeholder edit access to the backlog',
            ],
            'correct': 1,
            'explanation':
                'Regular Sprint Reviews enable continuous feedback. Three months without feedback = major Agile anti-pattern. Problems compound instead of being caught early.',
          },
          {
            'question':
                'At a Sprint Review, stakeholders find a feature unhelpful. What should the PO do?',
            'answers': [
              'Defend the feature — it was in the backlog',
              'Treat this as valuable feedback and adapt the Product Backlog accordingly',
              'Ask the team to redo it exactly as specified',
              'Escalate to management',
            ],
            'correct': 1,
            'explanation':
                'Empiricism in action — inspection leads to adaptation. The Sprint Review exists for exactly this feedback.',
          },
          {
            'question': 'What is product vision and why does the PO need one?',
            'answers': [
              'A technical architecture diagram',
              'A clear description of the desired future state guiding all prioritisation decisions',
              'The current Sprint Goal',
              'The quarterly roadmap approved by management',
            ],
            'correct': 1,
            'explanation':
                'Product vision = long-term goal the product works toward. Without vision, prioritisation becomes arbitrary.',
          },
          {
            'question':
                'A PO is unavailable during most of the Sprint. What risk does this create?',
            'answers': [
              'No risk — SM can cover',
              'Team cannot get timely answers, causing wrong assumptions and misaligned delivery',
              'Stakeholders miss the Sprint Review',
              'Velocity decreases permanently',
            ],
            'correct': 1,
            'explanation':
                'An unavailable PO creates a bottleneck — questions go unanswered, developers make assumptions (often wrong). PO must be available and engaged.',
          },
          {
            'question':
                'What technique prioritises backlog items by weighing cost of delay and value?',
            'answers': [
              'MoSCoW prioritisation',
              'WSJF (Weighted Shortest Job First)',
              'Kano model',
              'Story mapping',
            ],
            'correct': 1,
            'explanation':
                'WSJF prioritises items with highest cost of delay relative to job size — maximising economic value delivered over time.',
          },
        ];

      case 'module-07':
        return [
          {
            'question': 'What does "scaling Scrum" mean?',
            'answers': [
              'Increasing Sprint length for larger projects',
              'Applying Scrum across multiple teams working on the same product',
              'Adding more story points per Sprint',
              'Extending the Product Backlog',
            ],
            'correct': 1,
            'explanation':
                'Scaling Scrum involves coordinating multiple teams working on the same product. Frameworks: SAFe, LeSS, Nexus.',
          },
          {
            'question':
                'What does Kanban contribute when combined with Scrum (Scrumban)?',
            'answers': [
              'Replacing Sprint time-boxes with continuous flow',
              'Visualising work in progress and limiting WIP to improve flow',
              'Adding a release manager role',
              'Extending the Sprint Retrospective',
            ],
            'correct': 1,
            'explanation':
                'Kanban\'s key practices — visualising workflow and limiting WIP — complement Scrum by making flow visible and reducing bottlenecks.',
          },
          {
            'question': 'What is the purpose of Nexus in scaled Scrum?',
            'answers': [
              'A large central Product Backlog only',
              'A framework coordinating 3–9 Scrum teams working on a single product',
              'A tool for remote teams',
              'A governance body approving Sprint Goals',
            ],
            'correct': 1,
            'explanation':
                'Nexus (Scrum.org) = Nexus Integration Team coordinates dependencies between multiple Scrum teams and integrates their work each Sprint.',
          },
          {
            'question': 'In SAFe, what is a Program Increment (PI)?',
            'answers': [
              'A single Sprint across all teams',
              'A time-box (8–12 weeks) where multiple teams deliver significant value together',
              'A product release to customers',
              'A quarterly stakeholder review',
            ],
            'correct': 1,
            'explanation':
                'PI = typically 5 iterations (4 development + 1 hardening). Teams align to shared objectives and coordinate dependencies during PI Planning.',
          },
          {
            'question': 'What is the most common challenge when scaling Scrum?',
            'answers': [
              'Story point inflation',
              'Managing cross-team dependencies and integration of work',
              'Too many Scrum Masters',
              'Sprint length synchronisation',
            ],
            'correct': 1,
            'explanation':
                'Cross-team dependencies are the biggest scaling challenge — when Team A\'s work depends on Team B\'s output, synchronisation is critical.',
          },
          {
            'question':
                'What is a Community of Practice (CoP) in a scaled Agile context?',
            'answers': [
              'A formal governance committee',
              'An informal group of practitioners sharing expertise across teams',
              'A Sprint Review involving all scaled teams',
              'A role in SAFe',
            ],
            'correct': 1,
            'explanation':
                'CoPs are informal networks where practitioners share knowledge and best practices across team boundaries.',
          },
          {
            'question': 'What problem does LeSS (Large-Scale Scrum) solve?',
            'answers': [
              'Managing a single team\'s Sprint capacity',
              'Applying Scrum to multiple teams with minimal additional roles and processes',
              'Replacing Scrum for enterprises',
              'Managing vendor relationships in Agile projects',
            ],
            'correct': 1,
            'explanation':
                'LeSS extends Scrum to multiple teams with minimal new roles. Its philosophy: keep Scrum intact and scale by removing complexity, not adding layers.',
          },
          {
            'question': 'What is an Agile Release Train (ART) in SAFe?',
            'answers': [
              'A CI/CD deployment pipeline',
              'A long-lived team-of-teams (50–125 people) delivering value on a regular PI cadence',
              'A release management committee',
              'A product roadmap format',
            ],
            'correct': 1,
            'explanation':
                'ART = fundamental SAFe construct — long-lived virtual team of 50–125 people (5–12 teams) aligned to a common mission.',
          },
          {
            'question': 'What is Definition of Ready and who maintains it?',
            'answers': [
              'Criteria for releasing to customers, owned by PO',
              'A checklist defining when a PBI is sufficiently refined to enter a Sprint, collaboratively maintained by the Scrum Team',
              'Technical coding standards defined by dev team',
              'Sprint Review acceptance criteria',
            ],
            'correct': 1,
            'explanation':
                'Definition of Ready lists conditions a PBI must meet before Sprint Planning can include it. Collaboratively defined by the whole Scrum Team.',
          },
          {
            'question':
                'When does it make sense to introduce Scrum at an organisational level?',
            'answers': [
              'As soon as possible regardless of team size',
              'When multiple teams need to coordinate to deliver a single product with integrated releases',
              'Only for software development',
              'When project budget exceeds a threshold',
            ],
            'correct': 1,
            'explanation':
                'Organisational Scrum adoption makes sense when teams are interdependent on a shared product. Single independent teams don\'t need scaling frameworks.',
          },
        ];

      case 'module-08':
        return [
          {
            'question': 'How many questions are on the CSM exam?',
            'answers': ['40', '50', '60', '100'],
            'correct': 2,
            'explanation':
                '60 questions, 60 minutes. Pass mark typically 74% (45/60 correct). Scenario-based multiple choice.',
          },
          {
            'question':
                'A manager attends every Daily Scrum to monitor progress. What should the SM do?',
            'answers': [
              'Allow it — transparency is a Scrum value',
              'Make the Daily Scrum private',
              'Explain that the Daily Scrum is for the dev team; the manager may observe but must not participate or make it a status meeting',
              'Ask the manager to join as a team member',
            ],
            'correct': 2,
            'explanation':
                'Daily Scrum is owned by the dev team. Managers may observe but must not disrupt it or turn it into a status report.',
          },
          {
            'question': 'Which is an Agile anti-pattern?',
            'answers': [
              'Self-organising teams deciding how to accomplish Sprint work',
              'PO attending Sprint Reviews',
              'Detailed upfront planning inside sprints instead of backlog refinement (Water-Scrum-fall)',
              'Running Retrospective after every Sprint',
            ],
            'correct': 2,
            'explanation':
                '"Water-Scrum-fall" = using Sprint time-boxes but doing waterfall-style detailed planning upfront. True Scrum uses iterative refinement, not comprehensive upfront design.',
          },
          {
            'question':
                'The dev team says Feature X will be ready by Sprint 5. The PO promises it to a client after Sprint 4. What is the problem?',
            'answers': [
              'PO has full authority to commit dates',
              'PO made a commitment without team input — creating a false promise undermining trust',
              'Team is too conservative in estimates',
              'This is standard Agile planning',
            ],
            'correct': 1,
            'explanation':
                'PO should never commit delivery dates without team input. Promising before the team\'s earliest estimate sets false expectations.',
          },
          {
            'question':
                'Which CSM exam topic is most frequently tested in scenarios?',
            'answers': [
              'Agile Manifesto values word-for-word',
              'Scrum role boundaries, anti-patterns, and real-world challenge responses',
              'Fibonacci sequence numbers',
              'SAFe framework terminology',
            ],
            'correct': 1,
            'explanation':
                'CSM exam scenarios test HOW Scrum roles should behave in realistic situations. Role boundaries, impediment handling, and coaching dominate.',
          },
          {
            'question':
                'What should a SM do when performance reviews reward individual contributions over team outcomes?',
            'answers': [
              'Ignore it — HR is outside SM scope',
              'Coach the organisation to align HR practices with Agile values',
              'Ask developers to compete for best individual performance',
              'Cancel Retrospectives to avoid conflict',
            ],
            'correct': 1,
            'explanation':
                'SM serves the organisation — coaching leadership on how structures and incentives affect Agile adoption. Individual-focused reviews undermine team collaboration.',
          },
          {
            'question': 'When is it appropriate to cancel a Sprint?',
            'answers': [
              'When the team has not completed all Sprint Backlog items',
              'When only the Sprint Goal becomes obsolete',
              'When a key developer is sick',
              'When the Scrum Master recommends it',
            ],
            'correct': 1,
            'explanation':
                'Only the PO can cancel a Sprint, only when the Sprint Goal is obsolete. Sprint cancellations should be rare.',
          },
          {
            'question': 'What distinguishes a high-performing Scrum team?',
            'answers': [
              'They complete all Sprint items every Sprint',
              'They continuously inspect and adapt — learning from each Sprint to improve product and process',
              'They never need a SM after 6 months',
              'They have the highest velocity',
            ],
            'correct': 1,
            'explanation':
                'High-performing teams embody empiricism — learning continuously, adapting process in Retrospectives, improving quality and collaboration over time.',
          },
          {
            'question':
                'A new team member says "Scrum is just Agile." Most accurate response?',
            'answers': [
              'Yes — they are the same thing',
              'Agile is a set of values and principles; Scrum is a specific framework implementing Agile values through defined roles, events, and artifacts',
              'No — Scrum is a methodology not related to Agile',
              'Agile is for software; Scrum can be used for anything',
            ],
            'correct': 1,
            'explanation':
                'Agile = values and principles (the Manifesto). Scrum = a framework that operationalises Agile values. Scrum is one way to be Agile — not the only way.',
          },
          {
            'question':
                'Which best demonstrates the Scrum value of "Openness"?',
            'answers': [
              'Team hides technical debt from the PO',
              'Team transparently surfaces impediments, risks, and problems even when it creates short-term discomfort',
              'SM shares competitor analysis with the team',
              'PO publishes the roadmap publicly',
            ],
            'correct': 1,
            'explanation':
                'Openness = transparent about work, impediments, and problems — even uncomfortable ones. Hiding problems violates Openness and prevents inspection and adaptation.',
          },
        ];

      default:
        return [
          {
            'question': 'What is a Sprint in Scrum?',
            'answers': [
              'A long-term project plan',
              'A time-boxed iteration of one month or less producing a Done, usable Increment',
              'A type of stand-up meeting',
              'A backlog prioritisation session',
            ],
            'correct': 1,
            'explanation':
                'A Sprint is the core container event — time-box of one month or less producing a Done, usable, potentially releasable Increment.',
          },
        ];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Binary Cloud — 8 modules
  // ═══════════════════════════════════════════════════════════════════════════
  List<Map<String, dynamic>> _cloudFundamentalsQuestions(String moduleId) {
    switch (moduleId) {
      // ═══════════════════════════════════════════════════════════════════════════
// Binary Cloud — Modules 01–04 REWRITTEN (scenario-based)
// Drop these cases into _cloudFundamentalsQuestions() replacing the old ones.
// ═══════════════════════════════════════════════════════════════════════════

// ── MODULE 01 — Cloud Concepts & Characteristics ────────────────────────────
      case 'module-01':
        return [
          {
            'question':
                'A retail company runs its own servers. Every Black Friday they crash under traffic. The rest of the year, 70% of those servers sit idle. What is the core cloud characteristic that directly solves this problem?',
            'answers': [
              'Broad network access — staff can reach servers remotely',
              'Rapid elasticity — capacity scales up under load and releases when demand drops',
              'Measured service — they only pay for what they use',
              'Resource pooling — servers are shared across tenants',
            ],
            'correct': 1,
            'explanation':
                'Rapid elasticity directly solves seasonal spikes. The company scales up for Black Friday and scales down the rest of the year — no idle hardware. Measured service is a benefit of elasticity but is not itself the scaling mechanism.',
          },
          {
            'question':
                'A startup CTO says: "We spent \$400k on servers last year. Half that was sitting unused while we waited for our product to find users. We need a better model." Which cloud characteristic she is describing the absence of?',
            'answers': [
              'On-demand self-service',
              'Resource pooling',
              'Rapid elasticity combined with measured service — pay only for what you consume',
              'Broad network access',
            ],
            'correct': 2,
            'explanation':
                'The CTO wasted money on provisioned but unused capacity — the opposite of measured service (pay-per-use). Elasticity + measured service together mean she only pays while resources are actually being used.',
          },
          {
            'question':
                'A development team in London needs a new test server at 11pm. Their IT department is closed. In the cloud, they spin one up in 3 minutes without calling anyone. Which characteristic made this possible?',
            'answers': [
              'Broad network access',
              'On-demand self-service',
              'Resource pooling',
              'Measured service',
            ],
            'correct': 1,
            'explanation':
                'On-demand self-service = provisioning without human interaction from the provider. The team used a console or API to get the server themselves — no ticket, no IT department needed.',
          },
          {
            'question':
                'A company\'s finance team accesses their cloud ERP from office desktops. The sales team uses it on mobile phones in the field. The warehouse uses it on shared tablets. Which NIST characteristic enables this?',
            'answers': [
              'Rapid elasticity',
              'Measured service',
              'On-demand self-service',
              'Broad network access — services accessible via standard devices and protocols',
            ],
            'correct': 3,
            'explanation':
                'Broad network access = cloud services available over the network to any standard client device. Desktop, mobile, tablet — all work because the service uses standard web protocols.',
          },
          {
            'question':
                'An AWS data centre hosts workloads from thousands of different companies simultaneously on the same physical hardware — but each company only sees their own resources. Which characteristic describes this?',
            'answers': [
              'Multi-tenancy through resource pooling',
              'On-demand self-service',
              'Broad network access',
              'Measured service',
            ],
            'correct': 0,
            'explanation':
                'Resource pooling = provider\'s physical resources dynamically serve multiple tenants with logical isolation. The hardware is shared; the data and access are not.',
          },
          {
            'question':
                'A SaaS company\'s cloud bill increases by exactly 340% in December due to a viral campaign. In January it returns to normal. No infrastructure changes were made manually. Which two characteristics working together enabled this?',
            'answers': [
              'Broad network access and on-demand self-service',
              'Rapid elasticity and measured service',
              'Resource pooling and broad network access',
              'On-demand self-service and resource pooling',
            ],
            'correct': 1,
            'explanation':
                'Rapid elasticity automatically scaled capacity to meet demand. Measured service meant the bill reflected actual usage — up in December, back to normal in January. Neither works without the other here.',
          },
          {
            'question':
                'A company migrates from buying physical servers (£200k upfront every 3 years) to renting cloud VMs monthly. Their CFO asks what financial category has changed. What is the correct answer?',
            'answers': [
              'They moved from OpEx to CapEx — now they own less',
              'They moved from CapEx to OpEx — from large upfront capital to ongoing operational expense',
              'No change — cloud is just renting servers',
              'They moved to CapEx because cloud contracts are long-term',
            ],
            'correct': 1,
            'explanation':
                'Physical servers = CapEx (large upfront capital investment). Cloud VMs = OpEx (monthly operational expense). This shift improves cash flow and removes the risk of owning depreciating hardware.',
          },
          {
            'question':
                'A company\'s cloud bill shows line items for: 847 compute hours, 2.3TB storage, 180GB data transfer, and 4.2 million API calls. This billing model is an example of which cloud characteristic?',
            'answers': [
              'Rapid elasticity',
              'On-demand self-service',
              'Measured service — granular metering of actual consumption',
              'Resource pooling',
            ],
            'correct': 2,
            'explanation':
                'Measured service meters usage at a granular level — compute hours, GB stored, data transferred — and bills exactly for what was consumed. Like a utility bill for electricity.',
          },
          {
            'question':
                'A company wants to test a new application idea. They need 50 servers for 2 weeks, then nothing. On-premises this would require a 6-week hardware procurement process. What makes cloud the right choice here?',
            'answers': [
              'Cloud is always cheaper than on-premises',
              'On-demand self-service and elasticity — provision 50 servers in minutes, release them in 2 weeks',
              'Cloud providers manage the application for you',
              'Cloud servers are faster than physical servers',
            ],
            'correct': 1,
            'explanation':
                'On-demand self-service eliminates procurement delays. Elasticity means releasing the 50 servers when done — no sunk cost. A 2-week burst workload is the textbook use case for cloud economics.',
          },
          {
            'question':
                'An engineer sets up auto-scaling on a web fleet. During a load test, the fleet grows from 4 to 23 instances automatically, then shrinks back to 4 when the test ends. The total bill for the test is £18. Which NIST characteristics are directly demonstrated?',
            'answers': [
              'Broad network access and resource pooling',
              'On-demand self-service and broad network access',
              'Rapid elasticity and measured service',
              'Resource pooling and on-demand self-service',
            ],
            'correct': 2,
            'explanation':
                'Rapid elasticity = automatic scale-up and scale-down. Measured service = the £18 bill reflects only the hours those instances ran. Both characteristics are directly observable in this scenario.',
          },
        ];

// ── MODULE 02 — Cloud Service Models ────────────────────────────────────────
      case 'module-02':
        return [
          {
            'question':
                'A team needs to run a legacy Windows application that requires a specific OS version and custom registry settings. They need full control of the environment but don\'t want to own physical hardware. Which service model fits?',
            'answers': [
              'SaaS — the provider manages everything',
              'PaaS — the provider manages the OS for them',
              'IaaS — they get a VM and control everything from the OS up',
              'FaaS — run the app as a serverless function',
            ],
            'correct': 2,
            'explanation':
                'IaaS gives full OS control — they can set the exact Windows version and registry settings. PaaS manages the OS for you, which breaks their requirement for custom OS configuration.',
          },
          {
            'question':
                'A data science team wants to train machine learning models. They don\'t want to manage servers, install Python, or configure Jupyter notebooks. They just want to write code and run experiments. Which model serves them best?',
            'answers': [
              'IaaS — full control of the environment',
              'PaaS — platform manages infrastructure; team focuses on code and data',
              'SaaS — everything managed, including the application logic',
              'On-premises — better GPU performance',
            ],
            'correct': 1,
            'explanation':
                'PaaS (e.g. Google Colab, Azure ML, SageMaker Studio) provides the runtime, libraries, and infrastructure. The team writes code without managing any servers — exactly what they need.',
          },
          {
            'question':
                'A 500-person company switches from running their own email servers to using a cloud email product. Their IT team no longer manages servers, OS patches, or email software updates. Which model describes the new setup?',
            'answers': [
              'IaaS — servers are in the cloud',
              'PaaS — the platform handles the email logic',
              'SaaS — the entire application is managed by the provider',
              'Hybrid — some on-premises, some cloud',
            ],
            'correct': 2,
            'explanation':
                'SaaS: the provider manages everything — hardware, OS, application, updates. The IT team just administers user accounts. Email products like Microsoft 365 and Google Workspace are the canonical SaaS examples.',
          },
          {
            'question':
                'A developer pushes code with `git push` and it is live in 90 seconds. She never configured a web server, installed a runtime, or set up a database connection string. Which model is her platform using?',
            'answers': [
              'IaaS — fast provisioning scripts',
              'PaaS — the platform handles the full runtime stack',
              'SaaS — the application is pre-built',
              'FaaS — each git push triggers a function',
            ],
            'correct': 1,
            'explanation':
                'PaaS (Heroku, Render, Railway, Google App Engine) takes code and handles the rest — runtime, web server, scaling. The developer\'s only responsibility is the application code.',
          },
          {
            'question':
                'A company runs their customer database on a cloud VM. They are responsible for OS patching, database installation, backups, and firewall rules. A security breach occurs because they missed a OS patch. Who is liable?',
            'answers': [
              'The cloud provider — they manage the infrastructure',
              'The company — under IaaS, OS management is the customer\'s responsibility',
              'Shared equally — cloud security is always joint',
              'The database vendor — the software had a vulnerability',
            ],
            'correct': 1,
            'explanation':
                'Under IaaS shared responsibility: the provider secures the physical hardware and hypervisor. The customer owns everything from the OS up — including patching. Missing an OS patch is the customer\'s failure.',
          },
          {
            'question':
                'An application processes uploaded images. It runs code for 200ms per image then does nothing. The team is billed for 0 when no images are uploaded. Which model describes this?',
            'answers': [
              'PaaS — managed runtime platform',
              'IaaS — virtual machines that scale to zero',
              'FaaS — executes on event trigger, billed per execution, zero cost when idle',
              'SaaS — fully managed image processing service',
            ],
            'correct': 2,
            'explanation':
                'FaaS (AWS Lambda, Azure Functions) runs code only on trigger, scales to zero between events, and bills per millisecond of execution. Zero uploads = zero cost. No VM sits idle.',
          },
          {
            'question':
                'A startup has three engineers. They want to launch a web app in a week without hiring a DevOps engineer. Which service model lets them focus entirely on application code without managing infrastructure?',
            'answers': [
              'IaaS — cheap VMs they can configure themselves',
              'PaaS — handles all infrastructure so the team writes only application code',
              'SaaS — use someone else\'s application',
              'On-premises — full control from day one',
            ],
            'correct': 1,
            'explanation':
                'PaaS removes all infrastructure work for small teams. No DevOps hire needed — the platform handles servers, scaling, and runtime. IaaS would require significant ops work that a 3-person team cannot afford.',
          },
          {
            'question':
                'A company uses a cloud HR system. Their legal team needs a custom data export that the vendor doesn\'t offer and won\'t build. The company cannot modify the application. Which model\'s tradeoff are they experiencing?',
            'answers': [
              'IaaS — limited customisation at the infrastructure level',
              'PaaS — the platform controls the database schema',
              'SaaS — convenience comes at the cost of customisation; you use what the vendor provides',
              'FaaS — serverless functions cannot be customised',
            ],
            'correct': 2,
            'explanation':
                'SaaS tradeoff: maximum convenience, minimum customisation. You use the application as built. If the vendor doesn\'t offer a feature, you cannot add it yourself. IaaS and PaaS give you code-level control.',
          },
          {
            'question':
                'A team is deciding between hosting their API on a VM (IaaS) vs a managed container service (PaaS). The PaaS option costs 20% more per month. What is the strongest business case for choosing PaaS?',
            'answers': [
              'PaaS is always more reliable',
              'PaaS eliminates the engineering time spent on OS patching, scaling config, and runtime maintenance — that time cost exceeds 20%',
              'PaaS has better network performance',
              'PaaS is easier to migrate away from later',
            ],
            'correct': 1,
            'explanation':
                'The true cost of IaaS includes engineering hours for OS maintenance, security patching, and scaling configuration. A 20% price premium for PaaS is almost always cheaper when you factor in staff time.',
          },
          {
            'question':
                'An application runs smoothly on PaaS during normal traffic. During a flash sale it needs 40x more capacity for 2 hours. The team did not configure anything — the platform scaled automatically. Two hours later it scaled back. Which statement is correct?',
            'answers': [
              'This would not happen on PaaS — scaling requires manual configuration',
              'This is a PaaS advantage — the platform handles scaling without the team configuring individual VMs',
              'This is IaaS auto-scaling triggered by a monitoring alert',
              'This is FaaS — the application must be stateless for this to work',
            ],
            'correct': 1,
            'explanation':
                'Managed PaaS platforms handle scaling automatically as part of the service. The team writes code; the platform handles capacity. This is the core value proposition of PaaS over IaaS.',
          },
        ];

// ── MODULE 03 — Cloud Deployment Models ─────────────────────────────────────
      case 'module-03':
        return [
          {
            'question':
                'A bank stores customer financial records on private infrastructure in their own data centre. They run their customer-facing mobile app on AWS. A security audit flags that both environments must be treated as connected. What deployment model is this?',
            'answers': [
              'Multi-cloud — using two different environments',
              'Private cloud — everything stays internal',
              'Hybrid cloud — private infrastructure for sensitive data, public cloud for customer-facing workloads',
              'Community cloud — shared between regulated institutions',
            ],
            'correct': 2,
            'explanation':
                'Hybrid cloud combines private (sensitive regulated data) with public cloud (scalable customer-facing app). The connection between them is what makes it hybrid — not just using both independently.',
          },
          {
            'question':
                'A company uses AWS for their main application, Azure for their data analytics pipeline, and Google Cloud for their ML training jobs. Their CTO chose each for best-in-class capabilities. What is this strategy called and what risk does it introduce?',
            'answers': [
              'Hybrid cloud — risk is data sovereignty compliance',
              'Multi-cloud — risk is increased operational complexity and skill requirements across platforms',
              'Community cloud — risk is shared security responsibility',
              'Private cloud — risk is vendor lock-in',
            ],
            'correct': 1,
            'explanation':
                'Multi-cloud uses multiple providers intentionally for best-of-breed services. The primary risk is complexity — different APIs, tooling, billing, and skills needed for each platform.',
          },
          {
            'question':
                'A government ministry must ensure citizen data never leaves the country. Their legal team says third-party public cloud providers cannot be used. Which deployment model is required?',
            'answers': [
              'Public cloud with data encryption',
              'Community cloud shared with other government agencies',
              'Multi-cloud with regional restrictions configured',
              'Private cloud — complete control over data location and access',
            ],
            'correct': 3,
            'explanation':
                'Private cloud gives the ministry complete control over physical data location and who can access it. Public cloud — even with encryption — means a foreign company holds the keys. Data sovereignty regulations often mandate private infrastructure.',
          },
          {
            'question':
                'A company built their entire platform using proprietary AWS services: DynamoDB, Lambda, Kinesis, and SageMaker. Two years later they want to switch to Azure to cut costs. Their engineering team estimates 18 months of rewriting. What caused this?',
            'answers': [
              'Multi-cloud complexity — too many platforms to manage',
              'Vendor lock-in — deep use of proprietary services makes migration extremely costly',
              'Hybrid cloud risk — their on-premises systems cannot connect to Azure',
              'Private cloud limitation — they cannot scale on Azure without re-architecting',
            ],
            'correct': 1,
            'explanation':
                'Vendor lock-in: proprietary managed services (DynamoDB, Kinesis) have no direct equivalents elsewhere. Migrating requires rebuilding with different APIs and data models — the deeper you go, the more it costs to leave.',
          },
          {
            'question':
                'Five NHS hospital trusts share a cloud environment with common security controls, GDPR compliance frameworks, and NHS-specific data handling policies. No other organisations use this environment. What is this?',
            'answers': [
              'Public cloud with NHS-specific configuration',
              'Private cloud owned by the NHS',
              'Community cloud — shared by organisations with common compliance requirements',
              'Hybrid cloud — combines NHS data centres with public cloud',
            ],
            'correct': 2,
            'explanation':
                'Community cloud is shared exclusively by organisations with common concerns — in this case, NHS trusts sharing healthcare compliance requirements. It\'s not public (others cannot join) and not private (it\'s shared).',
          },
          {
            'question':
                'A growing e-commerce company currently hosts everything on-premises. They want to move their product catalogue to the cloud to handle traffic spikes, while keeping their payment processing on their own servers for compliance. What should they build?',
            'answers': [
              'Full public cloud migration — compliance concerns can be handled in the cloud',
              'Full private cloud — move everything to virtualised on-premises infrastructure',
              'Hybrid cloud — public cloud for scalable catalogue, private/on-premises for regulated payment processing',
              'Multi-cloud — split across AWS and Azure for redundancy',
            ],
            'correct': 2,
            'explanation':
                'Hybrid cloud is purpose-built for this: elastic public cloud for variable workloads (product catalogue), private/on-premises for compliance-sensitive workloads (payments). The right data in the right environment.',
          },
          {
            'question':
                'A startup chooses public cloud from day one. Their CTO says "we have zero budget for hardware, need to launch in 6 weeks, and don\'t know yet if the product will survive." Which characteristic of public cloud drove this decision?',
            'answers': [
              'Maximum security and compliance controls',
              'Zero upfront capital cost, instant provisioning, and the ability to shut everything down if the product fails',
              'Guaranteed performance SLAs not available on-premises',
              'Full control over the underlying infrastructure',
            ],
            'correct': 1,
            'explanation':
                'Public cloud removes capital risk for early-stage companies. No hardware to buy, provision in minutes, shut down without sunk costs if the product fails. This is why almost all startups begin on public cloud.',
          },
          {
            'question':
                'A company runs workloads on both AWS and their private data centre. During their annual DR test, a simulated AWS region failure automatically routes all traffic to their private data centre with no downtime. What made this possible?',
            'answers': [
              'Multi-cloud replication between AWS and Azure',
              'Hybrid cloud architecture with failover routing between public and private environments',
              'AWS global infrastructure automatically rerouting to nearest region',
              'Public cloud SLA guaranteeing 100% uptime',
            ],
            'correct': 1,
            'explanation':
                'Hybrid cloud enables failover between environments. The private data centre acts as the DR target. This pattern requires careful network connectivity and DNS failover between the two environments.',
          },
          {
            'question':
                'A company standardises all new services on open-source components (Kubernetes, PostgreSQL, Kafka) instead of proprietary cloud services. Their architect says "this costs more to manage but we can move it anywhere." What concern is she addressing?',
            'answers': [
              'Data sovereignty — open-source data stays in the country',
              'Vendor lock-in — using portable open standards keeps migration options open',
              'Community cloud compliance — open-source is required for shared environments',
              'Multi-cloud billing — proprietary services cannot be billed across providers',
            ],
            'correct': 1,
            'explanation':
                'Using open-source, cloud-agnostic components is the primary strategy for avoiding vendor lock-in. Kubernetes runs on any cloud. PostgreSQL runs anywhere. The extra management overhead is the tradeoff for portability.',
          },
          {
            'question':
                'A retailer uses public cloud for their website but processes end-of-day sales data on on-premises servers due to data residency laws. Their cloud architect says the two environments are "connected but separate." What model is this, and what is the primary technical challenge?',
            'answers': [
              'Multi-cloud — challenge is managing two cloud provider APIs',
              'Community cloud — challenge is data sharing between tenants',
              'Hybrid cloud — challenge is secure, low-latency connectivity between public and private environments',
              'Private cloud — challenge is scaling the on-premises infrastructure',
            ],
            'correct': 2,
            'explanation':
                'Hybrid cloud\'s core technical challenge is the connection between environments — VPN or dedicated link (AWS Direct Connect, Azure ExpressRoute), consistent security policies, and data transfer latency.',
          },
        ];

// ── MODULE 04 — Cloud Storage and Compute ───────────────────────────────────
      case 'module-04':
        return [
          {
            'question':
                'A media company stores 4 million user-uploaded videos. Videos are accessed via a URL in a mobile app. The storage must handle unlimited growth and serve files globally over HTTP. Which storage type is correct?',
            'answers': [
              'Block storage — fastest throughput for large files',
              'File storage — shared network filesystem for media assets',
              'Object storage — flat namespace, HTTP access, infinite scale for unstructured files',
              'Archive storage — lowest cost for large media libraries',
            ],
            'correct': 2,
            'explanation':
                'Object storage (S3, GCS, Azure Blob) is designed for exactly this: unstructured files served via HTTP at unlimited scale. Videos, images, and documents are the canonical object storage use case.',
          },
          {
            'question':
                'A database server on a cloud VM needs fast, low-latency disk I/O. The volume must mount directly to the VM and behave like a local hard drive. Which storage type should the engineer choose?',
            'answers': [
              'Object storage — accessible via API from the database process',
              'Block storage — raw volume attached directly to the VM, low-latency like a physical disk',
              'File storage — NFS mount shared across the database cluster',
              'Archive storage — cheapest option for database files',
            ],
            'correct': 1,
            'explanation':
                'Block storage (EBS, Azure Managed Disk) attaches directly to a VM as a raw volume. Databases require block storage for low-latency I/O — object storage APIs are too slow for database workloads.',
          },
          {
            'question':
                'A render farm has 30 worker VMs that all need read/write access to the same project files simultaneously. A single artist\'s change must be visible to all workers immediately. Which storage type enables this?',
            'answers': [
              'Object storage — each VM accesses files via S3 API',
              'Block storage — one volume per VM, manually synced',
              'File storage — shared NFS/SMB filesystem accessible by all VMs simultaneously',
              'Archive storage — low-cost shared access',
            ],
            'correct': 2,
            'explanation':
                'File storage (AWS EFS, Azure Files) provides a shared filesystem multiple VMs can mount simultaneously with read/write access. Block storage is one-to-one; object storage doesn\'t provide filesystem semantics.',
          },
          {
            'question':
                'An application serves 500 requests/second on normal days. On product launch days it hits 18,000 requests/second for about 4 hours. The team currently provisions for 18,000 at all times at enormous cost. What is the right cloud solution?',
            'answers': [
              'Upgrade to larger VMs permanently to handle peak load more efficiently',
              'Move to a multi-cloud setup to distribute the load',
              'Implement Auto Scaling — add instances automatically during launches, remove them after',
              'Use archive storage to reduce the cost of idle resources',
            ],
            'correct': 2,
            'explanation':
                'Auto Scaling solves exactly this: scale out to 18,000 req/s capacity during launch, scale back to 500 req/s capacity after. The team stops paying for peak capacity 24/7 and only pays during the actual peak.',
          },
          {
            'question':
                'A company\'s website loads slowly for users in Southeast Asia despite the servers being in Ireland. Static assets like images and CSS files account for 80% of page load time. What should the architect add?',
            'answers': [
              'A second server region in Singapore',
              'A Content Delivery Network — caches static assets at edge locations near Southeast Asian users',
              'Larger VMs in Ireland for faster response generation',
              'Object storage in Ireland with cross-region replication',
            ],
            'correct': 1,
            'explanation':
                'A CDN caches static assets at edge locations worldwide. A user in Singapore gets images served from a nearby edge node — not from Ireland. This is the standard solution for latency caused by geographic distance.',
          },
          {
            'question':
                'An engineer notices that 3 out of 6 VMs in a load-balanced pool are showing high error rates. The load balancer is still sending them traffic. What feature should have been configured to prevent this?',
            'answers': [
              'Auto Scaling — adds new instances to replace failing ones',
              'Health checks — load balancer removes instances failing checks from the rotation automatically',
              'CDN caching — reduces requests reaching unhealthy VMs',
              'Block storage snapshots — restores VMs to a known good state',
            ],
            'correct': 1,
            'explanation':
                'Load balancer health checks probe each instance on a configured interval. Instances returning errors are removed from the pool. Without health checks, the load balancer blindly sends traffic to broken instances.',
          },
          {
            'question':
                'A compliance team requires that database backups older than 90 days are kept for 7 years but may never be needed. Retrieval within 48 hours is acceptable. Storage cost must be minimised. Which storage class fits?',
            'answers': [
              'Standard storage — immediate retrieval, highest cost',
              'Infrequent access storage — cheaper but still fast retrieval',
              'Archive/glacier storage — lowest cost, hours-to-days retrieval, designed for long-term retention',
              'Block storage snapshots — best for database backup retention',
            ],
            'correct': 2,
            'explanation':
                'Archive storage (S3 Glacier, Azure Archive) is designed for data that must be kept but is rarely if ever accessed. Retrieval takes hours — acceptable for 7-year compliance archives. Cost is a fraction of standard storage.',
          },
          {
            'question':
                'A startup\'s web app runs on a single VM. During testing, the VM\'s CPU hits 95% and the site becomes unresponsive. The engineer wants to handle more load without rewriting the application. What are the two scaling options and which is easier?',
            'answers': [
              'Horizontal (add VMs) and vertical (bigger VM) — vertical is easier as it requires no application changes',
              'Horizontal (add VMs) and vertical (bigger VM) — horizontal is easier because VMs are cheap',
              'Diagonal scaling and multi-cloud — both require load balancer reconfiguration',
              'Auto Scaling and CDN — CDN is easier because it requires no server changes',
            ],
            'correct': 0,
            'explanation':
                'Vertical scaling (upgrading to a larger VM) is the easier immediate fix — no application changes, no load balancer needed. Horizontal scaling (adding VMs) is more resilient long-term but requires a load balancer and stateless application design.',
          },
          {
            'question':
                'A product team asks: "Can we store our 50TB of application logs cheaply but still run SQL queries against them occasionally?" Which storage approach handles both requirements?',
            'answers': [
              'Block storage attached to a database server — fastest query performance',
              'Standard object storage with a query service like Athena — cheap storage, on-demand SQL without loading data into a database',
              'File storage with a shared SQL server reading from the NFS mount',
              'Archive storage — cheapest option, retrieve logs before querying',
            ],
            'correct': 1,
            'explanation':
                'Object storage + serverless query (S3 + Athena, GCS + BigQuery) lets teams store logs cheaply and query them on demand without a persistent database. This pattern is standard for log analytics.',
          },
          {
            'question':
                'A team runs a batch processing job every night at 2am. The job takes 45 minutes and uses 20 large VMs. For the remaining 23 hours and 15 minutes, those VMs sit completely idle. What is the most cost-effective solution?',
            'answers': [
              'Reserve those VMs for 1 year to get a discount on the idle time',
              'Move to a larger VM so the job completes faster and costs less',
              'Terminate the VMs after each job and provision them fresh each night — pay only for 45 minutes of compute',
              'Use a CDN to cache the batch output and avoid re-running the job',
            ],
            'correct': 2,
            'explanation':
                'Provision on demand, terminate when done. Cloud pay-per-use means 45 minutes of 20 VMs costs a fraction of running them 24/7. This is the correct pattern for scheduled batch jobs — automation handles the provision/terminate cycle.',
          },
        ];

      case 'module-05':
        return [
          {
            'question':
                'Under the AWS Shared Responsibility Model, which is ALWAYS the customer\'s responsibility?',
            'answers': [
              'Physical security of data centres',
              'Patching the hypervisor',
              'Configuring IAM policies and managing user access',
              'Maintaining network hardware',
            ],
            'correct': 2,
            'explanation':
                'IAM configuration — who can access what — is always the customer\'s. AWS provides the IAM service; customer controls how it is configured.',
          },
          {
            'question': 'What is the principle of least privilege?',
            'answers': [
              'All users start with admin and have permissions removed',
              'Users receive only the minimum permissions required to perform their function',
              'Admin access only for senior staff',
              'All permissions reviewed quarterly',
            ],
            'correct': 1,
            'explanation':
                'Least privilege limits blast radius of compromised credentials. A developer needing only S3 reads should have exactly that.',
          },
          {
            'question': 'What does encryption "at rest" protect against?',
            'answers': [
              'Interception of data across networks',
              'Unauthorised access to data stored on disk — e.g. if physical media is stolen',
              'Misconfigured IAM policies',
              'DDoS attacks',
            ],
            'correct': 1,
            'explanation':
                'Encryption at rest protects stored data. If a drive is physically removed from a data centre, encrypted data is unreadable without the decryption key.',
          },
          {
            'question':
                'A Security Group in AWS is STATEFUL. What does this mean?',
            'answers': [
              'It remembers previous security configurations',
              'Return traffic for an allowed inbound request is automatically allowed outbound without an explicit rule',
              'It applies to an entire VPC',
              'It maintains logs of all connections',
            ],
            'correct': 1,
            'explanation':
                'Stateful = return traffic automatically permitted. Allow inbound HTTP on port 80 → response traffic automatically allowed out. Network ACLs are stateless.',
          },
          {
            'question':
                'Which compliance framework applies to EU citizens\' personal data regardless of organisation location?',
            'answers': ['HIPAA', 'PCI-DSS', 'SOC 2', 'GDPR'],
            'correct': 3,
            'explanation':
                'GDPR has extraterritorial scope — applies to ANY organisation processing personal data of EU residents, regardless of where the organisation is based.',
          },
          {
            'question':
                'Difference between a Security Group and Network ACL in AWS?',
            'answers': [
              'Security Groups apply at subnet level; ACLs at instance level',
              'Security Groups are stateful at instance level; Network ACLs are stateless at subnet level',
              'They are functionally identical',
              'ACLs replace Security Groups in modern VPC design',
            ],
            'correct': 1,
            'explanation':
                'Security Groups = stateful, instance-level. Network ACLs = stateless, subnet-level. Both provide layered defence and should be used together.',
          },
          {
            'question':
                'An S3 bucket with customer data is accidentally made publicly readable. Who is responsible?',
            'answers': [
              'AWS — they manage S3',
              'The customer — configuring access controls is the customer\'s responsibility',
              'Shared equally',
              'The cloud security vendor',
            ],
            'correct': 1,
            'explanation':
                'Configuring access controls — including S3 bucket policies and ACLs — is always the customer\'s responsibility.',
          },
          {
            'question':
                'What is MFA and why is it important for cloud accounts?',
            'answers': [
              'A way to share accounts between users securely',
              'An additional verification step beyond password that dramatically reduces account takeover risk',
              'A tool for managing multiple cloud accounts',
              'A compliance requirement only for financial services',
            ],
            'correct': 1,
            'explanation':
                'MFA = something you know + something you have. Even if a password is stolen, attacker cannot access account without the second factor. Critical for cloud root accounts.',
          },
          {
            'question':
                'Which is an example of a cloud misconfiguration vulnerability?',
            'answers': [
              'Deploying a new virtual machine',
              'Leaving an S3 bucket publicly accessible when it should be private',
              'Using managed databases instead of self-hosted',
              'Enabling Auto Scaling on a web tier',
            ],
            'correct': 1,
            'explanation':
                'Misconfigured cloud resources — publicly accessible storage, overly permissive IAM roles, open security group rules — are among the leading causes of cloud breaches.',
          },
          {
            'question':
                'What US regulation governs patient health information (PHI) in cloud deployments?',
            'answers': ['GDPR', 'PCI-DSS', 'HIPAA', 'SOX'],
            'correct': 2,
            'explanation':
                'HIPAA mandates strict protections for PHI — encrypted storage, audit logs, access controls, and Business Associate Agreements with cloud providers.',
          },
        ];

      case 'module-06':
        return [
          {
            'question': 'What is a VPC?',
            'answers': [
              'A type of virtual processor',
              'A logically isolated network in the cloud where you control IP ranges, subnets, and routing',
              'A cloud provider\'s physical data centre',
              'A VPN service for remote workers',
            ],
            'correct': 1,
            'explanation':
                'VPC = your own isolated network environment. You define network topology, subnets, route tables, internet gateways, and security.',
          },
          {
            'question': 'Key difference between public and private subnet?',
            'answers': [
              'Public subnets are faster',
              'Public subnets have internet access; private subnets are isolated from the internet',
              'Private subnets cost more',
              'No practical security difference',
            ],
            'correct': 1,
            'explanation':
                'Public subnet = has internet gateway route → internet-facing. Private subnet = no internet gateway → internal-only. Fundamental VPC security design.',
          },
          {
            'question':
                'A three-tier app has web servers, app servers, and databases. Which should be in a PRIVATE subnet?',
            'answers': [
              'Web servers only',
              'App servers and databases',
              'Databases only',
              'All three tiers in public subnets',
            ],
            'correct': 1,
            'explanation':
                'Web servers need internet access (public). App servers and databases should never be directly internet-accessible — belong in private subnets.',
          },
          {
            'question': 'What does a load balancer\'s health check do?',
            'answers': [
              'Monitors CPU usage',
              'Removes unhealthy instances from rotation and restores them when they recover',
              'Balances load between regions',
              'Encrypts traffic',
            ],
            'correct': 1,
            'explanation':
                'Health checks probe each instance. Failed instances are removed from traffic rotation. Recovered instances are added back — automatic fault tolerance.',
          },
          {
            'question': 'What is an AWS Region?',
            'answers': [
              'A single data centre',
              'A geographic area containing multiple Availability Zones with isolated data centres',
              'A pricing tier for cloud services',
              'A network segment within a VPC',
            ],
            'correct': 1,
            'explanation':
                'Region = geographic cluster of multiple AZs. AWS has 30+ Regions. Deploying within a Region provides low latency for users in that geography.',
          },
          {
            'question': 'Why deploy across multiple Availability Zones?',
            'answers': [
              'To reduce costs',
              'To ensure the application continues running if a single AZ experiences a failure',
              'To comply with GDPR data residency',
              'To improve global network performance',
            ],
            'correct': 1,
            'explanation':
                'Multi-AZ = high availability. AZs are isolated — power failure in one AZ does not affect others.',
          },
          {
            'question': 'What is the purpose of a NAT Gateway?',
            'answers': [
              'Allow inbound internet traffic to private subnets',
              'Allow private subnet resources to initiate outbound internet connections without being reachable from the internet',
              'Encrypt traffic between subnets',
              'Connect two VPCs together',
            ],
            'correct': 1,
            'explanation':
                'NAT Gateway enables private subnet resources to reach the internet for updates and APIs, without exposing them to inbound internet traffic. Outbound only.',
          },
          {
            'question': 'What is latency-based routing in cloud DNS?',
            'answers': [
              'Routing that adds artificial delay for testing',
              'Directing users to the cloud region with the lowest network latency for best performance',
              'Routing that delays DNS record changes',
              'Routing that prioritises the cheapest region',
            ],
            'correct': 1,
            'explanation':
                'Latency-based routing sends each user to the region giving them the fastest response. A user in Tokyo routes to ap-northeast-1, not us-east-1.',
          },
          {
            'question': 'What does VPC Peering allow?',
            'answers': [
              'Connecting a VPC to the public internet',
              'Private network communication between two VPCs without traffic traversing the public internet',
              'Sharing subnets between multiple customers',
              'Connecting a VPC to on-premises',
            ],
            'correct': 1,
            'explanation':
                'VPC Peering = private network link between two VPCs. Traffic stays on AWS private network — secure, low-latency inter-VPC communication.',
          },
          {
            'question': 'What does DNS resolution do in cloud services?',
            'answers': [
              'Routes traffic between Availability Zones',
              'Translates human-readable domain names to IP addresses that network routing can use',
              'Encrypts domain queries',
              'Manages SSL certificates',
            ],
            'correct': 1,
            'explanation':
                'DNS maps names to IPs. Cloud DNS services (Route 53, Azure DNS) also support advanced routing — latency-based, geolocation, failover.',
          },
        ];

      case 'module-07':
        return [
          {
            'question': 'What is serverless computing?',
            'answers': [
              'Computing using invisible servers',
              'A model where the cloud provider manages all infrastructure — developers deploy code without provisioning servers',
              'Computing without internet connectivity',
              'A type of on-premises virtualisation',
            ],
            'correct': 1,
            'explanation':
                'Serverless = no servers to provision, patch, or scale. Deploy code (functions) and billed per execution. Scales to zero — no idle cost.',
          },
          {
            'question': 'What triggers a serverless function?',
            'answers': [
              'A scheduled maintenance window',
              'An event — like an HTTP request, file upload, or queue message',
              'A billing threshold alert',
              'A network failure notification',
            ],
            'correct': 1,
            'explanation':
                'Serverless functions are event-driven. Common triggers: API Gateway request, S3 upload, SQS message, DynamoDB change, scheduled timer.',
          },
          {
            'question': 'What is cloud monitoring primarily used for?',
            'answers': [
              'Billing management only',
              'Collecting metrics, logs, and traces to gain visibility into application and infrastructure health',
              'Auditing user access',
              'Managing DNS records',
            ],
            'correct': 1,
            'explanation':
                'Cloud monitoring (CloudWatch, Azure Monitor) collects performance metrics, logs, and traces — enabling detection, diagnosis, and proactive resolution.',
          },
          {
            'question':
                'What does Infrastructure as Code (IaC) enable that manual configuration does not?',
            'answers': [
              'Faster network performance',
              'Version-controlled, repeatable, and auditable infrastructure deployments automatable in CI/CD pipelines',
              'Lower cloud pricing',
              'Direct database access',
            ],
            'correct': 1,
            'explanation':
                'IaC (Terraform, CloudFormation) = define infrastructure in code, check into Git, deploy consistently every time. Manual config drifts and cannot be automated.',
          },
          {
            'question': 'What is a cloud tag?',
            'answers': [
              'A security label on encrypted data',
              'A key-value metadata label on cloud resources enabling cost allocation, automation, and governance',
              'A type of DNS record',
              'An alert triggered by a security event',
            ],
            'correct': 1,
            'explanation':
                'Tags (e.g. "Team: Payments") enable cost reports by team/project, automated governance rules, and operational filtering.',
          },
          {
            'question': 'What is "high availability" in cloud architecture?',
            'answers': [
              'The app is available in all global regions',
              'The system remains operational with minimal downtime through redundancy across multiple failure domains',
              'The cloud provider guarantees 100% uptime',
              'The app uses the fastest available servers',
            ],
            'correct': 1,
            'explanation':
                'HA = designed to survive component failures through redundancy (multiple AZs, load balancers, auto-healing). Minimises downtime.',
          },
          {
            'question': 'What is a cloud SLA?',
            'answers': [
              'A list of cloud services',
              'A contractual commitment by the provider guaranteeing specific uptime with credits if targets are missed',
              'A security policy signed by the customer',
              'A pricing agreement for reserved capacity',
            ],
            'correct': 1,
            'explanation':
                'Cloud SLAs define guaranteed uptime (e.g. 99.99% for AWS EC2) with service credits if the provider misses targets.',
          },
          {
            'question': 'What is a cloud deployment pipeline?',
            'answers': [
              'A physical cable connecting data centres',
              'An automated sequence taking code from commit to deployment — build, test, release',
              'A network routing path in a VPC',
              'A billing workflow',
            ],
            'correct': 1,
            'explanation':
                'Deployment pipeline: code → build → unit tests → staging → integration tests → production. Reduces human error and speeds delivery.',
          },
          {
            'question': 'What is infrastructure drift?',
            'answers': [
              'Gradual increase in cloud costs',
              'When live infrastructure diverges from its desired state due to manual changes outside the pipeline',
              'When cloud providers change API behaviour',
              'Latency increase in ageing infrastructure',
            ],
            'correct': 1,
            'explanation':
                'Infrastructure drift: someone manually modifies a resource in the console, bypassing IaC. Live state no longer matches the code state.',
          },
          {
            'question': 'What is a cloud marketplace?',
            'answers': [
              'A price comparison site for cloud providers',
              'A provider-operated store where third-party software is pre-packaged for one-click deployment',
              'An exchange for trading cloud capacity',
              'A directory of cloud certifications',
            ],
            'correct': 1,
            'explanation':
                'Cloud marketplaces (AWS Marketplace, Azure Marketplace) offer pre-configured third-party software deployable directly into your cloud account, often with integrated billing.',
          },
        ];

      case 'module-08':
        return [
          {
            'question':
                'Recommended starting AWS certification for cloud professionals?',
            'answers': [
              'AWS Solutions Architect Associate',
              'AWS Certified Cloud Practitioner',
              'AWS DevOps Engineer Professional',
              'AWS Security Specialty',
            ],
            'correct': 1,
            'explanation':
                'AWS Cloud Practitioner = foundational certification. No technical prerequisites, covers core concepts. Start here before Associate and Professional levels.',
          },
          {
            'question': 'What does "cloud-native" mean?',
            'answers': [
              'Any application hosted in the cloud',
              'Applications designed from scratch to leverage cloud services — microservices, containers, serverless, managed services',
              'Applications migrated to cloud without modification',
              'Applications built using provider-specific languages',
            ],
            'correct': 1,
            'explanation':
                'Cloud-native = designed for the cloud. Uses containers, microservices, serverless, and managed services to fully exploit cloud scalability and resilience.',
          },
          {
            'question':
                'A company finds owning servers costs £120k over 3 years; equivalent cloud costs £80k. What analysis?',
            'answers': [
              'Return on Investment (ROI)',
              'Total Cost of Ownership (TCO) analysis',
              'Break-even analysis',
              'Capital expenditure planning',
            ],
            'correct': 1,
            'explanation':
                'TCO compares ALL costs of on-premises vs cloud — including power, cooling, facilities, and staff. Often reveals cloud is more economical than direct hardware cost suggests.',
          },
          {
            'question':
                'Which entry-level cloud role focuses on building and maintaining the cloud environment?',
            'answers': [
              'Cloud Architect',
              'Cloud Engineer',
              'FinOps Analyst',
              'Cloud Sales Engineer',
            ],
            'correct': 1,
            'explanation':
                'Cloud Engineer implements and operates cloud infrastructure — provisioning, automation, monitoring, troubleshooting. Cloud Architects design; Engineers build and run.',
          },
          {
            'question': 'What is the AWS Well-Architected Framework used for?',
            'answers': [
              'Generating cost estimates',
              'Reviewing cloud workloads against best practices across six pillars to identify improvement areas',
              'Certifying cloud architects',
              'Comparing AWS to competitors',
            ],
            'correct': 1,
            'explanation':
                'Well-Architected Framework (6 pillars) provides a structured lens for reviewing workload design — identifying high-risk items and improvement priorities.',
          },
          {
            'question':
                'What is the difference between a Cloud Architect and Cloud Engineer?',
            'answers': [
              'Cloud Architects write more code',
              'Architects design systems and define architecture; Engineers implement and operate those designs',
              'Cloud Engineers have more responsibility',
              'Architects only work in consultancy',
            ],
            'correct': 1,
            'explanation':
                'Cloud Architect = HOW (topology, service selection, security design). Cloud Engineer = WHAT (provisioning, automation, monitoring, incident response).',
          },
          {
            'question':
                'Which cloud certification is vendor-neutral covering foundational concepts?',
            'answers': [
              'AWS Cloud Practitioner',
              'Azure Fundamentals AZ-900',
              'CompTIA Cloud+',
              'Google Associate Cloud Engineer',
            ],
            'correct': 2,
            'explanation':
                'CompTIA Cloud+ is vendor-neutral — covering cloud concepts applicable to all providers. AWS, Azure, and GCP certifications are vendor-specific.',
          },
          {
            'question': 'What is a cloud Centre of Excellence (CCoE)?',
            'answers': [
              'A cloud provider\'s premium support programme',
              'An internal team setting cloud strategy, governance standards, and best practices for the organisation',
              'A certification body for cloud professionals',
              'A government body overseeing cloud security',
            ],
            'correct': 1,
            'explanation':
                'CCoE = internal cross-functional team (engineering, security, finance, architecture) governing cloud adoption — setting guardrails, standards, and accelerating teams\' cloud capability.',
          },
          {
            'question':
                'What is the recommended first step before a cloud migration project?',
            'answers': [
              'Choose provider based on price alone',
              'Conduct discovery and assessment to understand the existing environment, dependencies, and migration priorities',
              'Migrate the largest workload first',
              'Hire a cloud team before any planning',
            ],
            'correct': 1,
            'explanation':
                'Discovery and assessment maps the portfolio, identifies dependencies, assesses readiness, and categorises workloads by migration strategy. Without this, migrations fail.',
          },
          {
            'question':
                'What does TCO analysis reveal that direct hardware cost comparisons miss?',
            'answers': [
              'Cloud performance metrics',
              'Hidden costs of on-premises: power, cooling, rack space, staffing, insurance, and hardware refresh cycles',
              'Cloud provider SLA terms',
              'Software licensing costs',
            ],
            'correct': 1,
            'explanation':
                'TCO includes ALL costs. Hidden on-premises costs often make cloud more economical than the hardware sticker price suggests.',
          },
        ];

      default:
        return [
          {
            'question': 'What is cloud computing?',
            'answers': [
              'Storing data on USB drives',
              'Delivering computing services over the internet on a pay-as-you-go basis',
              'Installing software locally',
              'Using only private servers',
            ],
            'correct': 1,
            'explanation':
                'Cloud computing delivers servers, storage, databases, and software over the internet. Pay only for what you use.',
          },
        ];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Binary Cloud Pro — 8 modules
  // ═══════════════════════════════════════════════════════════════════════════
  List<Map<String, dynamic>> _cloudProQuestions(String moduleId) {
    switch (moduleId) {
      case 'module-01':
        return [
          {
            'question':
                'How many pillars does the AWS Well-Architected Framework have?',
            'answers': ['Four', 'Five', 'Six', 'Seven'],
            'correct': 2,
            'explanation':
                'Six pillars: Operational Excellence, Security, Reliability, Performance Efficiency, Cost Optimisation, and Sustainability.',
          },
          {
            'question':
                'What is the key distinction between High Availability and Fault Tolerance?',
            'answers': [
              'They are identical',
              'HA allows brief interruption during failover; Fault Tolerance requires zero interruption even during failure',
              'Fault Tolerance is less expensive',
              'HA requires multiple regions',
            ],
            'correct': 1,
            'explanation':
                'HA = minimised downtime (short failover possible). FT = zero interruption — requires full redundancy at every layer. FT is significantly more expensive.',
          },
          {
            'question': 'What problem does loose coupling solve?',
            'answers': [
              'High cloud costs',
              'Cascade failures — where one component\'s failure brings down dependent components',
              'Network latency between services',
              'Difficulty encrypting data',
            ],
            'correct': 1,
            'explanation':
                'Loose coupling (queues, APIs, event buses) means components are not directly dependent. If Service A fails, Service B queues requests and retries — no cascade.',
          },
          {
            'question':
                'A Terraform file defines your entire cloud environment and is stored in Git. What principle?',
            'answers': [
              'Site Reliability Engineering',
              'Infrastructure as Code (IaC)',
              'GitOps',
              'Configuration Management',
            ],
            'correct': 1,
            'explanation':
                'IaC defines infrastructure in machine-readable config files, enabling version control, peer review, automated deployment, and exact reproducibility.',
          },
          {
            'question': 'What does RPO (Recovery Point Objective) define?',
            'answers': [
              'How quickly a system must be restored',
              'The maximum acceptable amount of data loss measured in time',
              'The redundancy level required',
              'The testing frequency for DR plans',
            ],
            'correct': 1,
            'explanation':
                'RPO = maximum acceptable data loss. RPO of 1 hour means no more than 1 hour of data can be lost. Lower RPO = more frequent backups = higher cost.',
          },
          {
            'question': 'What is the "design for failure" principle?',
            'answers': [
              'Intentionally introducing bugs to test monitoring',
              'Assuming components will fail and designing systems to automatically detect, isolate, and recover',
              'Planning for project failure during procurement',
              'Designing with the cheapest components',
            ],
            'correct': 1,
            'explanation':
                '"Design for failure" = assume every component will eventually fail and build automated recovery. Failure handled without human intervention.',
          },
          {
            'question': 'What is RTO (Recovery Time Objective)?',
            'answers': [
              'Maximum data loss acceptable',
              'Maximum time allowed to restore a system to operation after failure',
              'Replication topology for standby',
              'Test frequency for runbooks',
            ],
            'correct': 1,
            'explanation':
                'RTO = maximum acceptable downtime. RTO of 4 hours means system must be operational within 4 hours of failure. Lower RTO = more expensive DR architecture.',
          },
          {
            'question':
                'Which Well-Architected pillar focuses on eliminating waste and matching spend to business value?',
            'answers': [
              'Operational Excellence',
              'Reliability',
              'Performance Efficiency',
              'Cost Optimisation',
            ],
            'correct': 3,
            'explanation':
                'Cost Optimisation covers right-sizing, eliminating waste, selecting appropriate pricing models, and measuring business value per dollar spent.',
          },
          {
            'question': 'What does chaos engineering practice involve?',
            'answers': [
              'Deliberately deploying broken code',
              'Intentionally introducing failures to verify that systems self-heal as designed',
              'Running load tests during business hours',
              'Randomly changing IAM policies',
            ],
            'correct': 1,
            'explanation':
                'Chaos engineering (Netflix\'s Chaos Monkey) deliberately injects failures to validate resilience mechanisms work. Better to find gaps in testing than during a real outage.',
          },
          {
            'question':
                'What is the benefit of multi-region vs multi-AZ deployment?',
            'answers': [
              'Multi-region is always cheaper',
              'Multi-region provides resilience against an entire region becoming unavailable — broader than multi-AZ',
              'Multi-region improves database write performance',
              'They provide identical resilience',
            ],
            'correct': 1,
            'explanation':
                'Multi-AZ = protection against single data centre failure. Multi-region = protection against an entire geographic region failing — broader failure domain.',
          },
        ];

      case 'module-02':
        return [
          {
            'question':
                'Primary advantage of containers over virtual machines?',
            'answers': [
              'Containers have a full built-in OS',
              'Containers share the host OS kernel — lighter, start in seconds, use far less memory than VMs',
              'Containers provide stronger isolation',
              'Containers are better for stateful apps',
            ],
            'correct': 1,
            'explanation':
                'Containers share host kernel — no guest OS overhead. Container starts in milliseconds and uses MBs; VM starts in minutes and uses GBs.',
          },
          {
            'question': 'What does Kubernetes\' self-healing capability do?',
            'answers': [
              'Automatically patches operating systems',
              'Detects failed containers and automatically restarts or replaces them',
              'Migrates workloads between cloud providers',
              'Optimises container images for size',
            ],
            'correct': 1,
            'explanation':
                'Kubernetes monitors container health continuously. If a container crashes, K8s automatically restarts or reschedules it — no manual intervention.',
          },
          {
            'question': 'When is a Spot/Preemptible instance NOT appropriate?',
            'answers': [
              'For batch data processing jobs',
              'For ML model training with checkpointing',
              'For a production payment processing API requiring consistent availability',
              'For rendering video files overnight',
            ],
            'correct': 2,
            'explanation':
                'Spot instances can be reclaimed with 2 minutes notice. A payment API cannot tolerate sudden termination. Spot = interruptible, fault-tolerant workloads only.',
          },
          {
            'question': 'What is horizontal vs vertical scaling?',
            'answers': [
              'Vertical = add more instances; horizontal = upgrade existing',
              'Horizontal = add more instances (scale out); vertical = upgrade existing to larger sizes (scale up)',
              'They are the same concept',
              'Horizontal = storage; vertical = compute',
            ],
            'correct': 1,
            'explanation':
                'Horizontal (scale out) = add instances. Vertical (scale up) = make instance larger. Cloud-native architectures prefer horizontal — more resilient and automatable.',
          },
          {
            'question': 'What makes serverless architecture "scale to zero"?',
            'answers': [
              'Instances shut down by administrators overnight',
              'Serverless functions consume no compute (and incur no cost) when not being invoked',
              'Serverless auto-scales to zero errors',
              'Serverless requires zero configuration',
            ],
            'correct': 1,
            'explanation':
                '"Scale to zero" = no idle cost. Functions only consume resources during execution. Invoked 0 times = \$0 cost. Traditional servers cost money whether processing requests or idle.',
          },
          {
            'question': 'What is a service mesh?',
            'answers': [
              'A network diagram of cloud services',
              'Infrastructure layer handling service-to-service communication — providing mTLS, load balancing, retries, and observability transparently',
              'A type of container network interface',
              'An API gateway for external traffic',
            ],
            'correct': 1,
            'explanation':
                'Service mesh (Istio, Linkerd) manages microservice communication transparently — without application code changes. Adds mTLS, retries, circuit breaking, distributed tracing.',
          },
          {
            'question':
                'What is the difference between stateless and stateful applications?',
            'answers': [
              'Stateless are faster; stateful are more reliable',
              'Stateless hold no session data between requests; stateful maintain session state — stateless scale horizontally far more easily',
              'Stateful work better in containers',
              'Stateless require databases; stateful do not',
            ],
            'correct': 1,
            'explanation':
                'Stateless = any instance can serve any request. Stateful = requests depend on previous state. Stateless scales trivially; stateful requires sticky sessions or shared state.',
          },
          {
            'question': 'What does "container orchestration" solve?',
            'answers': [
              'Building efficient container images',
              'Automating deployment, scaling, networking, and lifecycle management of containers across a cluster',
              'Writing Dockerfiles efficiently',
              'Managing container security policies',
            ],
            'correct': 1,
            'explanation':
                'Orchestration (Kubernetes, ECS) manages containers at scale: scheduling, load balancing, auto-scaling, rolling updates, secret management, and self-healing.',
          },
          {
            'question': 'What is a Kubernetes Deployment?',
            'answers': [
              'A YAML file describing cloud infrastructure',
              'A K8s resource managing a set of identical pod replicas, handling rolling updates and rollbacks',
              'The process of pushing code to production',
              'A cloud billing statement',
            ],
            'correct': 1,
            'explanation':
                'K8s Deployment declares desired state (e.g. 5 replicas of nginx:1.25). K8s continuously reconciles actual state with desired — replacing failed pods, managing rolling updates.',
          },
          {
            'question': 'What is a container registry?',
            'answers': [
              'A government registry of container companies',
              'A storage service for container images that teams push to and pull from',
              'A Kubernetes configuration file',
              'A monitoring dashboard for containerised apps',
            ],
            'correct': 1,
            'explanation':
                'Container registry (AWS ECR, Docker Hub, GCR) stores versioned container images. CI/CD pipelines push images after build; orchestrators pull images when deploying.',
          },
        ];

      case 'module-03':
        return [
          {
            'question':
                'Best S3 storage class for compliance data retained 7 years but rarely accessed?',
            'answers': [
              'S3 Standard',
              'S3 Intelligent-Tiering',
              'S3 Glacier Deep Archive',
              'S3 One Zone-IA',
            ],
            'correct': 2,
            'explanation':
                'S3 Glacier Deep Archive = cheapest tier (\$0.00099/GB/month). Long-term archival with 12-hour retrieval. Perfect for compliance data rarely accessed.',
          },
          {
            'question': 'When should you choose DynamoDB over Amazon RDS?',
            'answers': [
              'For financial transactions requiring ACID compliance',
              'For complex SQL reporting with multi-table joins',
              'For single-digit millisecond reads at any scale with key-value or document access',
              'When you need strong relational data integrity',
            ],
            'correct': 2,
            'explanation':
                'DynamoDB excels at key-value and document access at massive scale with consistent low latency. RDS = complex relational queries, transactions, SQL required.',
          },
          {
            'question': 'What is the purpose of read replicas?',
            'answers': [
              'To provide a writable failover',
              'To offload read traffic from the primary — reducing load and improving read performance',
              'To synchronise data across regions automatically',
              'To replace full database backups',
            ],
            'correct': 1,
            'explanation':
                'Read replicas serve SELECT queries, reducing load on the primary which handles all writes. Critical for read-heavy applications.',
          },
          {
            'question': 'What is database sharding?',
            'answers': [
              'Breaking a database into read and write nodes',
              'Horizontally partitioning data across multiple database instances so each stores a subset',
              'Compressing database tables for storage efficiency',
              'Encrypting specific database columns',
            ],
            'correct': 1,
            'explanation':
                'Sharding distributes data across multiple instances (shards). Enables horizontal scaling for datasets that exceed single-instance capacity.',
          },
          {
            'question': 'Difference between a data lake and a data warehouse?',
            'answers': [
              'A data warehouse stores more data',
              'Data lake stores raw data in any format at low cost; warehouse stores structured, processed data optimised for analytics',
              'Data lakes are for real-time; warehouses for historical',
              'Same technology, different marketing names',
            ],
            'correct': 1,
            'explanation':
                'Data lake (S3, ADLS) = raw, any format, cheap, requires processing. Data warehouse (Redshift, BigQuery) = structured, optimised for SQL analytics, faster queries.',
          },
          {
            'question': 'What is an ETL pipeline?',
            'answers': [
              'An encrypted tunnel for data transfer',
              'Extract, Transform, Load — a process extracting data from sources, transforming it, and loading it into a target system',
              'A type of streaming data ingestion',
              'A database backup process',
            ],
            'correct': 1,
            'explanation':
                'ETL: Extract from source → Transform (clean, enrich, aggregate) → Load into warehouse. Standard pipeline for moving data to analytics stores.',
          },
          {
            'question': 'What is S3 Intelligent-Tiering?',
            'answers': [
              'A premium tier with guaranteed sub-1ms retrieval',
              'Automatically moves objects between access tiers based on usage patterns — reducing costs without performance impact or retrieval fees',
              'A dedicated high-performance tier',
              'A tier for ML training datasets',
            ],
            'correct': 1,
            'explanation':
                'Intelligent-Tiering monitors object access and moves between frequent, infrequent, and archive tiers automatically. No retrieval fee. Ideal for unknown or changing access patterns.',
          },
          {
            'question': 'What is RDS Multi-AZ?',
            'answers': [
              'Running the same query on multiple databases',
              'A synchronous standby replica in a different AZ — automatic failover with no data loss if primary fails',
              'Distributing read traffic across AZs',
              'Deploying the database in multiple regions',
            ],
            'correct': 1,
            'explanation':
                'RDS Multi-AZ = synchronous standby replica. If primary fails, AWS automatically promotes the standby — typically within 60-120 seconds. Zero data loss because replication is synchronous.',
          },
          {
            'question': 'Primary use case for Amazon ElastiCache?',
            'answers': [
              'Long-term archival of database backups',
              'An in-memory caching layer reducing database load and improving latency by serving hot data from memory',
              'A content delivery network for static assets',
              'A database migration tool',
            ],
            'correct': 1,
            'explanation':
                'ElastiCache (Redis or Memcached) caches hot data in memory — reducing repetitive database queries. Read latency drops from milliseconds to microseconds.',
          },
          {
            'question': 'What is Amazon Aurora?',
            'answers': [
              'A NoSQL database; RDS MySQL is relational',
              'MySQL/PostgreSQL-compatible with a distributed fault-tolerant storage layer — up to 5x throughput of standard MySQL at 1/10th commercial database cost',
              'Aurora runs in a single AZ; RDS MySQL runs multi-AZ',
              'Aurora is cheaper in all scenarios',
            ],
            'correct': 1,
            'explanation':
                'Aurora = MySQL/PostgreSQL-compatible with purpose-built distributed storage — 6-way replication across 3 AZs, automatic failover in under 30 seconds, significantly higher performance.',
          },
        ];

      case 'module-04':
        return [
          {
            'question': 'Core principle of Zero Trust security?',
            'answers': [
              'Trust all traffic inside the corporate network',
              'Never trust, always verify — every request must be authenticated regardless of network location',
              'Block all external traffic and allow only VPN',
              'Grant all users admin access and audit retrospectively',
            ],
            'correct': 1,
            'explanation':
                'Zero Trust eliminates the trusted internal network. Inside or outside — every request requires authentication, authorisation, and encryption. No implicit trust based on IP.',
          },
          {
            'question': 'What does a CSPM tool primarily do?',
            'answers': [
              'Manages VPN connections for remote workers',
              'Continuously monitors cloud environments for misconfigurations, policy violations, and compliance drift',
              'Encrypts all data in transit',
              'Manages cloud costs and billing anomalies',
            ],
            'correct': 1,
            'explanation':
                'CSPM scans cloud configurations continuously — finding public S3 buckets, overly permissive IAM roles, unencrypted storage, and compliance violations. Some auto-remediate.',
          },
          {
            'question':
                'Why must secrets never be hardcoded in application source code?',
            'answers': [
              'It makes code run slower',
              'Code is stored in Git repositories where secrets are exposed permanently in commit history — even after removal',
              'It violates cloud provider terms',
              'Hardcoded secrets cause compilation errors',
            ],
            'correct': 1,
            'explanation':
                'Git history is forever — a secret committed once is always visible in history. Tools like GitGuardian scan for leaked secrets in public and private repos.',
          },
          {
            'question': 'What is AWS Secrets Manager used for?',
            'answers': [
              'Encrypting S3 bucket contents',
              'Securely storing, accessing, and automatically rotating secrets without hardcoding them',
              'Managing IAM user passwords',
              'Auditing all API calls',
            ],
            'correct': 1,
            'explanation':
                'Secrets Manager stores credentials centrally, controls access via IAM, audits access, and can automatically rotate secrets — eliminating static long-lived credentials.',
          },
          {
            'question': 'What is a WAF used for?',
            'answers': [
              'Encrypting data between cloud regions',
              'Filtering malicious HTTP/HTTPS traffic — blocking SQLi, XSS, and other OWASP Top 10 attacks before they reach the application',
              'Managing VPC security groups',
              'Detecting insider threats',
            ],
            'correct': 1,
            'explanation':
                'WAF inspects HTTP requests at the application layer, matching against rule sets. Blocks common web attacks before they reach application servers.',
          },
          {
            'question': 'What does AWS CloudTrail do?',
            'answers': [
              'Monitors application performance metrics',
              'Records all API calls and management events for auditing, compliance, and security investigation',
              'Manages IAM users and roles',
              'Monitors VPC network traffic',
            ],
            'correct': 1,
            'explanation':
                'CloudTrail logs every AWS API call — who, when, from where, what changed. Essential for security investigations ("who deleted that S3 bucket?") and compliance.',
          },
          {
            'question':
                'Cloud pen testing specifically requires what that on-premises doesn\'t?',
            'answers': [
              'A larger testing team',
              'Compliance with the cloud provider\'s pen testing policy — which permits testing your own resources but prohibits testing shared infrastructure',
              'Written permission from all customers sharing hardware',
              'A cloud security certification for all testers',
            ],
            'correct': 1,
            'explanation':
                'AWS, Azure, GCP allow pen testing your own cloud resources but prohibit testing shared infrastructure (hypervisors, network hardware). Always review the provider\'s policy first.',
          },
          {
            'question': 'What is the principle behind IAM roles vs IAM users?',
            'answers': [
              'Roles are more powerful than users',
              'Roles provide temporary credentials assumed by services/instances — more secure than long-lived user access keys',
              'Users are for humans; roles are for Kubernetes only',
              'No security difference between the two',
            ],
            'correct': 1,
            'explanation':
                'IAM roles = temporary, automatically rotated credentials via STS. IAM user access keys = long-lived static credentials — significant security risk if leaked.',
          },
          {
            'question': 'What is AWS GuardDuty?',
            'answers': [
              'A firewall service for VPCs',
              'A threat detection service using ML to identify malicious activity and unauthorised behaviour in AWS accounts',
              'A vulnerability scanner for EC2 instances',
              'A DDoS protection service',
            ],
            'correct': 1,
            'explanation':
                'GuardDuty analyses CloudTrail, VPC Flow Logs, and DNS logs using ML to detect threats — cryptocurrency mining, compromised credentials, data exfiltration.',
          },
          {
            'question':
                'What is data sovereignty and why does it matter in cloud?',
            'answers': [
              'The encryption standard applied to data in transit',
              'The legal requirement that certain data must remain within specific national or regional borders',
              'The cloud provider\'s right to analyse customer data',
              'A data classification system',
            ],
            'correct': 1,
            'explanation':
                'Data sovereignty laws (GDPR Article 44, China\'s MLPS) restrict where data can be stored. Cloud architects must select compliant regions and configure data residency controls.',
          },
        ];

      case 'module-05':
        return [
          {
            'question': 'Difference between CI and CD?',
            'answers': [
              'They are the same process',
              'CI automatically builds and tests code on every commit; CD automatically deploys passing builds to staging or production',
              'CD handles integration testing; CI handles deployment',
              'CI is for frontend; CD is for backend',
            ],
            'correct': 1,
            'explanation':
                'CI: commit → build → automated tests. CD: passing build → automatic deployment. Continuous Delivery = staging automatic; Continuous Deployment = all the way to production.',
          },
          {
            'question':
                'Key advantage of blue/green deployment over rolling update?',
            'answers': [
              'Requires fewer servers',
              'Instant rollback — switch traffic back to the old environment (blue) immediately if new version (green) has issues',
              'Automatically tests the new version',
              'Costs less than other strategies',
            ],
            'correct': 1,
            'explanation':
                'Blue/green = instant, zero-downtime rollback by keeping the previous version live. Rolling updates require reversing the rollout — which takes time.',
          },
          {
            'question': 'What is a canary deployment?',
            'answers': [
              'A deployment only to test environments',
              'Gradually shifting a small percentage of traffic to the new version, monitoring metrics before rolling out to all users',
              'Deploying to a canary region first',
              'A midnight deployment to minimise user impact',
            ],
            'correct': 1,
            'explanation':
                'Canary releases progressively shift traffic (5% → 25% → 100%) while monitoring error rates and metrics. Issues affect only a small cohort before full rollout.',
          },
          {
            'question': 'What are the three pillars of observability?',
            'answers': [
              'CPU, Memory, Network',
              'Metrics, Logs, Traces',
              'Availability, Performance, Security',
              'Uptime, MTTR, Error Rate',
            ],
            'correct': 1,
            'explanation':
                'Metrics (numerical time-series), Logs (timestamped event records), Traces (distributed request journeys) together provide full observability.',
          },
          {
            'question': 'What is GitOps?',
            'answers': [
              'A Git branching strategy',
              'Using Git as the single source of truth for infrastructure and app config — all changes via PRs, automated agents reconcile actual state with desired',
              'A CI/CD tool built on GitHub',
              'A practice for writing better commit messages',
            ],
            'correct': 1,
            'explanation':
                'GitOps (ArgoCD, Flux) treats Git as authoritative. All changes through pull requests (audit trail). Operators continuously sync live environment to match Git.',
          },
          {
            'question': 'What is a feature flag?',
            'answers': [
              'A Git tag marking a release version',
              'A configuration mechanism enabling/disabling features at runtime without code deployment — enabling dark launches and A/B testing',
              'A CI/CD pipeline status indicator',
              'A monitoring alert for feature-specific errors',
            ],
            'correct': 1,
            'explanation':
                'Feature flags decouple deployment from release. Code ships to production disabled; flags enable it for specific users. Enables gradual rollouts, A/B tests, and instant rollback.',
          },
          {
            'question': 'What are DORA\'s four key metrics?',
            'answers': [
              'Cost, Quality, Speed, Security',
              'Deployment Frequency, Lead Time for Changes, MTTR, Change Failure Rate',
              'Sprint Velocity, Bug Rate, Uptime, Customer Satisfaction',
              'Lines of Code, Test Coverage, Deployment Size, Rollback Rate',
            ],
            'correct': 1,
            'explanation':
                'DORA\'s four metrics are the industry standard for measuring DevOps performance. Elite performers deploy multiple times per day with <1 hour MTTR.',
          },
          {
            'question': 'What is infrastructure drift?',
            'answers': [
              'Gradual increase in cloud costs',
              'When live infrastructure diverges from desired state (in IaC) due to manual changes or updates outside the pipeline',
              'When cloud providers change API behaviour',
              'Latency increase in ageing infrastructure',
            ],
            'correct': 1,
            'explanation':
                'Drift occurs when someone manually modifies a resource in the console, bypassing IaC. Live state no longer matches code state — breaking reproducibility.',
          },
          {
            'question': 'What is a circuit breaker pattern in microservices?',
            'answers': [
              'A network security control blocking malicious traffic',
              'A pattern detecting when a downstream service is failing and automatically stopping requests to it — preventing cascading failures',
              'A deployment pattern switching traffic between versions',
              'An auto-scaling trigger based on error rates',
            ],
            'correct': 1,
            'explanation':
                'Circuit breakers prevent cascading failures. When Service B fails, the circuit "opens" — Service A stops calling B and uses a fallback, periodically testing if B recovered.',
          },
          {
            'question':
                'What is the purpose of environment promotion in CI/CD?',
            'answers': [
              'Promoting team members when releases succeed',
              'Moving code through environments (dev → staging → production) with progressively more rigorous testing before customer exposure',
              'Marketing a new software release',
              'Distributing releases across cloud regions',
            ],
            'correct': 1,
            'explanation':
                'Environment promotion validates code at increasing fidelity. Dev = unit tests. Staging = integration tests + load tests. Production = real traffic.',
          },
        ];

      case 'module-06':
        return [
          {
            'question': 'What is right-sizing in cloud cost optimisation?',
            'answers': [
              'Purchasing largest instances for future growth',
              'Matching instance types to actual workload requirements — eliminating over-provisioned idle capacity',
              'Reserving capacity 3 years in advance',
              'Running workloads exclusively on spot instances',
            ],
            'correct': 1,
            'explanation':
                'Right-sizing analyses actual CPU, RAM, and network utilisation to select the optimal instance size. Over-provisioned instances are the most common source of cloud waste.',
          },
          {
            'question': 'What is FinOps?',
            'answers': [
              'Financial auditing of cloud provider contracts',
              'A practice bringing financial accountability to cloud spending — aligning engineering, finance, and business to make real-time spend decisions',
              'A cloud cost calculator tool',
              'A budgeting framework for IT departments',
            ],
            'correct': 1,
            'explanation':
                'FinOps is a culture and practice — not just a tool. Creates shared ownership of cloud costs across engineering, finance, and product teams.',
          },
          {
            'question':
                'When is a Reserved Instance more cost-effective than On-Demand?',
            'answers': [
              'For workloads running 2–3 hours per day',
              'For steady-state workloads running continuously 24/7 for 12+ months',
              'For batch jobs running weekly',
              'For dev environments shut down on weekends',
            ],
            'correct': 1,
            'explanation':
                'Reserved Instances offer 40–72% discount for 1–3 year commitments. They break even quickly for 24/7 workloads. Dev environments with downtime are better served by On-Demand.',
          },
          {
            'question': 'What is an AWS Savings Plan vs Reserved Instance?',
            'answers': [
              'Savings Plans are always cheaper',
              'Savings Plans commit to a spending level (/\$hour) with more flexibility on instance type/size/region vs Reserved Instances which lock to specific instance type',
              'Reserved Instances offer more flexibility',
              'They are identical products',
            ],
            'correct': 1,
            'explanation':
                'Savings Plans commit to dollar-per-hour spend threshold with similar discounts (up to 66%) but more flexibility. Compute Savings Plans work across EC2, Lambda, and Fargate.',
          },
          {
            'question':
                'Immediate highest-impact cost reduction action in most cloud accounts?',
            'answers': [
              'Switch all workloads to spot instances',
              'Identify and terminate idle resources — stopped VMs still charging for EBS, forgotten test environments, unused load balancers',
              'Migrate to a cheaper provider',
              'Renegotiate enterprise support contract',
            ],
            'correct': 1,
            'explanation':
                'Idle resources = pure waste. Stopped EC2 instances still charge for attached EBS. Unused load balancers, NAT Gateways, and Elastic IPs have hourly fees.',
          },
          {
            'question':
                'What is a resource tagging strategy and why is it important?',
            'answers': [
              'Labelling network traffic for routing',
              'Applying consistent metadata to resources enabling cost allocation by team/project, automated governance, and lifecycle management',
              'Security classification of cloud resources',
              'DNS naming conventions',
            ],
            'correct': 1,
            'explanation':
                'Tags enable cost reports by dimension, automated cost allocation (chargeback), lifecycle policies, and governance.',
          },
          {
            'question': 'What is cloud cost anomaly detection?',
            'answers': [
              'A tool that automatically rightsizes instances',
              'ML-powered monitoring detecting unexpected cost spikes and alerting before bills become catastrophic',
              'A tool estimating next month\'s costs',
              'An audit tool comparing costs across providers',
            ],
            'correct': 1,
            'explanation':
                'Cost anomaly detection uses ML to identify unusual spending patterns and notify teams immediately — preventing "bill shock" from mistakes or runaway processes.',
          },
          {
            'question': 'What is "showback" vs "chargeback" in FinOps?',
            'answers': [
              'Showback = showing costs to providers; Chargeback = charging back refunds',
              'Showback = reporting costs to teams for visibility without billing them; Chargeback = actually billing teams for their cloud consumption',
              'They are the same process',
              'Showback = engineering; chargeback = finance',
            ],
            'correct': 1,
            'explanation':
                'Showback raises cost awareness without financial consequences. Chargeback formally allocates cloud costs to departments, driving financial accountability.',
          },
          {
            'question':
                'Which FinOps maturity phase involves real-time cost decisions and unit economics?',
            'answers': ['Crawl', 'Walk', 'Run', 'Sprint'],
            'correct': 2,
            'explanation':
                'FinOps maturity: Crawl (basic visibility/tagging), Walk (optimisation processes, reserved coverage), Run (real-time decisions, unit economics, predictive modelling).',
          },
          {
            'question':
                'What NAT Gateway cost optimisation do many organisations miss?',
            'answers': [
              'Replacing NAT Gateways with VPN connections',
              'Using VPC endpoints (e.g. S3 Gateway endpoint) to route traffic to AWS services privately — avoiding NAT Gateway data processing fees',
              'Scheduling NAT Gateways to shut down on weekends',
              'Consolidating multiple NAT Gateways into one',
            ],
            'correct': 1,
            'explanation':
                'S3 and DynamoDB Gateway Endpoints route traffic directly without going through the NAT Gateway — free of charge. For heavy S3 traffic, this saves hundreds per month.',
          },
        ];

      case 'module-07':
        return [
          {
            'question': 'What does "Replatform" mean in the 6 Rs?',
            'answers': [
              'Moving to cloud with no changes',
              'Making modest optimisations to take advantage of cloud capabilities without changing core architecture (lift, tinker, and shift)',
              'Rebuilding as microservices',
              'Replacing with a SaaS product',
            ],
            'correct': 1,
            'explanation':
                'Replatform = lift, tinker, shift. Example: move self-managed MySQL to RDS (managed patching, backups) without changing application code.',
          },
          {
            'question': 'What is a cloud landing zone?',
            'answers': [
              'A physical location where cloud hardware lands',
              'A pre-configured, secure cloud environment establishing account structure, networking, logging, and governance before workloads are deployed',
              'The first cloud region an organisation uses',
              'A load testing environment',
            ],
            'correct': 1,
            'explanation':
                'Landing zone (AWS Control Tower, Azure Landing Zones) establishes the foundation: multi-account structure, centralised logging, security guardrails, identity, and networking.',
          },
          {
            'question': 'What is AWS DMS used for?',
            'answers': [
              'Backing up RDS databases to S3',
              'Migrating databases to AWS with continuous replication — enabling low-downtime cutover by syncing source and target before switching',
              'Converting between SQL and NoSQL schemas',
              'Managing database user access',
            ],
            'correct': 1,
            'explanation':
                'DMS replicates your database in near-real-time. Cutover window is minimal (minutes) because changes during migration are captured and applied.',
          },
          {
            'question': 'Main advantage of Refactor/Re-architect over Rehost?',
            'answers': [
              'Rehosting is always slower',
              'Refactoring delivers greater long-term value — scalability, resilience, and cost efficiency by redesigning the application for cloud-native',
              'Refactoring requires no downtime',
              'Rehosting is more expensive',
            ],
            'correct': 1,
            'explanation':
                'Rehost = fastest, lowest risk, minimal cloud benefit. Refactor = rebuilds cloud-native — highest effort but greatest long-term ROI.',
          },
          {
            'question': 'What is application discovery in cloud migration?',
            'answers': [
              'Finding new applications to build',
              'Cataloguing all on-premises applications, their dependencies, performance profiles, and business criticality to plan migration order and strategy',
              'Testing application performance in cloud before migration',
              'Identifying cloud-native alternatives',
            ],
            'correct': 1,
            'explanation':
                'Application discovery maps the portfolio — what exists, what depends on what, how much it consumes, who uses it. Without discovery, migrations fail due to unknown dependencies.',
          },
          {
            'question': 'What is the strangler fig pattern?',
            'answers': [
              'A method for terminating legacy applications abruptly',
              'Incrementally replacing a monolith by routing new functionality to new services until the monolith can be decommissioned',
              'A security pattern for restricting legacy system access',
              'A cost pattern for decommissioning old cloud resources',
            ],
            'correct': 1,
            'explanation':
                'Strangler fig migrates piece by piece — new functionality is cloud-native while the monolith handles remaining requests. Reduces risk of big-bang migrations.',
          },
          {
            'question': 'What does "Repurchase" mean in the 6 Rs?',
            'answers': [
              'Buying new on-premises servers instead of migrating',
              'Moving from a self-managed application to a SaaS equivalent — e.g. replacing self-hosted email to Microsoft 365',
              'Renegotiating the cloud provider agreement',
              'Purchasing Reserved Instances after initial On-Demand assessment',
            ],
            'correct': 1,
            'explanation':
                'Repurchase = drop and shop. Move from custom/self-managed to SaaS equivalent. Lose customisation; gain managed updates, support, and reduced operational overhead.',
          },
          {
            'question': 'What is wave planning in cloud migration?',
            'answers': [
              'Rolling back migrations that encounter problems',
              'Grouping applications into sequential migration batches based on complexity, dependencies, and business priority',
              'Migrating applications in real-time without downtime',
              'A networking strategy for hybrid connectivity',
            ],
            'correct': 1,
            'explanation':
                'Wave planning sequences migration work — Wave 1: simple/low-risk apps. Wave 2: medium complexity. Wave 3: critical systems. Dependencies dictate grouping.',
          },
          {
            'question': 'What does Anthos (Google Cloud) or Azure Arc solve?',
            'answers': [
              'Centralised billing across cloud accounts',
              'Managing applications consistently across on-premises, multi-cloud, and edge from a single control plane',
              'Migrating Google workloads to AWS',
              'Replacing Kubernetes with a simpler orchestrator',
            ],
            'correct': 1,
            'explanation':
                'Anthos and Azure Arc extend cloud management to any infrastructure — consistent security policies, governance, and Kubernetes-based deployment across clouds and on-premises.',
          },
          {
            'question': 'What is a Proof of Concept (PoC) in cloud migration?',
            'answers': [
              'A legal document proving infrastructure ownership',
              'A small-scale trial migration demonstrating feasibility, identifying risks, and building team capability before full commitment',
              'A cloud provider certification of readiness',
              'A financial model proving cloud ROI',
            ],
            'correct': 1,
            'explanation':
                'Migration PoC validates technical assumptions, identifies unknown risks, and builds team skills on a non-critical workload before full-scale migration.',
          },
        ];

      case 'module-08':
        return [
          {
            'question':
                'Recommended AWS certification path for cloud solutions architect?',
            'answers': [
              'Start with AWS DevOps Engineer, then SAP',
              'Cloud Practitioner → Solutions Architect Associate → Solutions Architect Professional',
              'Skip foundational certifications and take professional exam directly',
              'Developer → Security Specialty → SAP',
            ],
            'correct': 1,
            'explanation':
                'Standard path: Cloud Practitioner (foundational) → SAA-C03 (associate) → SAP-C02 (professional). Professional exam is extremely difficult without the Associate foundation.',
          },
          {
            'question': 'What do SLI, SLO, and SLA stand for?',
            'answers': [
              'They are three different names for the same metric',
              'SLI = the metric measured; SLO = the internal target; SLA = the customer contract. SLOs should be stricter than SLAs to maintain a buffer',
              'SLA is the most internal metric; SLI is customer-facing',
              'SLOs set by customers; SLIs set by engineers',
            ],
            'correct': 1,
            'explanation':
                'SLI (what we measure) → SLO (internal target, e.g. 99.95%) → SLA (customer promise, e.g. 99.9%). SLO > SLA creates a safety buffer before breaching customer commitments.',
          },
          {
            'question': 'What is TCO analysis in cloud decision-making?',
            'answers': [
              'A tool for tracking monthly cloud spending',
              'A comprehensive comparison of ALL costs (hardware, power, cooling, facilities, staff) of on-premises vs cloud',
              'A cloud provider pricing calculator',
              'A Return on Investment calculation',
            ],
            'correct': 1,
            'explanation':
                'TCO includes ALL costs — hardware, power, cooling, rack space, staffing, insurance, and refresh cycles. Hidden costs often make on-premises more expensive than it appears.',
          },
          {
            'question': 'What is a Cloud Centre of Excellence (CCoE)?',
            'answers': [
              'A premium cloud provider support tier',
              'An internal cross-functional team setting cloud strategy, governance, best practices, and accelerating cloud capability',
              'A cloud certification body',
              'A government body overseeing cloud security',
            ],
            'correct': 1,
            'explanation':
                'CCoE (cloud, security, finance, architecture) creates guardrails, templates, and training enabling teams to use cloud safely at speed.',
          },
          {
            'question':
                'What is an error budget in Site Reliability Engineering (SRE)?',
            'answers': [
              'Financial allowance for fixing production bugs',
              'The allowable downtime before SLO is breached — teams spend it on risky changes and must slow releases when exhausted',
              'A KPI measuring bugs per sprint',
              'The maximum number of incidents per month',
            ],
            'correct': 1,
            'explanation':
                'Error budget = 1 - SLO. If SLO = 99.9%, monthly error budget = 43.8 minutes. Risky deployments consume the budget. If exhausted, feature releases pause until reliability recovers.',
          },
          {
            'question': 'What is a post-incident review (PIR)?',
            'answers': [
              'A performance review after an employee incident',
              'A blameless retrospective analysis of an incident to understand root causes and implement systemic improvements',
              'A legal process following a data breach',
              'A customer communication after an outage',
            ],
            'correct': 1,
            'explanation':
                'Blameless post-mortems (Google SRE) focus on systemic causes — process gaps, missing monitoring, tooling failures. Goal is learning and prevention, not punishment.',
          },
          {
            'question': 'What is platform engineering?',
            'answers': [
              'Building physical infrastructure for cloud providers',
              'Building internal developer platforms — standardised, self-service tools enabling product teams to build, deploy, and operate services',
              'Engineering cloud pricing platforms',
              'A role focused exclusively on Kubernetes management',
            ],
            'correct': 1,
            'explanation':
                'Platform engineering builds "golden paths" — pre-approved, automated ways to deploy services, manage secrets, and observe systems. Enables developer self-service while maintaining governance.',
          },
          {
            'question':
                'What distinguishes a Senior Cloud Architect from a Cloud Engineer?',
            'answers': [
              'Senior Architects write more code',
              'Senior Architects own cross-domain design decisions spanning multiple teams and business requirements; Engineers implement specific components',
              'Cloud Engineers have more certifications',
              'Senior Architects only work on greenfield projects',
            ],
            'correct': 1,
            'explanation':
                'Senior architects make high-level design decisions with broad business impact. Engineers implement those designs and operate systems day-to-day.',
          },
          {
            'question':
                'What is the primary measure of cloud transformation success beyond cost savings?',
            'answers': [
              'Number of certifications earned',
              'Business outcomes — faster time to market, improved reliability, and the organisation\'s ability to experiment and innovate',
              'Number of cloud services adopted',
              'Percentage of workloads migrated',
            ],
            'correct': 1,
            'explanation':
                'Cloud transformation = business impact. Can the organisation ship faster? Are systems more reliable? Can teams experiment cheaply? These outcomes justify cloud investment.',
          },
          {
            'question': 'What is a well-architected review?',
            'answers': [
              'A code review process for cloud configuration files',
              'A structured assessment of a workload against the AWS Well-Architected Framework\'s six pillars, identifying risks and improvement priorities',
              'An annual cloud cost audit',
              'A cloud provider\'s pre-sales consultation',
            ],
            'correct': 1,
            'explanation':
                'Well-Architected Reviews identify high-risk items across six pillars and generate prioritised improvement plans. Can be conducted via AWS console or with AWS Solutions Architects.',
          },
        ];

      default:
        return [
          {
            'question': 'What is the Well-Architected Framework?',
            'answers': [
              'A cloud pricing guide',
              'Best practice guidance across six pillars for designing reliable, secure, cost-effective cloud workloads',
              'An AWS certification programme',
              'A hardware sizing specification',
            ],
            'correct': 1,
            'explanation':
                'The Well-Architected Framework provides best practices across six pillars to help architects build secure, high-performing, resilient, and efficient infrastructure.',
          },
        ];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Binary Cyber Pro — 8 modules
  // ═══════════════════════════════════════════════════════════════════════════
  List<Map<String, dynamic>> _cyberProQuestions(String moduleId) {
    switch (moduleId) {
      case 'module-04':
        return [
          {
            'question': 'What is the first phase of ethical hacking?',
            'answers': [
              'Scanning',
              'Gaining Access',
              'Reconnaissance',
              'Covering Tracks',
            ],
            'correct': 2,
            'explanation':
                'Reconnaissance is the first phase — gathering information about the target before any active testing begins. Can be passive (OSINT) or active (direct probing).',
          },
          {
            'question': 'In black box testing, what does the tester know?',
            'answers': [
              'Full source code and architecture',
              'Only partial information',
              'Nothing — they simulate an external attacker with no prior knowledge of the system',
              'Everything, including credentials',
            ],
            'correct': 2,
            'explanation':
                'Black box = external attacker simulation with no prior knowledge. White box = full knowledge. Grey box = partial knowledge.',
          },
          {
            'question': 'What is vertical privilege escalation?',
            'answers': [
              'Moving between users of the same privilege level',
              'Gaining higher-level permissions such as admin or root from a lower-privilege account',
              'Reducing a user\'s permissions',
              'Accessing a network from a remote location',
            ],
            'correct': 1,
            'explanation':
                'Vertical escalation = gaining higher-level access (user → root). Horizontal escalation = accessing another user\'s account at the same privilege level.',
          },
          {
            'question': 'What does a CVSS score represent?',
            'answers': [
              'The cost of fixing a vulnerability',
              'The number of systems affected',
              'The severity of a CVE vulnerability rated 0–10 (Critical = 9.0–10.0)',
              'The time it takes to patch a system',
            ],
            'correct': 2,
            'explanation':
                'CVSS (Common Vulnerability Scoring System) rates severity from 0 (none) to 10 (critical). Drives patch prioritisation and risk management decisions.',
          },
          {
            'question': 'What is OSINT?',
            'answers': [
              'Open-source security intelligence software',
              'Gathering publicly available information about a target from social media, DNS records, and job postings during reconnaissance',
              'A government intelligence sharing programme',
              'An open-source vulnerability database',
            ],
            'correct': 1,
            'explanation':
                'OSINT = passive reconnaissance using public sources. Invisible to the target. LinkedIn, DNS lookups, Google dorks, Shodan — all OSINT.',
          },
          {
            'question':
                'Difference between vulnerability assessment and penetration test?',
            'answers': [
              'They are the same process',
              'A vulnerability assessment identifies and reports weaknesses; a penetration test actively exploits them to demonstrate real-world impact',
              'Pen tests are automated; assessments are manual',
              'Assessments require authorisation; pen tests do not',
            ],
            'correct': 1,
            'explanation':
                'VA = find and report. Pen test = find AND exploit to demonstrate actual attacker impact. Both require written authorisation.',
          },
          {
            'question': 'What is lateral movement in a cyberattack?',
            'answers': [
              'An attacker moving between physical data centres',
              'After initial compromise, moving horizontally through the network to reach high-value targets',
              'Spreading malware via USB drives',
              'Rotating between multiple attack vectors',
            ],
            'correct': 1,
            'explanation':
                'Lateral movement: after compromising one workstation, the attacker moves to servers, Active Directory, and eventually high-value targets.',
          },
          {
            'question': 'What is a CVE?',
            'answers': [
              'A cloud vulnerability enumeration tool',
              'A publicly disclosed, standardised identifier for a specific security vulnerability in a product',
              'A certificate verifying ethical hacker credentials',
              'A compliance framework for vulnerability management',
            ],
            'correct': 1,
            'explanation':
                'CVE (e.g. CVE-2021-44228 = Log4Shell) = standardised vulnerability ID. Allows organisations, tools, and researchers to reference the same vulnerability unambiguously.',
          },
          {
            'question': 'What does port scanning discover?',
            'answers': [
              'Physical cables and connectors on servers',
              'Which network ports and services are open on a target — mapping its attack surface',
              'The server\'s operating system version',
              'The server\'s geographic location',
            ],
            'correct': 1,
            'explanation':
                'Port scanning (Nmap) identifies open ports, running services, and sometimes OS versions. Both attackers (reconnaissance) and defenders (attack surface management) use it.',
          },
          {
            'question':
                'What does "covering tracks" mean in the ethical hacking lifecycle?',
            'answers': [
              'Deleting the pen test report',
              'Simulating how an attacker would hide their presence — deleting logs, altering timestamps — to demonstrate how long a real breach could go undetected',
              'Closing vulnerabilities found during testing',
              'Notifying the client of findings',
            ],
            'correct': 1,
            'explanation':
                '"Covering tracks" simulates attacker persistence and evasion. Understanding how attackers hide helps defenders improve detection and log monitoring.',
          },
        ];

      case 'module-05':
        return [
          {
            'question': 'How does ransomware impact a victim?',
            'answers': [
              'It slows down the internet connection',
              'It encrypts files and demands payment for the decryption key — typically cryptocurrency',
              'It deletes the operating system completely',
              'It monitors keystrokes silently and sends data to the attacker',
            ],
            'correct': 1,
            'explanation':
                'Ransomware encrypts victim\'s files and demands a ransom for the decryption key. Modern ransomware also exfiltrates data to add leverage (double extortion).',
          },
          {
            'question':
                'Which malware type self-replicates across networks without human interaction?',
            'answers': [
              'Virus (requires host file)',
              'Trojan (disguised as legitimate software)',
              'Worm (self-propagating, no host needed)',
              'Spyware (monitors user activity)',
            ],
            'correct': 2,
            'explanation':
                'Worms spread automatically through network connections without needing a host file or human action. WannaCry used EternalBlue exploit to spread as a worm.',
          },
          {
            'question':
                'What makes a zero-day vulnerability especially dangerous?',
            'answers': [
              'It only affects older operating systems',
              'It is easy to detect with antivirus software',
              'It is unknown to the vendor and has no patch available — zero days to defend against it',
              'It requires physical access to exploit',
            ],
            'correct': 2,
            'explanation':
                'Zero-days are unknown to the vendor — no patch exists. Traditional signature-based defences cannot detect unknown exploits. Behaviour-based detection is the primary defence.',
          },
          {
            'question': 'What is spear phishing?',
            'answers': [
              'Phishing targeting multiple recipients simultaneously',
              'Highly targeted phishing using personalised information about a specific individual or organisation — much higher success rate than generic phishing',
              'Phishing occurring only via social media platforms',
              'Phishing exclusively using malware attachments',
            ],
            'correct': 1,
            'explanation':
                'Spear phishing uses victim-specific details (name, role, colleagues, recent events) to create convincing targeted messages. Often precedes advanced persistent threats.',
          },
          {
            'question': 'What is a botnet in a DDoS attack?',
            'answers': [
              'A single powerful attack server',
              'A network of infected machines (bots) controlled by an attacker — all flooding a target simultaneously to overwhelm it',
              'An encrypted communication channel for attackers',
              'A tool for exfiltrating stolen data',
            ],
            'correct': 1,
            'explanation':
                'A botnet = network of compromised devices. In DDoS, all bots flood the target simultaneously. Traffic appears legitimate because it comes from real (compromised) IPs worldwide.',
          },
          {
            'question': 'What is a rootkit?',
            'answers': [
              'A tool for managing server root accounts',
              'Malware that hides its presence by modifying OS components — very difficult to detect because it operates at kernel level',
              'A type of ransomware targeting Linux systems',
              'An exploit kit for web application vulnerabilities',
            ],
            'correct': 1,
            'explanation':
                'Rootkits modify the OS to conceal malware presence — hiding processes, files, and network connections from security tools. Kernel-mode rootkits are exceptionally difficult to remove.',
          },
          {
            'question':
                'What distinguishes an APT (Advanced Persistent Threat)?',
            'answers': [
              'APTs only target government organisations',
              'Long-term, stealthy campaigns by well-resourced attackers who establish persistent access and operate undetected for months or years',
              'APTs always use zero-day exploits exclusively',
              'APTs are fully automated with no human involvement',
            ],
            'correct': 1,
            'explanation':
                'APTs are sophisticated, targeted, and persistent — nation-states and organised crime spend months inside victim networks before detection. Prioritise stealth over speed.',
          },
          {
            'question': 'What is a supply chain attack?',
            'answers': [
              'An attack targeting logistics and delivery companies',
              'Compromising a trusted third-party software vendor to attack their customers through the trusted relationship',
              'An attack targeting cloud provider infrastructure directly',
              'A physical attack on hardware during shipping',
            ],
            'correct': 1,
            'explanation':
                'Supply chain attacks (SolarWinds) compromise trusted supplier\'s software update. When customers install the update, they install the malware — bypassing perimeter defences.',
          },
          {
            'question': 'What is a Trojan horse?',
            'answers': [
              'Malware that replicates across networks autonomously',
              'Malware disguised as legitimate software — users install it willingly, believing it benign',
              'An exploit targeting outdated operating systems',
              'A virus specifically targeting healthcare systems',
            ],
            'correct': 1,
            'explanation':
                'Trojans trick users into installing them by posing as legitimate apps (game cracks, free tools). Unlike worms, they do not self-replicate — they rely on user execution.',
          },
          {
            'question': 'What is a watering hole attack?',
            'answers': [
              'Flooding a system with water to destroy hardware',
              'Compromising a website frequently visited by the target audience — infecting visitors when they browse the legitimate site',
              'Intercepting communications at a network hub',
              'Targeting a specific employee through LinkedIn',
            ],
            'correct': 1,
            'explanation':
                'Watering hole attacks compromise legitimate websites frequented by the target group. Instead of sending phishing emails, the attacker waits for victims to come to them.',
          },
        ];

      case 'module-06':
        return [
          {
            'question': 'What does SQL Injection allow an attacker to do?',
            'answers': [
              'Intercept HTTPS traffic between client and server',
              'Manipulate database queries by injecting malicious SQL code through input fields',
              'Overload a server with excessive requests',
              'Steal browser cookies from a victim',
            ],
            'correct': 1,
            'explanation':
                'SQL Injection inserts malicious SQL into input fields. Can expose all database contents, modify data, or in some cases execute OS commands.',
          },
          {
            'question': 'How does stored XSS work?',
            'answers': [
              'The attacker intercepts the HTTP response',
              'Malicious script is injected and stored on the server — executing in every user\'s browser when they view the content',
              'The attacker sends a crafted URL to a specific user',
              'The attacker modifies victim\'s local browser settings',
            ],
            'correct': 1,
            'explanation':
                'Stored XSS persists on the server (e.g. in a comment field). Every user loading that content executes the attacker\'s script — can steal session cookies or perform actions as the victim.',
          },
          {
            'question': 'What does CSRF exploit?',
            'answers': [
              'Weak encryption algorithms in transit',
              'Unpatched server software vulnerabilities',
              'An authenticated user\'s active session to make unintended requests without their knowledge',
              'Insecure direct object references',
            ],
            'correct': 2,
            'explanation':
                'CSRF tricks a logged-in user\'s browser into sending requests using their existing authenticated session. The server cannot distinguish legitimate from forged requests.',
          },
          {
            'question': 'What is the OWASP Top 10?',
            'answers': [
              'A list of the 10 best security tools',
              'The 10 most common programming languages used in security',
              'A list of the 10 most critical web application security risks, updated regularly',
              'A ranking of cybersecurity certifications',
            ],
            'correct': 2,
            'explanation':
                'OWASP Top 10 is a standard awareness document for web application security. Current entries include Broken Access Control, Cryptographic Failures, and Injection.',
          },
          {
            'question': 'Why is input validation important?',
            'answers': [
              'It improves page load speed',
              'It prevents injection attacks by rejecting malformed or malicious data before it is processed',
              'It compresses data for storage efficiency',
              'It ensures users fill out all required form fields',
            ],
            'correct': 1,
            'explanation':
                'Input validation checks that user-supplied data is safe and expected before processing. The primary defence against injection, XSS, and path traversal attacks.',
          },
          {
            'question': 'What is SSRF (Server-Side Request Forgery)?',
            'answers': [
              'Forging server certificates to intercept HTTPS traffic',
              'Tricking the server into making requests to internal resources the attacker cannot directly access — critical in cloud environments',
              'Injecting scripts into server-rendered web pages',
              'Creating fake server logs to cover attack tracks',
            ],
            'correct': 1,
            'explanation':
                'SSRF tricks the server into making requests on the attacker\'s behalf — reaching internal APIs, cloud metadata services (AWS instance metadata at 169.254.169.254), or other internal systems.',
          },
          {
            'question':
                'What is an IDOR (Insecure Direct Object Reference) vulnerability?',
            'answers': [
              'A vulnerability in database ORM frameworks',
              'Using user-supplied input to access objects without authorisation checks — changing an ID allows access to other users\' data',
              'A type of SQL injection targeting stored procedures',
              'A vulnerability in API authentication tokens',
            ],
            'correct': 1,
            'explanation':
                'IDOR: changing /invoice/1234 to /invoice/1235 and seeing another user\'s invoice — no authorisation check. Top cause of data breaches, especially in APIs.',
          },
          {
            'question': 'What is a Content Security Policy (CSP)?',
            'answers': [
              'A cloud content delivery policy for cached resources',
              'An HTTP response header restricting which resources a browser can load — mitigating XSS by blocking unauthorised scripts',
              'A classification policy for sensitive documents',
              'A firewall rule set for web applications',
            ],
            'correct': 1,
            'explanation':
                'CSP headers tell browsers which sources are trusted. A strict CSP prevents XSS by blocking inline scripts and scripts from untrusted domains.',
          },
          {
            'question': 'What is a path traversal attack?',
            'answers': [
              'An attack that maps all API endpoint paths',
              'Manipulating file path references to access files outside the intended directory — e.g. ../../etc/passwd',
              'An attack routing traffic through multiple proxy servers',
              'An SEO attack targeting website navigation',
            ],
            'correct': 1,
            'explanation':
                'Path traversal uses ../ sequences to escape the application\'s intended directory and read arbitrary files. Server-side validation of file paths is the primary defence.',
          },
          {
            'question': 'Why is API security increasingly critical?',
            'answers': [
              'Securing the physical servers hosting APIs',
              'APIs directly expose business logic and data, often with weaker controls than web UIs — they are a primary and rapidly growing attack surface',
              'Encrypting API responses using SSL',
              'Limiting API usage to reduce cloud costs',
            ],
            'correct': 1,
            'explanation':
                'APIs bypass UI-level protections. OWASP API Security Top 10 lists broken authentication, BOLA (IDOR), and excessive data exposure as key API risks.',
          },
        ];

      case 'module-07':
        return [
          {
            'question':
                'What factors can be used in Multi-Factor Authentication?',
            'answers': [
              'Only passwords and PINs',
              'Something you know, something you have, something you are',
              'Username and email only',
              'Device name and IP address only',
            ],
            'correct': 1,
            'explanation':
                'MFA combines: knowledge (password/PIN), possession (phone/token/smart card), and inherence (biometric — fingerprint, face, iris).',
          },
          {
            'question': 'Difference between authentication and authorisation?',
            'answers': [
              'They are the same process',
              'Authorisation happens before authentication',
              'Authentication verifies identity ("who are you?"); authorisation determines permissions ("what can you do?")',
              'Authentication grants access; authorisation verifies identity',
            ],
            'correct': 2,
            'explanation':
                'Authentication = verify identity (login). Authorisation = determine permissions (what resources you can access). Authentication always comes first.',
          },
          {
            'question': 'Core principle of Zero Trust?',
            'answers': [
              'Trust all internal network traffic automatically',
              'Never trust, always verify — every request must be authenticated regardless of network location or origin',
              'Only use VPNs for remote access security',
              'Grant all employees admin access by default',
            ],
            'correct': 1,
            'explanation':
                'Zero Trust eliminates the concept of a trusted internal network. Every request — internal or external — requires continuous verification.',
          },
          {
            'question': 'What does OAuth 2.0 allow?',
            'answers': [
              'Store the user\'s password securely in the app',
              'Third-party apps to access user resources without the user sharing their password — via tokens',
              'Encrypt all network traffic between services',
              'Create a new account on behalf of the user',
            ],
            'correct': 1,
            'explanation':
                'OAuth 2.0 lets users grant apps limited access to their resources via access tokens, without sharing actual credentials.',
          },
          {
            'question': 'Most effective defence against credential stuffing?',
            'answers': [
              'Longer password requirements',
              'Frequent mandatory password resets',
              'Multi-factor authentication — stops attackers even when the correct password is used',
              'Network-level firewalls',
            ],
            'correct': 2,
            'explanation':
                'Credential stuffing uses leaked password lists. MFA defeats it even when the correct password is available — the attacker cannot provide the second factor.',
          },
          {
            'question': 'What is SAML used for?',
            'answers': [
              'Encrypting XML files in transit',
              'Federated identity — enabling SSO by allowing an identity provider to authenticate users and pass assertions to service providers',
              'Managing API tokens between microservices',
              'Generating TOTP codes for MFA',
            ],
            'correct': 1,
            'explanation':
                'SAML enables SSO in enterprise environments. IdP (Okta, Azure AD) authenticates the user and issues a SAML assertion. The service provider trusts the assertion without requiring its own password.',
          },
          {
            'question': 'What is role-based access control (RBAC)?',
            'answers': [
              'Controlling access based on physical location',
              'Assigning permissions to roles rather than individuals — users inherit permissions by being assigned to a role',
              'A type of biometric authentication',
              'Logging user activities for audit purposes',
            ],
            'correct': 1,
            'explanation':
                'RBAC = permissions tied to roles (e.g. "Developer", "Admin", "Read-Only"). Users are assigned roles. Changing a role instantly affects all users in that role.',
          },
          {
            'question': 'What is a privileged access workstation (PAW)?',
            'answers': [
              'Any laptop with administrator rights',
              'A dedicated, hardened device used exclusively for privileged tasks — isolated from internet browsing and email to protect high-privilege credentials',
              'A type of hardware security key',
              'A VM for testing security tools',
            ],
            'correct': 1,
            'explanation':
                'PAWs protect privileged credentials by ensuring admin tasks happen on isolated, hardened systems. If an admin\'s regular laptop is phished, privileged credentials remain safe.',
          },
          {
            'question': 'What is attribute-based access control (ABAC)?',
            'answers': [
              'Access based on physical attributes like biometrics',
              'A fine-grained access control model granting permissions based on attributes of the user, resource, and environment — more flexible than RBAC',
              'Access control limited to file attributes like read/write/execute',
              'Access control based on network attributes like IP address',
            ],
            'correct': 1,
            'explanation':
                'ABAC grants access based on attributes (user.department = Finance AND resource.classification = Confidential AND time = BusinessHours). More flexible than RBAC for complex scenarios.',
          },
          {
            'question':
                'What is the purpose of a hardware security key (FIDO2/WebAuthn)?',
            'answers': [
              'Storing encrypted files offline',
              'Providing phishing-resistant MFA — private key never leaves the device, making credential theft via phishing impossible',
              'Managing VPN connections securely',
              'Generating one-time passwords via SMS',
            ],
            'correct': 1,
            'explanation':
                'FIDO2/WebAuthn hardware keys (YubiKey) are phishing-resistant — the private key never leaves the device and is bound to the legitimate site domain. SMS OTP can be intercepted; hardware keys cannot.',
          },
        ];

      case 'module-08':
        return [
          {
            'question':
                'What is the correct order of NIST Incident Response phases?',
            'answers': [
              'Eradication → Containment → Identification → Recovery',
              'Preparation → Detection/Analysis → Containment → Eradication → Recovery → Post-Incident Activity',
              'Detection → Response → Closure → Review',
              'Triage → Patch → Monitor → Report',
            ],
            'correct': 1,
            'explanation':
                'NIST IR lifecycle: Preparation, Detection/Analysis, Containment, Eradication, Recovery, Post-Incident Activity (lessons learned). Preparation phase is ongoing — not just at the start.',
          },
          {
            'question': 'What does a Security Operations Center (SOC) do?',
            'answers': [
              'Develops new software products',
              'Manages employee HR records',
              'Continuously monitors, detects, and responds to security incidents 24/7 using SIEM and threat intelligence',
              'Handles physical building security only',
            ],
            'correct': 2,
            'explanation':
                'SOC = centralised team using SIEM, threat intelligence, and security tooling to defend the organisation continuously. Tiers: L1 (alert triage), L2 (investigation), L3 (threat hunting/IR).',
          },
          {
            'question':
                'Under GDPR, how quickly must a data breach be reported to regulators?',
            'answers': [
              '24 hours',
              '48 hours',
              '72 hours of becoming aware of the breach',
              '7 days',
            ],
            'correct': 2,
            'explanation':
                'GDPR Article 33 requires notifying the supervisory authority within 72 hours of becoming aware of a breach affecting personal data.',
          },
          {
            'question':
                'Why do forensic investigators clone a drive before analysing it?',
            'answers': [
              'To speed up the investigation',
              'To preserve the original evidence — working on the original could alter timestamps and metadata, destroying evidence admissibility in court',
              'To compress data for easier storage',
              'To remove malware from the original drive',
            ],
            'correct': 1,
            'explanation':
                'Forensic cloning (bit-for-bit copy) preserves evidence integrity. Working on the original could accidentally modify access timestamps or metadata — destroying legal admissibility.',
          },
          {
            'question': 'What is a SIEM primarily used for?',
            'answers': [
              'Encrypting database records at rest',
              'Scanning for software vulnerabilities in the environment',
              'Collecting and correlating logs from across the organisation to detect and alert on suspicious activity',
              'Managing user passwords and access credentials',
            ],
            'correct': 2,
            'explanation':
                'SIEM (Splunk, Microsoft Sentinel, IBM QRadar) aggregates logs from all sources, correlates events across systems, and surfaces potential incidents through rules and ML.',
          },
          {
            'question': 'What is threat hunting?',
            'answers': [
              'Automated detection of threats via SIEM alerts',
              'Proactively searching through networks and systems to detect threats that have evaded existing security controls',
              'Scanning for vulnerabilities using automated tools',
              'Responding to security incidents after they are detected',
            ],
            'correct': 1,
            'explanation':
                'Threat hunting is proactive — analysts hypothesis-driven search for hidden threats. Assumes the environment is already compromised and actively looks for evidence of attacker presence.',
          },
          {
            'question': 'What is chain of custody in digital forensics?',
            'answers': [
              'The hierarchy of the forensics team',
              'A documented, unbroken record of who handled evidence, when, and how — essential for court admissibility',
              'The timeline of an attack reconstructed from logs',
              'The sequence of commands run during an investigation',
            ],
            'correct': 1,
            'explanation':
                'Chain of custody documents every person who handled evidence and every action taken. Broken chain of custody can render evidence inadmissible in court.',
          },
          {
            'question': 'What is a tabletop exercise in incident response?',
            'answers': [
              'A hands-on simulation in a live environment',
              'A discussion-based exercise where teams walk through simulated incident scenarios to identify gaps in IR plans without live systems',
              'A penetration test of the IR team\'s tools',
              'A post-incident debrief after a real security event',
            ],
            'correct': 1,
            'explanation':
                'Tabletop exercises simulate incidents in discussion form — leadership and IR teams talk through response actions. Lower risk than live simulations; good for testing decision-making and communication.',
          },
          {
            'question': 'What does MITRE ATT&CK provide?',
            'answers': [
              'A compliance framework for security audits',
              'A knowledge base of adversary tactics, techniques, and procedures (TTPs) based on real-world attack observations',
              'A vulnerability scoring system replacing CVSS',
              'A certification programme for security analysts',
            ],
            'correct': 1,
            'explanation':
                'MITRE ATT&CK documents real adversary behaviour across the kill chain. Used for threat modelling, detection engineering, and mapping security controls to known attacker techniques.',
          },
          {
            'question': 'What is a cyber kill chain?',
            'answers': [
              'A physical security barrier around data centres',
              'A framework describing the stages of a cyberattack — Reconnaissance → Weaponisation → Delivery → Exploitation → Installation → C2 → Actions on Objectives',
              'A log correlation model for SIEM',
              'A software development security framework',
            ],
            'correct': 1,
            'explanation':
                'Lockheed Martin\'s Cyber Kill Chain describes attack stages. Defenders can interrupt the attack at any stage — disrupting delivery prevents exploitation even if the weapon exists.',
          },
        ];

      default:
        return [
          {
            'question': 'What does CIA stand for in cybersecurity?',
            'answers': [
              'Computing, Infrastructure, Availability',
              'Confidentiality, Integrity, Availability',
              'Cyber Intelligence Agency',
              'Controlled Information Access',
            ],
            'correct': 1,
            'explanation':
                'CIA Triad = Confidentiality, Integrity, Availability. The three foundational pillars of information security.',
          },
        ];
    }
  }

  List<Map<String, dynamic>> _networkProQuestions(String moduleId) {
    switch (moduleId) {
      case 'module-01':
        return [
          {
            'question':
                'A packet leaves a web server destined for a client. At which OSI layer does the source and destination MAC address get added, and what device reads only this layer to make forwarding decisions?',
            'answers': [
              'Layer 3 — routers read MAC addresses to forward packets',
              'Layer 2 — switches use MAC addresses to forward frames within a network segment',
              'Layer 4 — firewalls inspect MAC addresses for access control',
              'Layer 1 — hubs broadcast all frames and read MAC addresses',
            ],
            'correct': 1,
            'explanation':
                'Layer 2 (Data Link) adds source and destination MAC addresses to create a frame. Switches operate at Layer 2 — they learn MAC addresses on each port and forward frames only to the port where the destination MAC is located. Hubs operate at Layer 1 and have no awareness of addresses — they broadcast all signals to all ports.',
          },
          {
            'question':
                'A user can ping a server by IP address but cannot reach it by hostname. Which OSI layer and protocol is failing?',
            'answers': [
              'Layer 3 — IP routing is broken between the two hosts',
              'Layer 4 — TCP port 80 is being blocked by a firewall',
              'Layer 7 — DNS resolution is failing, preventing hostname-to-IP translation',
              'Layer 2 — ARP cannot resolve the server\'s MAC address',
            ],
            'correct': 2,
            'explanation':
                'Successful ping by IP confirms Layer 3 routing is working. The failure is at Layer 7 (Application) — specifically DNS. The client cannot resolve the hostname to an IP address. DNS operates at Layer 7 and uses UDP/TCP port 53. Check DNS server configuration and connectivity to the DNS resolver.',
          },
          {
            'question':
                'A network engineer captures packets and sees a TCP segment with SYN flag set, source port 54231, destination port 443. What is happening and at which layer does this occur?',
            'answers': [
              'Layer 2 — a switch is initiating a spanning tree election',
              'Layer 3 — a router is establishing a routing adjacency',
              'Layer 4 — a client is initiating the first step of a TCP three-way handshake to an HTTPS server',
              'Layer 7 — an HTTPS application is negotiating TLS parameters',
            ],
            'correct': 2,
            'explanation':
                'TCP operates at Layer 4 (Transport). The SYN flag initiates the three-way handshake (SYN → SYN-ACK → ACK). Source port 54231 is an ephemeral client port; destination port 443 is HTTPS. The client is establishing a reliable connection before any application data (TLS negotiation, HTTP) is exchanged.',
          },
          {
            'question':
                'Two hosts on different VLANs need to communicate. What device is required and at which OSI layer does it operate?',
            'answers': [
              'A hub at Layer 1 — broadcasts the traffic to both VLANs',
              'A switch at Layer 2 — can forward traffic between VLANs using MAC addresses',
              'A router or Layer 3 switch at Layer 3 — inter-VLAN routing requires IP forwarding between subnets',
              'A firewall at Layer 7 — application inspection is required for cross-VLAN traffic',
            ],
            'correct': 2,
            'explanation':
                'VLANs are separate Layer 2 broadcast domains. Communication between them requires a Layer 3 device (router or Layer 3 switch) to route packets between the different subnets. A Layer 2 switch cannot forward traffic between VLANs without configured SVIs (Switched Virtual Interfaces) and routing enabled.',
          },
          {
            'question':
                'An application developer asks why their UDP-based video stream occasionally drops frames but a TCP-based file transfer never loses data. What is the correct explanation?',
            'answers': [
              'UDP uses a faster network path than TCP, causing congestion and drops',
              'TCP retransmits lost segments and uses flow control — UDP has no error recovery, sequencing, or retransmission, making it faster but unreliable for delivery',
              'UDP packets are smaller and more likely to be fragmented by routers',
              'TCP uses encryption that UDP does not, adding overhead that prevents drops',
            ],
            'correct': 1,
            'explanation':
                'TCP (Layer 4) provides reliable, ordered, error-checked delivery via sequence numbers, acknowledgements, and retransmission. UDP provides no guarantee of delivery, order, or error recovery — dropped packets are simply lost. For video streaming, a dropped frame is preferable to the delay caused by retransmission. For file transfers, every byte must arrive intact, so TCP is required.',
          },
          {
            'question':
                'A technician needs to identify which OSI layer a problem exists at. The user cannot send emails but can browse websites. ICMP pings to the mail server succeed. What is the most likely layer of failure?',
            'answers': [
              'Layer 1 — physical cable is partially damaged',
              'Layer 3 — routing to the mail server is broken',
              'Layer 4 or 7 — TCP port 25/587 (SMTP) may be blocked, or the mail application/DNS MX record is misconfigured',
              'Layer 2 — the mail server\'s MAC address is not in the ARP table',
            ],
            'correct': 2,
            'explanation':
                'ICMP ping success confirms Layers 1-3 are working. The failure is above Layer 3. SMTP uses TCP port 25 (server-to-server) or 587 (client submission) — a firewall may be blocking these specific ports while allowing HTTP/HTTPS. The mail application configuration or DNS MX record could also be the issue at Layer 7.',
          },
          {
            'question':
                'In the TCP/IP model, which layer combines the functions of the OSI Session, Presentation, and Application layers?',
            'answers': [
              'Internet layer',
              'Transport layer',
              'Application layer',
              'Network Access layer',
            ],
            'correct': 2,
            'explanation':
                'The TCP/IP model has 4 layers: Network Access (OSI Layers 1-2), Internet (OSI Layer 3), Transport (OSI Layer 4), and Application (OSI Layers 5-7). The Application layer in TCP/IP encompasses OSI\'s Session (5), Presentation (6), and Application (7) layers. Protocols like HTTP, FTP, DNS, and SMTP all operate at this combined layer.',
          },
          {
            'question':
                'A packet needs to travel from 192.168.1.10 to 10.0.0.50 across three routers. What changes and what stays the same at each router hop?',
            'answers': [
              'The source and destination IP addresses change at each hop; MAC addresses stay the same',
              'The source and destination MAC addresses are rewritten at each hop; the source and destination IP addresses remain unchanged end-to-end',
              'Both IP addresses and MAC addresses change at every router',
              'Nothing changes — routers forward packets without modifying any headers',
            ],
            'correct': 1,
            'explanation':
                'IP addresses (Layer 3) identify the ultimate source and destination — they remain unchanged across the entire path. MAC addresses (Layer 2) are local to each network segment. At each router, the frame is stripped, the IP packet is re-encapsulated in a new frame with the router\'s MAC as source and the next-hop device\'s MAC as destination.',
          },
          {
            'question':
                'Which protocol operates at Layer 2 and is responsible for mapping a known IP address to an unknown MAC address on the local network segment?',
            'answers': [
              'DNS — resolves hostnames to IP addresses',
              'DHCP — assigns IP addresses to hosts automatically',
              'ARP (Address Resolution Protocol) — broadcasts a request for the MAC address of a given IP on the local segment',
              'ICMP — used for network diagnostics and error reporting',
            ],
            'correct': 2,
            'explanation':
                'ARP operates at the Layer 2/3 boundary. When a host needs to send to an IP on the same subnet, it broadcasts an ARP request. The owner of that IP replies with its MAC address. The requesting host caches this in its ARP table. Without ARP, Layer 3 packets cannot be encapsulated into Layer 2 frames for local delivery.',
          },
          {
            'question':
                'An engineer troubleshooting a connectivity issue works from the bottom of the OSI model upward. They confirm the cable is connected (Layer 1), the switch port is up (Layer 2), and the IP address is correctly configured (Layer 3). The problem persists. What should they check next?',
            'answers': [
              'Replace the network cable — physical issues can be intermittent',
              'Layer 4 — check if the specific TCP/UDP port the application uses is being blocked by a firewall or not listening on the server',
              'Layer 1 again — duplex mismatch causes intermittent issues that appear resolved',
              'Layer 2 again — VLAN membership may be incorrect on the switch port',
            ],
            'correct': 1,
            'explanation':
                'The bottom-up troubleshooting approach confirms each layer before moving up. Layers 1-3 are confirmed working. Layer 4 is next: is the server listening on the required port? Is a firewall blocking that port? Use netstat or ss on the server to check listening ports, and test with telnet or nc to the specific port to verify reachability.',
          },
        ];

      case 'module-02':
        return [
          {
            'question':
                'A network engineer needs to subnet 192.168.10.0/24 to support 6 departments, each needing up to 30 hosts. Which subnet mask creates exactly enough subnets with sufficient host capacity?',
            'answers': [
              '/25 — provides 2 subnets of 126 hosts each',
              '/27 — provides 8 subnets of 30 hosts each (30 usable: 32 minus network and broadcast)',
              '/28 — provides 16 subnets of 14 hosts each — insufficient for 30 hosts',
              '/26 — provides 4 subnets of 62 hosts each — not enough subnets',
            ],
            'correct': 1,
            'explanation':
                '/27 borrows 3 bits from the host portion: 2³=8 subnets. Each subnet has 5 host bits: 2⁵-2=30 usable hosts. This exactly meets the requirement — 6 departments each needing up to 30 hosts. /28 gives only 14 usable hosts (insufficient). /26 gives only 4 subnets (not enough departments).',
          },
          {
            'question':
                'A host has IP address 172.16.45.200/20. What is the network address, broadcast address, and valid host range for this subnet?',
            'answers': [
              'Network: 172.16.45.0, Broadcast: 172.16.45.255, Hosts: 172.16.45.1–172.16.45.254',
              'Network: 172.16.32.0, Broadcast: 172.16.47.255, Hosts: 172.16.32.1–172.16.47.254',
              'Network: 172.16.40.0, Broadcast: 172.16.47.255, Hosts: 172.16.40.1–172.16.47.254',
              'Network: 172.16.0.0, Broadcast: 172.16.255.255, Hosts: 172.16.0.1–172.16.255.254',
            ],
            'correct': 1,
            'explanation':
                '/20 means 20 network bits, 12 host bits. The subnet mask is 255.255.240.0. In the third octet: 240 in binary is 11110000. 45 AND 240 = 32 (network). Network: 172.16.32.0, Broadcast: 172.16.47.255, Usable hosts: 172.16.32.1 to 172.16.47.254 (4094 hosts).',
          },
          {
            'question':
                'A company has 5 point-to-point WAN links between routers. They want to waste as few IP addresses as possible. Which subnet mask should they use for each link?',
            'answers': [
              '/24 — standard subnet size for simplicity',
              '/30 — provides exactly 2 usable host addresses per link (4 addresses: network, 2 hosts, broadcast)',
              '/29 — provides 6 usable host addresses, enough for future expansion',
              '/31 — not valid, no usable host addresses',
            ],
            'correct': 1,
            'explanation':
                '/30 provides 4 addresses: 1 network, 2 usable hosts (one per router end), 1 broadcast. This is the industry standard for point-to-point links.',
          },
          {
            'question':
                'Which of the following IP addresses is NOT a valid host address in the 10.10.10.128/26 subnet?',
            'answers': [
              '10.10.10.129',
              '10.10.10.150',
              '10.10.10.190',
              '10.10.10.191',
            ],
            'correct': 3,
            'explanation':
                '/26 in the last octet: mask is 192. 128 network address. 128+64-1=191 is the broadcast address. Valid hosts: 10.10.10.129 to 10.10.10.190. 10.10.10.191 is the broadcast address — not assignable to a host.',
          },
          {
            'question':
                'A network admin receives a complaint that two hosts — 192.168.1.65/26 and 192.168.1.130/26 — cannot communicate without a router even though they are on the same physical switch. Why?',
            'answers': [
              'The switch is misconfigured and needs a static route',
              'They are in different /26 subnets: .65 is in 192.168.1.64/26 (.64-.127) and .130 is in 192.168.1.128/26 (.128-.191) — a router is required to forward between subnets',
              'Both hosts have the same subnet mask so they should communicate directly',
              '192.168.1.130 is a broadcast address and cannot be assigned to a host',
            ],
            'correct': 1,
            'explanation':
                '/26 creates four subnets: .0-.63, .64-.127, .128-.191, .192-.255. Host .65 is in the .64/26 subnet; host .130 is in the .128/26 subnet. Even on the same switch, hosts in different subnets must communicate via a router.',
          },
          {
            'question':
                'What type of IPv6 address begins with FE80::/10 and what is its purpose?',
            'answers': [
              'Global unicast — routable on the public internet',
              'Multicast — sends to all IPv6 devices on the local segment',
              'Link-local — automatically configured on every IPv6 interface, used for communication on the local link only, never routed beyond the local segment',
              'Anycast — routes to the nearest node in a group of servers with the same address',
            ],
            'correct': 2,
            'explanation':
                'FE80::/10 addresses are link-local — automatically generated from the MAC address (EUI-64) or randomly. They are mandatory on every IPv6 interface and used for neighbour discovery, router discovery, and DHCPv6. They are never forwarded by routers.',
          },
          {
            'question':
                'A host sends a packet to 255.255.255.255. What type of transmission is this and what is its scope?',
            'answers': [
              'Multicast — delivered to a group of subscribed hosts across multiple subnets',
              'Unicast — delivered to a single specific host',
              'Limited broadcast — delivered to all hosts on the local subnet only, routers do not forward it',
              'Directed broadcast — delivered to all hosts in a specific remote subnet',
            ],
            'correct': 2,
            'explanation':
                '255.255.255.255 is the limited broadcast address. It is delivered to all hosts on the local network segment. Routers do not forward limited broadcasts. DHCP Discover uses this address because the client does not yet know its subnet.',
          },
          {
            'question':
                'An organisation needs 500 IP addresses for a new office. They are assigned 203.0.113.0/23 from their ISP. How many usable host addresses does this provide?',
            'answers': [
              '254 usable hosts',
              '510 usable hosts (2⁹ - 2 = 510)',
              '512 usable hosts',
              '1022 usable hosts',
            ],
            'correct': 1,
            'explanation':
                '/23 has 9 host bits (32-23=9). Total addresses: 2⁹=512. Subtract network and broadcast: 512-2=510 usable hosts. This covers 203.0.113.1 to 203.0.114.254.',
          },
          {
            'question':
                'What is VLSM (Variable Length Subnet Masking) and why is it used instead of fixed-length subnetting?',
            'answers': [
              'VLSM uses the same subnet mask for all subnets — it simplifies routing table management',
              'VLSM allows different subnet masks within the same address space — a /30 for WAN links and /24 for large LANs from the same block, minimising IP address waste',
              'VLSM automatically assigns IP addresses to hosts using DHCP',
              'VLSM is only used with IPv6 — IPv4 always uses fixed-length subnetting',
            ],
            'correct': 1,
            'explanation':
                'VLSM allows subnets of different sizes within the same address space. A WAN link needs only 2 hosts (/30), a small office needs 10 hosts (/28), a large LAN needs 200 hosts (/24). VLSM requires a classless routing protocol (OSPF, EIGRP, BGP).',
          },
          {
            'question':
                'A router has the following routes: 10.0.0.0/8, 10.1.0.0/16, and 10.1.1.0/24. A packet arrives destined for 10.1.1.50. Which route does the router use?',
            'answers': [
              '10.0.0.0/8 — it is the largest supernet covering this address',
              '10.1.0.0/16 — it is the most specific match covering the /24',
              '10.1.1.0/24 — longest prefix match selects the most specific route',
              'All three routes — the router load-balances across all matching routes',
            ],
            'correct': 2,
            'explanation':
                'Routers use longest prefix match — the most specific (longest) matching route wins. 10.1.1.50 matches all three routes, but /24 is the most specific. More specific routes always win over less specific ones.',
          },
        ];

      case 'module-03':
        return [
          {
            'question':
                'A switch receives a frame with a destination MAC address that is not in its MAC address table. What does the switch do?',
            'answers': [
              'Drops the frame — unknown destinations are discarded for security',
              'Sends the frame back to the source requesting the destination MAC',
              'Floods the frame out all ports except the port it was received on (unknown unicast flooding)',
              'Forwards the frame to the default gateway for routing',
            ],
            'correct': 2,
            'explanation':
                'When a switch encounters an unknown unicast destination, it floods the frame out all ports except the ingress port. The intended recipient receives the frame and responds — the switch learns the destination MAC from that reply and adds it to the MAC table.',
          },
          {
            'question':
                'Two switches are connected with a single uplink. VLANs 10, 20, and 30 need to pass between them. The engineer configures the link as a trunk. What protocol negotiates trunking on Cisco switches and what does it do?',
            'answers': [
              'STP — prevents loops and negotiates which VLANs are active',
              'DTP (Dynamic Trunking Protocol) — negotiates whether the link becomes a trunk and which encapsulation (802.1Q) to use',
              'VTP (VLAN Trunking Protocol) — synchronises VLAN databases between switches',
              'LACP — bundles multiple links and negotiates VLAN tagging',
            ],
            'correct': 1,
            'explanation':
                'DTP (Dynamic Trunking Protocol) is Cisco-proprietary and automatically negotiates trunk links between switches. It determines whether a port becomes a trunk and negotiates 802.1Q encapsulation. Best practice is to disable DTP on production ports and manually configure trunks.',
          },
          {
            'question':
                'A network engineer notices that traffic between VLAN 10 and VLAN 20 is unexpectedly reaching hosts in both VLANs without passing through a router. Investigation reveals the attack originated from a host in VLAN 10. What attack occurred?',
            'answers': [
              'MAC spoofing — the attacker changed their MAC to match a VLAN 20 host',
              'ARP poisoning — the attacker redirected VLAN 20 traffic through their host',
              'VLAN hopping via double tagging — the attacker sent frames with two 802.1Q tags; the first switch stripped the outer tag matching the native VLAN, and the second switch forwarded based on the inner tag',
              'STP manipulation — the attacker became the root bridge and captured inter-VLAN traffic',
            ],
            'correct': 2,
            'explanation':
                'Double-tagging VLAN hopping: the attacker sends a frame with two 802.1Q tags — the outer tag matches the native VLAN. The first switch strips the outer tag and the second switch forwards to the target VLAN. Mitigation: change the native VLAN to an unused VLAN ID.',
          },
          {
            'question':
                'Spanning Tree Protocol elects a root bridge. Which switch becomes the root bridge and why?',
            'answers': [
              'The switch with the highest MAC address — it has priority in the election',
              'The switch with the most ports — it can connect the most segments',
              'The switch with the lowest Bridge ID (combination of priority value and MAC address) — lowest priority wins, with MAC address as tiebreaker',
              'The switch configured first — it claims root status before others boot',
            ],
            'correct': 2,
            'explanation':
                'STP elects the root bridge based on Bridge ID = Priority (default 32768) + VLAN ID + MAC address. The switch with the lowest Bridge ID wins. Network engineers set the priority manually to ensure the most capable switch is root.',
          },
          {
            'question':
                'An access port on a switch is assigned to VLAN 30. The connected host has no VLAN awareness. How does the host communicate on VLAN 30?',
            'answers': [
              'The host must be configured with 802.1Q tagging to join VLAN 30',
              'The switch tags all frames entering the access port with VLAN 30 — the host sends and receives untagged frames and is unaware of VLAN membership',
              'The host must use a VLAN-aware network adapter to communicate on VLAN 30',
              'The host communicates on the native VLAN by default — VLAN 30 requires explicit configuration on the host',
            ],
            'correct': 1,
            'explanation':
                'Access ports handle VLAN tagging transparently. The host sends and receives normal untagged Ethernet frames. The switch adds the VLAN 30 tag to all ingress frames and strips it from all egress frames. The host has no knowledge of VLANs.',
          },
          {
            'question':
                'A network has three switches in a triangle topology (A-B, B-C, A-C links). STP blocks the A-C link. Link A-B fails. How does STP respond?',
            'answers': [
              'The network is partitioned — hosts on switch C cannot reach switch A until A-B is repaired',
              'STP immediately unblocks A-C — the previously blocked port transitions through Listening and Learning states before reaching Forwarding, taking ~30-50 seconds with classic STP',
              'STP unblocks A-C instantly — all blocked ports transition to forwarding within 1 second',
              'Switch C sends a topology change notification and the network administrator must manually unblock A-C',
            ],
            'correct': 1,
            'explanation':
                'When STP detects a topology change, blocked ports transition to Forwarding to restore connectivity. Classic STP takes 30-50 seconds. RSTP (802.1w) converges in 1-2 seconds. Always deploy RSTP in modern networks.',
          },
          {
            'question':
                'An engineer configures PortFast on a switch port connected to a PC. What does PortFast do and what risk does it introduce if misconfigured?',
            'answers': [
              'PortFast increases port speed to maximum — risk is duplex mismatch with slower devices',
              'PortFast skips the STP Listening and Learning states, immediately placing the port in Forwarding — risk is if connected to a switch, a loop forms instantly before STP can block the port',
              'PortFast enables BPDU filtering permanently — risk is that STP cannot detect topology changes',
              'PortFast disables STP entirely on the port — risk is broadcast storms on the segment',
            ],
            'correct': 1,
            'explanation':
                'PortFast bypasses the 30-second STP delay for ports connected to end devices. Risk: if a switch is connected to a PortFast port, a loop can form before STP blocks it. Always pair PortFast with BPDU Guard.',
          },
          {
            'question':
                'An organisation wants to allow only a single authorised MAC address per switch port and automatically disable the port if an unauthorised device connects. Which feature accomplishes this?',
            'answers': [
              '802.1X port authentication — requires RADIUS authentication before port access',
              'Dynamic ARP Inspection — validates ARP packets against the DHCP snooping table',
              'Port Security with violation mode shutdown — limits MACs per port and errdisables the port if violated',
              'DHCP snooping — blocks DHCP responses from unauthorised servers',
            ],
            'correct': 2,
            'explanation':
                'Port Security allows you to specify a maximum number of MAC addresses per port and define the violation action. Violation mode shutdown immediately shuts down the port if an unauthorised MAC is detected.',
          },
          {
            'question':
                'What is the purpose of the native VLAN on an 802.1Q trunk link?',
            'answers': [
              'The native VLAN carries management traffic and cannot be changed',
              'The native VLAN is used for inter-VLAN routing between trunk-connected switches',
              'Frames on the native VLAN are sent untagged across the trunk — both ends must agree on the native VLAN or frames will be misassigned to the wrong VLAN',
              'The native VLAN is the default VLAN for all access ports on the switch',
            ],
            'correct': 2,
            'explanation':
                'The native VLAN on a trunk carries untagged frames. By default this is VLAN 1. Mismatched native VLANs cause a security issue. Best practice: change the native VLAN to an unused VLAN and tag all user VLANs explicitly.',
          },
          {
            'question':
                'A network engineer must connect 48 access ports to a core switch that only has 4 uplinks available. The engineer adds a second uplink to the core switch, but STP blocks it. What technology allows both uplinks to be active simultaneously?',
            'answers': [
              'RSTP — enables faster failover but still blocks one link',
              'EtherChannel (LACP/PAgP) — bundles multiple physical links into a single logical link, providing both redundancy and increased bandwidth',
              'VTP — synchronises VLANs across the additional uplink',
              'BPDU Guard — disables STP blocking on the second uplink',
            ],
            'correct': 1,
            'explanation':
                'EtherChannel (IEEE 802.3ad LACP or Cisco PAgP) bundles multiple physical links into one logical interface. STP sees it as a single link (no blocking). Traffic is load-balanced across all member links.',
          },
        ];

      case 'module-04':
        return [
          {
            'question':
                'A router has OSPF and a static route to the same destination. The static route has AD 1, OSPF has AD 110. Which route is installed in the routing table and why?',
            'answers': [
              'OSPF — dynamic routing protocols are always preferred over static routes',
              'Static route — lower Administrative Distance (1) means it is more trusted than OSPF (110)',
              'Both — the router load-balances between them',
              'Neither — conflicting routes cause the router to drop traffic to that destination',
            ],
            'correct': 1,
            'explanation':
                'Administrative Distance (AD) is the measure of route source trustworthiness. Lower AD = more preferred. Static routes have AD 1. OSPF has AD 110. Common ADs: Connected=0, Static=1, EIGRP=90, OSPF=110, RIP=120, eBGP=20, iBGP=200.',
          },
          {
            'question':
                'OSPF routers on the same segment elect a Designated Router (DR). Router A has priority 100, Router B has priority 1, Router C has priority 100 but was the first to boot. Which becomes DR?',
            'answers': [
              'Router B — lowest priority is elected DR in OSPF',
              'Router C — the first router to boot always becomes DR regardless of priority',
              'Router A — tied on priority with C, highest Router ID breaks the tie (highest IP address on a loopback or physical interface)',
              'All three — OSPF elects multiple DRs for redundancy',
            ],
            'correct': 2,
            'explanation':
                'OSPF DR election: highest priority wins. Tie is broken by highest Router ID. Routers A and C are tied at priority 100 — the router with the higher Router ID becomes DR. OSPF DR election is not first-come-first-served when priorities are equal.',
          },
          {
            'question':
                'A network running RIP version 2 has a route that has been unreachable for 180 seconds. What happens next and why is RIP poorly suited for large networks?',
            'answers': [
              'RIP marks the route as invalid after 180 seconds and removes it after the flush timer (240s) — RIP is limited to 15 hops maximum, making it unsuitable for large networks',
              'RIP immediately floods the network with a route withdrawal message',
              'RIP waits for the hold-down timer (300s) before removing the route',
              'RIP recalculates the entire routing table using Dijkstra\'s algorithm',
            ],
            'correct': 0,
            'explanation':
                'RIP timers: Update (30s), Invalid (180s), Flush (240s). RIP limitations: maximum 15 hops, slow convergence, sends full routing table every 30 seconds. OSPF and EIGRP replace RIP in enterprise networks.',
          },
          {
            'question':
                'Two OSPF routers are connected but are not forming a neighbour relationship. Hello packets are being sent but no adjacency forms. What is the most likely cause?',
            'answers': [
              'The routers have different router IDs — OSPF requires matching router IDs',
              'OSPF Hello packets must match: Area ID, Hello/Dead intervals, subnet mask, and authentication — a mismatch in any of these prevents adjacency formation',
              'OSPF requires a static route to the neighbour before adjacency can form',
              'The routers are in different AS numbers — OSPF requires matching AS configuration',
            ],
            'correct': 1,
            'explanation':
                'OSPF neighbour requirements (must match): same Area ID, same Hello interval, same Dead interval, same subnet mask, same authentication. Router IDs must be unique. AS number is an EIGRP/BGP concept — OSPF uses Areas.',
          },
          {
            'question':
                'A company has two ISP connections for redundancy. They want traffic to use ISP-A by default but automatically fail over to ISP-B if ISP-A goes down. What routing approach achieves this?',
            'answers': [
              'Configure two default routes with equal cost — traffic load-balances between both ISPs',
              'Configure a floating static route: default route via ISP-A with AD 1, default route via ISP-B with AD 254 — ISP-B route only enters the routing table if ISP-A route is removed',
              'Use OSPF with ISP-A as the preferred OSPF path and ISP-B as backup',
              'Configure policy-based routing to direct traffic based on source address',
            ],
            'correct': 1,
            'explanation':
                'A floating static route has a higher AD than the primary route. When the primary is active, the floating route is not in the table. If the primary fails, the floating route becomes active. ISP-A static at AD 1 is primary; ISP-B static at AD 254 floats.',
          },
          {
            'question':
                'BGP is the routing protocol of the internet. What makes BGP fundamentally different from OSPF and EIGRP?',
            'answers': [
              'BGP uses hop count as its metric — OSPF and EIGRP use bandwidth',
              'BGP is a path-vector protocol that makes routing decisions based on AS-PATH and policies — not just shortest path. It is designed to route between organisations (eBGP), not just within a network',
              'BGP converges faster than OSPF because it uses incremental updates',
              'BGP requires all routers in an AS to be directly connected to each other',
            ],
            'correct': 1,
            'explanation':
                'BGP is a path-vector EGP. It carries AS-PATH, makes decisions based on policy attributes (Local Preference, MED, Weight), and is designed for inter-organisation routing. OSPF/EIGRP are IGPs optimising for shortest path within an organisation.',
          },
          {
            'question':
                'An engineer is configuring EIGRP. They see the term "feasible successor" in the routing table. What is a feasible successor and why is it important?',
            'answers': [
              'The current best route to a destination — the route installed in the forwarding table',
              'A backup route pre-calculated and held in the topology table, ready for instant installation if the successor fails — enabling EIGRP\'s sub-second convergence',
              'The next router in the path to the destination',
              'A route learned from a different EIGRP autonomous system',
            ],
            'correct': 1,
            'explanation':
                'EIGRP: Successor = current best route (in routing table). Feasible Successor = pre-computed backup route in topology table. When a successor fails, EIGRP instantly promotes the feasible successor — no recalculation needed.',
          },
          {
            'question':
                'A packet is destined for a network not in the router\'s routing table and no default route is configured. What happens?',
            'answers': [
              'The packet is forwarded to the nearest router for further processing',
              'The router drops the packet and sends an ICMP Destination Unreachable message back to the source',
              'The router holds the packet until the routing table is updated',
              'The router broadcasts the packet on all interfaces to find the destination',
            ],
            'correct': 1,
            'explanation':
                'If no matching route exists and no default route (0.0.0.0/0) is configured, the router drops the packet and sends ICMP Type 3 (Destination Unreachable) back to the source.',
          },
          {
            'question':
                'What is route summarisation and what benefit does it provide in a large OSPF network?',
            'answers': [
              'Route summarisation combines multiple specific routes into a single aggregate route — reducing routing table size, decreasing LSA flooding, and accelerating convergence',
              'Route summarisation compresses routing table entries to reduce memory usage on routers',
              'Route summarisation prevents routing loops by combining conflicting routes',
              'Route summarisation is only used in BGP to aggregate customer prefixes for ISPs',
            ],
            'correct': 0,
            'explanation':
                'Route summarisation at OSPF area boundaries reduces LSAs flooded throughout the network. Instead of 256 /24 routes, a single /16 summary covers all of them. Benefits: smaller routing tables, less LSA processing, faster SPF calculations.',
          },
          {
            'question':
                'A network engineer runs "show ip route" and sees: O 192.168.5.0/24 [110/20] via 10.0.0.1, 00:05:32, GigabitEthernet0/0. What does each component mean?',
            'answers': [
              'O=OSPF source, 192.168.5.0/24=destination, [110/20]=AD/metric, via 10.0.0.1=next-hop, 00:05:32=route age, Gi0/0=egress interface',
              'O=outbound route, [110/20]=source port/destination port, via 10.0.0.1=gateway, 00:05:32=TTL',
              'O=OSPF, [110/20]=bandwidth/delay metric, via 10.0.0.1=OSPF router ID',
              'O=optional route, 192.168.5.0/24=subnet, [110/20]=priority/cost, 00:05:32=expiry timer',
            ],
            'correct': 0,
            'explanation':
                'Cisco routing table: Code (O=OSPF) | Network | [AD/Metric] | via Next-Hop | Age | Egress Interface. AD 110 = OSPF. Metric 20 = OSPF cost. This output is fundamental to network troubleshooting.',
          },
        ];

      case 'module-05':
        return [
          {
            'question':
                'A host boots and sends a DHCP Discover packet to 255.255.255.255. The DHCP server is on a different subnet. The router between them is not forwarding DHCP broadcasts. What must be configured on the router to fix this?',
            'answers': [
              'A static route to the DHCP server subnet',
              'IP helper-address (DHCP relay) on the router\'s interface facing the clients — converts broadcasts to unicast and forwards to the DHCP server\'s IP',
              'A DHCP pool on the router itself',
              'Port forwarding for UDP port 67 on the firewall',
            ],
            'correct': 1,
            'explanation':
                'DHCP uses broadcasts (UDP port 67/68) that routers do not forward by default. The ip helper-address command converts the broadcast DHCP Discover to a unicast packet addressed to the DHCP server. This is the standard enterprise DHCP design — one server serving multiple subnets.',
          },
          {
            'question':
                'A DNS resolver receives a query for "mail.company.com". It has no cached answer. Describe the recursive resolution process that follows.',
            'answers': [
              'The resolver queries company.com\'s authoritative server directly for the A record',
              'The resolver queries a root nameserver for ".", which refers to the .com TLD server, which refers to company.com\'s authoritative nameserver, which returns the A record — the resolver caches and returns it to the client',
              'The resolver broadcasts the query on the local network segment to find an authoritative server',
              'The resolver queries the ISP\'s DNS server, which already has the answer cached',
            ],
            'correct': 1,
            'explanation':
                'DNS recursive resolution: (1) Root servers → .com TLD servers. (2) .com TLD → company.com authoritative servers. (3) Authoritative server returns A record. (4) Resolver caches and returns to client.',
          },
          {
            'question':
                'A company has a single public IP address from their ISP. They have 200 internal hosts that need internet access. What technology allows this and what are its two forms?',
            'answers': [
              'VPN — tunnels all internal traffic through the single public IP',
              'NAT (Network Address Translation) — PAT (Port Address Translation/NAT overload) maps many private IPs to one public IP using unique port numbers; static NAT maps one private IP to one public IP permanently',
              'DHCP — assigns the single public IP to whichever host needs it at the time',
              'BGP — advertises the single IP to all 200 hosts for direct internet access',
            ],
            'correct': 1,
            'explanation':
                'PAT (NAT overload) allows 200 hosts to share one public IP. Each internal connection gets a unique source port number in the translation table. Static NAT is one-to-one, used for servers that need a permanent public IP.',
          },
          {
            'question':
                'A DHCP server assigns a lease to a host. The host is shut down without releasing the lease. After many such events, the DHCP pool is exhausted. What are two solutions?',
            'answers': [
              'Increase the DHCP pool size and disable IP address reuse',
              'Reduce the lease time (e.g., 4 hours instead of 8 days) so addresses are returned faster, and implement DHCP snooping to prevent rogue servers from exhausting the pool',
              'Assign static IPs to all devices to eliminate DHCP dependency',
              'Enable DHCP failover so a second server handles overflow addresses',
            ],
            'correct': 1,
            'explanation':
                'Shorter lease times mean addresses are returned to the pool faster when devices disconnect without releasing. For environments with many transient devices (guest WiFi, classrooms), lease times of 1-4 hours are appropriate.',
          },
          {
            'question':
                'A security team asks why internal server IP addresses should not appear in public DNS records. What is the risk they are concerned about?',
            'answers': [
              'Public DNS records cause DNS cache poisoning attacks',
              'Exposing internal RFC 1918 addresses in public DNS reveals network topology to attackers — enabling reconnaissance for targeted attacks even though the addresses are not routable from the internet',
              'Internal IPs in public DNS cause routing loops between internal and external resolvers',
              'Public DNS records have a maximum size limit that internal IP records would exceed',
            ],
            'correct': 1,
            'explanation':
                'Information disclosure: internal IP addresses in public DNS reveal network architecture. An attacker learns subnet ranges and server naming conventions. Use split-horizon DNS: internal DNS returns RFC 1918 addresses; external DNS returns only public IPs.',
          },
          {
            'question':
                'An engineer examines a NAT translation table: Inside Local 192.168.1.10:54231 → Inside Global 203.0.113.5:54231 → Outside Global 142.250.80.100:443. What do these three addresses represent?',
            'answers': [
              'Source IP before NAT, destination IP, and gateway IP',
              'Inside Local = private IP of the host; Inside Global = public IP assigned to represent this host on the internet; Outside Global = the destination server\'s public IP',
              'RFC 1918 address, translated address, and return path address',
              'DHCP-assigned IP, static NAT IP, and BGP-advertised IP',
            ],
            'correct': 1,
            'explanation':
                'NAT terminology: Inside Local = actual private IP (192.168.1.10). Inside Global = how the source appears outside — the public IP (203.0.113.5). Outside Global = the destination server\'s IP (142.250.80.100:443). The NAT device maintains this table to translate return traffic.',
          },
          {
            'question':
                'What is the difference between an A record, AAAA record, MX record, and CNAME record in DNS?',
            'answers': [
              'A=hostname to IPv4, AAAA=hostname to IPv6, MX=mail server for a domain, CNAME=alias pointing one hostname to another hostname',
              'A=IPv4 address, AAAA=IPv4 address with authentication, MX=maximum hops, CNAME=canonical name for IP',
              'A=authoritative server, AAAA=backup authoritative server, MX=master exchange, CNAME=certified name',
              'All four record types store IP addresses — they differ only in the protocol version they support',
            ],
            'correct': 0,
            'explanation':
                'DNS record types: A = hostname → IPv4. AAAA = hostname → IPv6. MX = mail servers for a domain with priority values. CNAME = alias pointing one hostname to another. CNAMEs cannot coexist with other records at the zone apex.',
          },
          {
            'question':
                'A company uses NAT with a pool of 5 public IP addresses shared among 500 internal hosts. What happens when all 5 public IPs have their maximum port connections exhausted?',
            'answers': [
              'New connections are queued until a port becomes available',
              'The router randomly drops the oldest connections to free up ports',
              'New outbound connections fail — the NAT table is full and no translation entry can be created for additional sessions',
              'The router automatically requests additional public IPs from the ISP',
            ],
            'correct': 2,
            'explanation':
                'PAT supports ~65,535 port numbers per public IP. With 5 public IPs, the theoretical maximum is ~325,000 simultaneous sessions. When exhausted, new connection attempts fail because no unique translation entry can be created.',
          },
          {
            'question':
                'What is DDNS (Dynamic DNS) and what problem does it solve?',
            'answers': [
              'DDNS encrypts DNS queries to prevent snooping by ISPs',
              'DDNS automatically updates DNS A records when an IP address changes — solving the problem of hosts with dynamic IPs becoming unreachable when their IP changes',
              'DDNS distributes DNS resolution across multiple servers for load balancing',
              'DDNS caches DNS responses locally to reduce resolution time',
            ],
            'correct': 1,
            'explanation':
                'Dynamic DNS: a DDNS client detects IP address changes and automatically updates the DNS A record. This allows a hostname to always resolve to the current IP even when the ISP changes it.',
          },
          {
            'question':
                'An administrator notices that DNS queries are being answered in 5ms for some domains and 250ms for others. What explains this difference?',
            'answers': [
              'The 5ms responses are for local .local domains; 250ms responses are for internet domains',
              'The 5ms responses are served from the resolver\'s cache (TTL not expired); 250ms responses require full recursive resolution to authoritative servers',
              'The 5ms domains use IPv4; 250ms domains use IPv6 which has higher latency',
              'The 250ms domains have longer DNS records that take more time to transmit',
            ],
            'correct': 1,
            'explanation':
                'DNS caching: cached responses (5ms) come from local memory. Uncached responses (250ms) require the full recursive resolution path. Low TTL values = fresher records but more queries; high TTL = faster responses but slower propagation of changes.',
          },
        ];

      case 'module-06':
        return [
          {
            'question':
                'An attacker sends forged DHCP Offer packets faster than the legitimate DHCP server, causing hosts to receive attacker-controlled IP addresses and default gateways. What attack is this and what prevents it?',
            'answers': [
              'ARP poisoning — Dynamic ARP Inspection prevents forged ARP packets',
              'DHCP starvation — port security limits the number of MAC addresses per port',
              'Rogue DHCP server attack — DHCP snooping designates trusted ports and drops DHCP Offer/Ack packets arriving on untrusted ports',
              'VLAN hopping — disabling DTP on access ports prevents the attacker from reaching other VLANs',
            ],
            'correct': 2,
            'explanation':
                'DHCP snooping creates a trust boundary. Ports connected to DHCP servers are marked trusted; all other ports are untrusted. DHCP Offer and Ack from untrusted ports are dropped. DHCP snooping also builds a binding table used by Dynamic ARP Inspection.',
          },
          {
            'question':
                'A firewall is configured as stateful. A client sends a TCP SYN to a web server. The firewall allows it. The server responds with SYN-ACK. How does the stateful firewall handle the return traffic?',
            'answers': [
              'The firewall requires an explicit inbound rule allowing SYN-ACK packets from the server',
              'The firewall tracks the original outbound SYN in its connection state table and automatically allows the return SYN-ACK — no explicit inbound rule needed for established connections',
              'The firewall drops the SYN-ACK because no inbound rule exists',
              'The stateful firewall forwards all return traffic regardless of connection state',
            ],
            'correct': 1,
            'explanation':
                'Stateful firewalls maintain a connection state table. When the SYN-ACK arrives, it matches the existing state and is automatically permitted. This is why stateful firewalls are far more secure than stateless ones.',
          },
          {
            'question':
                'An IDS alert fires on a connection that turns out to be legitimate business traffic. What type of alert is this, and what is the operational risk of too many of them?',
            'answers': [
              'True negative — the IDS correctly ignored malicious traffic',
              'True positive — the IDS correctly identified a genuine threat',
              'False positive — legitimate traffic flagged as malicious. Too many false positives cause alert fatigue, where analysts ignore alerts, allowing real threats to go undetected',
              'False negative — malicious traffic that the IDS missed entirely',
            ],
            'correct': 2,
            'explanation':
                'False positives are operationally dangerous: when analysts see hundreds of false alarms daily, they tune out alerts — creating the exact blind spot attackers exploit. IDS tuning to reduce false positives is critical.',
          },
          {
            'question':
                'A network engineer must allow HTTP and HTTPS traffic from the internet to a web server in a DMZ, while blocking all direct internet traffic to the internal LAN. Describe the correct firewall zone architecture.',
            'answers': [
              'Two zones: internet and internal LAN. Web server sits in the internal LAN behind the firewall',
              'Three zones: internet (untrusted), DMZ (semi-trusted for public-facing servers), internal LAN (trusted). Rules: internet→DMZ allow HTTP/HTTPS; internet→LAN deny all; DMZ→LAN deny all except required application traffic',
              'Single zone with firewall rules differentiating traffic by IP address and port',
              'Two zones: DMZ and internal LAN. Internet connects directly to the DMZ switch without a firewall',
            ],
            'correct': 1,
            'explanation':
                'Three-zone DMZ architecture: the DMZ sits between two firewall interfaces. Public-facing servers go in the DMZ. If a DMZ server is compromised, the attacker cannot directly reach the internal LAN.',
          },
          {
            'question':
                'A network admin wants to control which devices can access the network based on their identity, not just their IP or MAC address. Which technology enforces this?',
            'answers': [
              'Port Security — restricts access by MAC address per switch port',
              '802.1X (port-based Network Access Control) — requires devices to authenticate via RADIUS before the switch port is placed in the network VLAN',
              'DHCP snooping — prevents unauthorised devices from receiving IP addresses',
              'ACLs — block traffic from unknown IP addresses at the router',
            ],
            'correct': 1,
            'explanation':
                '802.1X: before a device can access the network, the switch requires it to authenticate against a RADIUS server. Until authentication succeeds, the port is in an unauthorised state. After success, the port is placed in the correct VLAN.',
          },
          {
            'question':
                'A company implements an ACL: (1) Permit TCP 192.168.1.0/24 any eq 80, (2) Permit TCP 192.168.1.0/24 any eq 443, (3) Deny IP any any. A host at 192.168.1.50 tries to send a DNS query (UDP port 53). What happens?',
            'answers': [
              'The DNS query is permitted by rule 1 because port 80 is close to port 53',
              'The DNS query is permitted because DNS is a core protocol that ACLs cannot block',
              'The DNS query matches rule 3 (deny) and is dropped — the ACL only permits HTTP and HTTPS from the subnet',
              'The DNS query is forwarded because UDP is not covered by TCP-based ACL rules',
            ],
            'correct': 2,
            'explanation':
                'ACLs are processed top-down, first-match. UDP/53 (DNS) matches neither TCP rule — it falls through to Rule 3 (deny) and is dropped. This is a common misconfiguration: admins permit web traffic but forget DNS, ICMP, NTP.',
          },
          {
            'question':
                'What is the difference between an IDS and an IPS, and where is each typically deployed?',
            'answers': [
              'IDS and IPS are identical — the terms are interchangeable in modern security',
              'IDS is deployed inline and actively blocks malicious traffic; IPS is deployed out-of-band and only sends alerts',
              'IDS is out-of-band (receives a copy of traffic) — detects and alerts but cannot block. IPS is inline — can detect AND actively block malicious traffic in real time',
              'IDS monitors internal network traffic; IPS monitors only internet-facing traffic',
            ],
            'correct': 2,
            'explanation':
                'IDS receives a copy of traffic via SPAN port — passive, cannot block, only alerts. IPS sits inline — all traffic passes through it, enabling active blocking. Many modern NGFWs incorporate IPS functionality inline.',
          },
          {
            'question':
                'A penetration tester connects to a guest WiFi network and attempts to scan hosts on the corporate VLAN. The scan returns no results despite the corporate VLAN being on the same physical access point. What control prevented this?',
            'answers': [
              'The firewall blocked the scanner\'s traffic because it came from an unknown IP',
              'VLAN segmentation — the guest and corporate networks are on separate VLANs, and the router/firewall blocks unsolicited inbound scans from the guest VLAN to the corporate VLAN',
              'The access point\'s transmit power was too low for the scanner to reach corporate hosts',
              'WPA2 encryption prevented the scanner from seeing corporate traffic',
            ],
            'correct': 1,
            'explanation':
                'Proper segmentation places guest users on an isolated VLAN with internet access only — no access to corporate VLANs. The firewall/router between VLANs blocks lateral movement.',
          },
          {
            'question':
                'A router ACL is applied outbound on the interface connected to the internet. At which point is the ACL evaluated?',
            'answers': [
              'When the packet arrives on the router\'s internal interface (inbound evaluation)',
              'After routing, just before the packet leaves the internet-facing interface (outbound evaluation)',
              'Both inbound and outbound — the ACL is evaluated twice for every packet',
              'The ACL is evaluated at the firewall, not the router',
            ],
            'correct': 1,
            'explanation':
                'ACL direction is from the router\'s perspective: outbound = evaluated as packet leaves an interface, after routing. Inbound ACLs are more efficient — they drop unwanted traffic before routing.',
          },
          {
            'question':
                'What does a next-generation firewall (NGFW) do that a traditional stateful firewall cannot?',
            'answers': [
              'NGFW operates at Layer 3 and 4; traditional firewalls only operate at Layer 2',
              'NGFW performs deep packet inspection at Layer 7 — identifying applications regardless of port, integrating IPS, URL filtering, SSL inspection, and user identity awareness into a single policy engine',
              'NGFW can filter traffic based on MAC addresses; traditional firewalls cannot',
              'NGFW processes traffic faster than traditional firewalls using dedicated ASICs',
            ],
            'correct': 1,
            'explanation':
                'Traditional stateful firewalls match on IP/port/protocol (Layers 3-4). NGFWs add Layer 7 inspection: recognise applications regardless of port, enforce per-application policies, integrate IPS, perform SSL inspection, and apply policies based on user identity.',
          },
        ];

      case 'module-07':
        return [
          {
            'question':
                'A company deploys a new 802.11ax (WiFi 6) access point in a high-density conference room. Users report significantly better performance compared to the old 802.11ac AP, despite similar channel width. What technology in 802.11ax primarily enables this improvement?',
            'answers': [
              'Beamforming — directs the signal specifically at each client device',
              'OFDMA (Orthogonal Frequency-Division Multiple Access) — allows the AP to serve multiple clients simultaneously on different sub-channels, reducing contention in high-density environments',
              'MU-MIMO — enables multiple simultaneous streams to different clients',
              'WPA3 encryption — reduces overhead compared to WPA2, freeing bandwidth for data',
            ],
            'correct': 1,
            'explanation':
                'OFDMA is the key WiFi 6 improvement for high-density. In 802.11ac, only one client transmits per time slot. OFDMA divides channels into resource units — multiple clients transmit simultaneously on different sub-carriers, dramatically reducing contention.',
          },
          {
            'question':
                'A wireless network uses WPA2-Enterprise. A laptop connects without prompting for a password. Explain what is happening.',
            'answers': [
              'The network is open and unsecured — no authentication is required',
              'The laptop has a saved password from a previous connection',
              'WPA2-Enterprise uses 802.1X authentication — the laptop presents a certificate to a RADIUS server. The certificate was pre-installed, so authentication happens automatically without a user-visible password prompt',
              'WPA2-Enterprise uses MAC address authentication — the laptop\'s MAC is pre-approved',
            ],
            'correct': 2,
            'explanation':
                'WPA2-Enterprise (802.1X) replaces the shared PSK with per-user/device authentication via RADIUS. EAP-TLS (certificate-based) requires no password prompt if the cert is pre-installed. Each device has a unique credential that can be individually revoked.',
          },
          {
            'question':
                'An engineer surveys a building and finds multiple APs on channel 6 in adjacent areas, causing co-channel interference. What is the correct channel plan for 2.4GHz to minimise interference?',
            'answers': [
              'Use channels 1, 6, and 11 — the only three non-overlapping channels in 2.4GHz (20MHz wide)',
              'Use channels 1, 4, 8, and 11 — four non-overlapping channels in 2.4GHz',
              'Use channels 1, 3, 5, 7, 9, and 11 — even-numbered spacing prevents overlap',
              'The 2.4GHz band has 13 non-overlapping channels — use any combination',
            ],
            'correct': 0,
            'explanation':
                '2.4GHz has only channels 1, 6, and 11 as non-overlapping with 20MHz channel width. Adjacent channels (e.g., 1 and 3) overlap in frequency and cause interference. 5GHz has many more non-overlapping channels.',
          },
          {
            'question':
                'A security audit finds a rogue AP broadcasting the same SSID as the corporate network with stronger signal. Users\' devices automatically connect to it. What attack is this and what are the consequences?',
            'answers': [
              'Deauthentication attack — the rogue AP disconnects users from the legitimate AP',
              'Evil Twin attack — the rogue AP intercepts all user traffic as a man-in-the-middle, enabling credential theft, session hijacking, and malware injection',
              'WPS brute force attack — the rogue AP uses WPS to crack the network password',
              'Beacon flooding attack — the rogue AP overwhelms clients with fake beacon frames',
            ],
            'correct': 1,
            'explanation':
                'Evil Twin: the rogue AP (same SSID, stronger signal) intercepts all client traffic. Defences: 802.1X/WPA2-Enterprise with certificate validation (a rogue AP cannot present a valid cert); WIDS to detect rogue APs; always-on VPN.',
          },
          {
            'question':
                'What is the purpose of a wireless LAN controller (WLC) in an enterprise WiFi deployment, compared to autonomous APs?',
            'answers': [
              'A WLC increases the range of each AP by boosting signal strength',
              'A WLC centralises management, RF optimisation, roaming, and security policy for all APs — autonomous APs are independently managed with separate configurations and cannot support seamless roaming',
              'A WLC provides DHCP and DNS services that autonomous APs cannot offer',
              'A WLC is required to support WPA2 — autonomous APs only support WPA',
            ],
            'correct': 1,
            'explanation':
                'Controller-based (CAPWAP) architecture: APs are lightweight — they only handle RF. The WLC handles authentication, policy, roaming handoffs, and configuration. Benefits: single-pane management, seamless roaming, dynamic RF management, rogue AP detection.',
          },
          {
            'question':
                'A user 30 metres from an AP gets excellent signal but poor throughput. A client 5 metres away gets excellent throughput. What is the most likely cause?',
            'answers': [
              'The AP is transmitting at too high a power level, causing interference at 30 metres',
              'The distant client is connecting at a lower modulation rate (e.g., BPSK/QPSK) due to signal degradation — the AP must accommodate this slower rate, which consumes more airtime per transmission',
              'The AP\'s radio frequency is being absorbed by building materials at 30 metres',
              'The distant client\'s antenna is incorrectly oriented for optimal signal reception',
            ],
            'correct': 1,
            'explanation':
                'WiFi uses adaptive modulation: as signal degrades, clients drop to lower modulation schemes. Lower modulation = lower data rate but takes the same airtime. When a slow client transmits, it consumes channel time that faster clients could use — the "slow client problem."',
          },
          {
            'question':
                'What does the hidden node problem cause in wireless networks, and what mechanism attempts to address it?',
            'answers': [
              'Hidden nodes create duplicate SSIDs that confuse clients — beacon frames address this',
              'Two clients cannot hear each other but can both hear the AP — they transmit simultaneously, causing collisions at the AP that neither detects. RTS/CTS allows clients to reserve the channel before transmitting',
              'Clients hidden behind walls cannot authenticate to the AP — 802.1X addresses this',
              'Hidden nodes reduce signal strength — power control mechanisms compensate',
            ],
            'correct': 1,
            'explanation':
                'Hidden node: Client A and Client B are both in range of the AP but not each other. Both transmit simultaneously — a collision occurs at the AP. RTS/CTS: Client A sends RTS → AP responds CTS → Client B defers → Client A transmits.',
          },
          {
            'question':
                'A network engineer must provide WiFi coverage for a large warehouse with metal shelving. 2.4GHz and 5GHz are both available. Which band is more appropriate and why?',
            'answers': [
              '5GHz — higher frequency provides better penetration through metal obstacles',
              '2.4GHz — lower frequency has better range and penetration through obstacles including metal shelving, at the cost of fewer non-overlapping channels',
              '5GHz — it has more non-overlapping channels, reducing interference from metal reflections',
              '2.4GHz — it is immune to multipath interference caused by metal surfaces',
            ],
            'correct': 1,
            'explanation':
                '2.4GHz has longer wavelength = better wall and obstacle penetration and longer range. 5GHz has shorter wavelength = shorter range and higher absorption by obstacles. For warehouses with metal shelving, 2.4GHz is more practical.',
          },
          {
            'question':
                'What is BSS (Basic Service Set) vs ESS (Extended Service Set) in WiFi terminology?',
            'answers': [
              'BSS is the wireless standard for 2.4GHz; ESS is the standard for 5GHz',
              'BSS is a single AP with its associated clients; ESS is multiple APs sharing the same SSID, forming a unified network that supports roaming between APs',
              'BSS provides basic encryption; ESS provides enterprise-grade encryption',
              'BSS is used for indoor deployments; ESS extends coverage to outdoor areas',
            ],
            'correct': 1,
            'explanation':
                'BSS: one AP + its associated client stations = a single wireless cell identified by BSSID (the AP\'s MAC). ESS: multiple BSSs sharing the same SSID — clients can roam between APs without reconfiguring. Enterprise networks are always ESS.',
          },
          {
            'question':
                'WPA3 replaced WPA2 as the latest WiFi security standard. What specific cryptographic improvement does WPA3-Personal provide over WPA2-Personal?',
            'answers': [
              'WPA3 uses AES-256 instead of AES-128 for encryption',
              'WPA3 uses SAE (Simultaneous Authentication of Equals) instead of PSK — providing forward secrecy so that capturing the handshake and later learning the password cannot decrypt previously captured traffic',
              'WPA3 requires certificate-based authentication eliminating the need for passwords',
              'WPA3 uses TKIP encryption which is stronger than CCMP used in WPA2',
            ],
            'correct': 1,
            'explanation':
                'WPA2-Personal vulnerability: offline dictionary attacks against captured 4-way handshakes. WPA3 SAE provides forward secrecy — each session uses a unique key. Knowing the password after the fact cannot decrypt previously captured sessions.',
          },
        ];

      case 'module-08':
        return [
          {
            'question':
                'A network engineer runs "ping 8.8.8.8" from a host and gets 100% packet loss. They run "ping 192.168.1.1" (default gateway) and get replies. What layer and component should they investigate next?',
            'answers': [
              'Layer 1 — physical cable between host and switch',
              'Layer 2 — switch port VLAN configuration',
              'Layer 3 — the router\'s routing table, default route, or the uplink between the router and ISP. The gateway is reachable but packets are not reaching the internet',
              'Layer 4 — firewall is blocking ICMP outbound',
            ],
            'correct': 2,
            'explanation':
                'Gateway responds → Layers 1-3 to the gateway work. Next steps: (1) check if the router has a default route; (2) ping the ISP\'s next-hop router from the router; (3) check WAN interface status; (4) check NAT translations.',
          },
          {
            'question':
                'A "show interface" command on a router shows: "GigabitEthernet0/1 is up, line protocol is down." What does this status indicate?',
            'answers': [
              'The interface has no IP address configured',
              'The physical layer (Layer 1) is connected (carrier detected) but the data link layer (Layer 2) is not establishing — common causes: keepalive mismatch, encapsulation mismatch, or the remote device is not sending Layer 2 frames',
              'The interface is administratively shutdown by the "shutdown" command',
              'The interface has a speed or duplex mismatch with the connected device',
            ],
            'correct': 1,
            'explanation':
                '"Up/down": up = physical signal detected (Layer 1 OK), line protocol down = Layer 2 not functioning. Status combinations: up/up = fully operational; up/down = Layer 2 issue; down/down = no physical signal; administratively down/down = shutdown applied.',
          },
          {
            'question':
                'An engineer uses traceroute and sees: Hop 1: 1ms, Hop 2: 2ms, Hop 3: 150ms, Hop 4: 152ms, Hop 5: 153ms. What does this indicate?',
            'answers': [
              'The problem is at the remote server — Hop 5 has the highest latency',
              'The latency was introduced between Hop 2 and Hop 3 — the 148ms increase at Hop 3 indicates a slow or congested WAN link or geographic distance between those two routers',
              'The entire path is slow — all hops above 1ms indicate network problems',
              'Hop 3 is a firewall adding inspection latency — subsequent hops show normal performance',
            ],
            'correct': 1,
            'explanation':
                'Traceroute measures cumulative latency. The jump from 2ms to 150ms at Hop 3 shows the latency was introduced by the link between Hop 2 and Hop 3 — likely a WAN link, geographic distance, or congestion.',
          },
          {
            'question':
                'SNMP is used to monitor network devices. What is the difference between SNMP polling and SNMP traps, and which is more efficient for real-time alerting?',
            'answers': [
              'SNMP polling sends data continuously; traps send data only on demand — polling is better for real-time alerts',
              'SNMP polling (manager queries device at intervals) generates regular traffic regardless of events; SNMP traps (device proactively notifies manager when an event occurs) are more efficient for alerts',
              'SNMP polling uses UDP; traps use TCP — traps are more reliable for critical alerts',
              'SNMP traps require SNMPv3; polling works with SNMPv1 and v2c',
            ],
            'correct': 1,
            'explanation':
                'SNMP polling generates predictable traffic, good for trending data. SNMP traps are near-real-time with minimal overhead. Best practice: use both — traps for immediate alerts, polling for performance baselines.',
          },
          {
            'question':
                'A network engineer needs to capture traffic on a switch port to diagnose an issue. The switch supports SPAN (Switched Port Analyser). What does SPAN do?',
            'answers': [
              'SPAN blocks traffic on a port for analysis without affecting production traffic',
              'SPAN copies traffic from a source port or VLAN to a designated destination port where a packet analyser (e.g., Wireshark) is connected — no impact on source traffic',
              'SPAN compresses traffic statistics and sends them to a syslog server',
              'SPAN creates a second virtual port mirroring the configuration of the source port',
            ],
            'correct': 1,
            'explanation':
                'SPAN (Port Mirroring) copies all frames from the source port to a destination port. The source traffic is not affected — SPAN is non-intrusive. RSPAN extends mirroring across multiple switches.',
          },
          {
            'question':
                'A network monitoring system shows an interface with utilisation consistently above 90% during business hours. What are the correct next steps?',
            'answers': [
              'Immediately replace the link with a faster one — 90% utilisation always requires hardware upgrade',
              'Identify the traffic causing congestion using NetFlow or SNMP top-talkers analysis; implement QoS to prioritise business-critical traffic; evaluate whether a link upgrade is required',
              'Apply an ACL to block the top-consuming IP address',
              'Enable compression on the interface to reduce bandwidth consumption',
            ],
            'correct': 1,
            'explanation':
                'Before upgrading, understand what is consuming bandwidth. NetFlow identifies top talkers and applications. QoS can prioritise business applications over bulk transfers. A link upgrade should be a data-driven decision.',
          },
          {
            'question':
                'What is the difference between syslog severity levels and why does the level matter for network management?',
            'answers': [
              'Syslog levels only affect how fast messages are delivered',
              'Syslog defines 8 severity levels (0=Emergency to 7=Debug). Setting the logging level determines which messages are sent — too verbose floods the syslog server; too restrictive misses warnings',
              'Syslog severity levels are vendor-specific — Cisco and Juniper use different scales',
              'Syslog levels only apply to interface status messages',
            ],
            'correct': 1,
            'explanation':
                'Syslog severity: 0=Emergency, 1=Alert, 2=Critical, 3=Error, 4=Warning, 5=Notice, 6=Informational, 7=Debug. Debug generates enormous volume. Production: typically level 6 or level 4 for warning-and-above.',
          },
          {
            'question':
                'An engineer is asked to implement QoS to protect VoIP calls from being degraded by bulk file transfers on the same WAN link. Which QoS mechanism should be applied?',
            'answers': [
              'Traffic shaping — slows VoIP traffic to match the speed of file transfers',
              'DSCP marking + LLQ (Low Latency Queue) — VoIP packets are marked EF (Expedited Forwarding, DSCP 46) and placed in a strict priority queue that is always serviced before other queues',
              'WRED (Weighted Random Early Detection) — randomly drops file transfer packets to make room for VoIP',
              'Traffic policing — limits VoIP bandwidth to a fixed rate',
            ],
            'correct': 1,
            'explanation':
                'VoIP requirements: low latency (<150ms), low jitter (<30ms), low packet loss (<1%). LLQ provides a strict priority queue always serviced first. DSCP EF marking allows routers throughout the path to identify VoIP packets.',
          },
          {
            'question':
                'A change management process requires a rollback plan before any network change. An engineer is upgrading IOS on a core switch. What should the rollback plan include?',
            'answers': [
              'A note that the previous IOS version was installed',
              'A verified backup of the current IOS image and running configuration stored on a TFTP server, the ability to boot the previous image, a defined rollback trigger, a change window, and a tested restore procedure',
              'Contact information for the switch vendor\'s support line',
              'A plan to notify users that the network will be unavailable during the upgrade',
            ],
            'correct': 1,
            'explanation':
                'A proper rollback plan: (1) verified backup of current image + config; (2) defined rollback triggers; (3) tested rollback procedure; (4) time-boxed maintenance window; (5) communication plan. The most common failure is discovering the backup doesn\'t work during the incident.',
          },
          {
            'question':
                'NetFlow is configured on a router to monitor traffic patterns. What information does NetFlow provide that simple SNMP interface counters cannot?',
            'answers': [
              'NetFlow provides interface utilisation at higher granularity than SNMP polling',
              'NetFlow provides per-flow visibility: source/destination IP, port, protocol, bytes, and packets per conversation — SNMP shows only total interface byte counts with no insight into who is talking to whom',
              'NetFlow monitors packet loss and retransmissions; SNMP only counts total packets',
              'NetFlow works on wireless interfaces; SNMP only monitors wired interfaces',
            ],
            'correct': 1,
            'explanation':
                'SNMP: total bytes in/out, error counts. NetFlow: full flow records (src IP:port → dst IP:port, protocol, bytes, packets). This answers: "Who are the top talkers?", "What application is consuming bandwidth?", "Who is connecting to this server?"',
          },
        ];

      default:
        return [
          {
            'question': 'What does a router use to make forwarding decisions?',
            'answers': [
              'MAC address table',
              'IP routing table — matches destination IP to next-hop or egress interface',
              'ARP cache',
              'DNS records',
            ],
            'correct': 1,
            'explanation':
                'Routers use the IP routing table to forward packets. They match the destination IP address against routes using longest prefix match and forward to the next-hop router or directly connected network.',
          },
        ];
    }
  }
}
