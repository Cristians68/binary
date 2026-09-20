import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'account_deletion.dart';
import 'app_theme.dart';
import 'app_router.dart';
import 'auth_service.dart';
import 'review_service.dart';
import 'offline_service.dart';
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

  /// How this account re-confirms before deletion. See account_deletion.dart.
  DeletionReauth get _reauth => deletionReauthFor(
      _user?.providerData.map((p) => p.providerId) ?? const <String>[]);

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

      // Re-confirm with whatever this account actually signs in with. The old
      // split was "Google, or type a password", which asked guests and Apple
      // accounts for a password they do not have. See account_deletion.dart.
      String? appleAuthorizationCode;
      switch (_reauth) {
        case DeletionReauth.google:
          {
            final google = await AuthService.reauthenticateWithGoogle();
            if (!mounted) return;
            if (!google.isSuccess) {
              setState(() {
                _error = google.isCancelled
                    ? 'Google sign-in was cancelled.'
                    : google.displayMessage('Google');
                _loading = false;
              });
              return;
            }
          }
        case DeletionReauth.password:
          {
            // Never trim passwords — spaces may be intentional
            final password = _passwordController.text;
            if (password.isEmpty) {
              setState(() {
                _error = 'Please enter your password to confirm.';
                _loading = false;
              });
              return;
            }
            final credential = EmailAuthProvider.credential(
              email: user.email ?? '',
              password: password,
            );
            _passwordController.clear();
            await user.reauthenticateWithCredential(credential);
          }
        case DeletionReauth.apple:
          {
            final apple = await AuthService.reauthenticateWithApple();
            if (!apple.result.isSuccess) {
              setState(() {
                _error = apple.result.isCancelled
                    ? 'Apple sign-in was cancelled.'
                    : apple.result.displayMessage('Apple');
                _loading = false;
              });
              return;
            }
            appleAuthorizationCode = apple.authorizationCode;
          }
        case DeletionReauth.none:
          // A guest has nothing to re-enter. deleteAccount acts on this
          // session's verified ID token, which only this device holds.
          break;
      }

      // Apple requires an account's Sign in with Apple token to be revoked
      // when the account is deleted. Revoke first, while the Firebase user
      // still exists, which is the order Firebase documents. A failed
      // revocation does not block the deletion the person asked for.
      if (appleAuthorizationCode != null) {
        try {
          await FirebaseAuth.instance
              .revokeTokenWithAuthorizationCode(appleAuthorizationCode);
        } catch (e) {
          debugPrint('Apple token revocation failed: $e');
        }
      }

      // Firestore denies client-side deletes on /users/{uid} (see
      // firestore.rules), and doing this server-side keeps Firestore cleanup
      // and Auth-record deletion atomic from the client's point of view — see
      // functions/account.js for why. Reauthentication above proves this is
      // really the account owner asking.
      await FirebaseFunctions.instance
          .httpsCallable('deleteAccount')
          .call<void>();

      // The Auth record is gone server-side now; drop the local session too
      // so no stale cached user lingers on this device.
      await AuthService.signOut();

      // The spaced-repetition queue lives in SharedPreferences, not Firestore,
      // so the server-side delete above does not touch it. Without this the
      // next person to sign in on this device inherits the previous user's
      // missed questions.
      await ReviewService.clear(userId: user.uid);
      await OfflineService.clearForUser(user.uid);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          AppRouter.fade(const WelcomeScreen()),
          (route) => false,
        );
      }
    } on FirebaseFunctionsException catch (e) {
      // `not-found` means deleteAccount is not deployed. Show the code, so a
      // failure on a device can be read back instead of guessed at.
      setState(() {
        _error =
            'Could not delete your account (${e.code}). Please try again.';
        _loading = false;
      });
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
        child: WebContentBounds(maxWidth: 640, child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  color: AppColors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                    CupertinoIcons.exclamationmark_triangle_fill,
                    color: AppColors.red,
                    size: 28),
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
                style: TextStyle(
                    fontSize: 15, color: theme.subtext, height: 1.5),
              ),

              const SizedBox(height: 28),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: AppColors.red.withValues(alpha: 0.15)),
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

              if (_reauth == DeletionReauth.password) ...[
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
                      hintStyle:
                          TextStyle(color: theme.subtext, fontSize: 15),
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

              // Every other account is told how it will confirm, so a guest
              // or an Apple account is never left looking for a password.
              if (_reauth != DeletionReauth.password) ...[
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
                          switch (_reauth) {
                            DeletionReauth.google =>
                              'You signed in with Google. You\'ll be asked to re-authenticate before deletion.',
                            DeletionReauth.apple =>
                              'You signed in with Apple. You\'ll be asked to confirm with Apple before deletion.',
                            DeletionReauth.none =>
                              'No password is needed. Deleting removes this account and everything saved in it.',
                            // Excluded by the `if` above.
                            DeletionReauth.password => '',
                          },
                          style: TextStyle(
                              fontSize: 13,
                              color: theme.subtext,
                              height: 1.4)),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.red.withValues(alpha: 0.2)),
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

              GestureDetector(
                onTap: _loading ? null : _deleteAccount,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _loading
                        ? AppColors.red.withValues(alpha: 0.5)
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
        )),
      ),
    );
  }
}
