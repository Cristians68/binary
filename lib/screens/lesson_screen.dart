import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_screen.dart';
import 'app_router.dart';
import 'app_theme.dart';

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

      if (mounted) {
        setState(() {
          _flashcards = cards.isNotEmpty
              ? cards
              : _getHardcodedFlashcards(widget.courseTag, widget.moduleId);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _flashcards = _getHardcodedFlashcards(
            widget.courseTag,
            widget.moduleId,
          );
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
        AppRouter.push(
          QuizScreen(
            moduleTitle: widget.moduleTitle,
            courseTag: widget.courseTag,
            color: widget.color,
            moduleId: widget.moduleId,
            courseId: widget.courseId,
          ),
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
    final theme = AppTheme.of(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.bg,
        body: Center(
          child: CircularProgressIndicator(color: widget.color, strokeWidth: 2),
        ),
      );
    }

    final card = _flashcards[_currentCard];

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
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
                            size: 12,
                            color: widget.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Back',
                            style: TextStyle(
                              fontSize: 13,
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
                      color: theme.subtext,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // ── Progress bar ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentCard + 1) / _flashcards.length,
                  backgroundColor: theme.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.lightBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                  minHeight: 4,
                ),
              ),
            ),

            // ── Tag pill ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.18),
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
            ),

            const SizedBox(height: 14),

            // ── Scrollable card content ───────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    ),
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0.03, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_currentCard),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Main card ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.isDark
                                ? widget.color.withValues(alpha: 0.07)
                                : widget.color.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.isDark
                                  ? widget.color.withValues(alpha: 0.18)
                                  : widget.color.withValues(alpha: 0.25),
                            ),
                            boxShadow: theme.isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.color.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  card['label']!.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: widget.color,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                card['term']!,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: theme.text,
                                  height: 1.3,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Divider(
                                color: theme.isDark
                                    ? Colors.white.withValues(alpha: 0.07)
                                    : AppColors.lightBorder,
                                height: 1,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                card['definition']!,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: theme.isDark
                                      ? Colors.white.withValues(alpha: 0.80)
                                      : AppColors.lightSubtext,
                                  height: 1.65,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Example box ──
                        if (card['example'] != null &&
                            card['example']!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.surface,
                              borderRadius: BorderRadius.circular(16),
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
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    card['example']!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.subtext,
                                      height: 1.55,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Navigation buttons ───────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  if (_currentCard > 0) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: _prev,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: theme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: theme.border),
                          ),
                          child: Text(
                            '← Prev',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.text,
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: widget.color,
                          borderRadius: BorderRadius.circular(14),
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
            ),
          ],
        ),
      ),
    );
  }

  // ── Hardcoded flashcards — keyed by courseTag + moduleId ──────────────────
  List<Map<String, String>> _getHardcodedFlashcards(
    String tag,
    String moduleId,
  ) {
    // ── ITIL V4 ────────────────────────────────────────────────────────────
    if (tag == 'ITIL V4') {
      switch (moduleId) {
        // ── Module 01: IT Service Management & the ITIL Framework ──────────
        case 'module-01':
          return [
            {
              'label': 'Foundation',
              'term': 'What is IT Service Management (ITSM)?',
              'definition':
                  'ITSM is a set of organisational capabilities, policies, and processes for planning, delivering, managing, and improving IT services to meet business and customer needs. It focuses on value creation — not just technical operations.',
              'example':
                  'Exam trap: ITSM is NOT the same as IT operations. ITSM includes strategy, design, and continual improvement — not just keeping systems running. Expect scenario questions where a team "keeps the lights on" but has no ITSM — the answer is that value and alignment to business are missing.',
            },
            {
              'label': 'Foundation',
              'term': 'What is a Service?',
              'definition':
                  'A service is a means of enabling value co-creation by facilitating outcomes that customers want to achieve, without the customer having to manage specific costs and risks. Key phrase: "co-creation" — value is not delivered TO the customer, it is created WITH them.',
              'example':
                  'Exam trap: Do not say a service "delivers value." The correct ITIL V4 language is that a service "facilitates value co-creation." If the exam uses "delivers," that answer is likely wrong.',
            },
            {
              'label': 'Core concept',
              'term': 'Value, Outcomes, Costs, and Risks (VOCR)',
              'definition':
                  'ITIL V4 defines value in terms of four elements: Outcomes (results the customer wants), Costs (financial resources consumed), Risks (uncertainty about outcomes), and Value itself (the perceived benefits relative to costs and risks). A service must improve outcomes while managing costs and risks on behalf of the customer.',
              'example':
                  'Scenario: A customer uses a cloud storage service. Outcome = files accessible anywhere. Cost = monthly fee (transferred from customer managing own servers). Risk = data breach risk (partially transferred to provider). The service creates value by improving outcomes and absorbing costs/risks.',
            },
            {
              'label': 'Core concept',
              'term': 'Utility and Warranty',
              'definition':
                  'Utility is "fit for purpose" — the service does what the customer needs (functionality). Warranty is "fit for use" — the service is available, reliable, secure, and has sufficient capacity. BOTH must be present for a service to create value. A service with utility but no warranty is unreliable. A service with warranty but no utility is useless.',
              'example':
                  'Exam trap: A new payroll system calculates salaries correctly (utility ✓) but crashes every Friday (warranty ✗). The service has utility but fails warranty — it does NOT create value. Watch for scenarios where one is missing — the answer always requires BOTH.',
            },
            {
              'label': 'Core concept',
              'term': 'Service Provider, Consumer, and Stakeholder',
              'definition':
                  'Service Provider: the organisation delivering the service. Service Consumer roles split into three: Customer (defines requirements and owns outcomes), User (interacts with the service directly), Sponsor (authorises budget). One person can hold multiple roles. Stakeholders include anyone with an interest in the service.',
              'example':
                  'Scenario: A CTO approves budget for a new HR system (Sponsor). The HR manager specifies what the system must do (Customer). HR staff use it daily (Users). Exam trap: the CTO is NOT the customer — the HR manager owns the outcome requirements.',
            },
            {
              'label': 'Core concept',
              'term': 'Products vs Services',
              'definition':
                  'A product is a configuration of an organisation\'s resources designed to offer value to a consumer. A service is built on top of products. Products are owned by the provider; the customer accesses the service but does not manage the underlying product resources.',
              'example':
                  'A cloud provider\'s product is their server infrastructure and software stack. The service is the compute instance you rent. You get the outcome (processing power) without managing the physical servers (product).',
            },
            {
              'label': 'History',
              'term': 'Evolution from ITIL v3 to ITIL V4',
              'definition':
                  'ITIL v3 organised guidance around a Service Lifecycle (Strategy → Design → Transition → Operation → Continual Service Improvement). ITIL V4 replaces this with the Service Value System (SVS) and Service Value Chain, integrating modern practices like Agile, DevOps, and Lean. The 26 processes of v3 became 34 practices in V4.',
              'example':
                  'Exam trap: ITIL V4 does NOT use the word "processes" for its core guidance — it uses "practices." However, practices still contain processes within them. Do not confuse the two on exam questions.',
            },
            {
              'label': 'Framework',
              'term': 'What ITIL V4 Is — and Is NOT',
              'definition':
                  'ITIL V4 is a framework of guidance and best practices — it is NOT a standard (like ISO 20000), NOT a methodology (like PRINCE2), and NOT prescriptive. Organisations adopt what is relevant to their context. The phrase "adopt and adapt" is central to ITIL V4.',
              'example':
                  'Exam trap: If a question asks "what must an organisation do to comply with ITIL V4?" — the answer is that there is no mandatory compliance. ITIL is guidance. ISO/IEC 20000 is the certifiable standard. Know the difference.',
            },
            {
              'label': 'Acronym drill',
              'term': 'Key ITIL V4 Acronyms You Must Know',
              'definition':
                  'SVS = Service Value System. SVC = Service Value Chain. CSI = Continual Service Improvement (v3 term; V4 uses "Continual Improvement"). SLA = Service Level Agreement. OLA = Operational Level Agreement. UC = Underpinning Contract. KPI = Key Performance Indicator. CSF = Critical Success Factor.',
              'example':
                  'Exam trap: ITIL V4 replaces "Continual Service Improvement" with simply "Continual Improvement" — because improvement applies to all SVS components, not just services. If an exam option says "Continual Service Improvement" in a V4 context, be cautious.',
            },
            {
              'label': 'Scenario',
              'term': 'Why Organisations Adopt ITIL V4',
              'definition':
                  'Organisations adopt ITIL V4 to: align IT with business strategy, improve service quality and consistency, reduce costs through process efficiency, manage risk more effectively, support digital transformation, and provide a common language across IT and business teams.',
              'example':
                  'Scenario: A company\'s IT team is reactive — fixing problems as they occur with no standard process. After ITIL adoption, incidents are categorised, prioritised, and resolved consistently. Customer satisfaction scores rise. This is the classic "why ITIL" exam scenario.',
            },
            {
              'label': 'Core concept',
              'term': 'Service Relationships',
              'definition':
                  'A service relationship exists when two organisations cooperate to co-create value. It includes: Service Provision (activities performed to deliver a service), Service Consumption (activities performed to consume a service), and Service Relationship Management (joint activities ensuring ongoing value co-creation).',
              'example':
                  'A managed IT provider (provider) and a law firm (consumer) have a service relationship. The provider provisions infrastructure; the firm\'s IT staff manage software (consumption). Both collaborate on SLAs (relationship management).',
            },
            {
              'label': 'Misconception',
              'term': 'Common Misconception: ITIL V4 Replaces Agile/DevOps',
              'definition':
                  'ITIL V4 does NOT replace Agile, DevOps, or Lean — it integrates with them. ITIL V4 was redesigned specifically to complement these modern approaches. The SVS is intentionally flexible to allow organisations using Scrum, Kanban, or DevOps pipelines to align with ITIL without conflict.',
              'example':
                  'Exam trap: If a question implies ITIL V4 conflicts with DevOps or Agile, the answer is that they are complementary. ITIL V4 provides governance and structure; Agile/DevOps provides delivery speed and flexibility.',
            },
            {
              'label': 'Foundation',
              'term': 'What is Value — and Who Defines It?',
              'definition':
                  'In ITIL V4, value is subjective and defined by the stakeholder, not the service provider. Value is the perceived benefits, usefulness, and importance of a service — and that perception belongs to the customer. Two customers using the same service may perceive different levels of value.',
              'example':
                  'Exam trap: The provider does not determine value — the consumer does. If an exam question asks who defines whether a service is valuable, the answer is the customer/consumer, not the IT team or provider.',
            },
            {
              'label': 'Scenario',
              'term': 'Internal vs External Service Providers',
              'definition':
                  'An internal service provider delivers services within the same organisation (e.g. an IT department serving business units). An external service provider delivers services to other organisations (e.g. a managed service provider). ITIL applies to both — the concepts of utility, warranty, and value co-creation are identical.',
              'example':
                  'Scenario: A company\'s internal IT team manages email for staff. They are an internal service provider. If the company outsources email to Google Workspace, Google becomes an external service provider. Both must demonstrate utility and warranty.',
            },
            {
              'label': 'Exam prep',
              'term': 'Module 1 — Top 5 Exam Traps',
              'definition':
                  '1) "Value is delivered to customers" is WRONG — value is CO-CREATED. 2) ITIL V4 uses "practices" not "processes." 3) Warranty AND utility are both required for value. 4) The customer defines requirements; the sponsor controls budget — they may be different people. 5) ITIL is guidance, not a mandatory standard.',
              'example':
                  'Use this card as a rapid-fire review before your exam. These five traps appear in multiple-choice questions more than almost any other concepts in Module 1.',
            },
            {
              'label': 'Foundation',
              'term': 'The Role of Automation in ITIL V4',
              'definition':
                  'ITIL V4 recognises automation as a key enabler of service management. Automation supports practices such as Incident Management (auto-routing), Change Enablement (automated testing), and Monitoring (AI-driven alerting). Automation does not replace ITIL practices — it executes them faster and more consistently.',
              'example':
                  'An automated incident management tool detects a server outage, logs an incident record, assigns it to the on-call engineer, and notifies the customer — all within seconds. The ITIL practice is unchanged; automation improves its speed and consistency.',
            },
          ];

        // ── Module 02: The Service Value System (SVS) ──────────────────────
        case 'module-02':
          return [
            {
              'label': 'SVS Overview',
              'term': 'What is the Service Value System (SVS)?',
              'definition':
                  'The SVS describes how all components and activities of an organisation work together to enable value creation through IT-enabled services. The SVS has five components: Guiding Principles, Governance, Service Value Chain (SVC), Practices, and Continual Improvement.',
              'example':
                  'Exam trap: The SVS has FIVE components — not four, not six. Memorise: Guiding Principles + Governance + Service Value Chain + Practices + Continual Improvement. Any exam answer missing one of these is wrong.',
            },
            {
              'label': 'SVS Component',
              'term': 'SVS Inputs and Outputs',
              'definition':
                  'The SVS takes Opportunity (possibilities to add value or improve) and Demand (need or desire for services from customers) as inputs. The output is Value — for the organisation, its customers, and other stakeholders. Without demand or opportunity, the SVS has nothing to process.',
              'example':
                  'Scenario: A business identifies a customer need for 24/7 IT support (Demand) and a new monitoring tool becomes available (Opportunity). The SVS processes both and delivers improved uptime and customer satisfaction (Value).',
            },
            {
              'label': 'SVS Component',
              'term': 'Governance in the SVS',
              'definition':
                  'Governance is the means by which an organisation is directed and controlled. In the SVS, governance ensures that activities align with organisational objectives. Governance evaluates, directs, and monitors all SVS components. It sits at the top of the SVS, overseeing everything else.',
              'example':
                  'Exam trap: Governance is NOT the same as management. Governance sets direction and oversight; management executes. The board or senior leadership governs; IT management manages. If a question mentions "setting direction and ensuring accountability," the answer is Governance.',
            },
            {
              'label': 'SVS Component',
              'term': 'Continual Improvement in the SVS',
              'definition':
                  'Continual Improvement is a recurring organisational activity that applies to all SVS components — not just services. It uses the seven-step Continual Improvement Model to identify improvement opportunities, assess current state, define targets, implement changes, and measure outcomes.',
              'example':
                  'Exam trap: In ITIL V4, Continual Improvement applies to EVERYTHING — practices, the value chain, governance, and the guiding principles themselves — not just IT services. If an exam question limits CI to services only, that answer is incomplete.',
            },
            {
              'label': 'SVS Component',
              'term': 'Organisational Agility and the SVS',
              'definition':
                  'The SVS is designed to prevent "organisational silos" — isolated teams that optimise their own work at the expense of overall value. The SVS promotes visibility, collaboration, and end-to-end thinking so that all teams contribute to the same value stream.',
              'example':
                  'Scenario: The development team ships code fast (high agility) but the operations team takes weeks to deploy it (silo). The SVS — specifically the Service Value Chain — removes this bottleneck by connecting development and operations through shared activities.',
            },
            {
              'label': 'SVS Component',
              'term': 'The Seven Guiding Principles — Overview',
              'definition':
                  'The seven guiding principles are universal recommendations that guide organisations in all circumstances. They are: 1) Focus on Value, 2) Start Where You Are, 3) Progress Iteratively with Feedback, 4) Collaborate and Promote Visibility, 5) Think and Work Holistically, 6) Keep It Simple and Practical, 7) Optimise and Automate.',
              'example':
                  'Exam trap: There are EXACTLY seven guiding principles. No more, no less. They apply to EVERY initiative — not just ITIL implementations. If an exam option lists eight principles or omits one, it is wrong. Memorise all seven by their exact names.',
            },
            {
              'label': 'Guiding Principle',
              'term': 'Principle 1 — Focus on Value',
              'definition':
                  'Everything the organisation does must link, directly or indirectly, to value for itself, its customers, and other stakeholders. This means understanding who the consumer is, what they value, and how the service contributes — before performing any activity.',
              'example':
                  'Scenario: An IT team spends two months building a reporting dashboard. Before starting, they should ask: who uses this? What decision does it enable? If no one consults the output, it creates no value — Focus on Value principle violated.',
            },
            {
              'label': 'Guiding Principle',
              'term': 'Principle 2 — Start Where You Are',
              'definition':
                  'Do not start from scratch when existing services, processes, or capabilities can be built upon. Assess what already works, preserve what is valuable, and improve incrementally rather than replacing everything. Measurement of the current state must be objective — not based on assumption.',
              'example':
                  'Exam trap: "Start Where You Are" does NOT mean "keep everything as-is." It means assess objectively, preserve what works, improve what does not. Watch for scenarios where a new manager decides to rebuild all processes from scratch — this violates this principle.',
            },
            {
              'label': 'Guiding Principle',
              'term': 'Principle 3 — Progress Iteratively with Feedback',
              'definition':
                  'Work in smaller, manageable increments rather than large waterfall projects. Use feedback loops at each step to evaluate whether the direction is correct before committing further resources. This integrates naturally with Agile and Scrum delivery models.',
              'example':
                  'Scenario: Instead of deploying a complete new ITSM platform in one go, the team deploys incident management first, collects user feedback for four weeks, adjusts, then deploys change management. This iterative approach reduces risk and improves fit.',
            },
            {
              'label': 'Guiding Principle',
              'term': 'Principle 4 — Collaborate and Promote Visibility',
              'definition':
                  'Work together across boundaries — with customers, suppliers, and internal teams. Make work and decisions visible to all relevant stakeholders. Hidden agendas, siloed information, and lack of transparency undermine trust and the ability to improve.',
              'example':
                  'Exam trap: Collaboration is NOT just about teamwork — it explicitly includes customers and external partners. If an exam scenario shows an IT team solving problems without involving the business or customers, Collaborate and Promote Visibility is the violated principle.',
            },
            {
              'label': 'Guiding Principle',
              'term': 'Principle 5 — Think and Work Holistically',
              'definition':
                  'No service, practice, or component works in isolation. Understand how all parts of the SVS interconnect. Changes to one area can impact others. Decisions should consider the end-to-end value stream, not just a single team or process.',
              'example':
                  'Scenario: The security team implements strict access controls (good for security) but users can no longer reset passwords without a 48-hour wait (bad for availability). Thinking holistically would have caught this conflict during design.',
            },
            {
              'label': 'Guiding Principle',
              'term': 'Principle 6 — Keep It Simple and Practical',
              'definition':
                  'Use the minimum number of steps, processes, and metrics needed to achieve the objective. Eliminate waste — anything that does not contribute to value creation. If a process step cannot be justified with a clear value contribution, remove it.',
              'example':
                  'Exam trap: This principle is NOT about being lazy or cutting corners. It is about eliminating bureaucratic overhead that adds no value. A 40-step change approval process for replacing a keyboard violates this principle.',
            },
            {
              'label': 'Guiding Principle',
              'term': 'Principle 7 — Optimise and Automate',
              'definition':
                  'Optimise means maximise the value of work. Automate means use technology to perform repetitive, low-complexity tasks. The correct sequence is: optimise first (eliminate waste, simplify), THEN automate. Automating a broken process makes it fail faster and at greater scale.',
              'example':
                  'Exam trap: You must OPTIMISE before you AUTOMATE. If a question describes automating a flawed process, the correct ITIL answer is to optimise (fix) the process first, then automate. Automating waste is explicitly called out as a common mistake in ITIL V4 guidance.',
            },
            {
              'label': 'Application',
              'term': 'How Guiding Principles Work Together',
              'definition':
                  'The seven guiding principles are not applied in isolation or in a fixed sequence. Multiple principles often apply simultaneously to a single decision. They are also not prescriptive rules — they are guidance that must be interpreted in context. An organisation may prioritise different principles for different initiatives.',
              'example':
                  'Scenario: Deploying a new self-service portal. Focus on Value (what do users need?), Start Where You Are (existing portal?), Progress Iteratively (phased rollout), Collaborate (involve users in design), Think Holistically (impact on helpdesk volume), Keep It Simple (minimal clicks), Optimise and Automate (auto-resolve common requests).',
            },
            {
              'label': 'Exam prep',
              'term': 'Module 2 — Top Exam Traps on the SVS',
              'definition':
                  '1) SVS has FIVE components — not the value chain alone. 2) Continual Improvement applies to ALL SVS components — not just services. 3) Optimise BEFORE automating — always. 4) Governance directs and monitors — it is not management. 5) Guiding principles apply universally — not only to ITIL implementations.',
              'example':
                  'Rapid-fire check: Can you name all five SVS components without looking? Can you list all seven principles in order? If not, re-read this module before sitting the exam.',
            },
            {
              'label': 'Scenario',
              'term': 'SVS in Practice — Scenario Walkthrough',
              'definition':
                  'A retailer wants to improve its online order tracking service. Demand = customer complaints about tracking. Opportunity = new API from logistics partner. The SVS processes this via the SVC (Plan → Improve → Engage → Design & Transition → Obtain/Build → Deliver & Support). Practices like Incident Management, Change Enablement, and Release Management execute the work. Governance approves the change. Continual Improvement measures outcomes post-launch.',
              'example':
                  'This scenario spans ALL five SVS components simultaneously. Exam questions often describe a business scenario and ask which SVS component is primarily responsible for a specific aspect — know which component owns what.',
            },
          ];

        // ── Module 03: The Service Value Chain (SVC) ───────────────────────
        case 'module-03':
          return [
            {
              'label': 'SVC Overview',
              'term': 'What is the Service Value Chain (SVC)?',
              'definition':
                  'The Service Value Chain is the operating model at the heart of the SVS. It defines six interconnected activities that combine to convert demand and opportunities into value. The activities are: Plan, Improve, Engage, Design & Transition, Obtain/Build, and Deliver & Support. They are not a linear sequence — they can be combined in any order to form value streams.',
              'example':
                  'Exam trap: The SVC is NOT a lifecycle (unlike ITIL v3). It is a flexible model where activities combine in different ways for different scenarios. There is no fixed order. If a question implies a fixed sequence, that is an ITIL v3 concept, not V4.',
            },
            {
              'label': 'SVC Activity',
              'term': 'Plan',
              'definition':
                  'Plan ensures a shared understanding of vision, current status, and improvement direction across all four dimensions and all products and services. It produces policies, portfolios, architectures, and plans. Plan feeds into ALL other SVC activities.',
              'example':
                  'Scenario: The organisation defines its three-year IT strategy and service portfolio. This output (plans, policies, architectures) is consumed by all other SVC activities — Design & Transition uses architecture plans; Improve uses the improvement roadmap. Missing the Plan activity leads to uncoordinated execution.',
            },
            {
              'label': 'SVC Activity',
              'term': 'Improve',
              'definition':
                  'Improve ensures continual improvement of products, services, and practices across all SVC activities and all four dimensions. It is present in every value stream — not just at the end. It consumes performance data and improvement initiatives and produces improvement plans and implemented improvements.',
              'example':
                  'Exam trap: Improve is NOT only at the end of a process — it operates continuously throughout. If an exam option implies improvement only happens after delivery is complete, that is wrong. Every SVC activity feeds back into Improve.',
            },
            {
              'label': 'SVC Activity',
              'term': 'Engage',
              'definition':
                  'Engage provides a good understanding of stakeholder needs and ensures transparency and continual engagement with customers, users, and other stakeholders. It converts demand into requirements and manages ongoing relationships. It is the primary point of contact between the organisation and its customers.',
              'example':
                  'Scenario: A key customer reports that the service is not meeting their expectations. Engage is the SVC activity responsible — it captures the feedback, translates it into requirements, and feeds it into Plan, Improve, and Design & Transition. Failing to Engage causes services to drift from customer needs.',
            },
            {
              'label': 'SVC Activity',
              'term': 'Design & Transition',
              'definition':
                  'Design & Transition ensures services and products continually meet stakeholder expectations for quality, cost, and time-to-market. It covers the design of new or changed services and their transition into live operation. It consumes requirements from Engage and plans from Plan.',
              'example':
                  'Exam trap: Design & Transition is a SINGLE combined activity in V4 — not separate phases as in v3. The merger reflects the reality that design and transition work is iterative and overlapping, especially in Agile and DevOps environments.',
            },
            {
              'label': 'SVC Activity',
              'term': 'Obtain/Build',
              'definition':
                  'Obtain/Build ensures that service components are available when and where needed and that they meet agreed specifications. It covers acquiring components from external suppliers (Obtain) and developing or configuring them internally (Build). It feeds service components to Design & Transition and Deliver & Support.',
              'example':
                  'Scenario: The team needs a new monitoring tool. If bought from a vendor, that is Obtain. If built in-house, that is Build. The result — a working monitoring capability — flows into Deliver & Support to be used in live operations. Both routes share this one SVC activity.',
            },
            {
              'label': 'SVC Activity',
              'term': 'Deliver & Support',
              'definition':
                  'Deliver & Support ensures services are delivered and supported according to agreed specifications and stakeholder expectations. It covers day-to-day delivery, incident resolution, request fulfilment, and user support. It is where most operational ITIL practices execute.',
              'example':
                  'Exam trap: Deliver & Support is NOT the only activity that touches the customer — Engage handles ongoing relationship management. Deliver & Support focuses on operational execution: keeping services running and resolving issues as they occur.',
            },
            {
              'label': 'Core concept',
              'term': 'Value Streams',
              'definition':
                  'A value stream is a specific combination of SVC activities designed to create a particular product or respond to a particular demand. Each value stream is a sequence (or network) of steps selected from the six SVC activities. Organisations design multiple value streams for different scenarios.',
              'example':
                  'Example value stream — User Incident Resolution: Engage (user contacts helpdesk) → Deliver & Support (incident triaged and resolved) → Improve (resolution time recorded for trend analysis). A different value stream for new service deployment would use Design & Transition and Obtain/Build instead.',
            },
            {
              'label': 'Core concept',
              'term': 'SVC vs Service Lifecycle (v3)',
              'definition':
                  'ITIL v3 used a linear lifecycle: Strategy → Design → Transition → Operation → CSI. ITIL V4 replaces this with the flexible SVC where activities are recombined as needed. The SVC avoids the bottlenecks of sequential lifecycle stages and supports iterative, agile delivery models.',
              'example':
                  'Exam trap: If a question references "Service Strategy" or "Service Operation" as ITIL V4 phases, those are v3 concepts. In V4, the equivalent work happens within SVC activities — Plan (strategy), Design & Transition (design/transition), Deliver & Support (operations).',
            },
            {
              'label': 'Core concept',
              'term': 'Practices in the SVC',
              'definition':
                  'ITIL V4 practices are the tools used to execute SVC activities. A single practice (e.g. Change Enablement) may support multiple SVC activities. Conversely, a single SVC activity (e.g. Deliver & Support) draws on multiple practices (Incident Management, Service Desk, Monitoring).',
              'example':
                  'Scenario: The Change Enablement practice contributes to Plan (policy), Improve (CI input), Design & Transition (change authority), Deliver & Support (emergency changes). Understanding which practices support which SVC activities is a common exam question type.',
            },
            {
              'label': 'Scenario',
              'term': 'SVC Walkthrough — New Service Deployment',
              'definition':
                  'Demand: Business requests a new mobile app for field engineers. Value stream: Plan (architecture, budget) → Engage (capture requirements from engineers) → Design & Transition (design app, plan release) → Obtain/Build (develop app, procure MDM tool) → Deliver & Support (deploy app, support users) → Improve (monitor adoption, iterate features).',
              'example':
                  'Notice that Improve is present even after deployment — not just at the end. Notice that Plan informed the whole stream from the start. This is how V4 SVC differs from v3 lifecycle: all activities are continuously available, not locked in sequence.',
            },
            {
              'label': 'Scenario',
              'term': 'SVC Walkthrough — Incident Response',
              'definition':
                  'Demand: User reports email not working. Value stream: Engage (user contacts service desk) → Deliver & Support (incident logged, triaged, resolved) → Improve (incident data fed back for problem identification). Plan and Obtain/Build are not needed for a standard incident — value streams are minimal when appropriate.',
              'example':
                  'Exam trap: Not every SVC activity appears in every value stream. For routine incidents, only Engage, Deliver & Support, and Improve are typically used. Using all six activities for every request would violate "Keep It Simple and Practical."',
            },
            {
              'label': 'Exam prep',
              'term': 'Module 3 — SVC Exam Traps',
              'definition':
                  '1) SVC has SIX activities — not five, not seven. 2) There is NO fixed order — it is flexible. 3) Design & Transition is ONE activity in V4. 4) Improve runs throughout — not only at the end. 5) Value streams are combinations of SVC activities — not the activities themselves. 6) "Plan" feeds ALL other activities.',
              'example':
                  'The most common exam question type for the SVC is: "An organisation is doing X — which SVC activity is primarily responsible?" Map the scenario to the correct activity using the definitions on this card.',
            },
            {
              'label': 'Application',
              'term': 'How the SVC Supports Agile and DevOps',
              'definition':
                  'The SVC\'s non-linear, flexible structure directly mirrors how Agile sprints and DevOps pipelines work. Design & Transition can occur in short iterations. Obtain/Build aligns with sprint delivery. Deliver & Support aligns with continuous deployment. ITIL V4\'s SVC was redesigned specifically to stop conflicting with Agile and DevOps workflows.',
              'example':
                  'A DevOps team runs two-week sprints. Each sprint maps to: Engage (backlog grooming with stakeholders), Design & Transition (sprint planning and design), Obtain/Build (sprint development), Deliver & Support (deployment and monitoring). No conflict — SVC and DevOps are aligned.',
            },
            {
              'label': 'Foundation',
              'term': 'Information Flows in the SVC',
              'definition':
                  'Each SVC activity both produces and consumes information. For example: Plan produces policies (consumed by all activities). Engage produces requirements (consumed by Design & Transition). Deliver & Support produces performance data (consumed by Improve). Understanding these flows is essential for value stream design.',
              'example':
                  'Exam scenario: "The service desk is resolving incidents but improvement trends are not being identified." This means performance data from Deliver & Support is NOT flowing into Improve. The information flow between these two SVC activities is broken.',
            },
          ];

        // ── Module 04: The Four Dimensions of Service Management ───────────
        case 'module-04':
          return [
            {
              'label': 'Four Dimensions',
              'term': 'What Are the Four Dimensions?',
              'definition':
                  'ITIL V4 defines four dimensions that must be considered for every service and every SVS component: 1) Organisations & People, 2) Information & Technology, 3) Partners & Suppliers, 4) Value Streams & Processes. Each dimension is essential — neglecting any one leads to service failure.',
              'example':
                  'Exam trap: There are EXACTLY four dimensions. They apply to ALL services and ALL components of the SVS — not just new services. Memorise the four names and their order. Any exam option with five dimensions or a different name is wrong.',
            },
            {
              'label': 'Dimension 1',
              'term': 'Organisations & People',
              'definition':
                  'This dimension covers the structure, roles, responsibilities, culture, and capabilities of people involved in service management. It includes: organisational structures, staffing, skills, communication, and culture. Without the right people and culture, even perfect processes will fail.',
              'example':
                  'Scenario: A company implements ITIL but the service desk staff have no training and the management culture discourages reporting incidents. The Organisations & People dimension is the failure point — the process exists but people cannot or will not execute it.',
            },
            {
              'label': 'Dimension 1',
              'term': 'Organisational Culture in ITIL V4',
              'definition':
                  'Culture — the shared values, norms, and behaviours of an organisation — is explicitly part of the Organisations & People dimension. ITIL V4 recognises that culture can either enable or block effective service management. A blame culture, for example, will suppress incident reporting and prevent learning.',
              'example':
                  'Exam trap: Culture is NOT a soft add-on in ITIL V4 — it is a formal component of a defined dimension. If a question asks which dimension covers leadership style, management philosophy, or employee behaviour, the answer is Organisations & People.',
            },
            {
              'label': 'Dimension 2',
              'term': 'Information & Technology',
              'definition':
                  'This dimension covers the information and knowledge managed by services, and the technologies used to do so. It includes: information architecture, data management, tools, platforms, AI, automation, and knowledge management. Both the information itself AND the technology that stores/processes it are in scope.',
              'example':
                  'Scenario: A service desk uses a CMDB (Configuration Management Database) to track assets and an ITSM platform to manage tickets. Both the data (configuration records) and the tool (ITSM platform) fall under the Information & Technology dimension.',
            },
            {
              'label': 'Dimension 2',
              'term': 'Technology Considerations in ITIL V4',
              'definition':
                  'ITIL V4 highlights several technology considerations relevant to service management: AI and machine learning for automation, cloud platforms for flexibility, mobile solutions for accessibility, and integration between tools. The choice of technology must support — not constrain — the service management approach.',
              'example':
                  'Exam trap: Technology choices must align with the organisation\'s overall service strategy — not the other way around. If a scenario shows an organisation changing its processes to fit a tool they purchased, the Information & Technology dimension is being mismanaged.',
            },
            {
              'label': 'Dimension 3',
              'term': 'Partners & Suppliers',
              'definition':
                  'This dimension covers the organisation\'s relationships with other organisations involved in the design, development, deployment, delivery, support, and continual improvement of services. It includes outsourced providers, cloud vendors, contractors, and technology suppliers.',
              'example':
                  'Scenario: A company uses AWS for hosting, a third-party NOC for monitoring, and a software vendor for its ITSM tool. All three are Partners & Suppliers. Their contracts, SLAs, and performance directly affect the quality of services delivered to end customers.',
            },
            {
              'label': 'Dimension 3',
              'term': 'Service Integration and Management (SIAM)',
              'definition':
                  'SIAM is an approach to managing multiple suppliers delivering services to a single customer. It is directly associated with the Partners & Suppliers dimension. SIAM coordinates between suppliers, manages interfaces and contracts, and ensures end-to-end service quality when no single supplier owns the full value chain.',
              'example':
                  'Exam trap: SIAM is explicitly linked to the Partners & Suppliers dimension. If an exam question describes an organisation with multiple IT suppliers and asks which dimension is most relevant, the answer is Partners & Suppliers, and the management approach is SIAM.',
            },
            {
              'label': 'Dimension 4',
              'term': 'Value Streams & Processes',
              'definition':
                  'This dimension covers how the organisation\'s activities are organised to create value. It includes value streams (end-to-end sequences of activities) and processes (sets of interrelated activities that transform inputs into outputs). It defines HOW work gets done — the "workflow" of service management.',
              'example':
                  'Scenario: The incident management process defines steps for logging, categorising, investigating, and resolving incidents. This process is part of the Value Streams & Processes dimension. The value stream shows how this process contributes to service restoration from the customer\'s perspective.',
            },
            {
              'label': 'Dimension 4',
              'term': 'Processes vs Value Streams',
              'definition':
                  'A process is a specific set of activities with defined inputs, outputs, triggers, and outcomes — focused internally on how work is done. A value stream is an end-to-end view of how activities combine to deliver value to the customer — focused externally on what the customer receives. Value streams contain processes.',
              'example':
                  'Exam trap: Processes and value streams are both in the same dimension (Value Streams & Processes) but are different concepts. Processes are internal; value streams are customer-facing. A single value stream may include multiple processes from multiple practices.',
            },
            {
              'label': 'External factors',
              'term': 'PESTLE Factors and the Four Dimensions',
              'definition':
                  'All four dimensions are subject to external constraints captured by the PESTLE framework: Political, Economic, Social, Technological, Legal, and Environmental factors. These external forces can influence any dimension — for example, new data protection laws (Legal/PESTLE) affect the Information & Technology dimension.',
              'example':
                  'GDPR (Legal) forces changes to the Information & Technology dimension — data must be encrypted, access-controlled, and auditable. A new regulation about supplier audits (Legal) affects the Partners & Suppliers dimension. PESTLE is the "outside world" wrapper around the four dimensions.',
            },
            {
              'label': 'Application',
              'term': 'Applying All Four Dimensions — Scenario',
              'definition':
                  'When designing or improving any service, all four dimensions must be considered: 1) Who will run it and do they have the skills? (Org & People) 2) What data and tools are required? (Info & Tech) 3) Which suppliers are involved? (Partners & Suppliers) 4) How will the work flow end-to-end? (Value Streams & Processes).',
              'example':
                  'New service: automated patch management. Org & People: who approves patches, who is on-call? Info & Tech: what patch management tool, what CMDB integration? Partners & Suppliers: does the OS vendor provide patch feeds? Value Streams & Processes: what is the end-to-end flow from patch release to deployment to verification?',
            },
            {
              'label': 'Misconception',
              'term': 'Common Misconception: Dimensions Are Separate Concerns',
              'definition':
                  'The four dimensions are interdependent — a decision in one dimension always affects the others. For example, choosing a new technology tool (Info & Tech) may require new skills (Org & People), new supplier contracts (Partners & Suppliers), and revised workflows (Value Streams & Processes). No dimension is isolated.',
              'example':
                  'Exam trap: If a question describes an improvement that only addresses one dimension while ignoring others, ITIL V4 would flag this as incomplete. The correct approach always considers all four dimensions holistically — this connects to the "Think and Work Holistically" guiding principle.',
            },
            {
              'label': 'Exam prep',
              'term': 'Module 4 — Four Dimensions Exam Traps',
              'definition':
                  '1) There are FOUR dimensions — know all four names exactly. 2) Culture belongs to Organisations & People — not a separate dimension. 3) SIAM belongs to Partners & Suppliers. 4) PESTLE is an EXTERNAL factor affecting all four dimensions — it is NOT a fifth dimension. 5) Value Streams & Processes contains BOTH value streams AND processes — not just processes.',
              'example':
                  'Quick test: Which dimension covers the CMDB? (Info & Tech). Which covers an outsourced NOC? (Partners & Suppliers). Which covers the incident management workflow? (Value Streams & Processes). Which covers the service desk team\'s skills? (Org & People).',
            },
            {
              'label': 'Acronym drill',
              'term': 'Four Dimensions Mnemonics',
              'definition':
                  'Memory aid: "I OWN a Valuable Place" — Information & Technology, Organisations & People, (partners &) suppliers With contracts, (value streams and) processes for Value. Or simply: O-I-P-V (Organisations, Information, Partners, Value Streams). Any mnemonic that helps you recall all four without missing one is valid.',
              'example':
                  'Exam format: Questions often describe a scenario and ask "which dimension is MOST relevant?" Match the scenario to the dimension: people/culture = O&P; tools/data = I&T; third parties/vendors = P&S; workflows/processes = VS&P.',
            },
            {
              'label': 'Foundation',
              'term': 'Why Four Dimensions? The Holistic View',
              'definition':
                  'ITIL V4 introduced the four dimensions to replace the concept of "people, process, and technology" (a three-factor model from earlier frameworks). By separating "Partners & Suppliers" as its own dimension and explicitly adding "Value Streams," ITIL V4 reflects the reality of modern IT — where outsourcing and end-to-end thinking are essential.',
              'example':
                  'The old model (people, process, technology) missed supplier management and end-to-end value flow. V4 corrected this by making both explicit dimensions. If an exam option says "three dimensions" or uses the old PPT framework, it is describing pre-V4 thinking.',
            },
          ];

        // ── Module 05: ITIL V4 Management Practices (Part 1) ───────────────
        case 'module-05':
          return [
            {
              'label': 'Practices Overview',
              'term': 'What Are ITIL V4 Practices?',
              'definition':
                  'A practice is a set of organisational resources designed for performing work or accomplishing an objective. ITIL V4 defines 34 practices across three categories: General Management Practices (14), Service Management Practices (17), and Technical Management Practices (3). Practices replace the "processes" of ITIL v3.',
              'example':
                  'Exam trap: ITIL V4 has 34 practices, not 26. The ITIL V4 Foundation exam tests 18 of the 34 in detail — but you must know how many total practices exist and the three categories. Do not confuse "practices" with "processes" — V4 uses practices.',
            },
            {
              'label': 'Practice',
              'term': 'Incident Management',
              'definition':
                  'Incident Management minimises the negative impact of incidents by restoring normal service operation as quickly as possible. An incident is an unplanned interruption or reduction in quality of an IT service. The goal is speed of restoration — not necessarily identifying root cause (that is Problem Management).',
              'example':
                  'Exam trap: Incident Management does NOT find root cause — it restores service. Root cause analysis is Problem Management. A question describing "investigating why a server crashed repeatedly" is Problem Management. "Getting the server back online" is Incident Management.',
            },
            {
              'label': 'Practice',
              'term': 'Incident Categorisation and Prioritisation',
              'definition':
                  'Incidents are categorised by type (hardware, software, network, etc.) and prioritised by Impact (breadth of effect on business) × Urgency (speed at which the business needs resolution). Priority = Impact × Urgency. High impact + high urgency = Priority 1.',
              'example':
                  'Scenario: Email is down for all 500 staff (high impact) during year-end close (high urgency) = Priority 1. One user cannot access a non-critical report (low impact, low urgency) = Priority 4. Knowing how to calculate priority from a scenario is a guaranteed exam question type.',
            },
            {
              'label': 'Practice',
              'term': 'Problem Management',
              'definition':
                  'Problem Management reduces the likelihood and impact of incidents by identifying root causes and managing known errors. Three phases: Problem Identification (find the problem), Problem Control (analyse and document workarounds), Error Control (manage known errors until permanent fix). A Problem is the cause of incidents; a Known Error is a problem with a documented workaround.',
              'example':
                  'Exam trap: A "Known Error" is NOT the same as a Problem. A Known Error has a diagnosed root cause and a documented workaround. A Problem may not yet have a known root cause. The KEDB (Known Error Database) stores Known Errors. This distinction is tested on the exam.',
            },
            {
              'label': 'Practice',
              'term': 'Change Enablement',
              'definition':
                  'Change Enablement maximises successful service and product changes by ensuring risks are assessed, changes are authorised, and the schedule is managed. Change types: Standard (pre-authorised, low risk), Normal (requires CAB or change authority approval), Emergency (expedited approval for urgent changes). A change is the addition, modification, or removal of anything that could affect services.',
              'example':
                  'Exam trap: The practice is called "Change Enablement" in V4 — NOT "Change Management" (the v3 name). The Change Advisory Board (CAB) still exists in V4 but is one possible change authority — not mandatory for all changes. Standard changes bypass the CAB entirely.',
            },
            {
              'label': 'Practice',
              'term': 'Change Types — Standard, Normal, Emergency',
              'definition':
                  'Standard Change: pre-authorised, low-risk, well-understood, routine (e.g. password reset). Does not require individual approval. Normal Change: requires assessment, approval via change authority, scheduled. Emergency Change: implemented urgently to resolve a critical incident or threat. Has expedited but still documented approval.',
              'example':
                  'Scenario: A network engineer needs to reboot a switch during a maintenance window (Standard). A team wants to deploy a new application (Normal). A zero-day exploit requires an emergency patch tonight (Emergency). Identifying the change type from a scenario description is a core exam skill.',
            },
            {
              'label': 'Practice',
              'term': 'Service Request Management',
              'definition':
                  'Service Request Management supports the agreed quality of a service by handling all pre-defined, user-initiated service requests. A service request is a formal request for something the user is entitled to — e.g. a new laptop, password reset, or software installation. It is NOT an incident (no failure) and NOT a change (no risk assessment required).',
              'example':
                  'Exam trap: Service requests are SEPARATE from incidents and changes. A user requesting a new monitor is a service request. A user reporting their monitor has stopped working is an incident. Confusing these two is the most common mistake on this topic.',
            },
            {
              'label': 'Practice',
              'term': 'Service Desk Practice',
              'definition':
                  'The Service Desk is the single point of contact (SPOC) between the service provider and its users. It handles incidents, service requests, and communication. Service desk types: Local (on-site), Centralised (one location for all users), Virtual (distributed but unified by technology), Follow-the-Sun (24/7 across time zones).',
              'example':
                  'Exam trap: The Service Desk is a PRACTICE in V4, not just a team or a function. It is about the capability to handle interactions — enabled by people, tools, and processes. The "follow-the-sun" model (different time zones handle requests continuously) is a specific type worth knowing.',
            },
            {
              'label': 'Practice',
              'term': 'Service Level Management',
              'definition':
                  'Service Level Management sets clear business-based targets for service levels and ensures services are delivered to these targets. Key documents: SLA (Service Level Agreement — with customer), OLA (Operational Level Agreement — internal agreement), UC (Underpinning Contract — with external supplier). All three must align upwards to support the SLA.',
              'example':
                  'Scenario: The SLA promises 99.9% uptime. The OLA commits the infrastructure team to 99.95% uptime for their systems. The UC commits the data centre supplier to 99.99%. This hierarchy (UC → OLA → SLA) ensures the SLA target is achievable.',
            },
            {
              'label': 'Practice',
              'term': 'SLA, OLA, and UC — Hierarchy and Alignment',
              'definition':
                  'The SLA is the external-facing agreement with the customer. The OLA is the internal agreement between IT teams supporting the service. The UC is the contract with a third-party supplier. OLAs and UCs must collectively support SLA commitments — their targets should be stronger (higher availability, faster response) than the SLA requires.',
              'example':
                  'Exam trap: The OLA is INTERNAL — between teams within the same organisation. The UC is EXTERNAL — with an outside vendor. If an exam describes an agreement with a third-party cloud provider, it is a UC, not an OLA. If it is between the service desk and the infrastructure team, it is an OLA.',
            },
            {
              'label': 'Practice',
              'term': 'Monitoring and Event Management',
              'definition':
                  'Monitoring and Event Management observes services and service components systematically and records and reports selected changes of state (events). Event types: Informational (normal operation), Warning (threshold approaching), Exception (failure or threshold breached). Exceptions typically trigger Incident Management.',
              'example':
                  'Scenario: A monitoring tool detects CPU usage at 95% (Warning event) and sends an alert. IT staff investigate and add capacity before a failure occurs. If ignored and CPU hits 100%, the server crashes — an Exception event triggers an Incident. Effective monitoring prevents incidents.',
            },
            {
              'label': 'Practice',
              'term': 'IT Asset Management',
              'definition':
                  'IT Asset Management plans and manages the full lifecycle of all IT assets to help the organisation maximise value, control costs, manage risks, support decision-making, and meet regulatory requirements. An IT asset is any financially valuable component that contributes to delivering IT products or services.',
              'example':
                  'Exam trap: IT Asset Management covers the FULL LIFECYCLE — procurement, deployment, operation, maintenance, and disposal. It is not just an inventory list. If a question involves software licence compliance, hardware disposal, or lifecycle cost tracking, IT Asset Management is the relevant practice.',
            },
            {
              'label': 'Practice',
              'term': 'Configuration Management and the CMDB',
              'definition':
                  'The Service Configuration Management practice ensures that accurate information about configuration items (CIs) and their relationships is available when and where needed. The Configuration Management Database (CMDB) stores CI records. CIs include: hardware, software, services, documentation, and people.',
              'example':
                  'Scenario: An incident is raised about a failing application. The service desk queries the CMDB to see which servers the application runs on, which services depend on it, and which recent changes were made to its CIs. The CMDB enables faster, more accurate incident resolution.',
            },
            {
              'label': 'Exam prep',
              'term': 'Module 5 — Top Practice Exam Traps',
              'definition':
                  '1) Incident = restore service; Problem = find root cause. 2) Change Enablement (not "Change Management"). 3) Standard changes bypass CAB. 4) Service requests are NOT incidents. 5) OLA = internal; UC = external supplier. 6) Known Error has a documented workaround — Problem may not. 7) Service Desk is a practice, not just a team.',
              'example':
                  'Most ITIL V4 Foundation exam questions on practices are scenario-based. Practice mapping scenarios to practices: "user can\'t log in" = Incident. "why do users keep getting locked out?" = Problem. "user wants a new keyboard" = Service Request. "rolling out new firewall rules" = Change Enablement.',
            },
            {
              'label': 'Acronym drill',
              'term': 'Key Practice Acronyms',
              'definition':
                  'KEDB = Known Error Database (Problem Management). CMDB = Configuration Management Database. CAB = Change Advisory Board (Change Enablement). SPOC = Single Point of Contact (Service Desk). SLA = Service Level Agreement. OLA = Operational Level Agreement. UC = Underpinning Contract. CI = Configuration Item.',
              'example':
                  'These acronyms appear in exam questions and answer options. If you see "KEDB" in an answer, the question is about Problem Management. If you see "CAB," it is about Change Enablement. Acronym recognition speeds up answer elimination.',
            },
            {
              'label': 'Scenario',
              'term': 'Incident vs Problem — Scenario Practice',
              'definition':
                  'Use these rules: If the question asks about RESTORING SERVICE → Incident Management. If it asks about PREVENTING RECURRENCE or FINDING ROOT CAUSE → Problem Management. If it mentions KNOWN ERROR or WORKAROUND → Problem Management / Error Control. If it says "reactive" to a specific failure → Incident. If it says "proactive" analysis → Problem.',
              'example':
                  'Scenario A: "Users cannot access the VPN. The team is working to restore connectivity." → Incident Management. Scenario B: "The VPN has gone down four times this month. The team is investigating the underlying cause." → Problem Management. Scenario C: "A workaround exists — users connect via web portal while the VPN is fixed." → Known Error / Error Control.',
            },
          ];

        // ── Module 06: ITIL V4 Management Practices (Part 2) ───────────────
        case 'module-06':
          return [
            {
              'label': 'Practice',
              'term': 'Release Management',
              'definition':
                  'Release Management makes new and changed services and features available for use. A release is a version of a service or other configuration item made available for use. Release Management plans, schedules, controls, and deploys releases while ensuring integrity of the live environment.',
              'example':
                  'Exam trap: Release Management is about making a change AVAILABLE — it does NOT handle the change approval (that is Change Enablement). In a DevOps context, Release Management may be automated via a CI/CD pipeline. The practice manages WHAT is released and WHEN.',
            },
            {
              'label': 'Practice',
              'term': 'Deployment Management',
              'definition':
                  'Deployment Management moves new or changed hardware, software, documentation, processes, or any other component to live environments. It may also deploy to testing or staging environments. Deployment Management is the TECHNICAL execution of moving components — separate from Release Management which controls the "what and when."',
              'example':
                  'Exam trap: Release Management ≠ Deployment Management. Release Management decides what gets released and when. Deployment Management physically moves the components into place. Both practices work together but are distinct. Questions about "putting code onto production servers" = Deployment Management.',
            },
            {
              'label': 'Practice',
              'term': 'Continual Improvement Practice',
              'definition':
                  'The Continual Improvement practice aligns the organisation\'s practices and services with changing business needs through the ongoing identification and improvement of services, service components, practices, and the SVS. It uses the seven-step Continual Improvement Model as its core tool.',
              'example':
                  'Exam trap: Continual Improvement is BOTH a component of the SVS AND a standalone practice. The SVS component sets the culture and intent; the practice provides the structured process and tools (the model) to execute improvement. Do not confuse the two — they exist at different levels.',
            },
            {
              'label': 'Practice',
              'term': 'The Seven-Step Continual Improvement Model',
              'definition':
                  'The model has seven steps: 1) What is the vision? 2) Where are we now? 3) Where do we want to be? 4) How do we get there? 5) Take action. 6) Did we get there? 7) How do we keep the momentum going? Steps 2 and 6 require measurement — current state assessment and results evaluation.',
              'example':
                  'Exam trap: The model has SEVEN steps. Step 1 (vision) and Step 7 (momentum) are often missed by candidates. The model is iterative — after Step 7, you return to Step 1 for the next improvement cycle. It never truly ends.',
            },
            {
              'label': 'Practice',
              'term': 'Knowledge Management',
              'definition':
                  'Knowledge Management maintains and improves the effective, efficient, and convenient use of information and knowledge across the organisation. It uses the DIKW model: Data → Information → Knowledge → Wisdom. The goal is ensuring the right people have the right knowledge at the right time.',
              'example':
                  'Scenario: A service desk analyst uses a knowledge base article to resolve an incident in 3 minutes instead of 45. The article was created from a Previous incident (data → information → knowledge). Knowledge Management created and maintained that article, accelerating resolution and reducing escalations.',
            },
            {
              'label': 'Practice',
              'term': 'DIKW Model — Data, Information, Knowledge, Wisdom',
              'definition':
                  'Data: raw facts with no context. Information: data with context (who, what, where, when). Knowledge: information combined with experience and judgement (how). Wisdom: applying knowledge to make sound decisions (why). ITIL V4 Knowledge Management aims to move organisations up the DIKW pyramid.',
              'example':
                  'Exam trap: Know the correct sequence D → I → K → W and what each level means. A raw server log is Data. A report showing "Server X crashed 5 times on Tuesdays" is Information. "Server X crashes because of a scheduled backup conflict" is Knowledge. "Schedule backups to avoid peak hours to prevent recurrence" is Wisdom.',
            },
            {
              'label': 'Practice',
              'term': 'Relationship Management',
              'definition':
                  'Relationship Management establishes and nurtures links between the organisation and its stakeholders at strategic and tactical levels. It identifies and analyses stakeholder needs and ensures the organisation understands and responds to those needs. It covers both internal and external relationships.',
              'example':
                  'Exam trap: Relationship Management is NOT the same as Service Level Management. Relationship Management is about TRUST, COMMUNICATION, and ENGAGEMENT with stakeholders. SLM is about TARGETS and AGREEMENTS. Both are needed, but for different reasons.',
            },
            {
              'label': 'Practice',
              'term': 'Supplier Management',
              'definition':
                  'Supplier Management ensures the organisation\'s suppliers and their performances are managed appropriately to support the seamless provision of quality products and services. It manages supplier contracts, performance, relationships, and risk. Closely linked to the Partners & Suppliers dimension.',
              'example':
                  'Scenario: A cloud provider misses its uptime SLA. Supplier Management initiates a formal performance review, applies contract penalties, and evaluates whether to continue or switch suppliers. Without Supplier Management, poor supplier performance would go unaddressed.',
            },
            {
              'label': 'Practice',
              'term': 'Service Catalogue Management',
              'definition':
                  'Service Catalogue Management provides a single source of consistent information on all services and service offerings. The service catalogue is the portion of the service portfolio visible to customers — it lists available services, their descriptions, and how to request them.',
              'example':
                  'Exam trap: The Service Catalogue is part of the Service Portfolio. The portfolio contains ALL services (pipeline, catalogue, and retired). The catalogue contains only LIVE services available to customers. Questions about "what services can customers request?" = Service Catalogue.',
            },
            {
              'label': 'Practice',
              'term': 'Service Design Practice',
              'definition':
                  'Service Design ensures products and services are designed to meet customer expectations for quality, cost, and time-to-market. It addresses all four dimensions (O&P, I&T, P&S, VS&P) and produces service designs, plans, and architectures as inputs to the Design & Transition SVC activity.',
              'example':
                  'Scenario: A new HR system is being commissioned. Service Design produces: the technical architecture, the support model, the training plan for staff, the monitoring approach, and the SLA targets. All of this feeds into Design & Transition in the SVC.',
            },
            {
              'label': 'Practice',
              'term': 'Business Analysis Practice',
              'definition':
                  'Business Analysis identifies business needs and recommends solutions that deliver value to stakeholders. In ITIL V4 context, it bridges the gap between business requirements and IT services — ensuring the right services are built to meet the right needs. It supports the Engage and Plan SVC activities heavily.',
              'example':
                  'Scenario: Business stakeholders say they "need a better system." Business Analysis converts this vague need into documented requirements: specific workflows, data needs, user personas, and acceptance criteria. Without Business Analysis, IT teams build what they THINK is needed, not what is actually needed.',
            },
            {
              'label': 'Practice',
              'term': 'Risk Management Practice',
              'definition':
                  'Risk Management ensures that the organisation understands and effectively handles risks. In ITIL V4, risk is defined as a possible event that could cause harm, loss, or make it more difficult to achieve objectives. Risk management involves: risk identification, risk assessment (likelihood × impact), risk treatment (avoid, reduce, transfer, accept).',
              'example':
                  'Exam trap: Risk treatment has FOUR options — avoid, reduce, transfer, accept. "Transfer" means passing the risk to a third party (e.g. insurance or outsourcing). Exam questions may ask which treatment applies in a given scenario — know all four and when each is appropriate.',
            },
            {
              'label': 'Practice',
              'term': 'Workforce and Talent Management',
              'definition':
                  'Workforce and Talent Management ensures the organisation has the right people with the right skills in the right roles. It covers recruitment, training, performance management, and succession planning. It is part of the General Management Practices category and directly supports the Organisations & People dimension.',
              'example':
                  'Scenario: The service desk has high staff turnover and knowledge gaps. Workforce and Talent Management addresses this through improved onboarding, career development paths, and targeted training. Ignoring this practice causes service quality to degrade as experienced staff leave.',
            },
            {
              'label': 'Exam prep',
              'term': 'Module 6 — Practice Exam Traps (Part 2)',
              'definition':
                  '1) Release Management = WHAT/WHEN to release. Deployment Management = HOW to move it. 2) CI model has SEVEN steps. 3) DIKW = Data → Information → Knowledge → Wisdom (in order). 4) Service Catalogue = live services only. Service Portfolio = all services. 5) Continual Improvement is both an SVS component AND a practice.',
              'example':
                  'Scenario practice: "The team is deciding which improvements to tackle next quarter" = Continual Improvement. "New version of the app is ready — planning the go-live window" = Release Management. "Running the deployment script on production servers" = Deployment Management. "Logging resolved incident solutions in the knowledge base" = Knowledge Management.',
            },
            {
              'label': 'Acronym drill',
              'term': 'Practice Category Breakdown',
              'definition':
                  'General Management Practices (14): Strategy Mgmt, Portfolio Mgmt, Architecture Mgmt, Service Financial Mgmt, Workforce & Talent Mgmt, Continual Improvement, Measurement & Reporting, Risk Mgmt, Information Security Mgmt, Knowledge Mgmt, Org Change Mgmt, Project Mgmt, Relationship Mgmt, Supplier Mgmt. Service Management Practices (17) and Technical Management Practices (3) make up the remaining 20.',
              'example':
                  'Exam trap: Know that there are 14 General, 17 Service Management, and 3 Technical Management practices. The three Technical Management practices are: Deployment Management, Infrastructure & Platform Management, and Software Development & Management. These are the least-tested but can appear as distractors.',
            },
          ];

        // ── Module 07: Continual Improvement & Measurement ─────────────────
        case 'module-07':
          return [
            {
              'label': 'Continual Improvement',
              'term': 'Continual Improvement vs Continual Service Improvement',
              'definition':
                  'ITIL v3 used the term "Continual Service Improvement (CSI)" as one of five lifecycle stages. ITIL V4 replaces this with "Continual Improvement" — a broader concept that applies to all SVS components: practices, the value chain, governance, and the guiding principles — not just services.',
              'example':
                  'Exam trap: "Continual Service Improvement" is an ITIL v3 term. Using it in an ITIL V4 exam answer is risky. The correct V4 term is "Continual Improvement." If an exam option says "Continual Service Improvement" in a V4 context, read carefully — it may be the wrong answer.',
            },
            {
              'label': 'CI Model',
              'term': 'Step 1 — What is the Vision?',
              'definition':
                  'The first step of the Continual Improvement Model establishes the high-level direction of the improvement initiative by understanding the organisation\'s strategic goals and objectives. All improvement work must ultimately link back to this vision to ensure alignment. Without a clear vision, improvement efforts fragment and lose business support.',
              'example':
                  'Scenario: The organisation\'s vision is "become the most reliable financial services provider in the region." An improvement initiative to reduce service desk resolution times supports this vision. One that adds cosmetic features to an internal tool does not — and should be deprioritised.',
            },
            {
              'label': 'CI Model',
              'term': 'Step 2 — Where Are We Now? (Baseline Assessment)',
              'definition':
                  'Step 2 performs an objective assessment of the current state — using data, metrics, and observations rather than assumptions. This baseline is critical: without knowing the current state accurately, you cannot measure improvement. Subjective or anecdotal assessments violate the "Start Where You Are" guiding principle.',
              'example':
                  'Exam trap: The baseline must be OBJECTIVE and DATA-BASED — not based on perception or gut feeling. If an exam scenario describes an improvement where no current state measurement was taken, this is a failure of Step 2, and improvement results cannot be verified.',
            },
            {
              'label': 'CI Model',
              'term': 'Step 3 — Where Do We Want to Be? (Target State)',
              'definition':
                  'Step 3 defines measurable improvement targets — the desired future state. Targets should be SMART: Specific, Measurable, Achievable, Relevant, Time-bound. Vague targets like "improve customer satisfaction" are insufficient — "increase CSAT score from 72% to 85% by Q3" is a Step 3 target.',
              'example':
                  'Scenario: Current state (Step 2) = mean time to resolve (MTTR) incidents is 4 hours. Target (Step 3) = reduce MTTR to 2 hours within 6 months. This creates a measurable gap that drives the improvement plan in Steps 4 and 5.',
            },
            {
              'label': 'CI Model',
              'term': 'Step 4 — How Do We Get There? (Improvement Plan)',
              'definition':
                  'Step 4 designs the improvement plan — the specific actions, resources, timelines, and owners needed to close the gap between current state (Step 2) and target state (Step 3). Multiple approaches should be evaluated and the most practical, cost-effective option selected.',
              'example':
                  'Scenario: To reduce MTTR from 4h to 2h: hire two additional level-2 engineers, implement an automated triage tool, and create 50 knowledge base articles for common issues. Each action has an owner, a deadline, and a budget — this is the Step 4 plan.',
            },
            {
              'label': 'CI Model',
              'term': 'Step 5 — Take Action',
              'definition':
                  'Step 5 executes the improvement plan, using an iterative approach — making incremental changes and checking results at each stage rather than a single large-scale deployment. This aligns with the "Progress Iteratively with Feedback" guiding principle.',
              'example':
                  'Exam trap: Step 5 does NOT mean "implement everything at once." The ITIL V4 preference is iterative implementation — pilot a change, measure, adjust, then scale. Big-bang implementations that skip feedback loops violate the V4 principles and increase risk.',
            },
            {
              'label': 'CI Model',
              'term': 'Step 6 — Did We Get There? (Evaluate Results)',
              'definition':
                  'Step 6 measures and evaluates the results of the improvement actions against the target set in Step 3. Key question: did we achieve the defined target? If yes, document the success and communicate it. If no, identify what fell short and feed findings back into the model.',
              'example':
                  'Scenario: After six months, MTTR is now 2.5 hours — improved from 4h but not yet at the 2h target. Step 6 shows partial success. The findings loop back — a new Step 3 target (2h) and a revised plan (Step 4) are set. Improvement continues.',
            },
            {
              'label': 'CI Model',
              'term': 'Step 7 — How Do We Keep the Momentum Going?',
              'definition':
                  'Step 7 embeds the improvement in normal operations and maintains the motivation to continue improving. It involves communicating wins, recognising contributors, and identifying the NEXT improvement opportunity — returning to Step 1 for the next cycle. Continual improvement is circular, not linear.',
              'example':
                  'Exam trap: Many candidates think the model ends at Step 6. Step 7 explicitly exists to prevent "improvement fatigue" — where wins are celebrated briefly and then momentum is lost. If a question describes an organisation that improves, celebrates, then stagnates, Step 7 is the missing element.',
            },
            {
              'label': 'Measurement',
              'term': 'CSFs and KPIs',
              'definition':
                  'Critical Success Factors (CSFs) define WHAT must happen for the organisation to succeed. Key Performance Indicators (KPIs) measure HOW WELL the CSF is being achieved. For every CSF, there should be at least one KPI. KPIs should be few, meaningful, and directly tied to the CSF they measure.',
              'example':
                  'CSF: "Customer satisfaction with the service desk must be high." KPI: "CSAT score ≥ 90% monthly." CSF: "Incidents must be resolved quickly." KPI: "90% of P1 incidents resolved within 4 hours." Knowing the CSF → KPI relationship is directly tested on the exam.',
            },
            {
              'label': 'Measurement',
              'term': 'The Danger of Measuring the Wrong Things',
              'definition':
                  'ITIL V4 warns against "metric fixation" — optimising for metrics at the expense of actual value. If a service desk is measured only on call volume, staff will rush calls to inflate numbers, reducing quality. Metrics must measure VALUE, not just activity. Both quantitative and qualitative measures are needed.',
              'example':
                  'Scenario: A service desk KPI is "calls answered per hour." Staff start closing tickets prematurely to hit the target. CSAT drops from 87% to 63%. The KPI drove the wrong behaviour. ITIL V4 requires metrics to link to value outcomes — not just operational activity.',
            },
            {
              'label': 'Measurement',
              'term': 'Balanced Scorecard Approach to ITSM Metrics',
              'definition':
                  'ITIL V4 encourages measuring service performance across multiple perspectives — not just cost and efficiency. A balanced approach measures: Financial performance, Customer satisfaction, Internal process efficiency, and Learning & growth (people capability). No single category should dominate.',
              'example':
                  'An IT team reports 100% SLA compliance (financial/process ✓) but customer satisfaction is 55% (customer ✗) and staff turnover is 40% annually (learning & growth ✗). Balanced measurement reveals the full picture that single-metric reporting hides.',
            },
            {
              'label': 'Improvement Register',
              'term': 'Continual Improvement Register (CIR)',
              'definition':
                  'The Continual Improvement Register is a structured list of improvement opportunities and initiatives. It is used to record, prioritise, track, and review improvements across the organisation. All parts of the SVS can contribute items to the CIR. It ensures no improvement idea is lost.',
              'example':
                  'Scenario: A service desk analyst notices that 30% of incidents could be resolved with a self-service article. They log this in the CIR. The improvement is assessed, prioritised, and assigned. Without the CIR, the idea would be forgotten after the next team meeting.',
            },
            {
              'label': 'Measurement',
              'term': 'Leading vs Lagging Indicators',
              'definition':
                  'Lagging indicators measure past performance (e.g. number of P1 incidents last month). Leading indicators predict future performance (e.g. number of unpatched critical vulnerabilities today). ITIL V4 recommends using BOTH — lagging to assess historical trends, leading to enable proactive action.',
              'example':
                  'Exam scenario: "The organisation only measures incidents after they occur." This is lagging-only measurement. Adding monitoring of configuration drift, patch compliance, and error rates as leading indicators would enable the organisation to prevent incidents proactively.',
            },
            {
              'label': 'Application',
              'term': 'Applying the CI Model — Full Scenario',
              'definition':
                  'Scenario: Customer complaints about slow ticket resolution are rising. Step 1: Vision = best-in-class service quality. Step 2: MTTR = 5.2h average (data pulled). Step 3: Target = 2.5h within 90 days. Step 4: Plan = implement auto-triage + add two staff. Step 5: Execute in two phases. Step 6: After 90 days, MTTR = 2.3h (target met). Step 7: Publish result, identify next improvement (CSAT score).',
              'example':
                  'This scenario covers all seven steps in sequence. The exam may present a scenario with one or more steps missing and ask which step has been skipped. Know each step well enough to identify gaps.',
            },
            {
              'label': 'Exam prep',
              'term': 'Module 7 — Continual Improvement Exam Traps',
              'definition':
                  '1) CI model has SEVEN steps — not five, not six. 2) Step 2 requires OBJECTIVE data — not opinion. 3) Step 5 should be ITERATIVE — not big-bang. 4) Step 7 exists to maintain momentum — model is CIRCULAR. 5) CSF = what must happen. KPI = how well it is happening. 6) CI applies to ALL SVS components — not just services. 7) "Continual Service Improvement" is v3 language.',
              'example':
                  'Most exam questions on this module present a partial improvement story and ask what is missing or what happens next. If you can identify the CI model step from a scenario description, you will answer these correctly.',
            },
          ];

        // ── Module 08: ITIL V4 Foundation Exam Preparation ─────────────────
        case 'module-08':
          return [
            {
              'label': 'Exam overview',
              'term': 'ITIL V4 Foundation Exam — Format and Requirements',
              'definition':
                  'The ITIL V4 Foundation exam consists of 40 multiple-choice questions. Candidates have 60 minutes. The pass mark is 65% — 26 out of 40 correct answers required. No negative marking — always guess if unsure. The exam is closed book. Questions test understanding and application, not memorisation alone.',
              'example':
                  'Exam strategy: 60 minutes ÷ 40 questions = 90 seconds per question. Flag difficult questions and return to them. On scenario questions, eliminate obviously wrong answers first, then choose between the remaining two. Never leave a question blank — no penalty for wrong answers.',
            },
            {
              'label': 'Exam overview',
              'term': 'Question Types on the ITIL V4 Foundation Exam',
              'definition':
                  'Three question types appear: 1) Knowledge questions — define a term or concept. 2) Comprehension questions — explain why something is important. 3) Application/scenario questions — a situation is described and you identify the correct practice, principle, or action. Scenario questions are the majority — approximately 60% of the exam.',
              'example':
                  'Tip: Knowledge questions test definitions. Comprehension questions test understanding. Scenario questions test whether you can APPLY the framework. The scenario questions are where most candidates lose marks — practice mapping situations to ITIL V4 concepts using the examples throughout this course.',
            },
            {
              'label': 'Rapid review',
              'term': 'The SVS — Five Components (Must Know Cold)',
              'definition':
                  'The five SVS components: 1) Guiding Principles, 2) Governance, 3) Service Value Chain, 4) Practices, 5) Continual Improvement. Input to SVS: Opportunity + Demand. Output: Value. Any exam option listing fewer or more components, or using different names, is wrong.',
              'example':
                  'Test yourself: close your eyes and name all five SVS components. Then name all seven guiding principles. Then name all six SVC activities. If you cannot do this from memory, you are not exam-ready. These are the highest-frequency exam topics.',
            },
            {
              'label': 'Rapid review',
              'term': 'The SVC — Six Activities (Must Know Cold)',
              'definition':
                  'The six SVC activities: Plan, Improve, Engage, Design & Transition, Obtain/Build, Deliver & Support. Remember: they are flexible — not a fixed sequence. Each activity takes inputs and produces outputs. ALL activities can involve ALL four dimensions and ALL practices.',
              'example':
                  'Memory aid: "PIEDOD" — Plan, Improve, Engage, Design & Transition, Obtain/Build, Deliver & Support. Or use any mnemonic that gives you all six. Exam questions often name five activities and ask which is missing — know all six precisely.',
            },
            {
              'label': 'Rapid review',
              'term': 'The Seven Guiding Principles (Must Know Cold)',
              'definition':
                  '1) Focus on Value. 2) Start Where You Are. 3) Progress Iteratively with Feedback. 4) Collaborate and Promote Visibility. 5) Think and Work Holistically. 6) Keep It Simple and Practical. 7) Optimise and Automate. Universal — apply to every initiative. Not in a hierarchy — all seven are equal.',
              'example':
                  'Memory aid: "FoSPCTKO" or any mnemonic using the first letters: F-S-P-C-T-K-O. Exam questions describe a scenario violating a principle and ask which one. Know each principle well enough to match a scenario description to the correct principle name.',
            },
            {
              'label': 'Rapid review',
              'term': 'The Four Dimensions (Must Know Cold)',
              'definition':
                  '1) Organisations & People. 2) Information & Technology. 3) Partners & Suppliers. 4) Value Streams & Processes. All four apply to every service and SVS component. External factors (PESTLE) affect all four. No dimension is optional.',
              'example':
                  'Quick-fire: Culture = O&P. CMDB = I&T. Third-party cloud vendor = P&S. Incident process steps = VS&P. GDPR compliance = I&T (data) and P&S (supplier contracts). PESTLE = external constraints on ALL four dimensions.',
            },
            {
              'label': 'Rapid review',
              'term': 'Key Definitions — Must-Know List',
              'definition':
                  'Service = enables value co-creation. Incident = unplanned interruption. Problem = cause of incidents. Known Error = problem with documented workaround. Change = addition/modification/removal affecting services. Service Request = pre-defined user request (not an incident). Event = change of state with significance for service management.',
              'example':
                  'The exam tests whether you know the ITIL-specific definition of each term — not the everyday English meaning. "Change" in ITIL is not just any alteration; it specifically affects services. "Event" in ITIL is not just anything that happens — it is a change of state that is significant to service management.',
            },
            {
              'label': 'Rapid review',
              'term': 'Practices — The 18 Foundation-Tested Practices',
              'definition':
                  'The 18 practices tested in depth at Foundation level include: Incident Management, Problem Management, Change Enablement, Service Request Management, Service Desk, Service Level Management, Monitoring & Event Management, IT Asset Management, Service Configuration Management, Release Management, Deployment Management, Continual Improvement, Knowledge Management, Relationship Management, Supplier Management, Service Catalogue Management, Service Design, and Business Analysis.',
              'example':
                  'You do not need to know all 34 practices for Foundation — but you must know these 18 well. For each, know: its purpose, key terms it owns, which SVC activities it supports, and how it differs from similar practices (especially Incident vs Problem, Release vs Deployment, Request vs Incident).',
            },
            {
              'label': 'Exam strategy',
              'term': 'Eliminating Wrong Answers — Technique',
              'definition':
                  'ITIL V4 exam distractors often use: v3 language ("Continual Service Improvement," "Change Management"), incorrect scope (e.g. saying governance is management), conflation of similar practices (Release vs Deployment), and absolute language ("always," "never," "only") — ITIL V4 guidance rarely uses absolutes. Eliminate these patterns first.',
              'example':
                  'If an answer option says "the provider delivers value to the customer," eliminate it — V4 says value is CO-CREATED. If an answer says "the CAB must approve all changes," eliminate it — Standard changes bypass the CAB. If an answer uses "Continual Service Improvement," that is v3 language.',
            },
            {
              'label': 'Exam strategy',
              'term': 'Answering Scenario Questions — Method',
              'definition':
                  'Step 1: Identify what the scenario is describing (incident? problem? change? improvement?). Step 2: Identify the key action (restore service? find root cause? approve change? measure improvement?). Step 3: Match the action to the correct ITIL V4 concept (practice, principle, SVC activity, dimension). Step 4: Eliminate options that use wrong language or wrong scope.',
              'example':
                  'Scenario: "Users are complaining about repeated system crashes. The team is investigating why this keeps happening." Step 1: repeated crashes = Problem. Step 2: investigating why = root cause analysis. Step 3: Problem Management. Step 4: Eliminate "Incident Management" (restores, not investigates) and "Change Enablement" (not relevant here).',
            },
            {
              'label': 'Common mistakes',
              'term': 'Top 10 Reasons Candidates Fail ITIL V4 Foundation',
              'definition':
                  '1) Confusing Incident with Problem. 2) Saying value is "delivered" not "co-created." 3) Getting SVS components wrong (wrong count or names). 4) Using v3 lifecycle language. 5) Forgetting Utility AND Warranty are both required. 6) Thinking CI applies only to services. 7) Misidentifying OLA vs UC. 8) Saying optimise and automate are interchangeable. 9) Missing Step 7 of the CI model. 10) Not knowing all seven guiding principles by name.',
              'example':
                  'Review this list before your exam. Each of these mistakes has cost real candidates their pass mark. If you can confidently explain why each statement above is wrong, you are demonstrating the level of understanding the Foundation exam tests.',
            },
            {
              'label': 'Rapid review',
              'term': 'Value Co-Creation — The Central Thread of ITIL V4',
              'definition':
                  'The single most important concept in ITIL V4 is value co-creation. Every other concept — the SVS, SVC, four dimensions, practices, and guiding principles — exists in service of this one idea: IT and the business work together to create value. Neither can create value alone.',
              'example':
                  'Final exam thought: if you ever feel uncertain about an answer, ask yourself "which option best supports value co-creation between IT and the business?" ITIL V4 is built around this concept — answers that isolate IT from business, or that treat value as one-directional, are almost always wrong.',
            },
            {
              'label': 'Rapid review',
              'term': 'Full Framework Map — One Card Summary',
              'definition':
                  'SVS inputs: Demand + Opportunity. SVS components: Guiding Principles, Governance, SVC, Practices, Continual Improvement. SVS output: Value. SVC activities (6): Plan, Improve, Engage, Design & Transition, Obtain/Build, Deliver & Support. Four dimensions: O&P, I&T, P&S, VS&P. Guiding principles (7): FoV, SWyA, PIwF, CaPV, TaWH, KISaP, OaA. CI model: 7 steps.',
              'example':
                  'Use this card as your pre-exam 2-minute review. Every number and acronym here can be tested. If you can recite all of it accurately, you have the structural knowledge to pass. The exam tests whether you can also APPLY this structure — which is what all the scenario practice throughout this course builds.',
            },
            {
              'label': 'Exam prep',
              'term': 'Last 24 Hours Before the Exam — Checklist',
              'definition':
                  'DO: Review the 18 core practices and their key distinctions. Review the seven guiding principles with examples. Review the six SVC activities and what each does. Review the five SVS components. Review the seven CI model steps. DO NOT: Try to learn new material. Cram definitions you do not understand. Spend more than 2 hours reviewing.',
              'example':
                  'The night before: use the flashcards in this module for a timed 40-question self-test. Aim for 85%+ to give yourself a buffer. If you score below 75%, identify the weak areas and do targeted review — do not re-read everything. Targeted revision beats general re-reading.',
            },
          ];

        default:
          return _itilV4Default();
      }
    }

    // ── Binary Cloud ───────────────────────────────────────────────────────
    if (tag == 'Binary Cloud') {
      switch (moduleId) {
        case 'module-01':
          return [
            {
              'label': 'Definition',
              'term': 'What is cloud computing?',
              'definition':
                  'Cloud computing is the delivery of computing services — including servers, storage, databases, networking, software, and analytics — over the internet ("the cloud"). You pay for only what you use, rather than owning physical hardware.',
              'example':
                  'Instead of buying a server for your website, you rent computing power from AWS. When traffic spikes, you scale up instantly and pay for the extra hours only.',
            },
            {
              'label': 'Core concept',
              'term': 'On-Premises vs Cloud',
              'definition':
                  'On-premises (on-prem) means you own and manage your own physical hardware in your own data centre. Cloud means a provider manages the hardware and you access resources remotely over the internet.',
              'example':
                  'On-prem: your company owns servers in a basement IT room. Cloud: your company\'s files live on Google Drive and can be accessed from anywhere.',
            },
            {
              'label': 'Core concept',
              'term': 'The 5 Characteristics of Cloud (NIST)',
              'definition':
                  'NIST defines cloud by five essential characteristics: 1) On-demand self-service, 2) Broad network access, 3) Resource pooling, 4) Rapid elasticity, 5) Measured service (pay-as-you-go).',
              'example':
                  'You log into AWS, spin up a new server in 60 seconds without calling anyone (self-service), use it from your laptop anywhere (broad access), and are billed per hour (measured service).',
            },
            {
              'label': 'Key benefit',
              'term': 'Scalability & Elasticity',
              'definition':
                  'Scalability is the ability to increase capacity when needed. Elasticity means the system automatically scales up and down based on demand, so you never over-provision or under-provision resources.',
              'example':
                  'A retail website scales up to handle Black Friday traffic automatically, then scales back down overnight — you only pay for what was used.',
            },
            {
              'label': 'Key benefit',
              'term': 'CapEx vs OpEx',
              'definition':
                  'Traditional IT uses Capital Expenditure (CapEx) — large upfront purchases of hardware. Cloud uses Operational Expenditure (OpEx) — ongoing pay-as-you-go costs. Cloud converts big one-time costs into predictable monthly expenses.',
              'example':
                  'Buying a \$50,000 server is CapEx. Paying \$500/month for equivalent cloud resources is OpEx — better for cash flow and flexibility.',
            },
          ];
        case 'module-02':
          return [
            {
              'label': 'Service model',
              'term': 'Infrastructure as a Service (IaaS)',
              'definition':
                  'IaaS provides virtualised computing infrastructure over the internet — servers, storage, and networking. You manage the OS, middleware, and applications. The provider manages the physical hardware.',
              'example':
                  'AWS EC2 gives you a virtual server. You choose the OS, install software, and manage it yourself. The physical machine is Amazon\'s problem.',
            },
            {
              'label': 'Service model',
              'term': 'Platform as a Service (PaaS)',
              'definition':
                  'PaaS provides a platform allowing developers to build, run, and manage applications without worrying about the underlying infrastructure. The provider manages the OS, runtime, and servers.',
              'example':
                  'Heroku lets you deploy a web app by pushing code. You don\'t configure servers, install Node.js, or patch the OS — Heroku handles all of that.',
            },
            {
              'label': 'Service model',
              'term': 'Software as a Service (SaaS)',
              'definition':
                  'SaaS delivers fully functional software over the internet, managed entirely by the provider. You just use the application through a browser — no installation, no maintenance.',
              'example':
                  'Gmail, Slack, Salesforce, and Zoom are all SaaS. You log in and use them — you never think about the servers they run on.',
            },
            {
              'label': 'Comparison',
              'term': 'IaaS vs PaaS vs SaaS — Who manages what?',
              'definition':
                  'IaaS: You manage OS, apps, data. Provider manages hardware. PaaS: You manage apps and data only. Provider manages OS and hardware. SaaS: Provider manages everything. You just use the software.',
              'example':
                  'Think of it as pizza: IaaS = ingredients delivered (you cook). PaaS = pizza kit (you assemble). SaaS = pizza delivered and ready to eat.',
            },
            {
              'label': 'Emerging model',
              'term': 'Serverless / FaaS',
              'definition':
                  'Serverless (Function as a Service) lets you run code without provisioning or managing servers. You write a function, deploy it, and only pay when it executes. The cloud scales it automatically.',
              'example':
                  'AWS Lambda runs your image-resize function every time a user uploads a photo. You pay per execution (milliseconds), not per server hour.',
            },
          ];
        case 'module-03':
          return [
            {
              'label': 'Deployment model',
              'term': 'Public Cloud',
              'definition':
                  'Public cloud resources are owned and operated by a third-party provider and shared across multiple customers over the internet. Resources are provisioned on-demand and billed pay-as-you-go.',
              'example':
                  'AWS, Microsoft Azure, and Google Cloud are public clouds. Your servers share physical hardware with other companies\' workloads (but are logically isolated).',
            },
            {
              'label': 'Deployment model',
              'term': 'Private Cloud',
              'definition':
                  'A private cloud is cloud infrastructure dedicated to a single organisation, either on-premises or hosted by a provider. It offers greater control, customisation, and security but at higher cost.',
              'example':
                  'A bank runs its own virtualised data centre using VMware. Only the bank\'s employees use it — no resource sharing with outsiders.',
            },
            {
              'label': 'Deployment model',
              'term': 'Hybrid Cloud',
              'definition':
                  'Hybrid cloud combines public and private clouds, allowing data and applications to move between them. Organisations keep sensitive workloads on-prem and use public cloud for burst capacity or less critical apps.',
              'example':
                  'A hospital stores patient records on its private cloud (compliance) but uses AWS for its public-facing appointment booking website.',
            },
            {
              'label': 'Deployment model',
              'term': 'Multi-Cloud',
              'definition':
                  'Multi-cloud means using services from two or more cloud providers simultaneously. It avoids vendor lock-in, improves resilience, and lets you pick the best service from each provider.',
              'example':
                  'A company hosts its website on AWS, uses Google BigQuery for analytics, and Microsoft Azure for Active Directory — all at the same time.',
            },
            {
              'label': 'Key concept',
              'term': 'Vendor Lock-In',
              'definition':
                  'Vendor lock-in occurs when a customer becomes too dependent on a single cloud provider\'s proprietary services, making it difficult and expensive to switch providers later.',
              'example':
                  'If your entire app is built using AWS-specific services like DynamoDB and Lambda, migrating to Azure would require rewriting significant portions of your application.',
            },
          ];
        case 'module-04':
          return [
            {
              'label': 'Core service',
              'term': 'Compute (Virtual Machines)',
              'definition':
                  'Cloud compute services provide virtual servers you can provision on demand. You choose the CPU, RAM, and OS. VMs run your applications just like a physical server but are software-defined.',
              'example':
                  'AWS EC2, Azure Virtual Machines, and Google Compute Engine all let you spin up a Linux or Windows server in minutes.',
            },
            {
              'label': 'Core service',
              'term': 'Cloud Storage Types',
              'definition':
                  'Cloud storage comes in three types: Object storage (files/blobs — e.g. S3), Block storage (like a hard drive attached to a VM — e.g. EBS), and File storage (shared network drives — e.g. EFS).',
              'example':
                  'Object: store user profile photos on S3. Block: attach extra disk space to an EC2 instance. File: share a folder between multiple servers.',
            },
            {
              'label': 'Core service',
              'term': 'Managed Databases',
              'definition':
                  'Cloud providers offer managed database services where they handle backups, patching, replication, and scaling. You focus on your data, not database administration.',
              'example':
                  'AWS RDS runs MySQL for you — automated backups, multi-AZ failover, and no OS patching required. You just connect and query.',
            },
            {
              'label': 'Core service',
              'term': 'Content Delivery Network (CDN)',
              'definition':
                  'A CDN is a globally distributed network of servers that caches content close to users, reducing latency and improving load times. It\'s essential for fast websites with global audiences.',
              'example':
                  'CloudFront caches your website\'s images at 400+ edge locations worldwide. A user in Tokyo gets served from a nearby server instead of your US origin.',
            },
            {
              'label': 'Core service',
              'term': 'Auto Scaling',
              'definition':
                  'Auto Scaling automatically adjusts the number of compute resources based on demand. It adds capacity when load increases and removes it when load drops, optimising both performance and cost.',
              'example':
                  'Your app\'s traffic doubles during lunch hour. Auto Scaling adds two more servers automatically, then removes them at 3pm when traffic drops.',
            },
          ];
        case 'module-05':
          return [
            {
              'label': 'Security concept',
              'term': 'Shared Responsibility Model',
              'definition':
                  'In cloud, security is a shared responsibility. The provider secures the infrastructure (hardware, network, physical facilities). The customer secures what they put on it (data, access controls, OS configuration).',
              'example':
                  'AWS is responsible for the physical data centre security. You are responsible for not leaving your S3 bucket publicly readable and rotating your access keys.',
            },
            {
              'label': 'Security concept',
              'term': 'Identity and Access Management (IAM)',
              'definition':
                  'IAM controls who can access your cloud resources and what they can do. You create users, groups, and roles with specific permissions following the principle of least privilege.',
              'example':
                  'Your developer\'s IAM role allows reading from S3 but cannot delete EC2 instances. Your billing team can view invoices but cannot touch any infrastructure.',
            },
            {
              'label': 'Security concept',
              'term': 'Encryption at Rest and in Transit',
              'definition':
                  'Encryption at rest protects stored data (e.g. encrypted hard drives, databases). Encryption in transit protects data moving across networks (e.g. TLS/HTTPS). Both are required for a complete security posture.',
              'example':
                  'Your S3 bucket is encrypted with AES-256 at rest. Data sent between your app and the database uses TLS so it cannot be intercepted in transit.',
            },
            {
              'label': 'Security concept',
              'term': 'Security Groups and Network ACLs',
              'definition':
                  'Security Groups are virtual firewalls at the instance level that control inbound and outbound traffic. Network ACLs operate at the subnet level. Together they form layered network security in the cloud.',
              'example':
                  'Your web server\'s security group allows inbound port 443 (HTTPS) from anywhere but blocks all other ports. Only the load balancer can reach your app servers.',
            },
            {
              'label': 'Compliance',
              'term': 'Cloud Compliance Frameworks',
              'definition':
                  'Cloud environments must comply with industry standards depending on the workload: HIPAA (healthcare), PCI-DSS (payment cards), SOC 2 (service organisations), and GDPR (EU data protection).',
              'example':
                  'A healthcare startup stores patient data on AWS. They must ensure their configuration meets HIPAA requirements — encrypted storage, audit logs, and strict access controls.',
            },
          ];
        case 'module-06':
          return [
            {
              'label': 'Networking',
              'term': 'Virtual Private Cloud (VPC)',
              'definition':
                  'A VPC is a logically isolated section of the cloud where you can launch resources in a virtual network that you define. You control IP ranges, subnets, route tables, and gateways.',
              'example':
                  'You create a VPC with a public subnet (for web servers facing the internet) and a private subnet (for databases that should never be publicly accessible).',
            },
            {
              'label': 'Networking',
              'term': 'Subnets in the Cloud',
              'definition':
                  'A subnet is a range of IP addresses within your VPC. Public subnets have a route to an internet gateway. Private subnets do not — they are isolated from the internet.',
              'example':
                  'Your web tier lives in a public subnet with a public IP. Your database lives in a private subnet — it can only be reached from the web tier, never directly from the internet.',
            },
            {
              'label': 'Networking',
              'term': 'Load Balancers',
              'definition':
                  'A load balancer distributes incoming traffic across multiple servers to ensure no single server is overwhelmed. It also provides health checks and removes unhealthy instances automatically.',
              'example':
                  'Your app has 3 web servers. The load balancer sends each user request to whichever server is least busy. If one crashes, the load balancer stops sending it traffic.',
            },
            {
              'label': 'Networking',
              'term': 'DNS in the Cloud (Route 53 / Cloud DNS)',
              'definition':
                  'Cloud providers offer managed DNS services that route users to your applications. They support routing policies like latency-based, geolocation, failover, and weighted routing.',
              'example':
                  'Route 53 detects your US server is down and automatically routes traffic to your EU backup server — failover routing with no manual intervention.',
            },
            {
              'label': 'Networking',
              'term': 'Availability Zones & Regions',
              'definition':
                  'A Region is a geographic area containing multiple data centres. An Availability Zone (AZ) is one or more data centres within a region, isolated from failures in other AZs. Deploying across AZs gives high availability.',
              'example':
                  'You deploy your app in us-east-1 across 3 AZs. If one data centre loses power, your app keeps running in the other two AZs automatically.',
            },
          ];
        default:
          return _cloudFundamentalsDefault();
      }
    }

    // ── Binary Cloud Pro ───────────────────────────────────────────────────
    if (tag == 'Binary Cloud Pro') {
      switch (moduleId) {
        case 'module-01':
          return [
            {
              'label': 'Architecture',
              'term': 'Well-Architected Framework',
              'definition':
                  'The AWS Well-Architected Framework defines best practices across six pillars: Operational Excellence, Security, Reliability, Performance Efficiency, Cost Optimisation, and Sustainability.',
              'example':
                  'Before launching a production system, a cloud architect reviews each pillar — ensuring the design is secure, will recover from failures, performs well, and doesn\'t waste money.',
            },
            {
              'label': 'Architecture',
              'term': 'High Availability (HA)',
              'definition':
                  'High Availability is the ability of a system to remain operational and accessible with minimal downtime. It is achieved through redundancy — deploying across multiple AZs, regions, or servers so a single failure doesn\'t take the system offline.',
              'example':
                  'Your database runs as a primary in us-east-1a and a standby replica in us-east-1b. If the primary fails, the standby promotes automatically in under 60 seconds.',
            },
            {
              'label': 'Architecture',
              'term': 'Fault Tolerance vs High Availability',
              'definition':
                  'High Availability minimises downtime (brief interruption possible). Fault Tolerance means the system continues operating with zero interruption even when a component fails — it requires full redundancy at every layer.',
              'example':
                  'HA: your site has a 30-second failover. Fault tolerant: your site has redundant hardware so failure of any single component causes zero user impact.',
            },
            {
              'label': 'Architecture',
              'term': 'Loose Coupling',
              'definition':
                  'Loose coupling designs systems so components interact through well-defined interfaces and are not tightly dependent on each other. If one component fails or changes, it doesn\'t cascade failures to others.',
              'example':
                  'Instead of your order service calling your inventory service directly, both publish and subscribe to an SQS queue. The inventory service can be restarted without the order service knowing.',
            },
            {
              'label': 'Architecture',
              'term': 'Infrastructure as Code (IaC)',
              'definition':
                  'IaC manages and provisions cloud infrastructure through machine-readable configuration files instead of manual processes. It enables version control, reproducibility, and automated deployments.',
              'example':
                  'A Terraform file defines your entire AWS environment — VPCs, EC2 instances, RDS databases. Running "terraform apply" builds everything in minutes, identically every time.',
            },
          ];
        case 'module-02':
          return [
            {
              'label': 'Advanced compute',
              'term': 'Containers & Docker',
              'definition':
                  'A container packages an application and all its dependencies into a single portable unit. Unlike VMs, containers share the host OS kernel — they start in seconds and use far less memory.',
              'example':
                  'Your Node.js app runs in a Docker container. The same container image runs identically on your laptop, in CI/CD, and in production — eliminating "works on my machine" problems.',
            },
            {
              'label': 'Advanced compute',
              'term': 'Kubernetes (K8s)',
              'definition':
                  'Kubernetes is a container orchestration platform that automates deployment, scaling, and management of containerised applications. It ensures containers are always running, restarts failed ones, and distributes load.',
              'example':
                  'You deploy 10 replicas of your API container to K8s. K8s distributes them across nodes, restarts any that crash, and scales to 50 replicas during peak traffic.',
            },
            {
              'label': 'Advanced compute',
              'term': 'Serverless Architecture',
              'definition':
                  'Serverless architecture composes applications entirely from managed services and functions, with no servers to provision or maintain. It scales to zero (no cost when idle) and infinitely.',
              'example':
                  'API Gateway receives a request → triggers a Lambda function → Lambda writes to DynamoDB → result returned. No servers, no idle cost, scales to millions of requests automatically.',
            },
            {
              'label': 'Advanced compute',
              'term': 'Spot / Preemptible Instances',
              'definition':
                  'Spot instances (AWS) or Preemptible VMs (GCP) are spare cloud capacity sold at up to 90% discount. The catch: the provider can reclaim them with 2 minutes notice when capacity is needed elsewhere.',
              'example':
                  'Your ML training job uses Spot instances to cut costs by 70%. The job checkpoints progress so if a Spot instance is reclaimed, it resumes from where it left off.',
            },
            {
              'label': 'Advanced compute',
              'term': 'Reserved vs On-Demand Instances',
              'definition':
                  'On-Demand: pay full price per hour, no commitment. Reserved Instances: commit to 1 or 3 years for up to 72% discount. Savings Plans offer similar discounts with more flexibility.',
              'example':
                  'Your database runs 24/7 — buy a 1-year Reserved Instance and save 40%. Your dev environment runs 9-5 only — use On-Demand so you\'re not paying for idle nights.',
            },
          ];
        case 'module-03':
          return [
            {
              'label': 'Storage',
              'term': 'S3 Storage Classes',
              'definition':
                  'S3 offers multiple storage classes: Standard (frequent access), Infrequent Access (monthly access, cheaper), Glacier (archival, hours to retrieve), and Glacier Deep Archive (cheapest, 12-hour retrieval).',
              'example':
                  'Store active user photos in S3 Standard. Move photos not accessed in 90 days to S3-IA automatically. Archive compliance documents to Glacier for \$0.004/GB/month.',
            },
            {
              'label': 'Database',
              'term': 'Relational vs NoSQL in the Cloud',
              'definition':
                  'Relational databases (RDS, Cloud SQL) use structured tables with SQL — ideal for transactions and complex queries. NoSQL (DynamoDB, Firestore) uses flexible schemas — ideal for high-speed, high-scale key-value or document access.',
              'example':
                  'Use RDS for financial transactions that need ACID compliance. Use DynamoDB for user sessions that need single-digit millisecond reads at millions of requests per second.',
            },
            {
              'label': 'Database',
              'term': 'Read Replicas & Sharding',
              'definition':
                  'Read replicas offload read traffic from the primary database to one or more replica copies. Sharding horizontally partitions data across multiple database instances, distributing both storage and read/write load.',
              'example':
                  'Your e-commerce site\'s primary RDS handles all writes. 3 read replicas serve product browsing queries, reducing primary load by 80%.',
            },
            {
              'label': 'Storage',
              'term': 'Data Lakes & Warehouses',
              'definition':
                  'A data lake stores raw, unstructured data at massive scale (e.g. S3). A data warehouse stores structured, processed data optimised for analytics queries (e.g. Redshift, BigQuery).',
              'example':
                  'Raw clickstream events land in S3 (data lake). An ETL pipeline processes and loads them into Redshift (warehouse) where analysts run SQL reports.',
            },
            {
              'label': 'Storage',
              'term': 'Backup & Disaster Recovery Strategies',
              'definition':
                  'RTO (Recovery Time Objective) is the maximum acceptable downtime. RPO (Recovery Point Objective) is the maximum acceptable data loss. DR strategies range from Backup & Restore (cheapest) to Multi-Site Active-Active (instant).',
              'example':
                  'RTO: 4 hours, RPO: 1 hour means you must be back online within 4 hours and can lose at most 1 hour of data. This drives your backup frequency and standby configuration.',
            },
          ];
        case 'module-04':
          return [
            {
              'label': 'Advanced security',
              'term': 'Zero Trust in the Cloud',
              'definition':
                  'Zero Trust assumes no implicit trust based on network location. Every request must be authenticated, authorised, and encrypted. It replaces the traditional "castle and moat" perimeter model.',
              'example':
                  'Even a request from an internal microservice must present a valid JWT token. The receiving service verifies it against an identity provider before processing.',
            },
            {
              'label': 'Advanced security',
              'term': 'Cloud Security Posture Management (CSPM)',
              'definition':
                  'CSPM tools continuously monitor cloud environments for misconfigurations, policy violations, and compliance drift. They provide visibility across accounts and auto-remediate common issues.',
              'example':
                  'Your CSPM tool detects an S3 bucket was accidentally made public, alerts your security team immediately, and automatically reverts the ACL to private.',
            },
            {
              'label': 'Advanced security',
              'term': 'Secrets Management',
              'definition':
                  'Secrets management is the practice of securely storing, accessing, and rotating sensitive credentials using dedicated services rather than hardcoding them in code.',
              'example':
                  'AWS Secrets Manager stores your database password. Your Lambda function fetches it at runtime — the password is never in your code, environment variables, or Git.',
            },
            {
              'label': 'Advanced security',
              'term': 'DDoS Protection in the Cloud',
              'definition':
                  'Cloud providers offer DDoS protection at multiple layers: network-level (absorbing volumetric attacks) and application-level (WAF rules blocking malicious HTTP traffic).',
              'example':
                  'AWS Shield Advanced protects your ALB from volumetric attacks. AWS WAF sits in front of CloudFront, blocking SQL injection and XSS attempts before they reach your app.',
            },
            {
              'label': 'Advanced security',
              'term': 'Penetration Testing in the Cloud',
              'definition':
                  'Cloud pen testing follows the same principles as traditional pen testing but must comply with provider policies. AWS, Azure, and GCP allow pen testing on your own resources but prohibit testing shared infrastructure.',
              'example':
                  'Your team runs a pen test against your AWS environment — testing EC2 instances, API Gateway endpoints, and S3 configurations — all permitted under AWS\'s pen testing policy.',
            },
          ];
        case 'module-05':
          return [
            {
              'label': 'DevOps',
              'term': 'CI/CD Pipeline',
              'definition':
                  'CI (Continuous Integration) automatically builds and tests code on every commit. CD (Continuous Delivery/Deployment) automatically deploys tested code to staging or production.',
              'example':
                  'Developer pushes code → GitHub Actions runs unit tests → Docker image built → pushed to ECR → ECS deploys the new version. All automated, taking under 10 minutes.',
            },
            {
              'label': 'DevOps',
              'term': 'Blue/Green Deployment',
              'definition':
                  'Blue/Green deployment maintains two identical environments. Traffic switches instantly from the current version (blue) to the new version (green), with instant rollback capability.',
              'example':
                  'v1.0 runs on blue. v2.0 is deployed to green and smoke tested. Load balancer shifts 100% traffic to green. If issues arise, one click reverts to blue.',
            },
            {
              'label': 'DevOps',
              'term': 'Canary Releases',
              'definition':
                  'A canary release sends a small percentage of traffic to the new version while the majority stays on the old version. If the new version performs well, the percentage gradually increases to 100%.',
              'example':
                  'v2.0 receives 5% of traffic. Metrics look good after 30 minutes. Traffic increases to 25%, then 50%, then 100% over the following hours.',
            },
            {
              'label': 'DevOps',
              'term': 'GitOps',
              'definition':
                  'GitOps uses Git as the single source of truth for infrastructure and application configuration. All changes are made via pull requests. Automated agents reconcile the actual state with the desired state in Git.',
              'example':
                  'An engineer opens a PR changing the replica count from 3 to 5 in a YAML file. After approval and merge, ArgoCD automatically updates the Kubernetes cluster to match.',
            },
            {
              'label': 'DevOps',
              'term': 'Observability: Metrics, Logs & Traces',
              'definition':
                  'Observability is the ability to understand the internal state of a system from its external outputs. It has three pillars: Metrics (numerical measurements), Logs (timestamped events), Traces (request journeys).',
              'example':
                  'Metric: API latency is 800ms (too slow). Log: shows a specific query taking 750ms. Trace: reveals the slow query is happening in the payment service on checkout.',
            },
          ];
        case 'module-06':
          return [
            {
              'label': 'Cost optimisation',
              'term': 'Cloud Cost Optimisation Strategies',
              'definition':
                  'Cloud cost optimisation involves right-sizing resources, eliminating waste, choosing the right pricing model, and using managed services. The goal is maximum business value at minimum cost.',
              'example':
                  'An audit reveals 40 idle EC2 instances running 24/7. Scheduling them to shut down nights and weekends saves 65% on compute costs immediately.',
            },
            {
              'label': 'Cost optimisation',
              'term': 'Right-Sizing',
              'definition':
                  'Right-sizing is the process of matching instance types and sizes to actual workload requirements. Over-provisioning wastes money; under-provisioning causes performance issues.',
              'example':
                  'Your database uses 8-core, 64GB RAM instances but CPU never exceeds 10%. Downsizing to 4-core, 32GB saves 40% with no performance impact.',
            },
            {
              'label': 'Cost optimisation',
              'term': 'Tagging Strategy',
              'definition':
                  'Resource tagging assigns metadata labels to cloud resources (e.g. environment, team, project). Tags enable cost allocation reporting, showing which teams and projects are driving cloud spend.',
              'example':
                  'Every resource is tagged with "team: checkout" or "team: payments". The monthly bill is automatically broken down by team, enabling chargeback and budget accountability.',
            },
            {
              'label': 'Cost optimisation',
              'term': 'FinOps',
              'definition':
                  'FinOps (Cloud Financial Operations) brings financial accountability to cloud spending. It aligns engineering, finance, and business teams to make data-driven spending decisions in real time.',
              'example':
                  'The FinOps team creates a dashboard showing real-time cloud spend by service and team. Engineers see the cost impact of their changes before deploying.',
            },
            {
              'label': 'Cost optimisation',
              'term': 'Savings Plans & Committed Use Discounts',
              'definition':
                  'Savings Plans (AWS) and Committed Use Discounts (GCP/Azure) offer significant discounts in exchange for committing to a minimum spend or usage level over 1 or 3 years.',
              'example':
                  'You commit to spending \$1,000/month on AWS compute for 1 year. In return, you get a 40% discount on all covered compute usage — saving \$4,800 over the year.',
            },
          ];
        case 'module-07':
          return [
            {
              'label': 'Migration',
              'term': 'The 6 Rs of Cloud Migration',
              'definition':
                  'The 6 Rs are migration strategies: Rehost (lift & shift), Replatform (lift & tweak), Repurchase (move to SaaS), Refactor/Re-architect (redesign for cloud), Retire (decommission), Retain (keep on-prem).',
              'example':
                  'Rehost: move your app VM to EC2 unchanged. Replatform: move it to Elastic Beanstalk with minor changes. Refactor: rebuild it as microservices on Lambda. Retire: decommission the legacy CRM no one uses.',
            },
            {
              'label': 'Migration',
              'term': 'Database Migration Challenges',
              'definition':
                  'Migrating databases involves schema conversion, data transfer with minimal downtime, and handling differences between database engines. AWS DMS and Azure Database Migration Service automate much of this.',
              'example':
                  'You use AWS DMS to replicate your on-prem Oracle database to Aurora PostgreSQL in real time. Cutover takes 5 minutes with no data loss.',
            },
            {
              'label': 'Multi-cloud',
              'term': 'Multi-Cloud Architecture Patterns',
              'definition':
                  'Multi-cloud patterns include: Cloud-agnostic (using only portable services), Best-of-breed (picking best service per provider), and Segmented (different workloads on different clouds).',
              'example':
                  'ML workloads run on GCP (best ML tooling). Customer data stays on Azure (compliance). The public website runs on AWS (best CDN and global reach).',
            },
            {
              'label': 'Multi-cloud',
              'term': 'Service Mesh',
              'definition':
                  'A service mesh (e.g. Istio, Linkerd) manages communication between microservices, providing traffic management, mutual TLS, observability, and circuit breaking — without changing application code.',
              'example':
                  'Istio automatically encrypts all traffic between your 20 microservices with mTLS, collects latency metrics for each service call, and retries failed requests — all transparently.',
            },
            {
              'label': 'Migration',
              'term': 'Cloud Landing Zone',
              'definition':
                  'A landing zone is a pre-configured, secure, scalable cloud environment that serves as the foundation for an organisation\'s cloud adoption. It establishes governance, networking, security, and account structure from day one.',
              'example':
                  'Before any team deploys anything, the platform team builds a landing zone with separate accounts per environment, centralised logging, guardrails, and SSO.',
            },
          ];
        case 'module-08':
          return [
            {
              'label': 'Career',
              'term': 'AWS Certification Roadmap',
              'definition':
                  'AWS certifications start at Foundational (Cloud Practitioner), then Associate (Solutions Architect, Developer, SysOps), then Professional (Solutions Architect Pro, DevOps Pro), and Specialty tracks.',
              'example':
                  'Start with AWS Cloud Practitioner to understand basics. Then pursue Solutions Architect Associate. Then Solutions Architect Professional for advanced design.',
            },
            {
              'label': 'Career',
              'term': 'Cloud Roles & Responsibilities',
              'definition':
                  'Cloud roles include: Cloud Architect (designs systems), Cloud Engineer (builds and operates), DevOps Engineer (CI/CD and automation), Cloud Security Engineer (secures environments), FinOps Analyst (optimises costs).',
              'example':
                  'A Cloud Architect designs the multi-region architecture. The Cloud Engineer implements it in Terraform. The DevOps Engineer builds the deployment pipeline. The Security Engineer audits IAM policies.',
            },
            {
              'label': 'Career',
              'term': 'SLA, SLO & SLI',
              'definition':
                  'SLA (Service Level Agreement) is a contract with the customer. SLO (Service Level Objective) is the internal target. SLI (Service Level Indicator) is the metric you measure. SLOs should be stricter than SLAs.',
              'example':
                  'SLA: 99.9% uptime to customers. SLO: internal target of 99.95%. SLI: actual measured availability from monitoring. You need SLI > SLO to meet your SLA with a safety buffer.',
            },
            {
              'label': 'Career',
              'term': 'Total Cost of Ownership (TCO)',
              'definition':
                  'TCO analysis compares the full cost of on-premises vs cloud over time, including hardware, power, cooling, staffing, facilities, and maintenance.',
              'example':
                  'A server costs \$10,000 to buy. Add rack space, power, cooling, insurance, and 3 years of admin time — total TCO is \$38,000. Equivalent cloud capacity over 3 years: \$22,000.',
            },
            {
              'label': 'Career',
              'term': 'Cloud-Native vs Cloud-Enabled',
              'definition':
                  'Cloud-native applications are designed from the ground up for the cloud — using microservices, containers, serverless, and managed services. Cloud-enabled applications are legacy apps moved to the cloud with minimal changes.',
              'example':
                  'Cloud-native: a new app built with Lambda, DynamoDB, and API Gateway. Cloud-enabled: a 10-year-old monolithic Java app moved from a physical server to an EC2 instance unchanged.',
            },
          ];
        default:
          return _cloudProDefault();
      }
    }

    // ── CSM ────────────────────────────────────────────────────────────────
    if (tag == 'CSM') {
      return [
        {
          'label': 'Definition',
          'term': 'What is Scrum?',
          'definition':
              'Scrum is an agile framework for developing, delivering, and sustaining complex products. It uses short cycles called Sprints to deliver work in small, usable increments.',
          'example':
              'A software team works in 2-week sprints, releasing a working feature at the end of each sprint.',
        },
        {
          'label': 'Core role',
          'term': 'Scrum Master',
          'definition':
              'The Scrum Master is a servant-leader who helps the team follow Scrum practices. They remove obstacles, facilitate events, and protect the team from interruptions.',
          'example':
              'If the team is blocked waiting on approval, the Scrum Master steps in to resolve it.',
        },
        {
          'label': 'Core role',
          'term': 'Product Owner',
          'definition':
              'The Product Owner is responsible for maximizing the value of the product. They manage and prioritize the Product Backlog.',
          'example':
              'The Product Owner decides that fixing a login bug is more important than adding a new feature this sprint.',
        },
        {
          'label': 'Event',
          'term': 'Sprint',
          'definition':
              'A Sprint is a time-boxed period of one month or less during which a Done, usable, and potentially releasable product increment is created.',
          'example':
              'Each sprint starts with planning and ends with a review and retrospective.',
        },
        {
          'label': 'Artifact',
          'term': 'Product Backlog',
          'definition':
              'An ordered list of everything that might be needed in the product. It is the single source of requirements for any changes.',
          'example':
              'Items include features, bug fixes, and technical improvements, ranked by priority.',
        },
      ];
    }

    // ── Default networking fallback ────────────────────────────────────────
    return [
      {
        'label': 'Definition',
        'term': 'What is a Network?',
        'definition':
            'A network is a collection of computers, servers, and other devices connected together to share resources and communicate.',
        'example':
            'Your home WiFi connects your phone, laptop, and TV — that is a local area network (LAN).',
      },
      {
        'label': 'Core concept',
        'term': 'IP Address',
        'definition':
            'An IP address is a unique numerical label assigned to each device connected to a network. It identifies the device and its location.',
        'example':
            'Your computer IP might be 192.168.1.5 on your home network.',
      },
      {
        'label': 'Core concept',
        'term': 'DNS',
        'definition':
            'DNS translates human-readable domain names like google.com into IP addresses that computers use to identify each other.',
        'example':
            'When you type google.com, DNS translates it to an IP like 142.250.80.46.',
      },
      {
        'label': 'Core concept',
        'term': 'TCP/IP',
        'definition':
            'TCP/IP is the foundational communication protocol of the internet. TCP handles data packaging and delivery confirmation, while IP handles addressing and routing.',
        'example':
            'When you send an email, TCP breaks it into packets, IP routes them, and TCP confirms they all arrived.',
      },
      {
        'label': 'Key term',
        'term': 'Router',
        'definition':
            'A router forwards data packets between networks. It directs internet traffic and connects your local network to the internet.',
        'example':
            'The box your ISP gave you is a router — it connects your home devices to the internet.',
      },
    ];
  }

  // ── Fallback defaults ──────────────────────────────────────────────────────
  List<Map<String, String>> _itilV4Default() => [
    {
      'label': 'Definition',
      'term': 'What is ITIL V4?',
      'definition':
          'ITIL V4 is a framework of best practices for IT Service Management (ITSM). It provides guidance on designing, delivering, and improving IT services to create value for organisations and their customers.',
      'example':
          'Exam trap: ITIL V4 is guidance — not a mandatory standard. Organisations adopt and adapt it to their context.',
    },
  ];

  List<Map<String, String>> _cloudFundamentalsDefault() => [
    {
      'label': 'Definition',
      'term': 'What is cloud computing?',
      'definition':
          'Cloud computing delivers computing services over the internet — servers, storage, databases, and software — on a pay-as-you-go basis.',
      'example':
          'Instead of buying a server, you rent one from AWS and pay only for the hours you use.',
    },
  ];

  List<Map<String, String>> _cloudProDefault() => [
    {
      'label': 'Architecture',
      'term': 'Well-Architected Framework',
      'definition':
          'A set of best practices across six pillars: Operational Excellence, Security, Reliability, Performance Efficiency, Cost Optimisation, and Sustainability.',
      'example':
          'Before launching, an architect reviews each pillar to ensure the design is secure, resilient, and cost-effective.',
    },
  ];
}
