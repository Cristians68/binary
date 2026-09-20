import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Edge-swipe-to-go-back for the app's own page routes.
///
/// WHY THIS EXISTS
/// ---------------
/// The app navigates almost entirely through [AppRouter], which built
/// `PageRouteBuilder`s so it could keep its own quiet fade-and-lift
/// transition. That is also why dragging from the left edge did nothing: the
/// back gesture is not a property of the app or of the platform, it is built
/// into `CupertinoRouteTransitionMixin`, and a `PageRouteBuilder` does not
/// have it. `MaterialPageRoute` picks it up from `PageTransitionsTheme` —
/// which is why the handful of screens pushed that way could always be swiped
/// back, and the other twenty could not.
///
/// Flutter's implementation of the gesture is private
/// (`_CupertinoBackGestureDetector`), and the only public way in,
/// `CupertinoRouteTransitionMixin`, drags the whole Cupertino slide transition
/// along with it. Taking that would have replaced the app's transitions
/// everywhere. So the gesture itself is ported here — the drag tracking, the
/// fling thresholds and the hand-off to the navigator all follow
/// `flutter/lib/src/cupertino/route.dart`, so the feel matches iOS.

/// Width of the strip along the leading edge that can start a back swipe.
/// Cupertino's `_kBackGestureWidth`.
const double _kBackGestureWidth = 20.0;

/// Screen widths per second. Cupertino's `_kMinFlingVelocity`.
const double _kMinFlingVelocity = 1.0;

/// How long the page takes to finish travelling after the finger lifts.
const Duration _kDroppedSwipePageAnimationDuration = Duration(
  milliseconds: 350,
);

/// A page route that answers the back-swipe gesture.
///
/// The transition is described by [enterOffset] and [fadeCurve] rather than by
/// a `transitionsBuilder`, because the route has to be able to build a
/// *different* animation while a finger is down without changing the shape of
/// the widget tree. See [buildTransitions].
class SwipeBackPageRoute<T> extends PageRoute<T> {
  SwipeBackPageRoute({
    required this.child,
    required this.enterOffset,
    required this.fadeCurve,
    required this.transitionDuration,
    required this.reverseTransitionDuration,
  });

  final Widget child;

  /// Where the page starts, as a fraction of its own size, for an ordinary
  /// push. The app uses small values — it lifts and fades rather than sliding.
  final Offset enterOffset;

  final Curve fadeCurve;

  @override
  final Duration transitionDuration;

  @override
  final Duration reverseTransitionDuration;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  /// [TransitionRoute.controller] is `@protected`, which is fine to read from
  /// a subclass. The gesture needs it to drive the page with the finger.
  AnimationController get swipeController => controller!;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => child;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final bool dragging = popGestureInProgress;

    // The shape of this tree is identical in both branches, deliberately.
    //
    // The first version of this swapped widgets in and out when the drag
    // started, and the drag died the instant it began: moving a widget to a
    // different depth makes Flutter rebuild everything under it, which threw
    // away the gesture detector's own State mid-gesture — and would have reset
    // the page's scroll position with it. Only the animations differ.
    return _BackSwipeDetector<T>(
      route: this,
      child: FadeTransition(
        // A page being dragged must stay solid. Fading it while the finger
        // moves reads as the page dissolving rather than sliding away.
        opacity: dragging
            ? const AlwaysStoppedAnimation<double>(1)
            : CurvedAnimation(parent: animation, curve: fadeCurve),
        child: SlideTransition(
          // Under a finger the page travels the full width of the screen and
          // tracks it 1:1, uncurved. The app's own push only moves the page a
          // few percent — lovely for a tap, but during a drag it would look
          // like the swipe was doing nothing at all.
          //
          // This is the same split Cupertino makes with `linearTransition`.
          position: dragging
              ? Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(animation)
              : Tween<Offset>(begin: enterOffset, end: Offset.zero).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
          child: child,
        ),
      ),
    );
  }
}

/// Listens along the leading edge and drives [SwipeBackPageRoute.swipeController].
class _BackSwipeDetector<T> extends StatefulWidget {
  const _BackSwipeDetector({required this.route, required this.child});

  final SwipeBackPageRoute<T> route;
  final Widget child;

  @override
  State<_BackSwipeDetector<T>> createState() => _BackSwipeDetectorState<T>();
}

