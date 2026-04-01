import 'package:flutter/material.dart';
import 'quiz_screen.dart';

class LessonScreen extends StatefulWidget {
  final String moduleTitle;
  final String courseTag;
  final Color color;

  const LessonScreen({super.key, required this.moduleTitle, required this.courseTag, required this.color});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int currentCard = 0;

  List<Map<String, String>> get flashcards => _getFlashcards(widget.courseTag);

  void _next() {
    if (currentCard < flashcards.length - 1) {
      setState(() => currentCard++);
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => QuizScreen(
            moduleTitle: widget.moduleTitle,
            courseTag: widget.courseTag,
            color: widget.color,
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
    if (currentCard > 0) setState(() => currentCard--);
  }

  @override
  Widget build(BuildContext context) {
    final card = flashcards[currentCard];
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
                      Text('Back', style: TextStyle(fontSize: 13, color: widget.color)),
                    ]),
                  ),
                  Text('${currentCard + 1} / ${flashcards.length}',
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4))),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (currentCard + 1) / flashcards.length,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${widget.courseTag} · ${widget.moduleTitle}',
                    style: TextStyle(fontSize: 11, color: widget.color)),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(currentCard),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: widget.color.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: widget.color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(card['label']!, style: TextStyle(fontSize: 11, color: widget.color, fontWeight: FontWeight.w500)),
                          ),
                          const SizedBox(height: 20),
                          Text(card['term']!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3)),
                          const SizedBox(height: 16),
                          Divider(color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 16),
                          Text(card['definition']!, style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.75), height: 1.6)),
                          const Spacer(),
                          if (card['example'] != null && card['example']!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('💡', style: TextStyle(fontSize: 14)),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(card['example']!, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.55), height: 1.5))),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (currentCard > 0) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: _prev,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Text('← Previous', textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: Colors.white)),
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: widget.color,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          currentCard < flashcards.length - 1 ? 'Next →' : 'Start quiz 🎯',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
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

  List<Map<String, String>> _getFlashcards(String tag) {
    if (tag == 'ITIL V4') {
      return [
        {'label': 'Definition', 'term': 'What is ITIL V4?', 'definition': 'ITIL V4 is a framework of best practices for IT Service Management (ITSM). It provides guidance on how to design, deliver, and improve IT services that align with business needs.', 'example': 'Example: A company uses ITIL to make sure their helpdesk, software updates, and server maintenance all follow consistent, repeatable processes.'},
        {'label': 'Core concept', 'term': 'Service Value System (SVS)', 'definition': 'The SVS describes how all the components and activities of an organization work together to create value. It includes the guiding principles, governance, service value chain, practices, and continual improvement.', 'example': 'Think of the SVS as the engine of ITIL — it shows how everything connects to deliver value to customers.'},
        {'label': 'Core concept', 'term': 'The 4 Dimensions of Service Management', 'definition': 'ITIL V4 defines 4 dimensions that must all be considered when designing services: 1) Organizations & People, 2) Information & Technology, 3) Partners & Suppliers, 4) Value Streams & Processes.', 'example': 'Example: When launching a new IT service, you must think about who will run it, what tech is needed, which vendors help, and how the workflow works.'},
        {'label': 'Guiding principle', 'term': 'Focus on Value', 'definition': 'Everything the organization does should link back to delivering value for itself, its customers, and other stakeholders. Always ask: "How does this create value?"', 'example': 'Before building a new IT tool, ask: does this solve a real problem for the user? If not, reconsider.'},
        {'label': 'Guiding principle', 'term': 'Start Where You Are', 'definition': 'Do not start from scratch if you do not have to. Assess what already exists and build on current services, processes, and tools that can be reused.', 'example': 'Instead of replacing an entire system, evaluate what works and improve it step by step.'},
        {'label': 'Guiding principle', 'term': 'Progress Iteratively with Feedback', 'definition': 'Organize work into smaller, manageable sections that can be executed and completed in a timely manner. Use feedback to improve each iteration.', 'example': 'Like Agile — release in small steps, gather user feedback, then improve and release again.'},
        {'label': 'Key term', 'term': 'Service', 'definition': 'A means of enabling value co-creation by facilitating outcomes that customers want to achieve, without the customer having to manage specific costs and risks.', 'example': 'Example: A cloud storage service lets a company store data without managing physical servers themselves.'},
        {'label': 'Key term', 'term': 'Value Co-creation', 'definition': 'In ITIL V4, value is not just delivered by the provider — it is created together with the customer. Both parties play a role in achieving the desired outcome.', 'example': 'A help desk only creates value when users actively engage with it and report issues clearly.'},
      ];
    } else if (tag == 'CSM') {
      return [
        {'label': 'Definition', 'term': 'What is Scrum?', 'definition': 'Scrum is an agile framework for developing, delivering, and sustaining complex products. It uses short cycles called Sprints to deliver work in small, usable increments.', 'example': 'Example: A software team works in 2-week sprints, releasing a working feature at the end of each sprint.'},
        {'label': 'Core role', 'term': 'Scrum Master', 'definition': 'The Scrum Master is a servant-leader who helps the team follow Scrum practices. They remove obstacles, facilitate events, and protect the team from interruptions.', 'example': 'If the team is blocked waiting on approval from another department, the Scrum Master steps in to resolve it.'},
        {'label': 'Core role', 'term': 'Product Owner', 'definition': 'The Product Owner is responsible for maximizing the value of the product. They manage and prioritize the Product Backlog — the list of all work to be done.', 'example': 'The Product Owner decides that fixing a login bug is more important than adding a new feature this sprint.'},
        {'label': 'Core role', 'term': 'Development Team', 'definition': 'The self-organizing, cross-functional group of professionals who do the actual work of delivering a potentially releasable product increment each Sprint.', 'example': 'The dev team includes developers, testers, and designers who all work together without being told exactly what to do.'},
        {'label': 'Event', 'term': 'Sprint', 'definition': 'A Sprint is a time-boxed period of one month or less during which a Done, usable, and potentially releasable product increment is created.', 'example': 'Each sprint starts with planning and ends with a review and retrospective.'},
        {'label': 'Artifact', 'term': 'Product Backlog', 'definition': 'An ordered list of everything that might be needed in the product. It is the single source of requirements for any changes to be made to the product.', 'example': 'Items on the Product Backlog include features, bug fixes, and technical improvements, ranked by priority.'},
      ];
    } else {
      return [
        {'label': 'Definition', 'term': 'What is a Network?', 'definition': 'A network is a collection of computers, servers, and other devices connected together to share resources and communicate with each other.', 'example': 'Your home WiFi connects your phone, laptop, and TV — that is a local area network (LAN).'},
        {'label': 'Core concept', 'term': 'IP Address', 'definition': 'An IP (Internet Protocol) address is a unique numerical label assigned to each device connected to a network. It identifies the device and its location on the network.', 'example': 'Your computer IP address might be 192.168.1.5 on your home network.'},
        {'label': 'Core concept', 'term': 'DNS — Domain Name System', 'definition': 'DNS translates human-readable domain names like google.com into IP addresses that computers use to identify each other on the network.', 'example': 'When you type google.com, DNS translates it to an IP like 142.250.80.46 so your browser can connect.'},
        {'label': 'Core concept', 'term': 'TCP/IP', 'definition': 'TCP/IP is the foundational communication protocol of the internet. TCP handles data packaging and delivery confirmation, while IP handles addressing and routing.', 'example': 'When you send an email, TCP breaks it into packets, IP routes them, and TCP confirms they all arrived.'},
        {'label': 'Key term', 'term': 'Router', 'definition': 'A router is a networking device that forwards data packets between computer networks. It directs internet traffic and connects your local network to the internet.', 'example': 'The black box your ISP gave you is a router — it connects your home devices to the internet.'},
        {'label': 'Key term', 'term': 'Subnet', 'definition': 'A subnet is a logical subdivision of an IP network. Subnetting allows a network to be divided into smaller, more manageable pieces.', 'example': 'A company might use subnets to separate the HR department network from the Engineering network.'},
      ];
    }
  }
}