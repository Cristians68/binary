import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'subscription_service.dart';

/// Restore Purchases button — REQUIRED by Apple App Review Guideline 3.1.1
/// for any app with non-consumable in-app purchases.
///
/// Drop this anywhere visible. Best placements:
///   - Profile screen (most common)
///   - Paywall screen (also good)
///   - Settings menu
///
/// Usage:
///   ```dart
///   const RestorePurchasesButton()
///   ```
class RestorePurchasesButton extends StatefulWidget {
  const RestorePurchasesButton({super.key});

  @override
  State<RestorePurchasesButton> createState() => _RestorePurchasesButtonState();
}

class _RestorePurchasesButtonState extends State<RestorePurchasesButton> {
  bool _loading = false;

  Future<void> _restore() async {
    if (_loading) return;
    HapticFeedback.lightImpact();
    setState(() => _loading = true);

    try {
      final hasActive = await SubscriptionService.restore();
      if (!mounted) return;

      _showResult(
        success: hasActive,
        message: hasActive
            ? 'Your purchases have been restored.'
            : 'No previous purchases found on this Apple ID.',
      );
    } catch (e) {
      if (!mounted) return;
      _showResult(
        success: false,
        message: 'Could not restore purchases. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showResult({required bool success, required String message}) {
    final theme = AppTheme.of(context);
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(success ? 'Purchases Restored' : 'Notice'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return GestureDetector(
      onTap: _loading ? null : _restore,
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
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CupertinoActivityIndicator(
                        color: Color(0xFF10B981),
                      ),
                    )
                  : const Icon(
                      CupertinoIcons.arrow_clockwise,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Restore Purchases',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.text,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _loading
                        ? 'Checking your Apple ID…'
                        : 'Restore previous course purchases',
                    style:
                        TextStyle(fontSize: 12, color: theme.subtext),
                  ),
                ],
              ),
            ),
            if (!_loading)
              Icon(CupertinoIcons.chevron_right,
                  size: 14, color: theme.subtext),
          ],
        ),
      ),
    );
  }
}