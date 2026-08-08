import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

/// Absolute width constraints for the master pane on desktop (>= 960 px).
const double _kDesktopMin = 280.0;
const double _kDesktopMax = 560.0;

/// Absolute width constraints for the master pane on tablet (600–959 px).
const double _kTabletMin = 260.0;
const double _kTabletMax = 520.0;

/// Fraction of the viewport the master pane may never exceed, so the detail
/// pane can't be squeezed into an unusable sliver.
const double _kMaxViewportFraction = 0.55;

/// Fraction of the viewport used for the initial master-pane width.
///
/// Keeps the conversation visually dominant while leaving enough room for
/// workspace names and status in the master pane.
const double _kDefaultViewportFraction = 0.38;

/// Lower bound for the *default* width (not for dragging) — narrow enough for
/// small tablets, wide enough that a typical project path still fits.
const double _kDefaultMin = 300.0;

/// A draggable vertical divider that lets the user resize the master pane
/// in a two-column layout.
///
/// Prefer `ResizableSplitView`, which owns the width state, clamps it to
/// [minWidth]/[maxWidth], and persists the user's choice. Use this widget
/// directly only when the surrounding layout must own the width itself:
///
/// ```dart
/// ResizablePaneDivider(
///   onResize: (delta) => setState(() {
///     _masterWidth = (_masterWidth + delta).clamp(
///       ResizablePaneDivider.minWidth(context),
///       ResizablePaneDivider.maxWidth(context),
///     );
///   }),
///   onResizeEnd: _persistWidth,
/// ),
/// ```
class ResizablePaneDivider extends StatefulWidget {
  const ResizablePaneDivider({
    super.key,
    required this.onResize,
    this.onResizeEnd,
    this.semanticsLabel,
    this.semanticsValue,
    this.semanticsIncreasedValue,
    this.semanticsDecreasedValue,
  });

  /// Distance the pane moves per assistive-technology increase/decrease
  /// action, in logical pixels.
  static const double semanticsStep = 24.0;

  /// Called with the horizontal delta (in logical pixels) each drag update.
  final ValueChanged<double> onResize;

  /// Called once when a drag gesture finishes, for persisting the width.
  final VoidCallback? onResizeEnd;

  /// Accessibility label announced for the drag handle. When non-null the
  /// handle is exposed as an operable slider (see [semanticsValue]).
  final String? semanticsLabel;

  /// Current width announced by assistive technology, e.g. `'420 pixels'`.
  final String? semanticsValue;

  /// Width announced after an assistive-technology increase. Flutter asserts
  /// that a node exposing the `increase` action carries both `value` and
  /// `increasedValue` (or neither), so this must accompany [semanticsValue].
  final String? semanticsIncreasedValue;

  /// Width announced after an assistive-technology decrease. Symmetric
  /// requirement to [semanticsIncreasedValue] for the `decrease` action.
  final String? semanticsDecreasedValue;

  /// Returns the minimum master-pane width for the current screen size.
  static double minWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final absolute = w >= AppBreakpoint.desktop ? _kDesktopMin : _kTabletMin;
    // Never exceed the viewport-fraction cap on very narrow tablets.
    final cap = w * _kMaxViewportFraction;
    return absolute < cap ? absolute : cap;
  }

  /// Returns the maximum master-pane width for the current screen size.
  static double maxWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final absolute = w >= AppBreakpoint.desktop ? _kDesktopMax : _kTabletMax;
    final cap = w * _kMaxViewportFraction;
    final resolved = absolute < cap ? absolute : cap;
    final min = minWidth(context);
    return resolved < min ? min : resolved;
  }

  /// Initial master-pane width when the user has never dragged the divider.
  static double defaultWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final min = minWidth(context);
    final max = maxWidth(context);
    final preferred = w * _kDefaultViewportFraction;
    final floored = preferred < _kDefaultMin ? _kDefaultMin : preferred;
    return floored.clamp(min, max);
  }

  @override
  State<ResizablePaneDivider> createState() => _ResizablePaneDividerState();
}

class _ResizablePaneDividerState extends State<ResizablePaneDivider> {
  bool _hovering = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Applies one assistive-technology nudge and immediately ends the
  /// "gesture" so the new width is persisted like a drag would be.
  void _nudge(double delta) {
    widget.onResize(delta);
    widget.onResizeEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.semanticsLabel;
    final dividerColor = _hovering
        ? theme.colorScheme.primary.withValues(alpha: 0.6)
        : theme.dividerColor;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _nudge(ResizablePaneDivider.semanticsStep);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _nudge(-ResizablePaneDivider.semanticsStep);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Semantics(
          label: label,
          // Only claim to be a slider when the node is also operable:
          // assistive tech must be able to move it, not just read it.
          slider: label != null,
          value: label == null ? null : widget.semanticsValue,
          increasedValue: label == null ? null : widget.semanticsIncreasedValue,
          decreasedValue: label == null ? null : widget.semanticsDecreasedValue,
          onIncrease: label == null
              ? null
              : () => _nudge(ResizablePaneDivider.semanticsStep),
          onDecrease: label == null
              ? null
              : () => _nudge(-ResizablePaneDivider.semanticsStep),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _focusNode.requestFocus(),
            onPanStart: (_) => _focusNode.requestFocus(),
            onPanUpdate: (details) => widget.onResize(details.delta.dx),
            onPanEnd: (_) => widget.onResizeEnd?.call(),
            onPanCancel: () => widget.onResizeEnd?.call(),
            child: SizedBox(
              width: AppTouchTarget.min,
              child: Center(
                child: VerticalDivider(
                  width: AppBorder.thin,
                  thickness: AppBorder.thin,
                  color: dividerColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
