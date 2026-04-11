import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lesson_screen.dart';
import 'app_theme.dart';

class CourseDetailScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final double progress;
  final Color color;
  final String tag;

  const CourseDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.color,
    required this.tag,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  List<Map<String, dynamic>> _modules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );
    _headerSlide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _headerController,
            curve: Curves.easeOutCubic,
          ),
        );
    _headerController.forward();
    _loadModules();
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  String get _courseId {
    switch (widget.tag) {
      case 'ITIL V4':
        return 'itil-v4';
      case 'CSM':
        return 'csm';
      case 'Networking':
        return 'networking';
      default:
        return widget.tag.toLowerCase().replaceAll(' ', '-');
    }
  }

  Future<void> _loadModules() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('courses')
          .doc(_courseId)
          .collection('modules')
          .orderBy('order')
          .get();

      final modules = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'sub': data['subtitle'] ?? '',
          'status': data['status'] ?? 'locked',
          'order': data['order'] ?? 0,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _modules = modules.isNotEmpty
              ? modules
              : _getHardcodedModules(widget.tag);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _modules = _getHardcodedModules(widget.tag);
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getHardcodedModules(String tag) {
    if (tag == 'Binary Cyber Pro') {
      return [
        {
          'id': 'module-01',
          'title': 'Cybersecurity Fundamentals',
          'sub': 'CIA triad, threat landscape & core principles',
          'status': 'active',
          'order': 1,
        },
        {
          'id': 'module-02',
          'title': 'Network Security',
          'sub': 'Firewalls, IDS/IPS, VPNs & secure protocols',
          'status': 'locked',
          'order': 2,
        },
        {
          'id': 'module-03',
          'title': 'Cryptography',
          'sub': 'Encryption, hashing, PKI & digital signatures',
          'status': 'locked',
          'order': 3,
        },
        {
          'id': 'module-04',
          'title': 'Ethical Hacking & Pen Testing',
          'sub': 'Recon, exploitation, tools & methodology',
          'status': 'locked',
          'order': 4,
        },
        {
          'id': 'module-05',
          'title': 'Malware & Threats',
          'sub': 'Viruses, ransomware, trojans & attack vectors',
          'status': 'locked',
          'order': 5,
        },
        {
          'id': 'module-06',
          'title': 'Web Application Security',
          'sub': 'OWASP Top 10, SQLi, XSS & secure coding',
          'status': 'locked',
          'order': 6,
        },
        {
          'id': 'module-07',
          'title': 'Identity & Access Management',
          'sub': 'Authentication, MFA, OAuth & zero trust',
          'status': 'locked',
          'order': 7,
        },
        {
          'id': 'module-08',
          'title': 'Incident Response & Compliance',
          'sub': 'IR lifecycle, GDPR, SOC 2 & forensics basics',
          'status': 'locked',
          'order': 8,
        },
      ];
    } else if (tag == 'ITIL V4') {
      return [
        {
          'id': 'module-01',
          'title': 'Introduction to ITIL V4',
          'sub': 'History, purpose & key concepts',
          'status': 'active',
          'order': 1,
        },
        {
          'id': 'module-02',
          'title': 'Service Value System',
          'sub': 'SVS components & the value chain',
          'status': 'locked',
          'order': 2,
        },
        {
          'id': 'module-03',
          'title': 'Guiding Principles',
          'sub': 'The 7 principles of ITIL V4',
          'status': 'locked',
          'order': 3,
        },
        {
          'id': 'module-04',
          'title': 'The 4 Dimensions',
          'sub': 'People, technology, partners & processes',
          'status': 'locked',
          'order': 4,
        },
        {
          'id': 'module-05',
          'title': 'Key Practices',
          'sub': 'Incident, change & service desk management',
          'status': 'locked',
          'order': 5,
        },
      ];
    } else if (tag == 'CSM') {
      return [
        {
          'id': 'module-01',
          'title': 'Agile & Scrum Basics',
          'sub': 'Agile values, principles & Scrum overview',
          'status': 'active',
          'order': 1,
        },
        {
          'id': 'module-02',
          'title': 'Scrum Roles',
          'sub': 'Product Owner, Scrum Master & Dev Team',
          'status': 'locked',
          'order': 2,
        },
        {
          'id': 'module-03',
          'title': 'Scrum Events',
          'sub': 'Sprints, planning, reviews & retrospectives',
          'status': 'locked',
          'order': 3,
        },
        {
          'id': 'module-04',
          'title': 'Scrum Artifacts',
          'sub': 'Backlog, sprint backlog & increment',
          'status': 'locked',
          'order': 4,
        },
        {
          'id': 'module-05',
          'title': 'Scaling & Advanced Scrum',
          'sub': 'SAFe, LeSS & real-world application',
          'status': 'locked',
          'order': 5,
        },
      ];
    } else if (tag == 'Networking' || tag == 'Binary Network Pro') {
      return [
        {
          'id': 'module-01',
          'title': 'Network Architecture & Topologies',
          'sub': 'Star, mesh, spine-leaf & three-tier design',
          'status': 'active',
          'order': 1,
        },
        {
          'id': 'module-02',
          'title': 'OSI Model & TCP/IP Deep Dive',
          'sub': 'ARP, TCP handshake, QoS & HSRP',
          'status': 'locked',
          'order': 2,
        },
        {
          'id': 'module-03',
          'title': 'IP Addressing, Subnetting & VLSM',
          'sub': 'IPv4, IPv6, NAT/PAT & APIPA',
          'status': 'locked',
          'order': 3,
        },
        {
          'id': 'module-04',
          'title': 'Routing Protocols & WAN',
          'sub': 'OSPF, BGP, EIGRP & PBR',
          'status': 'locked',
          'order': 4,
        },
        {
          'id': 'module-05',
          'title': 'Switching, VLANs & Spanning Tree',
          'sub': 'CAM, DHCP snooping, DAI & BPDU Guard',
          'status': 'locked',
          'order': 5,
        },
      ];
    } else if (tag == 'Binary Cloud') {
      return [
        {
          'id': 'module-01',
          'title': 'What is Cloud Computing?',
          'sub': 'Core concepts, CapEx vs OpEx & the 5 characteristics',
          'status': 'active',
          'order': 1,
        },
        {
          'id': 'module-02',
          'title': 'Cloud Service Models',
          'sub': 'IaaS, PaaS, SaaS & serverless explained',
          'status': 'locked',
          'order': 2,
        },
        {
          'id': 'module-03',
          'title': 'Cloud Deployment Models',
          'sub': 'Public, private, hybrid & multi-cloud',
          'status': 'locked',
          'order': 3,
        },
        {
          'id': 'module-04',
          'title': 'Core Cloud Services',
          'sub': 'Compute, storage, databases & CDNs',
          'status': 'locked',
          'order': 4,
        },
        {
          'id': 'module-05',
          'title': 'Cloud Security Basics',
          'sub': 'Shared responsibility, IAM & encryption',
          'status': 'locked',
          'order': 5,
        },
        {
          'id': 'module-06',
          'title': 'Cloud Networking',
          'sub': 'VPCs, subnets, load balancers & availability zones',
          'status': 'locked',
          'order': 6,
        },
      ];
    } else if (tag == 'Binary Cloud Pro') {
      return [
        {
          'id': 'module-01',
          'title': 'Cloud Architecture Principles',
          'sub': 'Well-Architected, HA, fault tolerance & IaC',
          'status': 'active',
          'order': 1,
        },
        {
          'id': 'module-02',
          'title': 'Advanced Compute',
          'sub': 'Containers, Kubernetes, serverless & instance pricing',
          'status': 'locked',
          'order': 2,
        },
        {
          'id': 'module-03',
          'title': 'Cloud Storage & Databases',
          'sub': 'S3 tiers, NoSQL, read replicas & DR strategies',
          'status': 'locked',
          'order': 3,
        },
        {
          'id': 'module-04',
          'title': 'Advanced Cloud Security',
          'sub': 'Zero trust, CSPM, secrets management & WAF',
          'status': 'locked',
          'order': 4,
        },
        {
          'id': 'module-05',
          'title': 'DevOps & CI/CD',
          'sub': 'Pipelines, blue/green, canary & GitOps',
          'status': 'locked',
          'order': 5,
        },
        {
          'id': 'module-06',
          'title': 'Cost Optimisation',
          'sub': 'Right-sizing, FinOps, tagging & savings plans',
          'status': 'locked',
          'order': 6,
        },
        {
          'id': 'module-07',
          'title': 'Multi-Cloud & Migration',
          'sub': 'The 6 Rs, service mesh & landing zones',
          'status': 'locked',
          'order': 7,
        },
        {
          'id': 'module-08',
          'title': 'Cloud Careers & Certifications',
          'sub': 'AWS roadmap, roles, SLAs & TCO',
          'status': 'locked',
          'order': 8,
        },
      ];
    }
    return [
      {
        'id': 'module-01',
        'title': 'Introduction',
        'sub': 'Getting started',
        'status': 'active',
        'order': 1,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    // ── Pull theme so every color responds to light/dark toggle ──
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context, theme),
          _buildProgressBar(theme),
          if (_loading)
            SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: widget.color,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            _buildModuleList(context, _modules, theme),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ThemeNotifier theme) {
    return SliverToBoxAdapter(
      child: Stack(
        children: [
          // ── Gradient header — adapts colour intensity per mode ──
          Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.color.withValues(alpha: theme.isDark ? 0.22 : 0.12),
                  widget.color.withValues(alpha: theme.isDark ? 0.04 : 0.02),
                  theme.bg,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _headerFade,
              child: SlideTransition(
                position: _headerSlide,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BackButton(
                        color: widget.color,
                        theme: theme,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 32),
                      _TagPill(tag: widget.tag, color: widget.color),
                      const SizedBox(height: 14),
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: theme.text,
                          letterSpacing: -1.2,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 15,
                          color: theme.subtext,
                          letterSpacing: -0.2,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(ThemeNotifier theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your progress',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.subtext,
                    letterSpacing: -0.1,
                  ),
                ),
                Text(
                  '${(widget.progress * 100).toInt()}% complete',
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: widget.progress,
                backgroundColor: theme.isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.lightBorder,
                valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleList(
    BuildContext context,
    List<Map<String, dynamic>> modules,
    ThemeNotifier theme,
  ) {
    if (modules.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No modules found.',
              style: TextStyle(fontSize: 14, color: theme.subtext),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _AnimatedModule(
            delay: Duration(milliseconds: 60 * index),
            child: _buildModuleCard(context, modules[index], index, theme),
          ),
          childCount: modules.length,
        ),
      ),
    );
  }

  Widget _buildModuleCard(
    BuildContext context,
    Map<String, dynamic> module,
    int index,
    ThemeNotifier theme,
  ) {
    final status = module['status'] as String;
    final isLocked = status == 'locked';
    final isDone = status == 'done';
    final isActive = status == 'active';

    final statusColor = isLocked
        ? theme.subtext.withValues(alpha: 0.4)
        : isDone
        ? AppColors.green
        : widget.color;

    // ── Card decoration adapts to theme ──
    BoxDecoration cardDecoration;
    if (theme.isDark) {
      cardDecoration = BoxDecoration(
        color: isActive
            ? widget.color.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? widget.color.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
        ),
      );
    } else {
      cardDecoration = BoxDecoration(
        color: isActive
            ? widget.color.withValues(alpha: 0.05)
            : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? widget.color.withValues(alpha: 0.25)
              : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: isLocked
          ? null
          : () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, animation, __) => LessonScreen(
                    moduleTitle: module['title'],
                    courseTag: widget.tag,
                    color: widget.color,
                    moduleId: module['id'],
                    courseId: _courseId,
                  ),
                  transitionsBuilder: (_, animation, __, child) =>
                      SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(1, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                  transitionDuration: const Duration(milliseconds: 400),
                ),
              );
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(18),
        decoration: cardDecoration,
        child: Row(
          children: [
            // ── Status indicator circle ──
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: isDone
                    ? Icon(Icons.check_rounded, size: 18, color: statusColor)
                    : isLocked
                    ? Icon(
                        Icons.lock_outline_rounded,
                        size: 15,
                        color: statusColor,
                      )
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module['title'],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isLocked ? theme.subtext : theme.text,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    module['sub'],
                    style: TextStyle(fontSize: 12, color: theme.subtext),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // ── Right-side action ──
            if (isDone)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.green,
                  ),
                ),
              )
            else if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              )
            else
              Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: theme.subtext.withValues(alpha: 0.5),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Back button ───────────────────────────────────────────────────────────────
class _BackButton extends StatefulWidget {
  final Color color;
  final ThemeNotifier theme;
  final VoidCallback onTap;
  const _BackButton({
    required this.color,
    required this.theme,
    required this.onTap,
  });
  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.88,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.color.withValues(
              alpha: widget.theme.isDark ? 0.10 : 0.08,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.color.withValues(
                alpha: widget.theme.isDark ? 0.20 : 0.25,
              ),
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
                'Courses',
                style: TextStyle(
                  fontSize: 14,
                  color: widget.color,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tag pill ──────────────────────────────────────────────────────────────────
class _TagPill extends StatefulWidget {
  final String tag;
  final Color color;
  const _TagPill({required this.tag, required this.color});
  @override
  State<_TagPill> createState() => _TagPillState();
}

class _TagPillState extends State<_TagPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.color.withValues(alpha: 0.25)),
          ),
          child: Text(
            widget.tag.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: widget.color,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Scroll-reveal animation ───────────────────────────────────────────────────
class _AnimatedModule extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _AnimatedModule({required this.child, this.delay = Duration.zero});
  @override
  State<_AnimatedModule> createState() => _AnimatedModuleState();
}

class _AnimatedModuleState extends State<_AnimatedModule>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}
