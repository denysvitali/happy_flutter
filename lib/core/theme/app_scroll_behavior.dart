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

/// Forces clamping physics on the scrollables nested inside a subtree.
///
/// [SelectableText] (and [SelectionArea]) wrap their text in an internal
/// [EditableText], which always installs its own [Scrollable]. That scrollable
/// has `maxScrollExtent == 0` because the text is laid out at full height by
/// the surrounding scroll view, so it has nothing to scroll. Under
/// [AppScrollBehavior] its `AlwaysScrollableScrollPhysics` still *accepts* a
/// vertical drag, wins the gesture arena as the innermost vertical scrollable,
/// overscrolls against nothing, then springs straight back to the top — so the
/// real scroll view above it never moves and the content feels pinned
/// ("bounces back to the top"). Clamping physics refuses the drag when the
/// content fits, letting the gesture fall through to the real scroll view.
///
/// Place this on a [ScrollConfiguration] wrapping the [SelectableText] only —
/// not the outer scroll view, which still wants [AppScrollBehavior]. See the
/// identical private workaround in `json_viewer.dart`.
class NeutralizeInnerScrollBehavior extends MaterialScrollBehavior {
  /// Creates the neutralizing scroll behavior.
  const NeutralizeInnerScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}
