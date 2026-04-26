import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lesson_screen.dart';
import 'paywall_screen.dart';
import 'offline_service.dart';
import 'subscription_service.dart';
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
  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0;

  // Whether this user has purchased access to this course (any plan that
  // unlocks it). Drives whether modules 2+ are 'active' or 'locked'.
  bool _hasPaidAccess = false;

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
    _headerSlide =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: Curves.easeOutCubic,
      ),
    );
    _headerController.forward();
    _loadModules();
    _checkDownloadStatus();
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

  Future<void> _checkDownloadStatus() async {
    final downloaded = await OfflineService.isCourseDownloaded(_courseId);
    if (mounted) setState(() => _isDownloaded = downloaded);
  }

  Future<void> _toggleDownload() async {
    if (_isDownloading) return;
    HapticFeedback.mediumImpact();

    if (_isDownloaded) {
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Remove download?'),
          content:
              Text('This will remove the offline content for ${widget.title}.'),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await OfflineService.deleteCourse(
        courseId: _courseId,
        moduleIds: _modules.map((m) => m['id'] as String).toList(),
      );
      if (mounted) setState(() => _isDownloaded = false);
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    await OfflineService.downloadCourse(
      courseId: _courseId,
      modules: _modules,
      onProgress: (done, total) {
        if (mounted) {
          setState(() => _downloadProgress = done / total);
        }
      },
    );

    if (mounted) {
      setState(() {
        _isDownloading = false;
        _isDownloaded = true;
      });
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.title} downloaded for offline use.'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _loadModules() async {
    try {
      // Check whether user has paid access to this course (single, bundle, all)
      _hasPaidAccess = await SubscriptionService.canAccessCourse(_courseId);

      // Load shared module definitions (order, title, subtitle)
      final snapshot = await FirebaseFirestore.instance
          .collection('courses')
          .doc(_courseId)
          .collection('modules')
          .orderBy('order')
          .get();

      // Load THIS user's per-module progress
      final uid = FirebaseAuth.instance.currentUser?.uid;
      Map<String, String> userModuleStatus = {};
      if (uid != null) {
        final userModulesSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('progress')
            .doc(_courseId)
            .collection('modules')
            .get();
        userModuleStatus = {
          for (final d in userModulesSnap.docs)
            d.id: (d.data()['status'] as String? ?? 'locked')
        };
      }

      final modules = snapshot.docs.asMap().entries.map((entry) {
        final index = entry.key;
        final doc = entry.value;
        final data = doc.data();

        final status = _resolveStatus(
          moduleId: doc.id,
          index: index,
          userProgress: userModuleStatus,
        );

        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'sub': data['subtitle'] ?? '',
          'status': status,
          'order': data['order'] ?? 0,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _modules = modules.isNotEmpty
              ? modules
              : _applyAccessGateToHardcoded(_getHardcodedModules(widget.tag));
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _modules = _applyAccessGateToHardcoded(_getHardcodedModules(widget.tag));
          _loading = false;
        });
      }
    }
  }

  /// Resolve a module's display status, taking into account:
  /// - First module is always free (preview)
  /// - Other modules require paid access
  /// - User's own progress (done / active / locked)
  String _resolveStatus({
    required String moduleId,
    required int index,
    required Map<String, String> userProgress,
  }) {
    final isFirstModule = moduleId == 'module-01' || index == 0;

    // Respect user's recorded status only when they CAN access the module.
    // Prevents a returning user who completed module-02 in a previous purchase
    // (now expired/refunded) from re-opening a paid module.
    final recordedStatus = userProgress[moduleId];
    final canAccess = isFirstModule || _hasPaidAccess;

    if (recordedStatus == 'done' && canAccess) return 'done';
    if (recordedStatus == 'active' && canAccess) return 'active';

    if (canAccess) {
      // No recorded status, but user has access — first module of fresh course
      // shows as 'active', subsequent ones as 'locked' until prior is done.
      return isFirstModule ? 'active' : (recordedStatus ?? 'locked');
    }

    // No paid access AND not the first module → locked behind paywall.
    return 'locked';
  }

  /// For hardcoded fallback modules: respect first-module-free + paid access.
  List<Map<String, dynamic>> _applyAccessGateToHardcoded(
    List<Map<String, dynamic>> modules,
  ) {
    return modules.asMap().entries.map((entry) {
      final index = entry.key;
      final m = Map<String, dynamic>.from(entry.value);
      final id = m['id'] as String;
      final isFirstModule = id == 'module-01' || index == 0;

      if (isFirstModule) {
        m['status'] = 'active';
      } else if (_hasPaidAccess) {
        // Respect the original status if access is granted.
        // (hardcoded modules default to 'locked' which becomes the
        // standard "complete prior module first" gate.)
      } else {
        m['status'] = 'locked';
      }
      return m;
    }).toList();
  }

  /// Open a paywall for this course. Returns true if the user purchased
  /// (so we can refresh access).
  Future<void> _openPaywall() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => PaywallScreen(
          courseId: _courseId,
          courseTitle: widget.title,
          courseColor: widget.color,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );

    // If they purchased, refresh access so locked modules unlock immediately.
    if (result == true && mounted) {
      setState(() => _loading = true);
      await _loadModules();
    }
  }

  List<Map<String, dynamic>> _getHardcodedModules(String tag) {
    if (tag == 'Binary Cyber Pro') {
      return [
        {'id': 'module-01', 'title': 'Cybersecurity Fundamentals', 'sub': 'CIA triad, threat landscape & core principles', 'status': 'active', 'order': 1},
        {'id': 'module-02', 'title': 'Network Security', 'sub': 'Firewalls, IDS/IPS, VPNs & secure protocols', 'status': 'locked', 'order': 2},
        {'id': 'module-03', 'title': 'Cryptography', 'sub': 'Encryption, hashing, PKI & digital signatures', 'status': 'locked', 'order': 3},
        {'id': 'module-04', 'title': 'Ethical Hacking & Pen Testing', 'sub': 'Recon, exploitation, tools & methodology', 'status': 'locked', 'order': 4},
        {'id': 'module-05', 'title': 'Malware & Threats', 'sub': 'Viruses, ransomware, trojans & attack vectors', 'status': 'locked', 'order': 5},
        {'id': 'module-06', 'title': 'Web Application Security', 'sub': 'OWASP Top 10, SQLi, XSS & secure coding', 'status': 'locked', 'order': 6},
        {'id': 'module-07', 'title': 'Identity & Access Management', 'sub': 'Authentication, MFA, OAuth & zero trust', 'status': 'locked', 'order': 7},
        {'id': 'module-08', 'title': 'Incident Response & Compliance', 'sub': 'IR lifecycle, GDPR, SOC 2 & forensics basics', 'status': 'locked', 'order': 8},
      ];
    } else if (tag == 'ITIL V4') {
      return [
        {'id': 'module-01', 'title': 'Introduction to ITIL V4', 'sub': 'History, purpose & key concepts', 'status': 'active', 'order': 1},
        {'id': 'module-02', 'title': 'Service Value System', 'sub': 'SVS components & the value chain', 'status': 'locked', 'order': 2},
        {'id': 'module-03', 'title': 'Guiding Principles', 'sub': 'The 7 principles of ITIL V4', 'status': 'locked', 'order': 3},
        {'id': 'module-04', 'title': 'The 4 Dimensions', 'sub': 'People, technology, partners & processes', 'status': 'locked', 'order': 4},
        {'id': 'module-05', 'title': 'Key Practices', 'sub': 'Incident, change & service desk management', 'status': 'locked', 'order': 5},
      ];
    } else if (tag == 'CSM') {
      return [
        {'id': 'module-01', 'title': 'Agile & Scrum Basics', 'sub': 'Agile values, principles & Scrum overview', 'status': 'active', 'order': 1},
        {'id': 'module-02', 'title': 'Scrum Roles', 'sub': 'Product Owner, Scrum Master & Dev Team', 'status': 'locked', 'order': 2},
        {'id': 'module-03', 'title': 'Scrum Events', 'sub': 'Sprints, planning, reviews & retrospectives', 'status': 'locked', 'order': 3},
        {'id': 'module-04', 'title': 'Scrum Artifacts', 'sub': 'Backlog, sprint backlog & increment', 'status': 'locked', 'order': 4},
        {'id': 'module-05', 'title': 'Scaling & Advanced Scrum', 'sub': 'SAFe, LeSS & real-world application', 'status': 'locked', 'order': 5},
      ];
    } else if (tag == 'Networking' || tag == 'Binary Network Pro') {
      return [
        {'id': 'module-01', 'title': 'Network Architecture & Topologies', 'sub': 'Star, mesh, spine-leaf & three-tier design', 'status': 'active', 'order': 1},
        {'id': 'module-02', 'title': 'OSI Model & TCP/IP Deep Dive', 'sub': 'ARP, TCP handshake, QoS & HSRP', 'status': 'locked', 'order': 2},
        {'id': 'module-03', 'title': 'IP Addressing, Subnetting & VLSM', 'sub': 'IPv4, IPv6, NAT/PAT & APIPA', 'status': 'locked', 'order': 3},
        {'id': 'module-04', 'title': 'Routing Protocols & WAN', 'sub': 'OSPF, BGP, EIGRP & PBR', 'status': 'locked', 'order': 4},
        {'id': 'module-05', 'title': 'Switching, VLANs & Spanning Tree', 'sub': 'CAM, DHCP snooping, DAI & BPDU Guard', 'status': 'locked', 'order': 5},
      ];
    } else if (tag == 'Binary Cloud') {
      return [
        {'id': 'module-01', 'title': 'What is Cloud Computing?', 'sub': 'Core concepts, CapEx vs OpEx & the 5 characteristics', 'status': 'active', 'order': 1},
        {'id': 'module-02', 'title': 'Cloud Service Models', 'sub': 'IaaS, PaaS, SaaS & serverless explained', 'status': 'locked', 'order': 2},
        {'id': 'module-03', 'title': 'Cloud Deployment Models', 'sub': 'Public, private, hybrid & multi-cloud', 'status': 'locked', 'order': 3},
        {'id': 'module-04', 'title': 'Core Cloud Services', 'sub': 'Compute, storage, databases & CDNs', 'status': 'locked', 'order': 4},
        {'id': 'module-05', 'title': 'Cloud Security Basics', 'sub': 'Shared responsibility, IAM & encryption', 'status': 'locked', 'order': 5},
        {'id': 'module-06', 'title': 'Cloud Networking', 'sub': 'VPCs, subnets, load balancers & availability zones', 'status': 'locked', 'order': 6},
      ];
    } else if (tag == 'Binary Cloud Pro') {
      return [
        {'id': 'module-01', 'title': 'Cloud Architecture Principles', 'sub': 'Well-Architected, HA, fault tolerance & IaC', 'status': 'active', 'order': 1},
        {'id': 'module-02', 'title': 'Advanced Compute', 'sub': 'Containers, Kubernetes, serverless & instance pricing', 'status': 'locked', 'order': 2},
        {'id': 'module-03', 'title': 'Cloud Storage & Databases', 'sub': 'S3 tiers, NoSQL, read replicas & DR strategies', 'status': 'locked', 'order': 3},
        {'id': 'module-04', 'title': 'Advanced Cloud Security', 'sub': 'Zero trust, CSPM, secrets management & WAF', 'status': 'locked', 'order': 4},
        {'id': 'module-05', 'title': 'DevOps & CI/CD', 'sub': 'Pipelines, blue/green, canary & GitOps', 'status': 'locked', 'order': 5},
        {'id': 'module-06', 'title': 'Cost Optimisation', 'sub': 'Right-sizing, FinOps, tagging & savings plans', 'status': 'locked', 'order': 6},
        {'id': 'module-07', 'title': 'Multi-Cloud & Migration', 'sub': 'The 6 Rs, service mesh & landing zones', 'status': 'locked', 'order': 7},
        {'id': 'module-08', 'title': 'Cloud Careers & Certifications', 'sub': 'AWS roadmap, roles, SLAs & TCO', 'status': 'locked', 'order': 8},
      ];
    }
    return [
      {'id': 'module-01', 'title': 'Introduction', 'sub': 'Getting started', 'status': 'active', 'order': 1},
    ];
  }

  @override
  Widget build(BuildContext context) {
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _BackButton(
                            color: widget.color,
                            theme: theme,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                            },
                          ),
                          if (!_loading)
                            GestureDetector(
                              onTap: _toggleDownload,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _isDownloaded
                                      ? AppColors.green.withValues(alpha: 0.12)
                                      : widget.color.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _isDownloaded
                                        ? AppColors.green
                                            .withValues(alpha: 0.25)
                                        : widget.color
                                            .withValues(alpha: 0.20),
                                  ),
                                ),
                                child: _isDownloading
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          value: _downloadProgress > 0
                                              ? _downloadProgress
                                              : null,
                                          color: widget.color,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _isDownloaded
                                                ? CupertinoIcons.checkmark_circle_fill
                                                : CupertinoIcons.arrow_down_circle_fill,
                                            size: 14,
                                            color: _isDownloaded
                                                ? AppColors.green
                                                : widget.color,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            _isDownloaded ? 'Downloaded' : 'Download',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: _isDownloaded
                                                  ? AppColors.green
                                                  : widget.color,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                        ],
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
                      // Free preview banner — only show if user hasn't paid
                      if (!_loading && !_hasPaidAccess) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: widget.color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: widget.color.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.gift_fill,
                                size: 14,
                                color: widget.color,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Module 1 is free — try it now',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: widget.color,
                                  letterSpacing: -0.2,
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

    final moduleId = module['id'] as String;
    final isFirstModule = moduleId == 'module-01' || index == 0;

    // A locked non-first-module without paid access = paywall on tap.
    final isLockedBehindPaywall = isLocked && !isFirstModule && !_hasPaidAccess;

    final statusColor = isLocked
        ? theme.subtext.withValues(alpha: 0.4)
        : isDone
            ? AppColors.green
            : widget.color;

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
      onTap: () {
        // 1) Locked because not yet purchased → paywall.
        if (isLockedBehindPaywall) {
          _openPaywall();
          return;
        }
        // 2) Locked for progression reasons (prior module not done) → no-op.
        if (isLocked) return;

        // 3) Otherwise open the lesson.
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
            transitionsBuilder: (_, animation, __, child) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
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
                        ? Icon(Icons.lock_outline_rounded,
                            size: 15, color: statusColor)
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          module['title'],
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isLocked ? theme.subtext : theme.text,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      // Free preview badge on the first module
                      if (isFirstModule && !_hasPaidAccess && !isDone) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'FREE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: widget.color,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ],
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
            if (isDone)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isFirstModule && !_hasPaidAccess ? 'Try free' : 'Continue',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              )
            else if (isLockedBehindPaywall)
              // Distinct affordance: unlock CTA leading to paywall
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.lock_open_fill,
                      size: 11,
                      color: widget.color,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Unlock',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: widget.color,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
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

class _BackButton extends StatefulWidget {
  final Color color;
  final ThemeNotifier theme;
  final VoidCallback onTap;
  const _BackButton({required this.color, required this.theme, required this.onTap});
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
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
            color: widget.color.withValues(alpha: widget.theme.isDark ? 0.10 : 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.color.withValues(alpha: widget.theme.isDark ? 0.20 : 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: widget.color),
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
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
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
        vsync: this, duration: const Duration(milliseconds: 450));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
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