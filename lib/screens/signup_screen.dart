import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main_navigation.dart';
import 'app_router.dart';
import 'app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _selectedGoal = 'ITIL V4 Foundation';
  String? _errorMessage;

  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  final List<String> _goals = [
    'ITIL V4 Foundation',
    'CSM Certification',
    'Networking Basics',
    'CompTIA Security+',
    'Just exploring',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _signup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Create the Firebase Auth account
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // Set display name
      await credential.user?.updateDisplayName(name);

      // Save user profile to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'name': name,
        'email': email,
        'goal': _selectedGoal,
        'createdAt': FieldValue.serverTimestamp(),
        'enrolments': {},
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          AppRouter.fade(const MainNavigation()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.code == 'email-already-in-use'
            ? 'An account already exists with this email.'
            : e.code == 'invalid-email'
                ? 'Please enter a valid email address.'
                : e.code == 'weak-password'
                    ? 'Password is too weak. Use at least 6 characters.'
                    : 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final isDark = theme.isDark;

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildBackButton(context, theme),
                  const SizedBox(height: 48),
                  Text(
                    'Create\naccount.',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      color: theme.text,
                      letterSpacing: -1.8,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start your IT learning journey today.',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.subtext,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 48),
                  _buildLabel('Full name', theme),
                  const SizedBox(height: 8),
                  _buildTextField(_nameController, 'John Doe', false,
                      CupertinoIcons.person, theme),
                  const SizedBox(height: 16),
                  _buildLabel('Email address', theme),
                  const SizedBox(height: 8),
                  _buildTextField(_emailController, 'you@example.com', false,
                      CupertinoIcons.mail, theme),
                  const SizedBox(height: 16),
                  _buildLabel('Password', theme),
                  const SizedBox(height: 8),
                  _buildTextField(_passwordController, '••••••••', true,
                      CupertinoIcons.lock, theme),
                  const SizedBox(height: 28),
                  _buildLabel('What is your main learning goal?', theme),
                  const SizedBox(height: 12),
                  _buildGoalSelector(theme),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.red.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.exclamationmark_circle,
                              color: AppColors.red, size: 16),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_errorMessage!,
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.red)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 36),
                  _PressableButton(
                    onTap: _isLoading ? null : _signup,
                    color: AppColors.primary,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Create my account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(context);
                      },
                      child: RichText(
                        text: TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(
                              fontSize: 14, color: theme.subtext),
                          children: const [
                            TextSpan(
                              text: 'Sign in',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context, ThemeNotifier theme) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.chevron_left, size: 14, color: theme.subtext),
            const SizedBox(width: 4),
            Text('Back',
                style: TextStyle(
                    fontSize: 14,
                    color: theme.subtext,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, ThemeNotifier theme) {
    return Text(
      text,
      style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: theme.subtext,
          letterSpacing: -0.1),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint,
      bool isPassword, IconData icon, ThemeNotifier theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        keyboardType: isPassword
            ? TextInputType.visiblePassword
            : TextInputType.emailAddress,
        style: TextStyle(
            color: theme.text, fontSize: 15, letterSpacing: -0.2),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: theme.subtext, fontSize: 15),
          prefixIcon: Icon(icon, color: theme.subtext, size: 18),
          suffixIcon: isPassword
              ? GestureDetector(
                  onTap: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  child: Icon(
                    _obscurePassword
                        ? CupertinoIcons.eye_slash
                        : CupertinoIcons.eye,
                    color: theme.subtext,
                    size: 18,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        ),
      ),
    );
  }

  Widget _buildGoalSelector(ThemeNotifier theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _goals.map((goal) {
        final selected = _selectedGoal == goal;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedGoal = goal);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : theme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : theme.border,
              ),
            ),
            child: Text(
              goal,
              style: TextStyle(
                fontSize: 13,
                color: selected ? AppColors.primary : theme.subtext,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: -0.1,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PressableButton extends StatefulWidget {
  final VoidCallback? onTap;
  final Color color;
  final Widget child;

  const _PressableButton({
    required this.onTap,
    required this.color,
    required this.child,
  });

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:
          widget.onTap == null ? null : (_) => _controller.forward(),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              _controller.reverse();
              widget.onTap!();
            },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}
