import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// App-wide scroll behavior with iOS-style bouncing physics.
///
/// Replaces the Android stretch/glow overscroll indicator with the
/// rubber-band bounce used on iOS, so every scrollable in the app
/// shares the same physical feel on all platforms. Mouse drag is
/// enabled so desktop and web users can fling lists naturally.
class AppScrollBehavior extends MaterialScrollBehavior {
  /// Creates the app scroll behavior.
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      decelerationRate: ScrollDecelerationRate.fast,
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Bouncing physics already communicates the edge — no glow/stretch.
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}
