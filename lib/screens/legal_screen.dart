import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_links.dart';
import 'app_theme.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  /// Hand a URL to the browser.
  ///
  /// This deliberately does NOT gate on `canLaunchUrl`, which is what used to
  /// make these rows do nothing at all. `canLaunchUrl` does not ask "is this
  /// URL reachable" — it asks the platform "is anything registered to handle
  /// this scheme", and it answers no in two cases we actually ship into:
  ///
  ///  * Android 11+ hides other packages unless the manifest declares a
  ///    `<queries>` entry for them. Ours declared only PROCESS_TEXT, so every
  ///    https URL looked unhandleable and all four rows died here.
  ///  * On the web, awaiting anything before `launchUrl` spends the user
  ///    gesture, and the popup blocker then eats the `window.open`.
  ///
  /// In both cases the old code took the silent `else` branch: no navigation,
  /// no error, nothing to tell the user or us that a tap had been swallowed.
  ///
  /// The paywall has always launched directly and its links work, so this now
  /// matches it — and says so out loud when a launch genuinely fails.
  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw Exception('the platform refused to open it');
      }
    } catch (e) {
      debugPrint('Could not open $url: $e');
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Could not open $url'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showDisclaimer(BuildContext context) {
    final theme = AppTheme.of(context);
    showCupertinoModalPopup(
      context: context,
      // Material, and why this sheet needs one when nothing else here does.
      //
      // showCupertinoModalPopup builds its child in a route of its own, above
      // the Navigator — outside this screen's Scaffold, and so outside any
      // Material. With no Material ancestor there is no DefaultTextStyle from
      // the theme, so Text fell back to WidgetsApp's error style: red
      // monospace with a double YELLOW UNDERLINE. The styles below set size,
      // weight and colour but never `decoration`, and an unset field is
      // inherited — so every line in this sheet, and only this sheet, came out
      // underlined in yellow. That is the "highlighting everything" bug.
      //
      // Every other sheet in the app uses showModalBottomSheet, which wraps
      // its child in a Material and never had the problem.
      builder: (sheetContext) => Material(
        color: Colors.transparent,
        // Six trademark rows and two paragraphs are taller than a short screen,
        // and taller than any screen once the reader has turned text size up.
        // Unbounded, the Column simply overflowed and the bottom of the notice
        // — including the button that dismisses it — was clipped away.
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Certification Disclaimer',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: theme.text,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'B1nary is an independent educational app and is not affiliated with, endorsed by, or sponsored by any certification body.',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.subtext,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _disclaimerRow(
                      'ITIL®',
                      'Registered trademark of PeopleCert/AXELOS Limited',
                      theme),
                  _disclaimerRow('CSM®, Certified ScrumMaster®',
                      'Registered trademarks of Scrum Alliance, Inc.', theme),
                  _disclaimerRow('CompTIA®, Network+®, Security+®',
                      'Registered trademarks of CompTIA, Inc.', theme),
                  _disclaimerRow(
                      'AWS®',
                      'Registered trademark of Amazon Web Services, Inc.',
                      theme),
                  _disclaimerRow('Azure®',
                      'Registered trademark of Microsoft Corporation', theme),
                  _disclaimerRow('Google Cloud®',
                      'Registered trademark of Google LLC', theme),
                  const SizedBox(height: 16),
                  Text(
                    'All course content is created independently for educational purposes. Our flashcards and quizzes represent our own interpretation of publicly available frameworks and do not reproduce official exam materials.',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.subtext,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Got it',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _disclaimerRow(String trademark, String owner, ThemeNotifier theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              trademark,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.text,
              ),
            ),
          ),
          Expanded(
            child: Text(
              owner,
              style: TextStyle(fontSize: 13, color: theme.subtext),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        // Scrollable, because this page does not fit a short phone in
        // landscape or a small phone with the text size turned up: the footer
        // and the last tile were simply cut off the bottom.
        child: WebContentBounds(
            maxWidth: 720,
            child: SingleChildScrollView(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            color: theme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back_ios_new_rounded,
                                  size: 13, color: theme.subtext),
                              const SizedBox(width: 5),
                              Text('Back',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: theme.subtext,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text('Legal',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: theme.text,
                              letterSpacing: -0.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _LegalTile(
                        icon: CupertinoIcons.lock_shield_fill,
                        title: 'Privacy Policy',
                        subtitle: 'How we collect and use your data',
                        color: const Color(0xFF6366F1),
                        theme: theme,
                        onTap: () => _open(context, kPrivacyUrl),
                      ),
                      const SizedBox(height: 10),
                      _LegalTile(
                        icon: CupertinoIcons.doc_text_fill,
                        title: 'Terms of Service',
                        subtitle: 'Rules for using B1nary',
                        color: const Color(0xFF8B5CF6),
                        theme: theme,
                        onTap: () => _open(context, kTermsUrl),
                      ),
                      const SizedBox(height: 10),
                      _LegalTile(
                        icon: CupertinoIcons.cart_fill,
                        title: 'Subscription Terms',
                        subtitle: 'Purchases, trials and refund policy',
                        color: const Color(0xFF10B981),
                        theme: theme,
                        onTap: () => _open(context, kPurchaseTermsUrl),
                      ),
                      const SizedBox(height: 10),
                      _LegalTile(
                        icon: CupertinoIcons.rosette,
                        title: 'Certification Disclaimer',
                        subtitle:
                            'ITIL®, CSM®, CompTIA®, AWS® and other trademarks',
                        color: const Color(0xFFF59E0B),
                        theme: theme,
                        onTap: () => _showDisclaimer(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'B1nary is not affiliated with or endorsed by any certification body.\nVersion 1.0.0',
                    style: TextStyle(
                        fontSize: 12, color: theme.subtext, height: 1.6),
                  ),
                ),
              ],
            ))),
      ),
    );
  }
}

class _LegalTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final ThemeNotifier theme;
  final VoidCallback onTap;

  const _LegalTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.text,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: theme.subtext)),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 14, color: theme.subtext),
          ],
        ),
      ),
    );
  }
}
