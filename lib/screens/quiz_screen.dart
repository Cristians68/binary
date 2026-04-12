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

  // ── THE FIX: shuffle answer positions at runtime so correct answer is never
  // in a predictable position. The correctIndex tracks where it lands after shuffle.
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

  void _showResults() {
    final theme = AppTheme.of(context);
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
        final courseComplete = await ProgressService.isCourseComplete(
          widget.courseId,
        );
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
              GestureDetector(
                onTap: () async {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  Navigator.pop(context);
                  if (passed) {
                    final courseComplete =
                        await ProgressService.isCourseComplete(widget.courseId);
                    if (courseComplete && mounted) {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  CertificateScreen(
                                    courseTitle: widget.courseTag,
                                    courseTag: widget.courseTag,
                                    color: widget.color,
                                    courseId: widget.courseId,
                                  ),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) =>
                                  FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                          transitionDuration: const Duration(milliseconds: 500),
                        ),
                      );
                    }
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
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
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
    return _networkingFallback();
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
      case 'module-01':
        return [
          {
            'question':
                'Which is NOT one of NIST\'s five essential characteristics of cloud computing?',
            'answers': [
              'On-demand self-service',
              'Dedicated hardware per customer',
              'Rapid elasticity',
              'Measured service',
            ],
            'correct': 1,
            'explanation':
                'NIST\'s five: on-demand self-service, broad network access, resource POOLING (shared), rapid elasticity, measured service. Dedicated hardware is the opposite of pooling.',
          },
          {
            'question': 'What does "elasticity" mean in cloud?',
            'answers': [
              'Physical flexibility of data centre cables',
              'Automatically scaling resources up and down based on demand',
              'Using multiple cloud providers simultaneously',
              'Backing up data to multiple regions',
            ],
            'correct': 1,
            'explanation':
                'Elasticity = resources automatically scale with demand. Up under load, down when quiet. Pay only for what you use.',
          },
          {
            'question':
                'A company moves from owning physical servers to renting cloud resources monthly. What financial shift?',
            'answers': [
              'From OpEx to CapEx',
              'From CapEx to OpEx',
              'No overall financial benefit',
              'From monthly to annual contracts only',
            ],
            'correct': 1,
            'explanation':
                'Cloud shifts from Capital Expenditure (large upfront hardware = CapEx) to Operational Expenditure (monthly pay-as-you-go = OpEx). Improves cash flow and flexibility.',
          },
          {
            'question': 'What does "on-demand self-service" mean in cloud?',
            'answers': [
              'You can call provider support at any time',
              'You can provision resources yourself without human interaction from the provider',
              'Resources are available 24/7 with no downtime',
              'Billing is calculated automatically',
            ],
            'correct': 1,
            'explanation':
                'On-demand self-service = spin up servers, databases, storage via console or API — no calls, no tickets to the provider. Immediate automated provisioning.',
          },
          {
            'question': 'What is "resource pooling" in cloud?',
            'answers': [
              'All customers share the same login credentials',
              'Provider\'s physical resources serve multiple customers simultaneously, dynamically allocated',
              'Each customer gets dedicated physical hardware',
              'Storage and compute must be purchased together',
            ],
            'correct': 1,
            'explanation':
                'Resource pooling = multi-tenancy. Provider\'s hardware serves multiple customers with dynamic allocation. Customers get logical isolation but share physical infrastructure.',
          },
          {
            'question': 'What is "measured service" in cloud?',
            'answers': [
              'Provider measures distance to nearest data centre',
              'Resource usage is monitored, metered, and billed — you pay for exactly what you consume',
              'Performance is guaranteed via SLAs',
              'Customer satisfaction is measured monthly',
            ],
            'correct': 1,
            'explanation':
                'Measured service = pay for compute hours, GB transferred, or API calls — like a utility bill. Not a fixed fee for unused capacity.',
          },
          {
            'question':
                'What is the key difference between scalability and elasticity?',
            'answers': [
              'They are the same concept',
              'Scalability = ability to increase capacity; elasticity = automatic scale-up AND scale-down based on demand',
              'Scalability = storage; elasticity = compute',
              'Elasticity requires manual intervention',
            ],
            'correct': 1,
            'explanation':
                'Scalability = can handle growth. Elasticity = automatically adjusts in both directions. Elasticity is a specific automated form of scalability.',
          },
          {
            'question': 'Which best describes on-premises infrastructure?',
            'answers': [
              'Servers hosted in a co-location facility',
              'Computing resources owned and physically managed by the organisation in its own facility',
              'Any infrastructure not accessed via internet',
              'A private cloud hosted by a managed service provider',
            ],
            'correct': 1,
            'explanation':
                'On-premises = organisation owns physical hardware and manages it in their own data centre. Full control, full responsibility.',
          },
          {
            'question':
                'A startup needs servers for a product launch but doesn\'t want long-term hardware investment. Which cloud characteristic helps?',
            'answers': [
              'Resource pooling',
              'On-demand self-service combined with pay-as-you-go pricing',
              'Broad network access',
              'Data sovereignty',
            ],
            'correct': 1,
            'explanation':
                'On-demand self-service + measured service = launch with minimal upfront investment, scale if product succeeds, decommission if it doesn\'t.',
          },
          {
            'question': 'What does "broad network access" mean?',
            'answers': [
              'The provider has a very fast internet connection',
              'Cloud services are accessible via the network using standard devices like laptops and phones',
              'The provider operates in many countries',
              'All users share the same bandwidth',
            ],
            'correct': 1,
            'explanation':
                'Broad network access = cloud services available via internet using standard client devices and protocols — accessible from anywhere with a connection.',
          },
        ];

      case 'module-02':
        return [
          {
            'question':
                'In which cloud service model does the provider manage the OS and runtime?',
            'answers': ['IaaS', 'PaaS', 'SaaS', 'FaaS'],
            'correct': 1,
            'explanation':
                'PaaS: provider manages OS, runtime, and infrastructure. You only manage application code and data.',
          },
          {
            'question':
                'A team deploys code to Heroku by pushing to Git. Never configures servers. Which model?',
            'answers': ['IaaS', 'PaaS', 'SaaS', 'On-premises'],
            'correct': 1,
            'explanation':
                'Heroku = PaaS. Provider manages OS, runtime, and infrastructure. Team manages only their application code.',
          },
          {
            'question':
                'Which service model has the LEAST customer responsibility for infrastructure?',
            'answers': ['IaaS', 'PaaS', 'SaaS', 'FaaS'],
            'correct': 2,
            'explanation':
                'SaaS: provider manages everything. Customer just uses the application. No OS, runtime, or infrastructure management.',
          },
          {
            'question':
                'AWS Lambda runs a function when a file is uploaded to S3. Which model?',
            'answers': ['IaaS', 'PaaS', 'SaaS', 'FaaS (Serverless)'],
            'correct': 3,
            'explanation':
                'Lambda = FaaS. Code runs on event trigger, no servers to provision, billed per execution in milliseconds. Zero idle cost.',
          },
          {
            'question':
                'A company uses Microsoft 365 for email. Which service model?',
            'answers': ['IaaS', 'PaaS', 'SaaS', 'FaaS'],
            'correct': 2,
            'explanation':
                'Microsoft 365 = SaaS. Microsoft manages all infrastructure, updates, and maintenance. Company just uses the software.',
          },
          {
            'question':
                'Pizza analogy: which model is "pizza delivered and ready to eat"?',
            'answers': ['IaaS', 'PaaS', 'SaaS', 'On-premises'],
            'correct': 2,
            'explanation':
                'SaaS = pizza delivered ready to eat. IaaS = ingredients delivered (you cook). PaaS = pizza kit (you assemble). On-premises = you grow ingredients and build everything.',
          },
          {
            'question': 'Which correctly describes IaaS shared responsibility?',
            'answers': [
              'Provider manages everything including OS and app',
              'Customer manages OS, middleware, and app; provider manages physical hardware',
              'Customer only manages their data; provider manages everything else',
              'Responsibility is equal',
            ],
            'correct': 1,
            'explanation':
                'IaaS: Customer = OS upwards (patching, configuration, application). Provider = hardware, networking, virtualisation downwards.',
          },
          {
            'question':
                'Which service model gives developers the fastest path to running application without infrastructure work?',
            'answers': ['IaaS', 'PaaS', 'On-premises', 'Colocation'],
            'correct': 1,
            'explanation':
                'PaaS eliminates all infrastructure management. Developers focus only on code. Platform handles everything below the application layer.',
          },
          {
            'question':
                'Google App Engine is an example of which service model?',
            'answers': ['IaaS', 'PaaS', 'SaaS', 'FaaS'],
            'correct': 1,
            'explanation':
                'Google App Engine = PaaS. Deploy application code; Google manages underlying infrastructure, OS, and runtime.',
          },
          {
            'question': 'Key operational difference between PaaS and FaaS?',
            'answers': [
              'They are the same',
              'PaaS provides an always-on platform; FaaS executes code only on-demand and scales to zero when idle',
              'FaaS requires more server management',
              'PaaS is for mobile only; FaaS for web',
            ],
            'correct': 1,
            'explanation':
                'PaaS runs your application continuously. FaaS runs code only when triggered — scales to zero between invocations. FaaS has no idle cost; PaaS does.',
          },
        ];

      case 'module-03':
        return [
          {
            'question':
                'A hospital stores patient records on private infrastructure but uses AWS for a public appointment booking site. What model?',
            'answers': [
              'Public cloud',
              'Private cloud',
              'Hybrid cloud',
              'Multi-cloud',
            ],
            'correct': 2,
            'explanation':
                'Hybrid cloud = combining private and public. Sensitive data stays on private (compliance); less sensitive workloads use public cloud for flexibility.',
          },
          {
            'question':
                'Primary reason an organisation adopts a multi-cloud strategy?',
            'answers': [
              'Reduce all cloud costs to zero',
              'Avoid vendor lock-in and use the best services from multiple providers',
              'A single provider cannot serve multiple regions',
              'To comply with GDPR',
            ],
            'correct': 1,
            'explanation':
                'Multi-cloud avoids vendor lock-in and allows selecting the best service from each provider.',
          },
          {
            'question':
                'What makes a private cloud different from simply owning on-premises servers?',
            'answers': [
              'Private cloud is managed by a third party',
              'Private cloud uses virtualisation to provide on-demand, self-service resources — like a cloud, but dedicated',
              'Private cloud uses public internet',
              'They are the same thing',
            ],
            'correct': 1,
            'explanation':
                'Private cloud applies cloud characteristics (self-service, elasticity, measured service) to dedicated infrastructure. Traditional on-premises lacks these capabilities.',
          },
          {
            'question':
                'Most appropriate deployment model for a government agency with strict data sovereignty requirements?',
            'answers': [
              'Public cloud',
              'Multi-cloud',
              'Private cloud',
              'Community cloud',
            ],
            'correct': 2,
            'explanation':
                'Private cloud = complete control over where data is stored and who can access it. Essential for data sovereignty and national security compliance.',
          },
          {
            'question':
                'An org built entirely with AWS-specific services like DynamoDB, Lambda, SageMaker. What risk?',
            'answers': [
              'Performance will degrade over time',
              'Vendor lock-in — migrating to another provider would require significant rearchitecting',
              'App will become non-compliant',
              'AWS will increase prices unpredictably',
            ],
            'correct': 1,
            'explanation':
                'Vendor lock-in: deep use of proprietary services makes migrating extremely expensive. May require years of rewriting to use equivalent services elsewhere.',
          },
          {
            'question': 'What is a community cloud?',
            'answers': [
              'A public cloud with lower prices for charities',
              'A shared cloud used exclusively by organisations with common concerns like compliance or mission',
              'A cloud built by open-source communities',
              'A cloud for local government only',
            ],
            'correct': 1,
            'explanation':
                'Community cloud serves a group of organisations with shared requirements (e.g. NHS trusts sharing a compliant healthcare cloud). Shared but not public.',
          },
          {
            'question':
                'Which deployment model offers the lowest upfront cost and fastest provisioning?',
            'answers': [
              'Private cloud',
              'On-premises',
              'Public cloud',
              'Community cloud',
            ],
            'correct': 2,
            'explanation':
                'Public cloud = zero upfront capital cost, resources in minutes. Private and on-premises require hardware procurement and setup — weeks or months.',
          },
          {
            'question':
                'A company uses AWS for their web app and Azure for identity management simultaneously. What model?',
            'answers': [
              'Hybrid cloud',
              'Multi-cloud',
              'Community cloud',
              'Private cloud',
            ],
            'correct': 1,
            'explanation':
                'Multi-cloud = using services from multiple different cloud providers simultaneously. Hybrid = combining public and private/on-premises.',
          },
          {
            'question': 'Main disadvantage of private cloud vs public cloud?',
            'answers': [
              'Private cloud offers less security',
              'Private cloud requires the organisation to manage infrastructure — higher upfront and operational costs',
              'Private cloud cannot scale',
              'Private cloud does not support virtualisation',
            ],
            'correct': 1,
            'explanation':
                'Private cloud retains all infrastructure management — hardware, software, power, cooling, staffing. Significant investment and expertise required.',
          },
          {
            'question':
                'Which best describes the shared responsibility model in public cloud?',
            'answers': [
              'Provider is responsible for everything including customer data',
              'Customer is responsible for physical hardware',
              'Provider secures the infrastructure; customer secures what they run on it',
              'Responsibility is negotiated individually',
            ],
            'correct': 2,
            'explanation':
                'Shared responsibility: provider = security OF the cloud (hardware, network, facilities). Customer = security IN the cloud (data, access controls, OS config).',
          },
        ];

      case 'module-04':
        return [
          {
            'question':
                'Best storage type for user profile photos accessed via HTTP?',
            'answers': [
              'Block storage',
              'File storage',
              'Object storage',
              'Archive storage',
            ],
            'correct': 2,
            'explanation':
                'Object storage (S3) = ideal for unstructured files like photos, videos, documents. Scales infinitely, HTTP APIs, purpose-built for this use case.',
          },
          {
            'question': 'What is block storage in cloud?',
            'answers': [
              'Storage for large data blocks like video files',
              'Virtualised storage acting like a raw hard drive attached to a VM',
              'Shared network storage accessible from multiple instances',
              'Encrypted cold archive storage',
            ],
            'correct': 1,
            'explanation':
                'Block storage (EBS, Azure Managed Disk) = like a physical hard drive attached to your VM. Low-latency, directly mounted storage for OS and databases.',
          },
          {
            'question': 'Primary advantage of a managed database service?',
            'answers': [
              'Always performs better',
              'Provider handles backups, patching, replication, and failover automatically',
              'Supports more SQL features',
              'Always cheaper',
            ],
            'correct': 1,
            'explanation':
                'Managed databases eliminate DBA tasks. You focus on your data and queries — the provider handles the engine.',
          },
          {
            'question':
                'A global e-commerce site serves users in US, Europe, and Asia. What would most reduce load times?',
            'answers': [
              'Larger virtual machines',
              'A Content Delivery Network (CDN)',
              'More database read replicas',
              'Load balancing',
            ],
            'correct': 1,
            'explanation':
                'CDN caches static content at edge locations worldwide. Users receive content from the nearest edge server.',
          },
          {
            'question': 'Auto Scaling\'s key benefit during off-peak hours?',
            'answers': [
              'Maintains maximum capacity for sudden spikes',
              'Removes excess compute resources to reduce cost when demand is low',
              'Automatically patches servers overnight',
              'Backs up data more frequently',
            ],
            'correct': 1,
            'explanation':
                'Auto Scaling scales DOWN when demand drops — removing idle resources and reducing costs. Bidirectional scaling is its core value.',
          },
          {
            'question':
                'Best storage type for sharing files between multiple VMs simultaneously?',
            'answers': [
              'Object storage',
              'Block storage',
              'File storage (NFS/SMB)',
              'Archive storage',
            ],
            'correct': 2,
            'explanation':
                'File storage (AWS EFS, Azure Files) = shared network file systems accessible by multiple instances simultaneously. Block storage = one instance at a time.',
          },
          {
            'question': 'What is a virtual machine in cloud?',
            'answers': [
              'A physical server rented from the provider',
              'A software-defined server running on shared physical hardware, providing isolated compute resources',
              'A container running in Kubernetes',
              'A serverless function',
            ],
            'correct': 1,
            'explanation':
                'VM = virtualised server on physical hardware managed by the provider. Has dedicated vCPUs, RAM, and disk — isolated from other VMs despite sharing physical resources.',
          },
          {
            'question':
                'An application has stable 100 req/s but spikes to 2,000 during flash sales. Ideal compute strategy?',
            'answers': [
              'Always provision for 2,000 req/s',
              'Always provision for 100 req/s and accept degraded performance',
              'Use Auto Scaling to handle baseline and scale automatically during spikes',
              'Use multiple cloud providers simultaneously',
            ],
            'correct': 2,
            'explanation':
                'Auto Scaling adds instances automatically during the sale and removes them after — you pay for peak capacity only when needed, not 24/7.',
          },
          {
            'question':
                'What distinguishes object storage from traditional file systems?',
            'answers': [
              'Object storage is faster for all workloads',
              'Object storage uses a flat namespace with unique IDs instead of folders, accessed via HTTP APIs',
              'Object storage can only store images',
              'Object storage requires more management',
            ],
            'correct': 1,
            'explanation':
                'Object storage: no folder hierarchy, each object has a unique key. Accessed via REST APIs (HTTP GET/PUT). Highly scalable and globally accessible.',
          },
          {
            'question': 'What is CDN edge caching?',
            'answers': [
              'Permanently storing content at the edge',
              'Serving cached content to nearby users until it expires, reducing requests to the origin server',
              'Encrypting content before delivery',
              'Deleting content after each request',
            ],
            'correct': 1,
            'explanation':
                'Edge servers cache content for a TTL period. Cached content served locally — only cache misses hit the origin. Reduces origin load and latency.',
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
      case 'module-01':
        return [
          {
            'question': 'What does the CIA Triad stand for?',
            'answers': [
              'Computing, Infrastructure, Availability',
              'Confidentiality, Integrity, Availability',
              'Cryptography, Identity, Authentication',
              'Compliance, Integrity, Assurance',
            ],
            'correct': 1,
            'explanation':
                'CIA = Confidentiality (data is private), Integrity (data is accurate and unmodified), Availability (data is accessible when needed). The three pillars of information security.',
          },
          {
            'question':
                'What is the difference between a threat and a vulnerability?',
            'answers': [
              'They are the same thing',
              'A threat is a weakness; a vulnerability is an attacker',
              'A threat is a potential cause of harm; a vulnerability is an exploitable weakness in a system',
              'A threat is always internal; a vulnerability is always external',
            ],
            'correct': 2,
            'explanation':
                'Threat = potential cause of harm (attacker, natural disaster). Vulnerability = a weakness that can be exploited (unpatched software, weak password). Risk = threat exploiting a vulnerability.',
          },
          {
            'question': 'What is defense in depth?',
            'answers': [
              'Using one very strong security control',
              'Hiring a large security team',
              'Using multiple layered security controls so if one fails others protect the system',
              'Keeping all data on an offline server',
            ],
            'correct': 2,
            'explanation':
                'Defense in depth uses multiple independent layers — network, host, application, data. If one layer fails, others remain. No single point of failure.',
          },
          {
            'question': 'What does the principle of least privilege mean?',
            'answers': [
              'Users should have the lowest possible salary',
              'Users should only have the minimum access they need to do their job — no more',
              'Admins should not have any restrictions',
              'All users should share the same account',
            ],
            'correct': 1,
            'explanation':
                'Least privilege limits blast radius of compromised accounts. A user needing only read access to S3 should never have delete or admin permissions.',
          },
          {
            'question': 'Which is an example of social engineering?',
            'answers': [
              'Exploiting a buffer overflow vulnerability',
              'Running a port scan on a target',
              'Calling an employee pretending to be IT support to get their password',
              'Intercepting network packets with Wireshark',
            ],
            'correct': 2,
            'explanation':
                'Social engineering manipulates people rather than technology. Impersonating IT support to extract a password bypasses technical defences entirely.',
          },
          {
            'question': 'What does "integrity" mean in the CIA Triad?',
            'answers': [
              'Data is available when needed',
              'Data is kept confidential from unauthorised parties',
              'Data is accurate, complete, and has not been unauthorisedly modified',
              'Data is encrypted in transit',
            ],
            'correct': 2,
            'explanation':
                'Integrity ensures data has not been tampered with. Hash functions (SHA-256) and digital signatures are common integrity controls.',
          },
          {
            'question':
                'Which type of control attempts to STOP a security incident before it occurs?',
            'answers': [
              'Detective control',
              'Corrective control',
              'Preventive control',
              'Compensating control',
            ],
            'correct': 2,
            'explanation':
                'Preventive controls block threats before they succeed — firewalls, access controls, encryption. Detective = identify incidents. Corrective = fix after the fact.',
          },
          {
            'question': 'What is non-repudiation?',
            'answers': [
              'Preventing unauthorised access to data',
              'Ensuring a sender cannot deny having sent a message — implemented via digital signatures',
              'Encrypting data so only the recipient can read it',
              'Verifying identity before granting access',
            ],
            'correct': 1,
            'explanation':
                'Non-repudiation ensures parties cannot deny their actions. Digital signatures provide non-repudiation for messages and transactions.',
          },
          {
            'question': 'How is risk calculated?',
            'answers': [
              'Risk = Threat × Vulnerability × Impact',
              'Risk = Likelihood × Impact',
              'Risk = Vulnerability × Asset Value',
              'Risk = Threat × Asset Value',
            ],
            'correct': 1,
            'explanation':
                'Risk = Likelihood (probability of exploit) × Impact (business damage). High-likelihood + high-impact = Priority 1 risk.',
          },
          {
            'question': 'What is a zero-day vulnerability?',
            'answers': [
              'A vulnerability that has been patched but not deployed',
              'A vulnerability disclosed publicly but not yet exploited',
              'A vulnerability unknown to the vendor with no available patch',
              'A vulnerability affecting only zero-trust environments',
            ],
            'correct': 2,
            'explanation':
                'Zero-day = unknown to the vendor — there are zero days between discovery and exploitation risk. No patch is available, making it especially dangerous.',
          },
        ];

      case 'module-02':
        return [
          {
            'question': 'Primary function of a firewall?',
            'answers': [
              'Speed up network traffic',
              'Monitor and control network traffic based on predefined security rules',
              'Store backup copies of data',
              'Assign IP addresses to devices',
            ],
            'correct': 1,
            'explanation':
                'A firewall monitors and controls incoming and outgoing network traffic based on security rules — either permitting or blocking based on defined criteria.',
          },
          {
            'question': 'What does an IPS do that an IDS does not?',
            'answers': [
              'Detects suspicious traffic',
              'Generates alerts for suspicious activity',
              'Automatically blocks malicious traffic in real time',
              'Logs network events',
            ],
            'correct': 2,
            'explanation':
                'IDS detects and alerts. IPS goes further — automatically blocking the malicious traffic without requiring human action.',
          },
          {
            'question': 'What is a VPN primarily used for?',
            'answers': [
              'Speeding up internet connection',
              'Creating an encrypted tunnel to secure data in transit over untrusted networks',
              'Blocking ads on websites',
              'Storing passwords securely',
            ],
            'correct': 1,
            'explanation':
                'VPN creates an encrypted tunnel between a device and a remote endpoint, securing data in transit — commonly used for remote access and site-to-site connectivity.',
          },
          {
            'question': 'What makes HTTPS more secure than HTTP?',
            'answers': [
              'HTTPS loads pages faster',
              'HTTPS uses a different port number',
              'HTTPS uses TLS encryption to protect data in transit from eavesdropping and tampering',
              'HTTPS blocks all cookies',
            ],
            'correct': 2,
            'explanation':
                'HTTPS uses TLS, preventing eavesdropping and man-in-the-middle attacks. HTTP transmits data in plaintext — readable by anyone intercepting the traffic.',
          },
          {
            'question': 'What is the goal of network segmentation?',
            'answers': [
              'Increase internet speed',
              'Reduce the number of devices on a network',
              'Limit the spread of attacks and control which systems can communicate with each other',
              'Replace firewalls entirely',
            ],
            'correct': 2,
            'explanation':
                'Network segmentation divides the network into zones — if an attacker compromises one segment, they cannot freely access others. Contains blast radius.',
          },
          {
            'question': 'Difference between stateful and stateless firewall?',
            'answers': [
              'Stateful firewalls are faster',
              'Stateless firewalls track connections; stateful ones do not',
              'Stateful firewalls track TCP connection state and make context-aware decisions; stateless inspect each packet independently',
              'Stateless firewalls are more secure',
            ],
            'correct': 2,
            'explanation':
                'Stateful firewalls track connection state — allowing return traffic automatically. Stateless require explicit rules for both directions of traffic.',
          },
          {
            'question': 'What is a DMZ in network security?',
            'answers': [
              'A geographic region excluded from cloud coverage',
              'An isolated network segment between internet and internal network where publicly accessible services are placed',
              'A type of VPN configuration',
              'A firewall rule set for outbound traffic',
            ],
            'correct': 1,
            'explanation':
                'DMZ hosts publicly accessible services in an isolated zone. Compromise of a DMZ host does not directly expose the internal network.',
          },
          {
            'question': 'What is a honeypot?',
            'answers': [
              'A type of encrypted password storage',
              'A decoy system designed to attract and detect attackers, gathering intelligence about their techniques',
              'A backup server for production systems',
              'A security patch management tool',
            ],
            'correct': 1,
            'explanation':
                'A honeypot mimics a real system to lure attackers. Any interaction triggers alerts and reveals attacker techniques, tools, and intentions.',
          },
          {
            'question': 'What does port scanning discover?',
            'answers': [
              'Scanning physical ports on networking hardware',
              'Which network ports and services are open on a target system — mapping the attack surface',
              'Monitoring bandwidth usage per port',
              'Filtering traffic by destination port',
            ],
            'correct': 1,
            'explanation':
                'Port scanning (Nmap) maps open ports and services. Essential for both attackers (discovery) and defenders (attack surface management). Open unused ports should be closed.',
          },
          {
            'question': 'What does VPC Flow Logs capture?',
            'answers': [
              'Application-level HTTP requests',
              'IP traffic metadata (source, destination, port, protocol, bytes) flowing through VPC network interfaces',
              'User login and authentication events',
              'Database query logs',
            ],
            'correct': 1,
            'explanation':
                'VPC Flow Logs record network traffic metadata. Essential for security investigations, anomaly detection, and compliance — who connected to what, when, and how much data moved.',
          },
        ];

      case 'module-03':
        return [
          {
            'question':
                'Which type of encryption uses the same key to encrypt and decrypt?',
            'answers': [
              'Asymmetric encryption',
              'Symmetric encryption',
              'Hashing',
              'Public Key Infrastructure',
            ],
            'correct': 1,
            'explanation':
                'Symmetric encryption uses one shared key for both encryption and decryption. AES-256 is the industry standard. Fast — used for bulk data encryption.',
          },
          {
            'question':
                'What makes hash functions useful for integrity verification?',
            'answers': [
              'They are reversible — you can recover the original data',
              'They produce a fixed-length output; any change to input produces a completely different hash',
              'They use two keys for extra security',
              'They encrypt data for secure storage',
            ],
            'correct': 1,
            'explanation':
                'Hash functions are one-way (cannot reverse). Any change to input — even one bit — produces a completely different hash. Used to verify files haven\'t been tampered with.',
          },
          {
            'question': 'What is the role of a Certificate Authority (CA)?',
            'answers': [
              'Store encryption keys for users',
              'Issue and verify digital certificates, creating a chain of trust for HTTPS and other secure communications',
              'Block malicious network traffic',
              'Generate one-time passwords',
            ],
            'correct': 1,
            'explanation':
                'CAs issue and sign digital certificates, establishing the chain of trust. Your browser trusts a website because a trusted CA signed its certificate.',
          },
          {
            'question': 'How does a digital signature work?',
            'answers': [
              'The sender encrypts with the receiver\'s public key',
              'The sender signs with their private key; anyone verifies with the sender\'s public key',
              'Both parties use the same secret key',
              'The message is hashed and stored in the cloud',
            ],
            'correct': 1,
            'explanation':
                'Digital signature: private key signs → public key verifies. Provides authentication (proves who signed), integrity (message not altered), and non-repudiation.',
          },
          {
            'question': 'What protocol does HTTPS use for encryption?',
            'answers': [
              'SSH',
              'IPSec',
              'TLS (Transport Layer Security)',
              'SFTP',
            ],
            'correct': 2,
            'explanation':
                'TLS (Transport Layer Security) is the cryptographic protocol powering HTTPS. It replaces the deprecated SSL protocol.',
          },
          {
            'question':
                'Difference between symmetric and asymmetric encryption?',
            'answers': [
              'Symmetric uses two keys; asymmetric uses one',
              'Symmetric uses one shared key (fast, for bulk data); asymmetric uses a key pair (slower, for key exchange and authentication)',
              'Asymmetric is older and less secure',
              'Symmetric cannot be used for data at rest',
            ],
            'correct': 1,
            'explanation':
                'TLS combines both: asymmetric to exchange a symmetric session key, then symmetric for bulk data transfer — security of asymmetric with speed of symmetric.',
          },
          {
            'question': 'What is end-to-end encryption (E2EE)?',
            'answers': [
              'Encryption applied only at the server end',
              'Encryption where only the communicating parties can read messages — no intermediary can decrypt',
              'Encrypting data from database to API',
              'Full disk encryption on endpoint devices',
            ],
            'correct': 1,
            'explanation':
                'E2EE ensures only sender and recipient hold decryption keys. WhatsApp and Signal use E2EE — even the service provider cannot read messages.',
          },
          {
            'question': 'What is a rainbow table attack?',
            'answers': [
              'A network flood attack using colourful packets',
              'A precomputed table of hash values used to reverse hash functions and crack passwords',
              'An attack targeting multi-coloured CAPTCHA systems',
              'A social engineering attack using visual deception',
            ],
            'correct': 1,
            'explanation':
                'Rainbow tables contain precomputed hash → password mappings. Salt (random data added before hashing) defeats rainbow tables because every hash is unique.',
          },
          {
            'question': 'What is the purpose of salting passwords?',
            'answers': [
              'Adding special characters to improve password requirements',
              'Adding a unique random value to each password before hashing — making rainbow table attacks and identical password detection impossible',
              'Encrypting passwords before storing them',
              'Requiring passwords to contain symbols',
            ],
            'correct': 1,
            'explanation':
                'Salt ensures two users with the same password have different hashes — rainbow tables are defeated. Even identical passwords produce unique stored hashes.',
          },
          {
            'question': 'What is key management and why is it critical?',
            'answers': [
              'Managing API keys for cloud services',
              'The secure generation, storage, rotation, and revocation of cryptographic keys — poor key management undermines even the strongest encryption',
              'Managing physical server keys in data centres',
              'Managing user login credentials',
            ],
            'correct': 1,
            'explanation':
                'Strong encryption with poor key management is useless. If an attacker gets the key, they can decrypt everything. KMS provides centralised, audited, hardware-backed key management.',
          },
        ];

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

  // ═══════════════════════════════════════════════════════════════════════════
  // Networking fallback
  // ═══════════════════════════════════════════════════════════════════════════
  List<Map<String, dynamic>> _networkingFallback() {
    return [
      {
        'question': 'What does DNS stand for?',
        'answers': [
          'Data Network System',
          'Domain Name System',
          'Digital Network Service',
          'Direct Name Server',
        ],
        'correct': 1,
        'explanation':
            'DNS = Domain Name System. Translates human-readable domain names (google.com) to IP addresses computers use to route traffic.',
      },
      {
        'question': 'What is an IP address?',
        'answers': [
          'A password for accessing networks',
          'A unique numerical label identifying each device on a network',
          'A type of network cable',
          'An internet browser plugin',
        ],
        'correct': 1,
        'explanation':
            'An IP address uniquely identifies a device on a network. IPv4 addresses are 32-bit (e.g. 192.168.1.1); IPv6 addresses are 128-bit.',
      },
      {
        'question': 'What does TCP stand for?',
        'answers': [
          'Transfer Control Protocol',
          'Transmission Control Protocol',
          'Technical Computing Process',
          'Terminal Connection Point',
        ],
        'correct': 1,
        'explanation':
            'TCP = Transmission Control Protocol. Provides reliable, ordered, error-checked delivery of data between applications.',
      },
      {
        'question': 'What is a router?',
        'answers': [
          'A type of computer terminal',
          'A device that forwards data packets between networks based on IP addresses',
          'A wireless keyboard transmitter',
          'A network storage device',
        ],
        'correct': 1,
        'explanation':
            'A router forwards data packets between networks using routing tables. Your home router connects your local network to the internet.',
      },
      {
        'question': 'What is a subnet?',
        'answers': [
          'A type of internet browser',
          'A logical subdivision of an IP network enabling organised, secure network segments',
          'A wireless signal type',
          'A server hardware type',
        ],
        'correct': 1,
        'explanation':
            'A subnet is a logical subdivision of an IP network. Subnetting organises large networks, improves performance, and enables security isolation between network segments.',
      },
    ];
  }
}
