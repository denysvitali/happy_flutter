import 'package:flutter/material.dart';

/// Forces clamping physics on every descendant scrollable.
///
/// [SelectableText] always wraps its content in a [Scrollable] (via
/// [EditableText]). Under the app-wide scroll behavior
/// (BouncingScrollPhysics + AlwaysScrollableScrollPhysics) that phantom
/// scrollable accepts vertical drags even though its content fits
/// (maxScrollExtent == 0): it wins the gesture arena as the innermost
/// vertical scrollable, overscrolls, then springs straight back — so the
/// chat list underneath never moves and the block feels like a scroll trap.
///
/// Clamping physics refuses the drag when the content fits, letting the
/// gesture fall through to the enclosing list.
class NeutralizeInnerScrollBehavior extends MaterialScrollBehavior {
  const NeutralizeInnerScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

/// Convenience wrapper applying [NeutralizeInnerScrollBehavior] to [child].
class NeutralizeInnerScroll extends StatelessWidget {
  const NeutralizeInnerScroll({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: const NeutralizeInnerScrollBehavior(),
    child: child,
  );
}
