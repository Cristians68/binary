import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../app_links.dart';
import '../credential.dart';
import 'app_theme.dart';

class CertificateScreen extends StatefulWidget {
  final String courseTitle;
  final String courseTag;
  final Color color;
  final String courseId;

  /// Optional overrides. Both are normally left null and loaded from the
  /// learner's own record instead.
  ///
  /// These used to default to `8` and `100`, and the only caller — the quiz
  /// screen — never passed either. So every certificate this app has ever
  /// produced claimed eight modules and a perfect score, on a document people
  /// share publicly, regardless of what they actually did.
  final int? totalModules;
  final int? quizScore;

  const CertificateScreen({
    super.key,
    required this.courseTitle,
    required this.courseTag,
    required this.color,
    required this.courseId,
    this.totalModules,
    this.quizScore,
  });

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleIn;
  late Animation<Offset> _slideUp;

  /// Real values from the learner's own record, loaded in initState.
  int? _loadedModules;
  int? _loadedScore;
  DateTime? _loadedCompletedAt;

  int? get _modules => widget.totalModules ?? _loadedModules;
  int? get _score => widget.quizScore ?? _loadedScore;

  /// The credential for this learner's completion of this course.
  ///
  /// Derived, not stored, so it is identical every time the certificate is
  /// opened. Empty when nobody is signed in, in which case the certificate
  /// shows no credential rather than a plausible-looking one that means
  /// nothing.
  String get _credentialId => courseCredentialId(
        uid: FirebaseAuth.instance.currentUser?.uid ?? '',
        courseId: widget.courseId,
      );

