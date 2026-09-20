import 'package:flutter/material.dart';

import 'back_swipe.dart';

/// The app's page transitions.
///
/// [push] and [slide] build [SwipeBackPageRoute]s, so every screen reached
/// through them can also be dismissed by dragging in from the left edge. The
/// transitions themselves are unchanged — see [SwipeBackPageRoute] for why the
/// gesture had to be written out rather than taken from Cupertino, and for the
/// one moment the transition differs (while a finger is actually dragging).
class AppRouter {
  /// Lifts the page up into place.
  static Route<T> slide<T>(Widget page) {
    return SwipeBackPageRoute<T>(
      child: page,
      enterOffset: const Offset(0, 0.03),
      fadeCurve: Curves.easeOut,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// The standard forward push: a short slide in from the trailing edge.
  static Route<T> push<T>(Widget page) {
    return SwipeBackPageRoute<T>(
      child: page,
      enterOffset: const Offset(0.04, 0),
      fadeCurve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// Deliberately NOT swipeable.
  ///
  /// This is the "replace the world" transition — sign in, sign out, delete
  /// account. Swiping back into a session that has just been torn down is not
  /// something a user should be able to do, so it stays a plain route.
  static Route<T> fade<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 500),
      reverseTransitionDuration: const Duration(milliseconds: 400),
    );
  }
}
