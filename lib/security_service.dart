import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:flutter/services.dart';

class SecurityService {
  /// Call this in main.dart before runApp()
  /// Returns true if device is safe, false if compromised
  static Future<bool> isDeviceSafe() async {
    try {
      final bool isJailbroken = await FlutterJailbreakDetection.jailbroken;
      final bool isDeveloperMode = await FlutterJailbreakDetection.developerMode;
      return !isJailbroken && !isDeveloperMode;
    } on PlatformException {
      // If we can't check, assume safe (avoids blocking legitimate users)
      return true;
    }
  }
}

/// Wrap your MaterialApp with this to block compromised devices
class SecurityGate extends StatefulWidget {
  final Widget child;
  const SecurityGate({super.key, required this.child});

  @override
  State<SecurityGate> createState() => _SecurityGateState();
}

class _SecurityGateState extends State<SecurityGate> {
  bool _isChecking = true;
  bool _isDeviceSafe = true;

  @override
  void initState() {
    super.initState();
    _checkSecurity();
  }

  Future<void> _checkSecurity() async {
    final safe = await SecurityService.isDeviceSafe();
    if (mounted) {
      setState(() {
        _isDeviceSafe = safe;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF0A0A0F),
          body: Center(
            child: CircularProgressIndicator(
              color: Color(0xFF6366F1),
            ),
          ),
        ),
      );
    }

    if (!_isDeviceSafe) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0A0A0F),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      CupertinoIcons.shield_slash_fill,
                      color: Color(0xFFEF4444),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Device Not Supported',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Binary Academy cannot run on jailbroken or rooted devices. This protects your account and learning data.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
