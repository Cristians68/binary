import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_screen.dart';

class LessonScreen extends StatefulWidget {
  final String moduleTitle;
  final String courseTag;
  final Color color;
  final String moduleId;
  final String courseId;

  const LessonScreen({
    super.key,
    required this.moduleTitle,
    required this.courseTag,
    required this.color,
    required this.moduleId,
    required this.courseId,
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int _currentCard = 0;
  bool _loading = true;
  List<Map<String, String>> _flashcards = [];

  @override
  void initState() {
    super.initState();
    _loadFlashcards();
  }

  Future<void> _loadFlashcards() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('modules')
          .doc(widget.moduleId)
          .collection('flashcards')
          .orderBy('order')
          .get();

      final cards = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'term': (data['question'] ?? '').toString(),
          'definition': (data['answer'] ?? '').toString(),
          'label': 'Flashcard',
          'example': (data['example'] ?? '').toString(),
        };
      }).toList();

      // Fall back to hardcoded if Firestore has no flashcards
      if (mounted) {
        setState(() {
          _flashcards = cards.isNotEmpty
              ? cards
              : _getHardcodedFlashcards(widget.courseTag);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _flashcards = _getHardcodedFlashcards(widget.courseTag);
          _loading = false;
        });
      }
    }
  }

  void _next() {
    if (_currentCard < _flashcards.length - 1) {
      HapticFeedback.selectionClick();
      setState(() => _currentCard++);
    } else {
      HapticFeedback.mediumImpact();
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => QuizScreen(
            moduleTitle: widget.moduleTitle,
            courseTag: widget.courseTag,
            color: widget.color,
            moduleId: widget.moduleId,
            courseId: widget.courseId,
          ),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  void _prev() {
    if (_currentCard > 0) {
      HapticFeedback.selectionClick();
      setState(() => _currentCard--);
    }
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

    final card = _flashcards[_currentCard];

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
                            'Back',
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
                    '${_currentCard + 1} / ${_flashcards.length}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentCard + 1) / _flashcards.length,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(widget.color),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 14),
              // Course tag
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
              // Flashcard
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: animation, curve: Curves.easeOut)),
                      child:
                          FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_currentCard),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: widget.color.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: widget.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              card['label']!,
                              style: TextStyle(
                                fontSize: 11,
                                color: widget.color,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            card['term']!,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.3,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Divider(
                              color: Colors.white.withOpacity(0.08)),
                          const SizedBox(height: 16),
                          Text(
                            card['definition']!,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withOpacity(0.75),
                              height: 1.6,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const Spacer(),
                          if (card['example'] != null &&
                              card['example']!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color:
                                        Colors.white.withOpacity(0.07)),
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    CupertinoIcons.lightbulb_fill,
                                    size: 14,
                                    color: const Color(0xFFF59E0B),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      card['example']!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white
                                            .withOpacity(0.55),
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Navigation buttons
              Row(
                children: [
                  if (_currentCard > 0) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: _prev,
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Text(
                            '← Previous',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _next,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: widget.color,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _currentCard < _flashcards.length - 1
                              ? 'Next →'
                              : 'Start quiz →',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, String>> _getHardcodedFlashcards(String tag) {
    if (tag == 'ITIL V4') {
      return [
        {'label': 'Definition', 'term': 'What is ITIL V4?', 'definition': 'ITIL V4 is a framework of best practices for IT Service Management (ITSM). It provides guidance on how to design, deliver, and improve IT services that align with business needs.', 'example': 'A company uses ITIL to make sure their helpdesk, software updates, and server maintenance all follow consistent, repeatable processes.'},
        {'label': 'Core concept', 'term': 'Service Value System (SVS)', 'definition': 'The SVS describes how all the components and activities of an organization work together to create value. It includes the guiding principles, governance, service value chain, practices, and continual improvement.', 'example': 'Think of the SVS as the engine of ITIL — it shows how everything connects to deliver value to customers.'},
        {'label': 'Core concept', 'term': 'The 4 Dimensions of Service Management', 'definition': 'ITIL V4 defines 4 dimensions: 1) Organizations & People, 2) Information & Technology, 3) Partners & Suppliers, 4) Value Streams & Processes.', 'example': 'When launching a new IT service, you must think about who will run it, what tech is needed, which vendors help, and how the workflow works.'},
        {'label': 'Guiding principle', 'term': 'Focus on Value', 'definition': 'Everything the organization does should link back to delivering value for itself, its customers, and other stakeholders.', 'example': 'Before building a new IT tool, ask: does this solve a real problem for the user?'},
        {'label': 'Guiding principle', 'term': 'Start Where You Are', 'definition': 'Do not start from scratch if you do not have to. Assess what already exists and build on current services, processes, and tools.', 'example': 'Instead of replacing an entire system, evaluate what works and improve it step by step.'},
      ];
    } else if (tag == 'CSM') {
      return [
        {'label': 'Definition', 'term': 'What is Scrum?', 'definition': 'Scrum is an agile framework for developing, delivering, and sustaining complex products. It uses short cycles called Sprints to deliver work in small, usable increments.', 'example': 'A software team works in 2-week sprints, releasing a working feature at the end of each sprint.'},
        {'label': 'Core role', 'term': 'Scrum Master', 'definition': 'The Scrum Master is a servant-leader who helps the team follow Scrum practices. They remove obstacles, facilitate events, and protect the team from interruptions.', 'example': 'If the team is blocked waiting on approval, the Scrum Master steps in to resolve it.'},
        {'label': 'Core role', 'term': 'Product Owner', 'definition': 'The Product Owner is responsible for maximizing the value of the product. They manage and prioritize the Product Backlog.', 'example': 'The Product Owner decides that fixing a login bug is more important than adding a new feature this sprint.'},
        {'label': 'Event', 'term': 'Sprint', 'definition': 'A Sprint is a time-boxed period of one month or less during which a Done, usable, and potentially releasable product increment is created.', 'example': 'Each sprint starts with planning and ends with a review and retrospective.'},
        {'label': 'Artifact', 'term': 'Product Backlog', 'definition': 'An ordered list of everything that might be needed in the product. It is the single source of requirements for any changes.', 'example': 'Items include features, bug fixes, and technical improvements, ranked by priority.'},
      ];
    } else {
      return [
        {'label': 'Definition', 'term': 'What is a Network?', 'definition': 'A network is a collection of computers, servers, and other devices connected together to share resources and communicate.', 'example': 'Your home WiFi connects your phone, laptop, and TV — that is a local area network (LAN).'},
        {'label': 'Core concept', 'term': 'IP Address', 'definition': 'An IP address is a unique numerical label assigned to each device connected to a network. It identifies the device and its location.', 'example': 'Your computer IP might be 192.168.1.5 on your home network.'},
        {'label': 'Core concept', 'term': 'DNS', 'definition': 'DNS translates human-readable domain names like google.com into IP addresses that computers use to identify each other.', 'example': 'When you type google.com, DNS translates it to an IP like 142.250.80.46.'},
        {'label': 'Core concept', 'term': 'TCP/IP', 'definition': 'TCP/IP is the foundational communication protocol of the internet. TCP handles data packaging and delivery confirmation, while IP handles addressing and routing.', 'example': 'When you send an email, TCP breaks it into packets, IP routes them, and TCP confirms they all arrived.'},
        {'label': 'Key term', 'term': 'Router', 'definition': 'A router forwards data packets between networks. It directs internet traffic and connects your local network to the internet.', 'example': 'The box your ISP gave you is a router — it connects your home devices to the internet.'},
      ];
    }
  }
}