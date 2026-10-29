import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'build_identity.dart';
import 'service_backend.dart';

/// Private feedback stays separate from the public App Store rating action.
class FeedbackSheet extends StatefulWidget {
  const FeedbackSheet({super.key});

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  final _message = TextEditingController();
  int _stars = 0;
  bool _sending = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final message = _message.text.trim();
    if (message.isEmpty && _stars == 0) {
      setState(() => _error = 'Please add a rating or message.');
      return;
    }
    final uid = ServiceBackend.uid;
    if (uid == null) {
      setState(() => _error = 'Sign in again to send feedback.');
      return;
    }
    final stars = _stars;
    setState(() {
      _sending = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();
    try {
      final build = await BuildIdentity.load();
      if (!mounted) return;
      if (ServiceBackend.uid != uid) {
        setState(() {
          _sending = false;
          _error = 'Your account changed. Please reopen feedback.';
        });
        return;
      }
      await ServiceBackend.db.collection('feedback').add({
        'uid': uid,
        'stars': stars,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'appVersion': build.version ?? 'unknown',
        if (build.build != null) 'build': build.build,
        if (build.revision != null) 'revision': build.revision,
      });
      if (!mounted) return;
      setState(() {
        _sending = false;
        _submitted = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Feedback could not be sent. Your message is still here. '
            'Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _submitted
              ? [
                  const Icon(CupertinoIcons.checkmark_circle_fill,
                      color: AppColors.green, size: 48),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text('Thanks for your feedback!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: theme.text)),
                  ),
                  const SizedBox(height: 12),
                  Text('Your feedback helps us improve B1nary.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.subtext)),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ]
              : [
                  Text('Send feedback',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: theme.text)),
                  const SizedBox(height: 12),
                  Text('How would you rate B1nary?',
                      style: TextStyle(color: theme.text)),
                  const SizedBox(height: 8),
                  Wrap(
                    children: List.generate(5, (i) {
                      final selected = i < _stars;
                      return Semantics(
                        selected: _stars == i + 1,
                        child: IconButton(
                          tooltip: '${i + 1} ${i == 0 ? 'star' : 'stars'}',
                          onPressed: _sending
                              ? null
                              : () => setState(() => _stars = i + 1),
                          color: theme.accent(AppColors.amber),
                          icon: Icon(selected
                              ? CupertinoIcons.star_fill
                              : CupertinoIcons.star),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _message,
                    enabled: !_sending,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 4000,
                    style: TextStyle(color: theme.text),
                    decoration: const InputDecoration(
                      labelText: 'Your message',
                      hintText: 'What is working well? What could be better?',
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(_error!,
                          style: TextStyle(color: theme.accent(AppColors.red))),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send feedback'),
                  ),
                ],
        ),
      ),
    );
  }
}
