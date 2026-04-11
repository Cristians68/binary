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

    if (tag == 'ITIL V4') {
      return [
        {
          'label': 'Definition',
          'term': 'What is ITIL V4?',
          'definition':
              'ITIL V4 is a framework of best practices for IT Service Management (ITSM). It provides guidance on how to design, deliver, and improve IT services that align with business needs.',
          'example':
              'A company uses ITIL to make sure their helpdesk, software updates, and server maintenance all follow consistent, repeatable processes.',
        },
        {
          'label': 'Core concept',
          'term': 'Service Value System (SVS)',
          'definition':
              'The SVS describes how all the components and activities of an organization work together to create value. It includes the guiding principles, governance, service value chain, practices, and continual improvement.',
          'example':
              'Think of the SVS as the engine of ITIL — it shows how everything connects to deliver value to customers.',
        },
        {
          'label': 'Core concept',
          'term': 'The 4 Dimensions',
          'definition':
              'ITIL V4 defines 4 dimensions: 1) Organizations & People, 2) Information & Technology, 3) Partners & Suppliers, 4) Value Streams & Processes.',
          'example':
              'When launching a new IT service, you must think about who will run it, what tech is needed, which vendors help, and how the workflow works.',
        },
        {
          'label': 'Guiding principle',
          'term': 'Focus on Value',
          'definition':
              'Everything the organization does should link back to delivering value for itself, its customers, and other stakeholders.',
          'example':
              'Before building a new IT tool, ask: does this solve a real problem for the user?',
        },
        {
          'label': 'Guiding principle',
          'term': 'Start Where You Are',
          'definition':
              'Do not start from scratch if you do not have to. Assess what already exists and build on current services, processes, and tools.',
          'example':
              'Instead of replacing an entire system, evaluate what works and improve it step by step.',
        },
      ];
    } else if (tag == 'CSM') {
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

    // Default networking fallback
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
