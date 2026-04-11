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
              : _getHardcodedQuestions(widget.courseTag, widget.moduleId);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _questions = _getHardcodedQuestions(
            widget.courseTag,
            widget.moduleId,
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

    // ── Save progress if passed ───────────────────────────────────────────
    if (passed) {
      ProgressService.completeModule(
        courseId: widget.courseId,
        moduleId: widget.moduleId,
        moduleTitle: widget.moduleTitle,
        courseTag: widget.courseTag,
        score: _score,
        total: _questions.length,
      ).then((_) async {
        // Check if course is now fully complete
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
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context); // back to course detail

                  // Check if course complete → show certificate
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
              // ── Header ──────────────────────────────────────────────────────
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

              // ── Progress ─────────────────────────────────────────────────────
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

              // ── Tag pill ─────────────────────────────────────────────────────
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

              // ── Question ─────────────────────────────────────────────────────
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

              // ── Answer options ───────────────────────────────────────────────
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

              // ── Explanation ──────────────────────────────────────────────────
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

              // ── Next button ──────────────────────────────────────────────────
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

  // ── Hardcoded questions — keyed by courseTag + moduleId ────────────────────
  List<Map<String, dynamic>> _getHardcodedQuestions(
    String tag,
    String moduleId,
  ) {
    if (tag == 'Binary Cyber Pro') {
      switch (moduleId) {
        case 'module-01':
          return [
            {
              'question': 'What does the "C" in the CIA Triad stand for?',
              'answers': [
                'Computing',
                'Confidentiality',
                'Cryptography',
                'Compliance',
              ],
              'correct': 1,
              'explanation':
                  'The CIA Triad stands for Confidentiality, Integrity, and Availability — the three pillars of information security.',
            },
            {
              'question':
                  'What is the difference between a threat and a vulnerability?',
              'answers': [
                'They are the same thing',
                'A threat is a weakness; a vulnerability is an attacker',
                'A threat is a potential cause of harm; a vulnerability is an exploitable weakness',
                'A threat is always internal; a vulnerability is always external',
              ],
              'correct': 2,
              'explanation':
                  'A threat is a potential cause of harm (e.g. a hacker), while a vulnerability is a weakness that can be exploited (e.g. unpatched software).',
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
                  'Defense in depth uses multiple independent layers of security — if one fails, the others still protect the system.',
            },
            {
              'question': 'What does the principle of least privilege mean?',
              'answers': [
                'Users should have the lowest possible salary',
                'Users should only have the minimum access they need to do their job',
                'Admins should not have any restrictions',
                'All users should share the same account',
              ],
              'correct': 1,
              'explanation':
                  'Least privilege limits damage from compromised accounts by ensuring users cannot access systems beyond what their role requires.',
            },
            {
              'question':
                  'Which of the following is an example of social engineering?',
              'answers': [
                'Exploiting a buffer overflow vulnerability',
                'Running a port scan on a target',
                'Calling an employee pretending to be IT support to get their password',
                'Intercepting network packets',
              ],
              'correct': 2,
              'explanation':
                  'Social engineering manipulates people rather than technology. Impersonating IT support to extract a password is a classic example.',
            },
          ];
        case 'module-02':
          return [
            {
              'question': 'What is the primary function of a firewall?',
              'answers': [
                'Speed up network traffic',
                'Monitor and control network traffic based on security rules',
                'Store backup copies of data',
                'Assign IP addresses to devices',
              ],
              'correct': 1,
              'explanation':
                  'A firewall monitors and controls incoming and outgoing network traffic based on predefined security rules.',
            },
            {
              'question': 'What does an IPS do that an IDS does not?',
              'answers': [
                'Detects suspicious traffic',
                'Generates alerts',
                'Automatically blocks malicious traffic in real time',
                'Logs network events',
              ],
              'correct': 2,
              'explanation':
                  'An IDS detects and alerts. An IPS goes further by automatically blocking the malicious traffic.',
            },
            {
              'question': 'What is a VPN primarily used for?',
              'answers': [
                'Speeding up internet connection',
                'Creating an encrypted tunnel to secure data in transit',
                'Blocking ads on websites',
                'Storing passwords securely',
              ],
              'correct': 1,
              'explanation':
                  'A VPN creates an encrypted tunnel between a device and a remote server, securing data in transit.',
            },
            {
              'question': 'What makes HTTPS more secure than HTTP?',
              'answers': [
                'HTTPS loads pages faster',
                'HTTPS uses a different port',
                'HTTPS uses TLS encryption to protect data in transit',
                'HTTPS blocks all cookies',
              ],
              'correct': 2,
              'explanation':
                  'HTTPS uses TLS/SSL encryption, preventing eavesdropping and tampering with data in transit.',
            },
            {
              'question': 'What is the goal of network segmentation?',
              'answers': [
                'Increase internet speed',
                'Reduce the number of devices on a network',
                'Limit the spread of attacks and control who can communicate with what',
                'Replace firewalls entirely',
              ],
              'correct': 2,
              'explanation':
                  'Network segmentation divides a network into zones to contain attacks and enforce access controls between segments.',
            },
          ];
        case 'module-03':
          return [
            {
              'question':
                  'Which type of encryption uses the same key to encrypt and decrypt?',
              'answers': ['Asymmetric', 'Symmetric', 'Hashing', 'PKI'],
              'correct': 1,
              'explanation':
                  'Symmetric encryption uses one shared key for both encryption and decryption. AES is a common example.',
            },
            {
              'question':
                  'What property makes hash functions useful for verifying integrity?',
              'answers': [
                'They are reversible',
                'They always produce the same length output and any change in input changes the hash completely',
                'They use two keys',
                'They encrypt data for storage',
              ],
              'correct': 1,
              'explanation':
                  'Hash functions are one-way and produce a unique fixed-length output. Any change to the input produces a completely different hash.',
            },
            {
              'question':
                  'What is the role of a Certificate Authority (CA) in PKI?',
              'answers': [
                'Store encryption keys for users',
                'Issue and verify digital certificates, creating a chain of trust',
                'Block malicious network traffic',
                'Generate one-time passwords',
              ],
              'correct': 1,
              'explanation':
                  'CAs issue and verify digital certificates, establishing the chain of trust that underpins HTTPS and other secure communications.',
            },
            {
              'question': 'How does a digital signature work?',
              'answers': [
                'The sender encrypts with the receiver\'s public key',
                'The sender signs with their private key; anyone verifies with the sender\'s public key',
                'Both parties use the same secret key',
                'The message is hashed and the hash is stored in the cloud',
              ],
              'correct': 1,
              'explanation':
                  'A digital signature uses the sender\'s private key to sign, and anyone with the public key can verify the signature\'s authenticity.',
            },
            {
              'question': 'What protocol does HTTPS use for encryption?',
              'answers': ['SSH', 'IPSec', 'TLS', 'SFTP'],
              'correct': 2,
              'explanation':
                  'TLS (Transport Layer Security) is the cryptographic protocol that powers HTTPS, protecting data in transit.',
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
                  'Reconnaissance is the first phase — gathering information about the target before any active testing begins.',
            },
            {
              'question':
                  'In black box testing, what does the tester know about the target?',
              'answers': [
                'Full source code and architecture',
                'Only partial information',
                'Nothing — they simulate an external attacker',
                'Everything, including credentials',
              ],
              'correct': 2,
              'explanation':
                  'Black box testing simulates an external attacker with no prior knowledge of the system.',
            },
            {
              'question': 'What is the purpose of a port scan?',
              'answers': [
                'Encrypt network traffic',
                'Discover which network ports and services are open on a target',
                'Block incoming connections',
                'Reset a device\'s IP address',
              ],
              'correct': 1,
              'explanation':
                  'Port scanning maps a system\'s attack surface by identifying open ports and the services running on them.',
            },
            {
              'question': 'What is vertical privilege escalation?',
              'answers': [
                'Moving between users of the same privilege level',
                'Gaining higher-level permissions such as admin or root',
                'Reducing a user\'s permissions',
                'Accessing a network from a remote location',
              ],
              'correct': 1,
              'explanation':
                  'Vertical escalation means gaining higher-level access (e.g. user → root). Horizontal escalation means accessing another user\'s account at the same level.',
            },
            {
              'question': 'What does a CVSS score represent?',
              'answers': [
                'The cost of fixing a vulnerability',
                'The number of systems affected',
                'The severity of a CVE vulnerability, rated 0–10',
                'The time it takes to patch a system',
              ],
              'correct': 2,
              'explanation':
                  'CVSS (Common Vulnerability Scoring System) rates vulnerability severity from 0 (none) to 10 (critical).',
            },
          ];
        case 'module-05':
          return [
            {
              'question': 'How does ransomware typically impact a victim?',
              'answers': [
                'It slows down the internet connection',
                'It encrypts files and demands payment for the decryption key',
                'It deletes the operating system',
                'It monitors keystrokes silently',
              ],
              'correct': 1,
              'explanation':
                  'Ransomware encrypts the victim\'s files and demands a ransom — usually cryptocurrency — for the key to decrypt them.',
            },
            {
              'question':
                  'Which type of malware self-replicates across networks without human interaction?',
              'answers': ['Virus', 'Trojan', 'Worm', 'Spyware'],
              'correct': 2,
              'explanation':
                  'Worms spread automatically through network connections without needing a host file or human action.',
            },
            {
              'question':
                  'What makes a zero-day vulnerability especially dangerous?',
              'answers': [
                'It only affects older operating systems',
                'It is easy to detect with antivirus',
                'It is unknown to the vendor and has no patch available',
                'It requires physical access to exploit',
              ],
              'correct': 2,
              'explanation':
                  'Zero-days are unknown to the vendor, meaning there is no patch yet — giving defenders zero days to protect against it.',
            },
            {
              'question': 'What is the goal of a phishing attack?',
              'answers': [
                'Crash the target\'s server',
                'Steal credentials or install malware by deceiving users with fraudulent messages',
                'Intercept encrypted traffic',
                'Exploit a software vulnerability remotely',
              ],
              'correct': 1,
              'explanation':
                  'Phishing uses deceptive emails or messages mimicking trusted sources to trick users into revealing credentials or downloading malware.',
            },
            {
              'question': 'What is a botnet used for in a DDoS attack?',
              'answers': [
                'Encrypting attacker communications',
                'Storing stolen data',
                'Flooding a target with traffic from many infected devices simultaneously',
                'Bypassing two-factor authentication',
              ],
              'correct': 2,
              'explanation':
                  'A botnet is a network of infected machines the attacker controls. In a DDoS, all bots flood the target at once, overwhelming it.',
            },
          ];
        case 'module-06':
          return [
            {
              'question': 'What does SQL Injection allow an attacker to do?',
              'answers': [
                'Intercept HTTPS traffic',
                'Manipulate database queries by injecting malicious SQL code',
                'Overload a server with requests',
                'Steal cookies from a browser',
              ],
              'correct': 1,
              'explanation':
                  'SQL Injection inserts malicious SQL into input fields to manipulate queries, potentially exposing or modifying database contents.',
            },
            {
              'question': 'How does a stored XSS attack work?',
              'answers': [
                'The attacker intercepts the HTTP response',
                'Malicious script is injected and stored on the server, executing when other users view the content',
                'The attacker sends a crafted URL to a specific user',
                'The attacker modifies the victim\'s local browser settings',
              ],
              'correct': 1,
              'explanation':
                  'Stored XSS saves malicious scripts on the server (e.g. in a comment). Every user who loads that content runs the attacker\'s script.',
            },
            {
              'question': 'What does CSRF exploit?',
              'answers': [
                'Weak encryption algorithms',
                'Unpatched server software',
                'An authenticated user\'s active session to make unintended requests',
                'Insecure direct object references',
              ],
              'correct': 2,
              'explanation':
                  'CSRF tricks a logged-in user\'s browser into sending requests using their existing authenticated session without their knowledge.',
            },
            {
              'question': 'What is the OWASP Top 10?',
              'answers': [
                'A list of the 10 best security tools',
                'The 10 most common programming languages',
                'A list of the 10 most critical web application security risks',
                'A ranking of cybersecurity certifications',
              ],
              'correct': 2,
              'explanation':
                  'The OWASP Top 10 is a standard awareness document listing the most critical web application security risks, updated regularly.',
            },
            {
              'question': 'Why is input validation important?',
              'answers': [
                'It improves page load speed',
                'It prevents injection attacks by rejecting malformed or malicious data',
                'It compresses data for storage',
                'It ensures users fill out all form fields',
              ],
              'correct': 1,
              'explanation':
                  'Input validation checks that user-supplied data is safe and expected before processing it, blocking injection and other input-based attacks.',
            },
          ];
        case 'module-07':
          return [
            {
              'question':
                  'Which factors can be used in Multi-Factor Authentication?',
              'answers': [
                'Only passwords',
                'Something you know, something you have, something you are',
                'Username and email only',
                'Device name and IP address',
              ],
              'correct': 1,
              'explanation':
                  'MFA combines factors: knowledge (password), possession (phone/token), and inherence (biometric).',
            },
            {
              'question':
                  'What is the difference between authentication and authorization?',
              'answers': [
                'They are the same process',
                'Authorization happens before authentication',
                'Authentication verifies identity; authorization determines permissions',
                'Authentication grants access; authorization verifies identity',
              ],
              'correct': 2,
              'explanation':
                  'Authentication answers "who are you?" while authorization answers "what are you allowed to do?" — authentication always comes first.',
            },
            {
              'question': 'What is the core principle of Zero Trust?',
              'answers': [
                'Trust all internal network traffic automatically',
                'Never trust, always verify — every request must be authenticated regardless of origin',
                'Only use VPNs for remote access',
                'Grant all employees admin access by default',
              ],
              'correct': 1,
              'explanation':
                  'Zero Trust assumes no user or device is trusted by default — even inside the network — and continuously verifies every access request.',
            },
            {
              'question': 'What does OAuth 2.0 allow a third-party app to do?',
              'answers': [
                'Store the user\'s password securely',
                'Access user resources without the user sharing their password',
                'Encrypt all network traffic',
                'Create a new account on behalf of the user',
              ],
              'correct': 1,
              'explanation':
                  'OAuth 2.0 lets users grant apps access to their resources via tokens, without ever sharing their actual credentials.',
            },
            {
              'question':
                  'Which defence is most effective against credential stuffing attacks?',
              'answers': [
                'Longer passwords',
                'Frequent password resets',
                'Multi-factor authentication',
                'Firewalls',
              ],
              'correct': 2,
              'explanation':
                  'Credential stuffing uses leaked password lists from other breaches. MFA stops attackers even when the correct password is used.',
            },
          ];
        case 'module-08':
          return [
            {
              'question':
                  'What is the correct order of the NIST Incident Response phases?',
              'answers': [
                'Eradication → Containment → Identification → Recovery',
                'Preparation → Identification → Containment → Eradication → Recovery → Lessons Learned',
                'Detection → Response → Closure → Review',
                'Triage → Patch → Monitor → Report',
              ],
              'correct': 1,
              'explanation':
                  'The NIST IR lifecycle: Preparation, Identification, Containment, Eradication, Recovery, Lessons Learned.',
            },
            {
              'question': 'What does a Security Operations Center (SOC) do?',
              'answers': [
                'Develops new software products',
                'Manages employee HR records',
                'Continuously monitors, detects, and responds to security incidents',
                'Handles physical building security only',
              ],
              'correct': 2,
              'explanation':
                  'A SOC is a centralised team using SIEM and threat intelligence to defend the organisation around the clock.',
            },
            {
              'question':
                  'Under GDPR, how quickly must a data breach be reported to regulators?',
              'answers': ['24 hours', '48 hours', '72 hours', '7 days'],
              'correct': 2,
              'explanation':
                  'GDPR requires organisations to notify the relevant supervisory authority within 72 hours of becoming aware of a breach.',
            },
            {
              'question':
                  'Why do forensic investigators clone a drive before analysing it?',
              'answers': [
                'To speed up the investigation',
                'To preserve the original evidence and ensure admissibility in court',
                'To compress the data for easier storage',
                'To remove malware from the original',
              ],
              'correct': 1,
              'explanation':
                  'Working on a clone preserves the integrity of the original evidence, which is essential for legal proceedings.',
            },
            {
              'question': 'What is a SIEM primarily used for?',
              'answers': [
                'Encrypting database records',
                'Scanning for software vulnerabilities',
                'Collecting and correlating logs to detect and alert on suspicious activity',
                'Managing user passwords',
              ],
              'correct': 2,
              'explanation':
                  'A SIEM aggregates log data from across the organisation and correlates events to surface potential security incidents.',
            },
          ];
        default:
          return _defaultCyberQuestions();
      }
    }

    if (tag == 'Binary Cloud') {
      return _getCloudFundamentalsQuestions(moduleId);
    }

    if (tag == 'Binary Cloud Pro') {
      return _getCloudProQuestions(moduleId);
    }

    if (tag == 'ITIL V4') {
      return [
        {
          'question': 'What does the Service Value System describe?',
          'answers': [
            'How components work together to create value',
            'A list of IT tools',
            'The billing process',
            'Network protocols',
          ],
          'correct': 0,
          'explanation':
              'The SVS shows how all components and activities work together to enable value creation.',
        },
        {
          'question': 'Which is one of the 4 dimensions of service management?',
          'answers': [
            'Hardware only',
            'Organizations and people',
            'Financial budgeting',
            'Customer complaints',
          ],
          'correct': 1,
          'explanation':
              'The 4 dimensions are: Organizations & People, Information & Technology, Partners & Suppliers, Value Streams & Processes.',
        },
        {
          'question': 'What is the main purpose of ITIL V4?',
          'answers': [
            'Replace IT staff',
            'Provide IT service management guidance',
            'Define programming languages',
            'Manage company finances',
          ],
          'correct': 1,
          'explanation':
              'ITIL V4 provides guidance for IT service management best practices.',
        },
        {
          'question':
              'Which guiding principle says to start with what you have?',
          'answers': [
            'Think holistically',
            'Keep it simple',
            'Start where you are',
            'Progress iteratively',
          ],
          'correct': 2,
          'explanation':
              'Start where you are means assessing what exists before building anything new.',
        },
        {
          'question': 'What does value co-creation mean?',
          'answers': [
            'Only the provider creates value',
            'Value is created together by provider and customer',
            'Value is measured in money',
            'IT creates value alone',
          ],
          'correct': 1,
          'explanation':
              'In ITIL V4, value is co-created between the service provider and the customer.',
        },
      ];
    }

    if (tag == 'CSM') {
      return [
        {
          'question': 'What is a Sprint in Scrum?',
          'answers': [
            'A long-term project plan',
            'A time-boxed development cycle',
            'A type of meeting',
            'A backlog item',
          ],
          'correct': 1,
          'explanation':
              'A Sprint is a time-boxed period (usually 1-4 weeks) where a usable increment is created.',
        },
        {
          'question': 'Who prioritizes the Product Backlog?',
          'answers': [
            'Scrum Master',
            'Development Team',
            'Product Owner',
            'Stakeholders',
          ],
          'correct': 2,
          'explanation':
              'The Product Owner is responsible for managing and prioritizing the Product Backlog.',
        },
        {
          'question': 'What is the Scrum Master\'s role?',
          'answers': [
            'Write all the code',
            'Manage the budget',
            'Facilitate Scrum and remove blockers',
            'Define product features',
          ],
          'correct': 2,
          'explanation':
              'The Scrum Master is a servant-leader who facilitates Scrum and removes impediments.',
        },
        {
          'question': 'How long is a Sprint typically?',
          'answers': ['6 months', '1 year', '1-4 weeks', '1 day'],
          'correct': 2,
          'explanation':
              'Sprints are time-boxed to one month or less, typically 1-4 weeks.',
        },
        {
          'question': 'What is the Product Backlog?',
          'answers': [
            'A bug tracking system',
            'An ordered list of work for the product',
            'A meeting agenda',
            'A test plan',
          ],
          'correct': 1,
          'explanation':
              'The Product Backlog is an ordered list of everything needed in the product.',
        },
      ];
    }

    // Networking fallback
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
            'DNS stands for Domain Name System — it translates domain names to IP addresses.',
      },
      {
        'question': 'What is an IP address?',
        'answers': [
          'A password for networks',
          'A unique numerical label for devices',
          'A type of cable',
          'An internet browser',
        ],
        'correct': 1,
        'explanation':
            'An IP address uniquely identifies a device on a network.',
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
        'explanation': 'TCP stands for Transmission Control Protocol.',
      },
      {
        'question': 'What is a router?',
        'answers': [
          'A type of computer',
          'A device that forwards data between networks',
          'A wireless keyboard',
          'A storage device',
        ],
        'correct': 1,
        'explanation':
            'A router forwards data packets between networks and connects devices to the internet.',
      },
      {
        'question': 'What is a subnet?',
        'answers': [
          'A type of internet browser',
          'A logical subdivision of an IP network',
          'A wireless signal',
          'A server type',
        ],
        'correct': 1,
        'explanation':
            'A subnet is a logical subdivision of an IP network, used to organize and secure networks.',
      },
    ];
  }

  List<Map<String, dynamic>> _getCloudFundamentalsQuestions(String moduleId) {
    switch (moduleId) {
      case 'module-01':
        return [
          {
            'question': 'What does "elasticity" mean in cloud computing?',
            'answers': [
              'The ability to stretch physical cables',
              'Automatically scaling resources up and down based on demand',
              'Using multiple cloud providers',
              'Backing up data automatically',
            ],
            'correct': 1,
            'explanation':
                'Elasticity means the system automatically adjusts capacity to match demand — scaling up under load and back down when load drops.',
          },
          {
            'question': 'What does CapEx stand for?',
            'answers': [
              'Cloud Application Expenditure',
              'Capital Expenditure — large upfront hardware purchases',
              'Capacity Extension',
              'Certified Application Experience',
            ],
            'correct': 1,
            'explanation':
                'CapEx is Capital Expenditure — traditional IT uses large upfront purchases. Cloud shifts this to OpEx (pay-as-you-go monthly costs).',
          },
          {
            'question':
                'Which of the following is NOT one of NIST\'s 5 cloud characteristics?',
            'answers': [
              'On-demand self-service',
              'Broad network access',
              'Dedicated hardware per customer',
              'Measured service',
            ],
            'correct': 2,
            'explanation':
                'NIST\'s 5 characteristics are: on-demand self-service, broad network access, resource pooling, rapid elasticity, and measured service. Resource pooling means hardware is shared.',
          },
          {
            'question':
                'What is a key financial advantage of cloud over on-premises?',
            'answers': [
              'Cloud always costs less in absolute terms',
              'Cloud converts large CapEx purchases into manageable OpEx',
              'Cloud eliminates all IT costs',
              'Cloud provides free hardware',
            ],
            'correct': 1,
            'explanation':
                'Cloud converts unpredictable large capital expenses into predictable operational expenses, improving cash flow and flexibility.',
          },
          {
            'question': 'What does "on-demand self-service" mean in cloud?',
            'answers': [
              'You must call the provider to get resources',
              'You can provision resources yourself without human interaction from the provider',
              'Resources are only available during business hours',
              'You share login credentials with the provider',
            ],
            'correct': 1,
            'explanation':
                'On-demand self-service means you can spin up servers, storage, and other resources yourself via a console or API, without waiting for a human to help you.',
          },
        ];
      case 'module-02':
        return [
          {
            'question':
                'In which service model does the provider manage the OS and runtime?',
            'answers': ['IaaS', 'PaaS', 'SaaS', 'FaaS'],
            'correct': 1,
            'explanation':
                'In PaaS, the provider manages the OS, runtime, and infrastructure. You only manage your application code and data.',
          },
          {
            'question': 'Which is an example of SaaS?',
            'answers': ['AWS EC2', 'Google Compute Engine', 'Gmail', 'Docker'],
            'correct': 2,
            'explanation':
                'Gmail is SaaS — you use fully managed software via a browser. You never touch the servers, OS, or maintenance.',
          },
          {
            'question': 'What is a key characteristic of serverless/FaaS?',
            'answers': [
              'You manage the server configuration',
              'You pay per server hour',
              'Code runs only when triggered and you pay per execution',
              'Requires Kubernetes',
            ],
            'correct': 2,
            'explanation':
                'Serverless functions are event-driven and billed per execution. There is no idle cost — you pay only when code actually runs.',
          },
          {
            'question':
                'Which service model gives you the most control over the infrastructure?',
            'answers': ['SaaS', 'PaaS', 'IaaS', 'FaaS'],
            'correct': 2,
            'explanation':
                'IaaS gives you the most control — you manage the OS, middleware, and applications. The provider only manages physical hardware.',
          },
          {
            'question': 'Heroku is an example of which service model?',
            'answers': ['IaaS', 'PaaS', 'SaaS', 'On-premises'],
            'correct': 1,
            'explanation':
                'Heroku is PaaS — you deploy code and it handles the runtime, OS, and infrastructure automatically.',
          },
        ];
      case 'module-03':
        return [
          {
            'question': 'What is the main advantage of a hybrid cloud?',
            'answers': [
              'It is always cheaper than public cloud',
              'It combines public and private cloud, keeping sensitive workloads on-prem while using public cloud for flexibility',
              'It eliminates the need for any on-prem hardware',
              'It provides unlimited free storage',
            ],
            'correct': 1,
            'explanation':
                'Hybrid cloud lets organisations keep sensitive or regulated workloads on private infrastructure while using public cloud for burst capacity and less critical workloads.',
          },
          {
            'question': 'What is vendor lock-in?',
            'answers': [
              'A physical lock on server racks',
              'Being contractually prevented from leaving a provider',
              'Over-dependence on a single provider\'s services, making it costly to switch',
              'A discount programme for long-term customers',
            ],
            'correct': 2,
            'explanation':
                'Vendor lock-in occurs when deep use of proprietary services makes migrating to another provider extremely expensive and complex.',
          },
          {
            'question':
                'Which deployment model uses resources shared across multiple customers over the internet?',
            'answers': [
              'Private cloud',
              'On-premises',
              'Public cloud',
              'Community cloud',
            ],
            'correct': 2,
            'explanation':
                'Public cloud resources are owned by a provider and shared across multiple customer organisations, though logically isolated from each other.',
          },
          {
            'question': 'What is a multi-cloud strategy?',
            'answers': [
              'Using multiple accounts with the same provider',
              'Using services from two or more different cloud providers simultaneously',
              'Having a cloud and on-prem environment',
              'Running multiple VMs on one cloud',
            ],
            'correct': 1,
            'explanation':
                'Multi-cloud means using services from different providers (e.g. AWS + GCP + Azure) to avoid lock-in, improve resilience, or use each provider\'s best services.',
          },
          {
            'question':
                'A private cloud is best suited for organisations that need:',
            'answers': [
              'The cheapest possible infrastructure',
              'Greater control, compliance, and dedicated resources',
              'Public internet access for all users',
              'No IT team',
            ],
            'correct': 1,
            'explanation':
                'Private clouds suit organisations with strict compliance, security, or customisation requirements that cannot be met in a shared public cloud environment.',
          },
        ];
      case 'module-04':
        return [
          {
            'question':
                'What type of cloud storage is best for storing user-uploaded photos at scale?',
            'answers': [
              'Block storage',
              'File storage',
              'Object storage',
              'In-memory storage',
            ],
            'correct': 2,
            'explanation':
                'Object storage (like S3) is ideal for unstructured data like photos, videos, and documents — it scales to petabytes and is accessed via HTTP.',
          },
          {
            'question':
                'What is the main benefit of a managed database service?',
            'answers': [
              'You have full control of the OS',
              'The provider handles backups, patching, and scaling automatically',
              'It is always faster than self-managed',
              'It supports only NoSQL',
            ],
            'correct': 1,
            'explanation':
                'Managed databases handle maintenance tasks like backups, patching, replication, and failover automatically, letting you focus on your data and application.',
          },
          {
            'question': 'What does a CDN do?',
            'answers': [
              'Backs up your database',
              'Caches content close to users globally to reduce latency',
              'Encrypts all data at rest',
              'Monitors server performance',
            ],
            'correct': 1,
            'explanation':
                'A CDN (Content Delivery Network) distributes content to edge servers worldwide, serving users from the nearest location to reduce load times.',
          },
          {
            'question': 'What is auto scaling?',
            'answers': [
              'Manually adding servers when traffic grows',
              'Automatically adjusting compute capacity based on real-time demand',
              'A pricing model for cloud storage',
              'A backup strategy',
            ],
            'correct': 1,
            'explanation':
                'Auto Scaling monitors load and automatically adds or removes compute resources, ensuring performance during peaks without wasting money during quiet periods.',
          },
          {
            'question': 'Block storage in the cloud is most similar to:',
            'answers': [
              'A USB flash drive',
              'A hard drive attached directly to a server',
              'A shared network folder',
              'An email attachment',
            ],
            'correct': 1,
            'explanation':
                'Block storage (like EBS) acts like a physical hard drive attached to a virtual machine — low latency, directly mounted storage for OS and application data.',
          },
        ];
      case 'module-05':
        return [
          {
            'question':
                'Under the Shared Responsibility Model, who is responsible for encrypting data stored in S3?',
            'answers': [
              'The cloud provider',
              'The customer',
              'A third-party auditor',
              'The internet service provider',
            ],
            'correct': 1,
            'explanation':
                'The customer is responsible for their data — including encryption configuration. The provider secures the physical infrastructure but not how you configure your resources.',
          },
          {
            'question': 'What is the principle of least privilege in IAM?',
            'answers': [
              'All users should have admin access for efficiency',
              'Users receive only the minimum permissions required for their job',
              'Admins should rotate passwords monthly',
              'IAM should only be configured by the provider',
            ],
            'correct': 1,
            'explanation':
                'Least privilege limits the blast radius of a compromised account — a user who only needs to read S3 should never have permission to delete EC2 instances.',
          },
          {
            'question': 'What does encryption "in transit" protect against?',
            'answers': [
              'Data being deleted accidentally',
              'Unauthorised access to physical hard drives',
              'Eavesdropping on data as it travels across networks',
              'Misconfigured IAM policies',
            ],
            'correct': 2,
            'explanation':
                'Encryption in transit (TLS/HTTPS) protects data moving between systems from being intercepted and read by attackers on the network.',
          },
          {
            'question': 'A Security Group in AWS acts as:',
            'answers': [
              'A team of security engineers',
              'A virtual firewall controlling traffic to and from cloud instances',
              'A compliance certification',
              'A type of encryption key',
            ],
            'correct': 1,
            'explanation':
                'Security Groups are stateful virtual firewalls at the instance level — you define which ports and protocols are allowed in and out.',
          },
          {
            'question':
                'Which compliance framework applies to organisations handling EU personal data?',
            'answers': ['PCI-DSS', 'HIPAA', 'GDPR', 'SOX'],
            'correct': 2,
            'explanation':
                'GDPR (General Data Protection Regulation) applies to any organisation processing personal data of EU residents, regardless of where the organisation is based.',
          },
        ];
      case 'module-06':
        return [
          {
            'question': 'What is a VPC?',
            'answers': [
              'A type of virtual processor',
              'A logically isolated network in the cloud where you control IP ranges and routing',
              'A cloud provider\'s data centre',
              'A virtual private computer',
            ],
            'correct': 1,
            'explanation':
                'A VPC (Virtual Private Cloud) is your own isolated section of the cloud — you define the network topology, subnets, and access controls.',
          },
          {
            'question':
                'What is the difference between a public and private subnet?',
            'answers': [
              'Public subnets are faster',
              'Public subnets have internet access; private subnets are isolated from the internet',
              'Private subnets cost more',
              'There is no practical difference',
            ],
            'correct': 1,
            'explanation':
                'Public subnets have a route to an internet gateway, allowing resources to be reached from the internet. Private subnets are only accessible internally.',
          },
          {
            'question': 'What does a load balancer do?',
            'answers': [
              'Compresses data for storage',
              'Distributes incoming traffic across multiple servers',
              'Encrypts network traffic',
              'Assigns IP addresses to new instances',
            ],
            'correct': 1,
            'explanation':
                'A load balancer ensures no single server is overwhelmed, distributing requests evenly and removing unhealthy instances from the pool automatically.',
          },
          {
            'question': 'What is an Availability Zone (AZ)?',
            'answers': [
              'A country where cloud services are available',
              'One or more isolated data centres within a region',
              'A type of content delivery network',
              'A backup storage location',
            ],
            'correct': 1,
            'explanation':
                'An AZ is an isolated data centre (or cluster) within a region. Deploying across multiple AZs ensures your app survives a single data centre failure.',
          },
          {
            'question': 'Why deploy across multiple Availability Zones?',
            'answers': [
              'To reduce latency for all users',
              'To ensure the application survives a failure in any single data centre',
              'To reduce cloud costs significantly',
              'To comply with GDPR',
            ],
            'correct': 1,
            'explanation':
                'Multi-AZ deployment provides high availability — if one AZ loses power or connectivity, your app continues running in the other AZs without interruption.',
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
                'Cloud computing delivers servers, storage, databases, and software over the internet — you pay only for what you use.',
          },
          {
            'question': 'What does IaaS stand for?',
            'answers': [
              'Internet as a Service',
              'Infrastructure as a Service',
              'Integration as a Service',
              'Intelligence as a Service',
            ],
            'correct': 1,
            'explanation':
                'IaaS provides virtualised infrastructure — compute, storage, and networking — over the internet.',
          },
          {
            'question': 'Which cloud model is shared by many customers?',
            'answers': ['Private', 'On-premises', 'Public', 'Dedicated'],
            'correct': 2,
            'explanation':
                'Public cloud resources are owned by a provider and shared across multiple customer organisations.',
          },
          {
            'question': 'What is elasticity in cloud?',
            'answers': [
              'Physical flexibility of cables',
              'Auto-scaling resources based on demand',
              'Stretching storage limits',
              'Flexible billing dates',
            ],
            'correct': 1,
            'explanation':
                'Elasticity is the ability to automatically scale resources up and down in response to demand.',
          },
          {
            'question': 'What is the shared responsibility model?',
            'answers': [
              'Sharing costs with the provider',
              'Provider secures infrastructure; customer secures their data and config',
              'Both parties share one account',
              'The provider handles everything',
            ],
            'correct': 1,
            'explanation':
                'The cloud provider secures the underlying infrastructure while the customer is responsible for securing their data and configurations.',
          },
        ];
    }
  }

  List<Map<String, dynamic>> _getCloudProQuestions(String moduleId) {
    switch (moduleId) {
      case 'module-01':
        return [
          {
            'question':
                'How many pillars does the AWS Well-Architected Framework have?',
            'answers': ['4', '5', '6', '7'],
            'correct': 2,
            'explanation':
                'The Well-Architected Framework has 6 pillars: Operational Excellence, Security, Reliability, Performance Efficiency, Cost Optimisation, and Sustainability.',
          },
          {
            'question':
                'What is the difference between High Availability and Fault Tolerance?',
            'answers': [
              'They are identical concepts',
              'HA allows brief downtime; Fault Tolerance means zero interruption even during failure',
              'Fault Tolerance is cheaper to implement',
              'HA requires more regions',
            ],
            'correct': 1,
            'explanation':
                'HA minimises downtime (brief failover possible). Fault Tolerance requires full redundancy so the system never interrupts, even during component failures.',
          },
          {
            'question': 'What is Infrastructure as Code (IaC)?',
            'answers': [
              'Writing application code that runs on cloud',
              'Managing infrastructure via machine-readable config files instead of manual processes',
              'A programming language for cloud',
              'Documentation for cloud architecture',
            ],
            'correct': 1,
            'explanation':
                'IaC defines infrastructure in config files (Terraform, CloudFormation) enabling version control, repeatability, and automated provisioning.',
          },
          {
            'question': 'What is loose coupling in cloud architecture?',
            'answers': [
              'Using fewer services to reduce complexity',
              'Designing components so failures don\'t cascade — they interact through defined interfaces',
              'Tightly integrating all services for performance',
              'Using a single monolithic application',
            ],
            'correct': 1,
            'explanation':
                'Loose coupling means components interact through well-defined interfaces (queues, APIs) so a failure in one doesn\'t bring down others.',
          },
          {
            'question': 'What does RTO stand for in disaster recovery?',
            'answers': [
              'Real-Time Operations',
              'Recovery Time Objective — the maximum acceptable downtime',
              'Redundant Transfer Option',
              'Regional Topology Overview',
            ],
            'correct': 1,
            'explanation':
                'RTO is the maximum acceptable time to restore service after a failure. It drives your disaster recovery architecture and investment.',
          },
        ];
      case 'module-02':
        return [
          {
            'question':
                'What is the key advantage of containers over virtual machines?',
            'answers': [
              'Containers have their own OS kernel',
              'Containers are slower but more secure',
              'Containers share the host OS kernel — they are lighter and start faster',
              'Containers require more RAM',
            ],
            'correct': 2,
            'explanation':
                'Containers share the host OS kernel rather than running a full guest OS, making them significantly smaller and faster to start than VMs.',
          },
          {
            'question': 'What does Kubernetes do?',
            'answers': [
              'Builds Docker images',
              'Orchestrates containers — automating deployment, scaling, and self-healing',
              'Manages cloud billing',
              'Provides a CI/CD pipeline',
            ],
            'correct': 1,
            'explanation':
                'Kubernetes automates container management — scheduling them across nodes, restarting failed ones, scaling based on load, and managing networking.',
          },
          {
            'question': 'When would you use a Spot/Preemptible instance?',
            'answers': [
              'For production databases requiring 99.99% uptime',
              'For fault-tolerant, interruptible workloads like batch processing or ML training',
              'For real-time financial transactions',
              'For the primary web server',
            ],
            'correct': 1,
            'explanation':
                'Spot instances can be reclaimed by the provider with short notice — ideal for stateless or checkpointed workloads that can tolerate interruption in exchange for deep discounts.',
          },
          {
            'question':
                'What is the benefit of Reserved Instances over On-Demand?',
            'answers': [
              'They are more flexible with no commitment',
              'They offer up to 72% discount in exchange for a 1 or 3 year commitment',
              'They guarantee unlimited capacity',
              'They include free support',
            ],
            'correct': 1,
            'explanation':
                'Reserved Instances trade flexibility for cost savings — ideal for predictable, steady-state workloads that run continuously.',
          },
          {
            'question':
                'In a serverless architecture, what triggers a Lambda/Cloud Function?',
            'answers': [
              'A scheduled server process',
              'An event — such as an HTTP request, file upload, or queue message',
              'A human operator',
              'A nightly batch job only',
            ],
            'correct': 1,
            'explanation':
                'Serverless functions are event-driven — they execute in response to triggers like API calls, file uploads to S3, or messages arriving in a queue.',
          },
        ];
      case 'module-03':
        return [
          {
            'question':
                'Which S3 storage class is most appropriate for archived compliance data rarely accessed?',
            'answers': [
              'S3 Standard',
              'S3 Intelligent-Tiering',
              'S3 Glacier Deep Archive',
              'S3 One Zone-IA',
            ],
            'correct': 2,
            'explanation':
                'S3 Glacier Deep Archive is the cheapest storage class, ideal for long-term retention of data that is rarely if ever accessed, with retrieval times of 12+ hours.',
          },
          {
            'question': 'When should you choose DynamoDB over RDS?',
            'answers': [
              'When you need complex multi-table SQL joins',
              'When you need ACID transactions across tables',
              'When you need single-digit millisecond performance at any scale with flexible schemas',
              'When you are storing financial ledger data',
            ],
            'correct': 2,
            'explanation':
                'DynamoDB excels at high-speed, high-scale key-value and document access with flexible schemas. RDS is better for relational data with complex queries.',
          },
          {
            'question': 'What is the purpose of a read replica?',
            'answers': [
              'To provide a writable backup of the database',
              'To offload read traffic from the primary database, improving performance',
              'To replace the primary database automatically',
              'To archive old data',
            ],
            'correct': 1,
            'explanation':
                'Read replicas serve read queries, reducing load on the primary instance which handles all writes — critical for read-heavy applications.',
          },
          {
            'question':
                'What is the difference between a data lake and a data warehouse?',
            'answers': [
              'They are the same thing',
              'A data lake stores raw unstructured data; a warehouse stores processed data optimised for analytics',
              'A data warehouse stores more data',
              'A data lake only stores images and video',
            ],
            'correct': 1,
            'explanation':
                'Data lakes store raw data in any format at low cost. Data warehouses store structured, processed data optimised for SQL analytics queries.',
          },
          {
            'question': 'What does RPO mean in disaster recovery?',
            'answers': [
              'Recovery Process Overview',
              'Recovery Point Objective — the maximum acceptable amount of data loss',
              'Redundant Processing Operations',
              'Real-time Performance Output',
            ],
            'correct': 1,
            'explanation':
                'RPO defines how much data you can afford to lose. An RPO of 1 hour means your backups must run at least every hour.',
          },
        ];
      case 'module-04':
        return [
          {
            'question': 'What is the core principle of Zero Trust?',
            'answers': [
              'Trust all traffic inside the corporate network',
              'Never trust, always verify — authenticate every request regardless of origin',
              'Block all external traffic by default',
              'Only use VPNs for security',
            ],
            'correct': 1,
            'explanation':
                'Zero Trust eliminates the concept of a trusted internal network. Every request must be authenticated and authorised, whether it comes from inside or outside.',
          },
          {
            'question': 'What does a CSPM tool primarily do?',
            'answers': [
              'Manages user passwords',
              'Monitors cloud environments for misconfigurations and compliance drift',
              'Encrypts data at rest',
              'Handles DDoS mitigation',
            ],
            'correct': 1,
            'explanation':
                'CSPM continuously scans cloud configurations for security issues — like public S3 buckets or overly permissive IAM policies — and alerts or auto-remediates them.',
          },
          {
            'question':
                'Why should secrets never be hardcoded in application code?',
            'answers': [
              'It slows down application performance',
              'Code is often stored in version control where secrets can be exposed permanently',
              'It makes the code harder to read',
              'Cloud providers prohibit it contractually',
            ],
            'correct': 1,
            'explanation':
                'Hardcoded secrets end up in Git history, logs, and shared repositories — once committed, they\'re nearly impossible to fully remove and can be stolen easily.',
          },
          {
            'question': 'What is a WAF used for in cloud security?',
            'answers': [
              'Encrypting data at rest',
              'Filtering malicious HTTP traffic like SQL injection and XSS at the application layer',
              'Managing VPC routing rules',
              'Monitoring cost anomalies',
            ],
            'correct': 1,
            'explanation':
                'A Web Application Firewall (WAF) inspects HTTP/S traffic and blocks known attack patterns before they reach your application servers.',
          },
          {
            'question':
                'What layer does AWS Shield Advanced protect against DDoS attacks?',
            'answers': [
              'Only application layer (Layer 7)',
              'Only network layer (Layer 3)',
              'Both network/transport layers and application layer',
              'Storage layer only',
            ],
            'correct': 2,
            'explanation':
                'AWS Shield Advanced provides protection at multiple layers — volumetric network attacks and sophisticated application-layer attacks — with 24/7 DDoS response team access.',
          },
        ];
      case 'module-05':
        return [
          {
            'question': 'What is Continuous Integration (CI)?',
            'answers': [
              'Deploying code to production automatically',
              'Automatically building and testing code on every commit',
              'Monitoring production systems',
              'Managing infrastructure with code',
            ],
            'correct': 1,
            'explanation':
                'CI automatically runs builds and tests whenever code is committed, catching integration issues early before they reach production.',
          },
          {
            'question': 'What is the key benefit of blue/green deployment?',
            'answers': [
              'It reduces server costs by 50%',
              'It enables instant traffic switching and zero-downtime rollback',
              'It automatically fixes bugs',
              'It requires no testing',
            ],
            'correct': 1,
            'explanation':
                'Blue/green maintains two environments — if the new version (green) has issues, traffic switches back to the old version (blue) instantly with no downtime.',
          },
          {
            'question': 'What is a canary release?',
            'answers': [
              'A deployment only to canary test servers',
              'Sending a small percentage of traffic to the new version before rolling out fully',
              'Releasing code at midnight only',
              'A rollback strategy after failure',
            ],
            'correct': 1,
            'explanation':
                'Canary releases reduce risk by gradually shifting traffic to the new version, monitoring for issues before exposing all users to the change.',
          },
          {
            'question': 'What are the three pillars of observability?',
            'answers': [
              'Uptime, Latency, Errors',
              'Metrics, Logs, Traces',
              'CPU, Memory, Disk',
              'Availability, Performance, Security',
            ],
            'correct': 1,
            'explanation':
                'Metrics (numerical measurements), Logs (timestamped events), and Traces (request journeys) together provide full observability into system behaviour.',
          },
          {
            'question': 'In GitOps, what is the single source of truth?',
            'answers': [
              'The production environment',
              'The monitoring dashboard',
              'The Git repository containing all infrastructure and app configuration',
              'The cloud provider console',
            ],
            'correct': 2,
            'explanation':
                'GitOps uses Git as the authoritative source — all changes go through pull requests, giving full audit history, approvals, and automated reconciliation.',
          },
        ];
      case 'module-06':
        return [
          {
            'question': 'What is right-sizing in cloud cost optimisation?',
            'answers': [
              'Buying the largest instances for future growth',
              'Matching instance types to actual workload requirements to avoid waste',
              'Reserving capacity 3 years in advance',
              'Using only free tier services',
            ],
            'correct': 1,
            'explanation':
                'Right-sizing analyses actual CPU, RAM, and network usage to select the most appropriate and cost-effective instance size without over-provisioning.',
          },
          {
            'question': 'What is the purpose of a resource tagging strategy?',
            'answers': [
              'To label servers with their IP addresses',
              'To enable cost allocation by team, project, or environment',
              'To group servers for automatic scaling',
              'To apply security patches automatically',
            ],
            'correct': 1,
            'explanation':
                'Tags enable you to see exactly who and what is driving cloud spend — essential for chargeback, budgeting, and accountability.',
          },
          {
            'question': 'What is FinOps?',
            'answers': [
              'Financial auditing of cloud providers',
              'A practice bringing financial accountability and engineering collaboration to cloud spending decisions',
              'A cloud cost calculator tool',
              'Finalising cloud contracts',
            ],
            'correct': 1,
            'explanation':
                'FinOps aligns engineering, finance, and business to make real-time, data-driven cloud spending decisions — it\'s a culture and practice, not just a tool.',
          },
          {
            'question':
                'When should you use Reserved Instances instead of On-Demand?',
            'answers': [
              'For temporary development environments',
              'For workloads that run continuously and predictably (24/7)',
              'For unpredictable burst traffic',
              'For Spot-eligible batch jobs',
            ],
            'correct': 1,
            'explanation':
                'Reserved Instances make financial sense for steady-state workloads that run constantly — the 1 or 3-year commitment pays off quickly compared to On-Demand rates.',
          },
          {
            'question': 'What is the most immediate way to reduce cloud waste?',
            'answers': [
              'Migrate to a cheaper provider',
              'Identify and terminate idle or unused resources',
              'Switch from SaaS to self-managed',
              'Disable monitoring to save costs',
            ],
            'correct': 1,
            'explanation':
                'Idle resources — stopped VMs still incurring EBS charges, forgotten test environments, unattached load balancers — are the fastest wins in a cost optimisation effort.',
          },
        ];
      case 'module-07':
        return [
          {
            'question': 'What does "Rehost" mean in the 6 Rs of migration?',
            'answers': [
              'Redesigning the application as microservices',
              'Moving to a SaaS replacement',
              'Lift and shift — moving the application to cloud with no changes',
              'Retiring the application entirely',
            ],
            'correct': 2,
            'explanation':
                'Rehost (lift & shift) moves an application to cloud infrastructure without any modifications — the fastest migration path but doesn\'t take advantage of cloud-native features.',
          },
          {
            'question': 'What is a cloud landing zone?',
            'answers': [
              'A physical location for cloud hardware',
              'A pre-configured, secure foundation of accounts and governance for cloud adoption',
              'A type of load balancer',
              'A disaster recovery region',
            ],
            'correct': 1,
            'explanation':
                'A landing zone establishes the foundational structure — account hierarchy, networking, security guardrails, and logging — before any workloads are deployed.',
          },
          {
            'question': 'What is a service mesh used for?',
            'answers': [
              'Storing microservice configuration files',
              'Managing inter-service communication with traffic control, mTLS, and observability',
              'Replacing Kubernetes networking',
              'Deploying containers to production',
            ],
            'correct': 1,
            'explanation':
                'A service mesh (Istio, Linkerd) handles service-to-service communication transparently — providing encryption, retries, circuit breaking, and telemetry without application code changes.',
          },
          {
            'question':
                'What does AWS Database Migration Service (DMS) primarily help with?',
            'answers': [
              'Backing up databases automatically',
              'Migrating databases to the cloud with minimal downtime using continuous replication',
              'Converting SQL queries to NoSQL',
              'Managing database user permissions',
            ],
            'correct': 1,
            'explanation':
                'AWS DMS replicates your database to the target in near-real-time, enabling a minimal-downtime cutover — often just minutes of interruption during final sync.',
          },
          {
            'question':
                'Which migration strategy involves the most redesign effort?',
            'answers': [
              'Rehost (lift & shift)',
              'Retain (keep on-prem)',
              'Retire (decommission)',
              'Refactor/Re-architect (redesign for cloud-native)',
            ],
            'correct': 3,
            'explanation':
                'Refactoring involves redesigning the application to leverage cloud-native services — the highest effort but delivers the most long-term benefit in scalability and cost.',
          },
        ];
      case 'module-08':
        return [
          {
            'question':
                'What is the recommended starting AWS certification for someone new to cloud?',
            'answers': [
              'AWS Solutions Architect Professional',
              'AWS Security Specialty',
              'AWS Certified Cloud Practitioner',
              'AWS DevOps Engineer Professional',
            ],
            'correct': 2,
            'explanation':
                'AWS Cloud Practitioner is the foundational certification — it covers core cloud concepts without deep technical requirements and is the right first step.',
          },
          {
            'question': 'What does SLO stand for?',
            'answers': [
              'Service Level Organisation',
              'Service Level Objective — an internal target for reliability',
              'System Latency Output',
              'Software Lifecycle Operations',
            ],
            'correct': 1,
            'explanation':
                'An SLO is an internal reliability target (e.g. 99.95% uptime). It should be stricter than the SLA so you have a buffer before breaching customer commitments.',
          },
          {
            'question': 'What does a Cloud Architect primarily do?',
            'answers': [
              'Writes all application code',
              'Designs cloud systems — selecting services, defining topology, and ensuring non-functional requirements',
              'Manages the billing account',
              'Monitors servers 24/7',
            ],
            'correct': 1,
            'explanation':
                'A Cloud Architect designs the overall system — choosing the right services, defining security and networking, and ensuring the design meets availability, performance, and cost requirements.',
          },
          {
            'question': 'What is TCO analysis used for in cloud decisions?',
            'answers': [
              'Tracking application performance',
              'Comparing the full true cost of on-premises vs cloud to justify migration decisions',
              'Calculating employee salaries',
              'Measuring SLA compliance',
            ],
            'correct': 1,
            'explanation':
                'TCO includes all costs — hardware, power, cooling, facilities, staffing. When all hidden on-prem costs are counted, cloud often proves more cost-effective than it appears.',
          },
          {
            'question': 'What is a cloud-native application?',
            'answers': [
              'Any application running on a cloud server',
              'An application designed from scratch using cloud services like containers, serverless, and managed services',
              'A legacy app moved to the cloud unchanged',
              'An application that only runs on one cloud provider',
            ],
            'correct': 1,
            'explanation':
                'Cloud-native means designed for the cloud — built with microservices, containers, serverless, and managed services to fully exploit cloud scalability and resilience.',
          },
        ];
      default:
        return [
          {
            'question': 'What is the Well-Architected Framework?',
            'answers': [
              'A cloud pricing guide',
              'Best practice pillars for designing reliable, secure, and cost-effective cloud systems',
              'A certification programme',
              'A hardware specification',
            ],
            'correct': 1,
            'explanation':
                'The Well-Architected Framework provides architectural best practices across six pillars for cloud systems.',
          },
          {
            'question': 'What are containers?',
            'answers': [
              'Physical server racks',
              'Portable packages containing an app and all its dependencies, sharing the host OS kernel',
              'A type of cloud storage',
              'Virtual machines with GUIs',
            ],
            'correct': 1,
            'explanation':
                'Containers package apps with dependencies and share the host kernel — lighter and faster than VMs.',
          },
          {
            'question': 'What is CI/CD?',
            'answers': [
              'Cloud Infrastructure / Cloud Deployment',
              'Continuous Integration / Continuous Delivery — automated build, test, and deployment pipelines',
              'Cost Inspection / Cost Dashboard',
              'Container Isolation / Container Delivery',
            ],
            'correct': 1,
            'explanation':
                'CI/CD automates the path from code commit to production deployment through automated testing and delivery pipelines.',
          },
          {
            'question': 'What is right-sizing?',
            'answers': [
              'Buying the biggest instance available',
              'Matching cloud resource sizes to actual workload requirements',
              'Resizing storage only',
              'Scaling to maximum capacity',
            ],
            'correct': 1,
            'explanation':
                'Right-sizing selects the most appropriate and cost-effective resource size based on actual measured usage.',
          },
          {
            'question': 'What are the 6 Rs of cloud migration?',
            'answers': [
              'Run, Restart, Rebuild, Replace, Retire, Repeat',
              'Rehost, Replatform, Repurchase, Refactor, Retire, Retain',
              'Relocate, Rewrite, Rebuild, Replace, Remove, Restore',
              'Refresh, Reboot, Reconfigure, Restore, Remove, Realign',
            ],
            'correct': 1,
            'explanation':
                'The 6 Rs describe the different strategies for migrating workloads to the cloud.',
          },
        ];
    }
  }

  List<Map<String, dynamic>> _defaultCyberQuestions() {
    return [
      {
        'question': 'What does CIA stand for in cybersecurity?',
        'answers': [
          'Confidentiality, Integrity, Availability',
          'Cyber Intelligence Agency',
          'Centralized IT Administration',
          'Controlled Information Access',
        ],
        'correct': 0,
        'explanation':
            'The CIA Triad — Confidentiality, Integrity, Availability — is the foundation of information security.',
      },
      {
        'question': 'What is a firewall?',
        'answers': [
          'A physical barrier in a data center',
          'Software that monitors and controls network traffic',
          'A type of encryption',
          'A backup system',
        ],
        'correct': 1,
        'explanation':
            'A firewall monitors and controls network traffic based on security rules.',
      },
      {
        'question': 'What does MFA stand for?',
        'answers': [
          'Multi-Factor Authentication',
          'Managed Firewall Access',
          'Multiple File Attachment',
          'Main Framework Architecture',
        ],
        'correct': 0,
        'explanation':
            'MFA requires two or more verification factors to grant access.',
      },
      {
        'question': 'What is ransomware?',
        'answers': [
          'Antivirus software',
          'Malware that encrypts files and demands payment',
          'A type of firewall',
          'A secure messaging app',
        ],
        'correct': 1,
        'explanation':
            'Ransomware encrypts a victim\'s files and demands payment for the decryption key.',
      },
      {
        'question': 'What is the principle of least privilege?',
        'answers': [
          'Giving all users admin access',
          'Giving users only the minimum access they need',
          'Blocking all external access',
          'Using the cheapest security tools',
        ],
        'correct': 1,
        'explanation':
            'Least privilege limits access to only what is necessary, reducing the impact of compromised accounts.',
      },
    ];
  }
}
