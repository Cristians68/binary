import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
          _questions = questions.isNotEmpty
              ? questions
              : _getHardcodedQuestions(widget.courseTag);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _questions = _getHardcodedQuestions(widget.courseTag);
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
    final percent = (_score / _questions.length * 100).toInt();
    final passed = _score >= (_questions.length * 0.6).ceil();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF13131A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
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
                      ? const Color(0xFF10B981).withOpacity(0.15)
                      : const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  passed
                      ? CupertinoIcons.checkmark_seal_fill
                      : CupertinoIcons.book_fill,
                  color: passed
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                passed ? 'Great work!' : 'Keep studying!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You scored $_score out of ${_questions.length}',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: passed
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  Navigator.pop(context);
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
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(
                    'Try again',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
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
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: Center(
          child: CircularProgressIndicator(
            color: widget.color,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: Center(
          child: Text(
            'No questions found.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    final q = _questions[_currentQuestion];
    final correct = q['correct'] as int;
    final answers = q['answers'] as List<String>;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: widget.color.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_ios_new_rounded,
                              size: 13, color: widget.color),
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
                      color: Colors.white.withOpacity(0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Progress
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentQuestion + 1) / _questions.length,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(widget.color),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 14),
              // Tag
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: widget.color.withOpacity(0.2)),
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
              // Question
              Text(
                q['question'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.4,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 24),
              // Answers
              ...List.generate(answers.length, (i) {
                Color borderColor = Colors.white.withOpacity(0.08);
                Color bgColor = Colors.white.withOpacity(0.03);
                Color textColor = Colors.white.withOpacity(0.7);
                Widget? trailingIcon;

                if (_answered) {
                  if (i == correct) {
                    borderColor =
                        const Color(0xFF10B981).withOpacity(0.5);
                    bgColor =
                        const Color(0xFF10B981).withOpacity(0.12);
                    textColor = const Color(0xFF10B981);
                    trailingIcon = const Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        color: Color(0xFF10B981),
                        size: 18);
                  } else if (i == _selectedAnswer && i != correct) {
                    borderColor =
                        const Color(0xFFEF4444).withOpacity(0.5);
                    bgColor =
                        const Color(0xFFEF4444).withOpacity(0.12);
                    textColor = const Color(0xFFEF4444);
                    trailingIcon = const Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: Color(0xFFEF4444),
                        size: 18);
                  }
                } else if (_selectedAnswer == i) {
                  borderColor = widget.color.withOpacity(0.5);
                  bgColor = widget.color.withOpacity(0.12);
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
              // Explanation
              if (_answered &&
                  q['explanation'] != null &&
                  (q['explanation'] as String).isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(CupertinoIcons.lightbulb_fill,
                          size: 14,
                          color: const Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          q['explanation'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.5),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              // Next button
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

  List<Map<String, dynamic>> _getHardcodedQuestions(String tag) {
    if (tag == 'ITIL V4') {
      return [
        {'question': 'What does the Service Value System describe?', 'answers': ['How components work together to create value', 'A list of IT tools', 'The billing process', 'Network protocols'], 'correct': 0, 'explanation': 'The SVS shows how all components and activities work together to enable value creation.'},
        {'question': 'Which is one of the 4 dimensions of service management?', 'answers': ['Hardware only', 'Organizations and people', 'Financial budgeting', 'Customer complaints'], 'correct': 1, 'explanation': 'The 4 dimensions are: Organizations & People, Information & Technology, Partners & Suppliers, Value Streams & Processes.'},
        {'question': 'What is the main purpose of ITIL V4?', 'answers': ['Replace IT staff', 'Provide IT service management guidance', 'Define programming languages', 'Manage company finances'], 'correct': 1, 'explanation': 'ITIL V4 provides guidance for IT service management best practices.'},
        {'question': 'Which guiding principle says to start with what you have?', 'answers': ['Think holistically', 'Keep it simple', 'Start where you are', 'Progress iteratively'], 'correct': 2, 'explanation': 'Start where you are means assessing what exists before building anything new.'},
        {'question': 'What does value co-creation mean?', 'answers': ['Only the provider creates value', 'Value is created together by provider and customer', 'Value is measured in money', 'IT creates value alone'], 'correct': 1, 'explanation': 'In ITIL V4, value is co-created between the service provider and the customer.'},
      ];
    } else if (tag == 'CSM') {
      return [
        {'question': 'What is a Sprint in Scrum?', 'answers': ['A long-term project plan', 'A time-boxed development cycle', 'A type of meeting', 'A backlog item'], 'correct': 1, 'explanation': 'A Sprint is a time-boxed period (usually 1-4 weeks) where a usable increment is created.'},
        {'question': 'Who prioritizes the Product Backlog?', 'answers': ['Scrum Master', 'Development Team', 'Product Owner', 'Stakeholders'], 'correct': 2, 'explanation': 'The Product Owner is responsible for managing and prioritizing the Product Backlog.'},
        {'question': 'What is the Scrum Master\'s role?', 'answers': ['Write all the code', 'Manage the budget', 'Facilitate Scrum and remove blockers', 'Define product features'], 'correct': 2, 'explanation': 'The Scrum Master is a servant-leader who facilitates Scrum and removes impediments.'},
        {'question': 'How long is a Sprint typically?', 'answers': ['6 months', '1 year', '1-4 weeks', '1 day'], 'correct': 2, 'explanation': 'Sprints are time-boxed to one month or less, typically 1-4 weeks.'},
        {'question': 'What is the Product Backlog?', 'answers': ['A bug tracking system', 'An ordered list of work for the product', 'A meeting agenda', 'A test plan'], 'correct': 1, 'explanation': 'The Product Backlog is an ordered list of everything needed in the product.'},
      ];
    } else {
      return [
        {'question': 'What does DNS stand for?', 'answers': ['Data Network System', 'Domain Name System', 'Digital Network Service', 'Direct Name Server'], 'correct': 1, 'explanation': 'DNS stands for Domain Name System — it translates domain names to IP addresses.'},
        {'question': 'What is an IP address?', 'answers': ['A password for networks', 'A unique numerical label for devices', 'A type of cable', 'An internet browser'], 'correct': 1, 'explanation': 'An IP address uniquely identifies a device on a network.'},
        {'question': 'What does TCP stand for?', 'answers': ['Transfer Control Protocol', 'Transmission Control Protocol', 'Technical Computing Process', 'Terminal Connection Point'], 'correct': 1, 'explanation': 'TCP stands for Transmission Control Protocol.'},
        {'question': 'What is a router?', 'answers': ['A type of computer', 'A device that forwards data between networks', 'A wireless keyboard', 'A storage device'], 'correct': 1, 'explanation': 'A router forwards data packets between networks and connects devices to the internet.'},
        {'question': 'What is a subnet?', 'answers': ['A type of internet browser', 'A logical subdivision of an IP network', 'A wireless signal', 'A server type'], 'correct': 1, 'explanation': 'A subnet is a logical subdivision of an IP network, used to organize and secure networks.'},
      ];
    }
  }
}