  /// Load the module count, the course's average quiz score, and the date the
  /// course was actually completed.
  ///
  /// The date matters as much as the numbers: it used to be `DateTime.now()`,
  /// so re-opening a certificate months later reprinted it as if it had been
  /// earned that morning.
  Future<void> _loadRecord() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection('users').doc(uid).collection('progress')
            .doc(widget.courseId).get(),
        db.collection('users').doc(uid).get(),
      ]);

      final progress = results[0].data() ?? {};
      final user = results[1].data() ?? {};

      // Average of this course's quiz scores, rounded.
      final scores = (user['quizScores'] as List<dynamic>?)
              ?.whereType<Map>()
              .where((e) =>
                  e['courseId'] == widget.courseId ||
                  e['course'] == widget.courseTag)
              .map((e) => ((e['score'] as num?) ?? 0).toDouble())
              .toList() ??
          [];

      if (!mounted) return;
      setState(() {
        _loadedModules = (progress['totalModules'] as num?)?.toInt();
        _loadedScore = scores.isEmpty
            ? null
            : (scores.reduce((a, b) => a + b) / scores.length).round();
        _loadedCompletedAt =
            (progress['completedAt'] as Timestamp?)?.toDate();
      });
    } catch (e) {
      // Leave the fields null. The certificate renders an em dash rather than
      // inventing a figure.
      debugPrint('CertificateScreen._loadRecord error: $e');
    }
  }

  String get _userName {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    return 'Student';
  }

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// When the course was completed, falling back to today only while the
  /// record is still loading.
  DateTime get _issuedOn => _loadedCompletedAt ?? DateTime.now();

  String get _completionDate =>
      '${_months[_issuedOn.month - 1]} ${_issuedOn.day}, ${_issuedOn.year}';

  String get _completionMonthYear =>
      '${_months[_issuedOn.month - 1]} ${_issuedOn.year}';

  int get _issueMonth => _issuedOn.month;
  int get _issueYear => _issuedOn.year;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scaleIn = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _controller.forward();
    });

    HapticFeedback.heavyImpact();
    _loadRecord();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── LinkedIn — Add to profile ─────────────────────────────────────────────
  Future<void> _addToLinkedIn() async {
    HapticFeedback.selectionClick();
    final name = Uri.encodeComponent(widget.courseTitle);
    final org = Uri.encodeComponent('ByteStack');
    final certUrl = Uri.encodeComponent(kCertificateUrl);
    final uri = Uri.parse(
      'https://www.linkedin.com/profile/add'
      '?startTask=CERTIFICATION_NAME'
      '&name=$name'
      '&organizationName=$org'
      '&issueYear=$_issueYear'
      '&issueMonth=$_issueMonth'
      '&certUrl=$certUrl'
      // The credential, not the course id. The course id is the same string
      // for every holder, so LinkedIn was being handed an identifier that
      // identified the course rather than the person's completion of it.
      '&certId=${Uri.encodeComponent(_credentialId)}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open LinkedIn.'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // ── Share certificate as text ─────────────────────────────────────────────
  Future<void> _shareCertificate() async {
    HapticFeedback.selectionClick();
    final text = '''🎓 I just completed ${widget.courseTitle} on ByteStack!

✅ ${_modules ?? '—'} modules completed
📊 ${_score == null ? '—' : '$_score%'} quiz score
📅 $_completionDate
🔖 Credential $_credentialId

Prepare for your IT certifications at $kSiteDisplayHost

#ByteStack #${widget.courseTag.replaceAll(' ', '')} #ITCertification #Learning''';

    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'I completed ${widget.courseTitle}!',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final color = widget.color;

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: WebContentBounds(maxWidth: 720, child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
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
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: color.withValues(alpha: 0.20)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_ios_new_rounded,
                              size: 12, color: color),
                          const SizedBox(width: 4),
                          Text('Back',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: color,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: SlideTransition(
                    position: _slideUp,
                    child: ScaleTransition(
                      scale: _scaleIn,
                      child: Column(
                        children: [
                          const SizedBox(height: 8),

                          // Top badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text('COURSE COMPLETED',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                      letterSpacing: 1.5)),
                              const SizedBox(width: 8),
                              Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle)),
                            ],
                          ),
                          const SizedBox(height: 14),

                          const Text('🎉',
                              style: TextStyle(fontSize: 44)),
                          const SizedBox(height: 12),

                          Text('You did it!',
                              style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  color: theme.text,
                                  letterSpacing: -0.8,
                                  height: 1.1)),
                          const SizedBox(height: 6),
                          Text('Your certificate is ready to share',
                              style: TextStyle(
                                  fontSize: 14, color: theme.subtext)),

                          const SizedBox(height: 28),

                          // ── Certificate card ──────────────────────────
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: theme.isDark ? const Color(0xFF111111) : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: theme.border),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                // Card header — dark gradient
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFF1a1a2e),
                                        const Color(0xFF16213e),
                                        color.withValues(alpha: 0.4),
                                      ],
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Brand row
                                      Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Center(
                                              child: Text('01',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Colors.white,
                                                      letterSpacing: 1)),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text('ByteStack',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              Text(kSiteDisplayHost,
                                                  style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(alpha: 0.4),
                                                      fontSize: 11)),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),

                                      // Seal + title row
                                      Row(
                                        children: [
                                          Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              color: color.withValues(alpha: 0.2),
                                              border: Border.all(
                                                  color:
                                                      color.withValues(alpha: 0.5),
                                                  width: 2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                                CupertinoIcons
                                                    .checkmark_seal_fill,
                                                color: color,
                                                size: 26),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    'CERTIFICATE OF COMPLETION',
                                                    style: TextStyle(
                                                        color: Colors.white
                                                            .withValues(alpha: 0.5),
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        letterSpacing: 1.2)),
                                                const SizedBox(height: 4),
                                                Text(widget.courseTitle,
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        letterSpacing: -0.3)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Card body
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('This is to certify that',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: theme.subtext)),
                                      const SizedBox(height: 4),
                                      Text(_userName,
                                          style: TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.w700,
                                              color: theme.text,
                                              letterSpacing: -0.6)),
                                      const SizedBox(height: 16),

                                      Text('HAS COMPLETED',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: theme.subtext,
                                              letterSpacing: 0.8)),
                                      const SizedBox(height: 8),

                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.08),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color:
                                                  color.withValues(alpha: 0.2)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(widget.courseTitle,
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: theme.text,
                                                    letterSpacing: -0.3)),
                                            const SizedBox(height: 2),
                                            Text(
                                                'Issued by ByteStack',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: color,
                                                    fontWeight:
                                                        FontWeight.w500)),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 16),

                                      // Stats row
                                      Row(
                                        children: [
                                          _buildStat(
                                              theme,
                                              _modules?.toString() ?? '—',
                                              'Modules',
                                              color),
                                          const SizedBox(width: 10),
                                          _buildStat(
                                              theme,
                                              _score == null
                                                  ? '—'
                                                  : '$_score%',
                                              'Score',
                                              color),
                                          const SizedBox(width: 10),
                                          _buildStat(theme,
                                              _completionMonthYear,
                                              'Completed', color),
                                        ],
                                      ),

                                      const SizedBox(height: 16),
                                      Divider(
                                          color: theme.border, height: 1),
                                      const SizedBox(height: 16),

                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // "ISSUED BY / ByteStack"
                                              // was here, which both duplicated
                                              // the "Issued by ByteStack"
                                              // line above and used a third
                                              // name for the same company. The
                                              // credential is what belongs in
                                              // this position on a certificate.
                                              Text('CREDENTIAL ID',
                                                  style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: theme.subtext,
                                                      letterSpacing: 1)),
                                              const SizedBox(height: 3),
                                              Text(
                                                  _credentialId.isEmpty
                                                      ? '—'
                                                      : _credentialId,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: theme.text,
                                                      fontFeatures: const [
                                                        FontFeature
                                                            .tabularFigures()
                                                      ])),
                                            ],
                                          ),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6),
                                            decoration: BoxDecoration(
                                              color: AppColors.green
                                                  .withValues(alpha: 0.1),
                                              border: Border.all(
                                                  color: AppColors.green
                                                      .withValues(alpha: 0.25)),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize:
                                                  MainAxisSize.min,
                                              children: [
                                                Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration:
                                                        const BoxDecoration(
                                                            color: AppColors
                                                                .green,
                                                            shape: BoxShape
                                                                .circle)),
                                                const SizedBox(width: 5),
                                                const Text('Verified',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            AppColors.green)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── LinkedIn button ───────────────────────────
                          GestureDetector(
                            onTap: _addToLinkedIn,
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0077B5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: const Center(
                                      child: Text('in',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0077B5))),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text('Add to LinkedIn Profile',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          letterSpacing: -0.2)),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // ── Share button ──────────────────────────────
                          GestureDetector(
                            onTap: _shareCertificate,
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.share,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Share Certificate',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: -0.2)),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // ── Back button ───────────────────────────────
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: theme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: theme.border),
                              ),
                              child: Text('Back to courses',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: theme.subtext)),
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        )),
      ),
    );
  }

  Widget _buildStat(
      ThemeNotifier theme, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.isDark ? const Color(0xFF161616) : theme.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.border),
        ),
        child: Column(
          children: [
            Text(value,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: value.length > 5 ? 11 : 15,
                    fontWeight: FontWeight.w700,
                    color: theme.text,
                    letterSpacing: -0.3)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 10, color: theme.subtext)),
          ],
        ),
      ),
    );
  }
}