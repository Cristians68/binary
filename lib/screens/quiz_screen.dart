import 'package:flutter/material.dart';

class QuizScreen extends StatefulWidget {
  final String moduleTitle;
  final String courseTag;
  final Color color;

  const QuizScreen({super.key, required this.moduleTitle, required this.courseTag, required this.color});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int currentQuestion = 0;
  int? selectedAnswer;
  bool answered = false;
  int score = 0;

  final List<Map<String, dynamic>> questions = [
    {
      'question': 'What does the Service Value System (SVS) describe in ITIL V4?',
      'answers': ['How components work together to create value', 'A list of IT tools and software', 'The billing process for IT services', 'Network security protocols'],
      'correct': 0,
    },
    {
      'question': 'Which of the following is one of the 4 dimensions of service management?',
      'answers': ['Hardware and software only', 'Organizations and people', 'Financial budgeting', 'Customer complaints'],
      'correct': 1,
    },
    {
      'question': 'What is the main purpose of ITIL V4?',
      'answers': ['To replace all IT staff with automation', 'To provide guidance for IT service management', 'To define programming languages', 'To manage company finances'],
      'correct': 1,
    },
    {
      'question': 'Which ITIL guiding principle says to start with what you have?',
      'answers': ['Think and work holistically', 'Keep it simple and practical', 'Start where you are', 'Progress iteratively'],
      'correct': 2,
    },
    {
      'question': 'What does "value co-creation" mean in ITIL V4?',
      'answers': ['Only the provider creates value', 'Value is created together by provider and customer', 'Value is measured in money only', 'IT creates value without input from users'],
      'correct': 1,
    },
  ];

  void _selectAnswer(int index) {
    if (answered) return;
    setState(() {
      selectedAnswer = index;
      answered = true;
      if (index == questions[currentQuestion]['correct']) score++;
    });
  }

  void _nextQuestion() {
    if (currentQuestion < questions.length - 1) {
      setState(() {
        currentQuestion++;
        selectedAnswer = null;
        answered = false;
      });
    } else {
      _showResults();
    }
  }

  void _showResults() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF13131A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(score >= 4 ? '🎉' : '📚', style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(score >= 4 ? 'Great job!' : 'Keep studying!',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              Text('You scored $score out of ${questions.length}',
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5))),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(14)),
                  child: const Text('Back to course', textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
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
    final q = questions[currentQuestion];
    final correct = q['correct'] as int;

    return Scaffold(
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
                    onTap: () => Navigator.pop(context),
                    child: Row(children: [
                      Icon(Icons.arrow_back_ios, size: 14, color: widget.color),
                      Text('Lesson', style: TextStyle(fontSize: 13, color: widget.color)),
                    ]),
                  ),
                  Text('Question ${currentQuestion + 1} of ${questions.length}',
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4))),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (currentQuestion + 1) / questions.length,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                  minHeight: 3,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${widget.courseTag} · ${widget.moduleTitle}',
                    style: TextStyle(fontSize: 11, color: widget.color)),
              ),
              const SizedBox(height: 16),
              Text(q['question'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white, height: 1.5)),
              const SizedBox(height: 24),
              ...List.generate(
                (q['answers'] as List).length,
                (i) {
                  Color borderColor = Colors.white.withOpacity(0.1);
                  Color bgColor = Colors.white.withOpacity(0.04);
                  Color textColor = Colors.white.withOpacity(0.7);

                  if (answered) {
                    if (i == correct) {
                      borderColor = const Color(0xFF10B981).withOpacity(0.5);
                      bgColor = const Color(0xFF10B981).withOpacity(0.15);
                      textColor = const Color(0xFF10B981);
                    } else if (i == selectedAnswer && i != correct) {
                      borderColor = const Color(0xFFEF4444).withOpacity(0.5);
                      bgColor = const Color(0xFFEF4444).withOpacity(0.15);
                      textColor = const Color(0xFFEF4444);
                    }
                  } else if (selectedAnswer == i) {
                    borderColor = widget.color.withOpacity(0.5);
                    bgColor = widget.color.withOpacity(0.15);
                    textColor = widget.color;
                  }

                  return GestureDetector(
                    onTap: () => _selectAnswer(i),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(q['answers'][i], style: TextStyle(fontSize: 13, color: textColor)),
                    ),
                  );
                },
              ),
              const Spacer(),
              if (answered)
                GestureDetector(
                  onTap: _nextQuestion,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(16)),
                    child: Text(
                      currentQuestion < questions.length - 1 ? 'Next question →' : 'See results 🎉',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}