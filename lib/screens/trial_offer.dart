import 'dart:async';

import 'package:flutter/material.dart';
import '../course_catalog.dart';
import 'app_theme.dart';
import 'subscription_service.dart';

class TrialOffer extends StatefulWidget {
  final String? courseId;
  final Color color;
  final bool disabled;
  final Future<TrialState> Function() loadState;
  final Future<bool> Function(String) startTrial;
  final VoidCallback onActivated;
  final ValueChanged<bool> onBusyChanged;

  const TrialOffer({
    super.key,
    this.courseId,
    required this.color,
    this.disabled = false,
    this.loadState = SubscriptionService.getTrialState,
    this.startTrial = SubscriptionService.startTrial,
    required this.onActivated,
    required this.onBusyChanged,
  });

  @override
  State<TrialOffer> createState() => _TrialOfferState();
}

class _TrialOfferState extends State<TrialOffer> {
  TrialState? _trial;
  String? _selection;
  String? _error;
  bool _checking = true;
  bool _starting = false;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _selection = courseInfo(widget.courseId ?? '')?.id;
    _load();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final trial = await widget.loadState();
      if (!mounted) return;
      _expiryTimer?.cancel();
      if (trial.isActive) {
        _expiryTimer = Timer(trial.expiresAt!.difference(DateTime.now()), () {
          if (mounted) setState(() {});
        });
      }
      setState(() => _trial = trial);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not check your trial. Check your connection and retry.');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _start() async {
    final courseId = _selection;
    if (_starting || widget.disabled || courseId == null) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    widget.onBusyChanged(true);
    try {
      final activated = await widget.startTrial(courseId);
      if (!mounted) return;
      if (activated) {
        widget.onActivated();
      } else {
        setState(
            () => _error = 'Your trial was not activated. Please try again.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is TrialFailure
            ? error.message
            : 'Your trial could not be started. Please try again. No payment was taken.');
      }
    } finally {
      if (mounted) {
        setState(() => _starting = false);
        widget.onBusyChanged(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final trial = _trial;
    final active = trial?.isActive ?? false;
    final used = trial?.hasUsedTrial ?? false;
    final courseTitle =
        courseInfo(trial?.courseId ?? '')?.title ?? 'your chosen course';
    final canContinue = active &&
        (widget.courseId == null || trial!.courseId == widget.courseId);
    final expiry = trial?.expiresAt;
    final expiryLabel = expiry == null
        ? ''
        : '${MaterialLocalizations.of(context).formatMediumDate(expiry.toLocal())}, '
            '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(expiry.toLocal()))}';

    return Container(
      key: const ValueKey('trial-offer'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.accent(widget.color)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              active
                  ? 'Your free trial is active'
                  : used
                      ? 'Your free trial has ended'
                      : 'Try a full course free for 7 days',
              style: TextStyle(
                  color: theme.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
              active
                  ? '$courseTitle is unlocked until $expiryLabel. No automatic charge.'
                  : used
                      ? 'Your one-time trial has been used. The first module of every course is still free. Buy a course to keep full access.'
                      : 'One course of your choice, including every lesson and quiz. One trial per account. No card required. No automatic charge.',
              style: TextStyle(color: theme.subtext, height: 1.5)),
          if (_checking) ...[
            const SizedBox(height: 12),
            Text('Checking trial availability…',
                style: TextStyle(color: theme.subtext)),
          ] else if (trial == null) ...[
            TextButton(
                onPressed: widget.disabled ? null : _load,
                child: const Text('Retry trial check')),
          ] else if (!used && !active) ...[
            const SizedBox(height: 12),
            if (widget.courseId == null)
              DropdownButtonFormField<String>(
                key: const ValueKey('trial-course-picker'),
                initialValue: _selection,
                isExpanded: true,
                itemHeight: null,
                decoration: const InputDecoration(
                    labelText: 'Course for your free trial'),
                items: [
                  for (final course in kCourseCatalog)
                    DropdownMenuItem(
                        value: course.id,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(course.title)))
                ],
                onChanged: widget.disabled || _starting
                    ? null
                    : (value) => setState(() => _selection = value),
                selectedItemBuilder: (_) => [
                  for (final course in kCourseCatalog)
                    Text(course.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis)
                ],
              )
            else
              Text(courseInfo(_selection ?? '')?.title ?? 'Choose a course',
                  style: TextStyle(
                      color: theme.text, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('start-trial'),
              style: FilledButton.styleFrom(
                  backgroundColor: theme.accent(widget.color),
                  foregroundColor: Colors.white),
              onPressed: _selection == null || widget.disabled || _starting
                  ? null
                  : _start,
              child: Text(_starting
                  ? 'Starting your trial…'
                  : 'Start 7-day free trial'),
            ),
            const SizedBox(height: 6),
            Text(
                'Your 7 days begin when you tap Start. You cannot switch the trial to another course.',
                style:
                    TextStyle(color: theme.subtext, fontSize: 12, height: 1.4)),
          ] else if (canContinue)
            TextButton(
                onPressed: widget.disabled ? null : widget.onActivated,
                child: const Text('Continue with trial access')),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Semantics(
                liveRegion: true,
                child: Text(_error!,
                    style: TextStyle(color: theme.text, height: 1.4))),
          ],
        ],
      ),
    );
  }
}
