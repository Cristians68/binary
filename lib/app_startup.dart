import 'dart:async';

import 'package:flutter/material.dart';
import 'screens/app_theme.dart';

/// Cache a successful or still-running initialization. A deadline releases
/// the caller, but cannot cancel a native operation; a retry must await that
/// same operation instead of starting another sign-out or SDK instance.
class StartupTask<T> {
  StartupTask(this.initialize);

  final Future<T> Function() initialize;
  Future<T>? _initialization;

  Future<T> run({Duration timeout = const Duration(seconds: 30)}) {
    final initialization = _initialization ??= Future<T>.sync(initialize);
    return initialization.then((value) => value,
        onError: (Object error, StackTrace stack) {
      if (identical(_initialization, initialization)) {
        _initialization = null;
      }
      Error.throwWithStackTrace(error, stack);
    }).timeout(timeout);
  }
}

/// Paint immediately, including when Firebase cannot initialize. A startup
/// failure must offer recovery instead of leaving the native launch screen up.
class AppStartup extends StatefulWidget {
  const AppStartup({
    super.key,
    required this.initialize,
    this.timeout = const Duration(seconds: 30),
  });

  final Future<Widget> Function() initialize;
  final Duration timeout;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  late final StartupTask<Widget> _startup;
  late Future<Widget> _app;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _startup = StartupTask(widget.initialize);
    _beginAttempt();
  }

  void _beginAttempt() {
    _retrying = true;
    _app = _startup.run(timeout: widget.timeout);
    // Attach an error handler immediately. A synchronous retry failure can
    // arrive before the next frame subscribes FutureBuilder to the new future.
    unawaited(_app.then<void>((_) {
      _retrying = false;
    }, onError: (Object error, StackTrace stack) {
      _retrying = false;
    }));
  }

  void _retry() {
    if (_retrying) return;
    setState(_beginAttempt);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
        future: _app,
        builder: (context, snapshot) {
          final finished = snapshot.connectionState == ConnectionState.done;
          final failed = finished && snapshot.hasError;
          if (finished && snapshot.hasData) return snapshot.requireData;
          return MaterialApp(
            title: 'B1nary',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(colorSchemeSeed: AppColors.primary),
            home: Scaffold(
              body: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIcon(size: 72),
                          const SizedBox(height: 24),
                          Text(
                            failed ? 'Let’s try again' : 'B1nary',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 16),
                          if (failed) ...[
                            const Text(
                              'We couldn’t open your study space. Try again. If this keeps happening, check your connection or restart the app.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _retry,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Try again'),
                            ),
                          ] else
                            const CircularProgressIndicator(
                                semanticsLabel: 'Opening your study space'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}

/// Optional SDKs must neither fail launch nor keep it waiting indefinitely.
Future<void> runOptionalStartupTask(
    String name, Future<void> Function() initialize,
    {Duration timeout = const Duration(seconds: 5)}) async {
  try {
    await Future.sync(initialize).timeout(timeout);
  } catch (error) {
    debugPrint('$name initialization deferred: $error');
  }
}
