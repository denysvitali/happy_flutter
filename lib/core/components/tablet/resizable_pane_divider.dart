import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

/// Width of the interactive drag handle area.
const double _kHandleWidth = 8.0;

/// Width constraints for the master pane on desktop (>= 960 px).
const double _kDesktopMin = 280.0;
const double _kDesktopMax = 500.0;

/// Width constraints for the master pane on tablet (600–959 px).
const double _kTabletMin = 250.0;
const double _kTabletMax = 400.0;

/// A draggable vertical divider that lets the user resize the master pane
/// in a two-column layout.
///
/// Wrap the master-detail [Row] with a [StatefulWidget] that stores the
/// master-pane width, then wire [onResize] to update that width:
///
/// ```dart
/// double _masterWidth = AppBreakpoint.sidebarMax;
///
/// // Inside the Row children:
/// ResizablePaneDivider(
///   onResize: (delta) {
///     setState(() {
///       _masterWidth = (_masterWidth + delta).clamp(
///         ResizablePaneDivider.minWidth(context),
///         ResizablePaneDivider.maxWidth(context),
///       );
///     });
///   },
/// ),
/// ```
class ResizablePaneDivider extends StatefulWidget {
  const ResizablePaneDivider({
    super.key,
    required this.onResize,
  });

  /// Called with the horizontal delta (in logical pixels) each drag update.
  final ValueChanged<double> onResize;

  /// Returns the minimum master-pane width for the current screen size.
  static double minWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= AppBreakpoint.desktop ? _kDesktopMin : _kTabletMin;
  }

  /// Returns the maximum master-pane width for the current screen size.
  static double maxWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= AppBreakpoint.desktop ? _kDesktopMax : _kTabletMax;
  }

  @override
  State<ResizablePaneDivider> createState() =>
      _ResizablePaneDividerState();
}

class _ResizablePaneDividerState extends State<ResizablePaneDivider> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = _hovering
        ? theme.colorScheme.primary.withValues(alpha: 0.6)
        : theme.dividerColor;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) =>
            widget.onResize(details.delta.dx),
        child: SizedBox(
          width: _kHandleWidth,
          child: Center(
            child: VerticalDivider(
              width: AppBorder.thin,
              thickness: AppBorder.thin,
              color: dividerColor,
            ),
          ),
        ),
      ),
    );
  }
}