class _BackSwipeDetectorState<T> extends State<_BackSwipeDetector<T>> {
  _BackSwipeController<T>? _controller;
  late final HorizontalDragGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = HorizontalDragGestureRecognizer(debugOwner: this)
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd
      ..onCancel = _handleDragCancel;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    // Being disposed mid-drag would otherwise leave the navigator believing a
    // user gesture is still running, which freezes later navigation.
    final _BackSwipeController<T>? inFlight = _controller;
    if (inFlight != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (inFlight.navigator.mounted) {
          inFlight.navigator.didStopUserGesture();
        }
      });
      _controller = null;
    }
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    // `popGestureEnabled` is the framework's own guard. It already refuses the
    // gesture on the first route, while another transition is running, and
    // when the route has a pop callback that might veto the pop.
    if (widget.route.popGestureEnabled) {
      _recognizer.addPointer(event);
    }
  }

  void _handleDragStart(DragStartDetails details) {
    widget.route.navigator!.didStartUserGesture();
    _controller = _BackSwipeController<T>(
      navigator: widget.route.navigator!,
      controller: widget.route.swipeController,
      getIsCurrent: () => widget.route.isCurrent,
      getIsActive: () => widget.route.isActive,
    );
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final double width = _width;
    if (width == 0) return;
    _controller?.dragUpdate(_toLogical(details.primaryDelta! / width));
  }

  void _handleDragEnd(DragEndDetails details) {
    final double width = _width;
    _controller?.dragEnd(
      width == 0
          ? 0.0
          : _toLogical(details.velocity.pixelsPerSecond.dx / width),
    );
    _controller = null;
  }

  void _handleDragCancel() {
    _controller?.dragEnd(0.0);
    _controller = null;
  }

  double get _width {
    final size = context.size;
    return size == null ? 0 : size.width;
  }

  double _toLogical(double value) {
    return switch (Directionality.of(context)) {
      TextDirection.rtl => -value,
      TextDirection.ltr => value,
    };
  }

  @override
  Widget build(BuildContext context) {
    // On a device with a notch or a rounded corner the system already reserves
    // a wider inset on the leading edge; match it so the grab area is never
    // narrower than the part of the screen the thumb actually lands on.
    final double edgeInset = switch (Directionality.of(context)) {
      TextDirection.rtl => MediaQuery.paddingOf(context).right,
      TextDirection.ltr => MediaQuery.paddingOf(context).left,
    };

    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.child,
        PositionedDirectional(
          start: 0.0,
          width: max(edgeInset, _kBackGestureWidth),
          top: 0.0,
          bottom: 0.0,
          child: Listener(
            onPointerDown: _handlePointerDown,
            behavior: HitTestBehavior.translucent,
          ),
        ),
      ],
    );
  }
}

/// Converts finger movement into route animation, and decides on release
/// whether the page finishes leaving or springs back.
class _BackSwipeController<T> {
  _BackSwipeController({
    required this.navigator,
    required this.controller,
    required this.getIsCurrent,
    required this.getIsActive,
  });

  final NavigatorState navigator;
  final AnimationController controller;
  final ValueGetter<bool> getIsCurrent;
  final ValueGetter<bool> getIsActive;

  /// 0.0 is "previous page showing", 1.0 is "this page showing".
  void dragUpdate(double delta) {
    controller.value -= delta;
  }

  void dragEnd(double velocity) {
    const Curve curve = Curves.fastEaseInToSlowEaseOut;
    final bool isCurrent = getIsCurrent();
    final bool animateForward;

    if (!isCurrent) {
      // Something popped this route while the finger was still down. Let the
      // stack decide, not the drag.
      animateForward = getIsActive();
    } else if (velocity.abs() >= _kMinFlingVelocity) {
      // A definite flick wins regardless of how far the page actually got.
      animateForward = velocity <= 0;
    } else {
      animateForward = controller.value > 0.5;
    }

    if (animateForward) {
      controller.animateTo(
        1.0,
        duration: _kDroppedSwipePageAnimationDuration,
        curve: curve,
      );
    } else {
      if (isCurrent) {
        // Go through the navigator rather than the controller, so results,
        // observers and the rest of the pop machinery all still run.
        navigator.pop();
      }
      if (controller.isAnimating) {
        controller.animateBack(
          0.0,
          duration: _kDroppedSwipePageAnimationDuration,
          curve: curve,
        );
      }
    }

    if (controller.isAnimating) {
      // Hold userGestureInProgress until the page settles, so the transition
      // does not switch curves halfway through the flight.
      late AnimationStatusListener listener;
      listener = (AnimationStatus status) {
        navigator.didStopUserGesture();
        controller.removeStatusListener(listener);
      };
      controller.addStatusListener(listener);
    } else {
      navigator.didStopUserGesture();
    }
  }
}
