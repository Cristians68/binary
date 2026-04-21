import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'app_router.dart';
import 'welcome_screen.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  User? get _user => FirebaseAuth.instance.currentUser;

  bool get _isGoogleUser =>
      _user?.providerData.any((p) => p.providerId == 'google.com') ?? false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (_loading) return;
    HapticFeedback.mediumImpact();

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently delete your account and all your data. This cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Re-authenticate
      if (_isGoogleUser) {
        await user.reauthenticateWithProvider(GoogleAuthProvider());
      } else {
        final credential = EmailAuthProvider.credential(
          email: user.email ?? '',
          password: _passwordController.text.trim(),
        );
        await user.reauthenticateWithCredential(credential);
      }

      final uid = user.uid;

      // Delete Firestore data first
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      } catch (_) {}

      // Delete auth account
      await user.delete();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          AppRouter.fade(const WelcomeScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'wrong-password' => 'Incorrect password. Please try again.',
          'requires-recent-login' =>
            'Please sign out and sign back in, then try again.',
          _ => 'Something went wrong. Please try again.',
        };
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

              const SizedBox(height: 40),

              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                    color: AppColors.red, size: 28),
              ),

              const SizedBox(height: 20),

              Text('Delete account',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: theme.text,
                      letterSpacing: -0.8)),

              const SizedBox(height: 10),

              Text(
                'This will permanently delete your account and all associated data including your progress, badges, and quiz scores. This cannot be undone.',
                style:
                    TextStyle(fontSize: 15, color: theme.subtext, height: 1.5),
              ),

              const SizedBox(height: 28),

              // What gets deleted
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.red.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What will be deleted:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.text)),
                    const SizedBox(height: 10),
                    ...[
                      'Account and sign-in credentials',
                      'All course progress and completions',
                      'Badges and streak history',
                      'Quiz scores and lesson history',
                      'Subscription and purchase records',
                    ].map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(children: [
                            const Icon(CupertinoIcons.xmark_circle_fill,
                                size: 14, color: AppColors.red),
                            const SizedBox(width: 8),
                            Text(item,
                                style: TextStyle(
                                    fontSize: 13, color: theme.subtext)),
                          ]),
                        )),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              if (!_isGoogleUser) ...[
                Text('Enter your password to confirm',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.subtext)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.border),
                  ),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    style: TextStyle(color: theme.text, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: TextStyle(color: theme.subtext, fontSize: 15),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 15),
                      suffixIcon: GestureDetector(
                        onTap: () => setState(() => _obscure = !_obscure),
                        child: Icon(
                            _obscure
                                ? CupertinoIcons.eye_slash
                                : CupertinoIcons.eye,
                            color: theme.subtext,
                            size: 18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_isGoogleUser) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.border),
                  ),
                  child: Row(children: [
                    Icon(CupertinoIcons.info_circle,
                        size: 16, color: theme.subtext),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          'You signed in with Google. You\'ll be asked to re-authenticate before deletion.',
                          style: TextStyle(
                              fontSize: 13, color: theme.subtext, height: 1.4)),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.red.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(CupertinoIcons.exclamationmark_circle,
                        color: AppColors.red, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.red))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // Delete button
              GestureDetector(
                onTap: _loading ? null : _deleteAccount,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _loading
                        ? AppColors.red.withOpacity(0.5)
                        : AppColors.red,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _loading
                      ? const Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2)))
                      : const Text('Delete my account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: -0.3)),
                ),
              ),

              const SizedBox(height: 12),

              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.border),
                  ),
                  child: Text('Cancel',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: theme.subtext)),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
