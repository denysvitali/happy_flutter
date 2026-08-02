import 'package:flutter/material.dart';

import '../../services/pane_layout_storage.dart';
import 'resizable_pane_divider.dart';

/// Two-column layout whose split point the user can drag, with the chosen
/// master-pane width persisted per [paneId].
///
/// The width is resolved in this order:
/// 1. the width the user dragged to in this session,
/// 2. the width persisted in MMKV by [PaneLayoutStorage],
/// 3. [ResizablePaneDivider.defaultWidth] for the current viewport.
///
/// The result is always clamped to
/// `[ResizablePaneDivider.minWidth, ResizablePaneDivider.maxWidth]`, so a
/// width persisted on a large screen can never collapse a pane after a
/// rotation or a window resize.
class ResizableSplitView extends StatefulWidget {
  const ResizableSplitView({
    required this.paneId,
    required this.master,
    required this.detail,
    super.key,
    this.storage,
    this.dividerSemanticsLabel,
  });

  /// Stable identifier used as the persistence key (e.g. `'sessions'`).
  final String paneId;

  /// Leading (list) pane — its width is what the divider controls.
  final Widget master;

  /// Trailing pane; takes the remaining width.
  final Widget detail;

  /// Injectable storage; defaults to [PaneLayoutStorage.instance].
  final PaneLayoutStorage? storage;

  /// Accessibility label for the drag handle.
  final String? dividerSemanticsLabel;

  @override
  State<ResizableSplitView> createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  /// Width chosen during this session; null until the user drags.
  double? _draggedWidth;

  PaneLayoutStorage get _storage =>
      widget.storage ?? PaneLayoutStorage.instance;

  double _resolveWidth(BuildContext context) {
    final min = ResizablePaneDivider.minWidth(context);
    final max = ResizablePaneDivider.maxWidth(context);
    final stored = _draggedWidth ?? _readStoredWidth();
    final base = stored ?? ResizablePaneDivider.defaultWidth(context);
    return base.clamp(min, max);
  }

  double? _readStoredWidth() {
    try {
      return _storage.widthFor(widget.paneId);
    } catch (_) {
      // Storage is unavailable (e.g. MMKV not initialised in a widget test):
      // fall back to the viewport default rather than failing the build.
      return null;
    }
  }

  void _onResize(double delta, BuildContext context) {
    final min = ResizablePaneDivider.minWidth(context);
    final max = ResizablePaneDivider.maxWidth(context);
    setState(() {
      _draggedWidth = (_resolveWidth(context) + delta).clamp(min, max);
    });
  }

  void _persist() {
    final width = _draggedWidth;
    if (width == null) return;
    try {
      _storage.setWidth(widget.paneId, width);
    } catch (_) {
      // Persisting a UI preference must never break the layout.
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterWidth = _resolveWidth(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: masterWidth, child: widget.master),
        ResizablePaneDivider(
          semanticsLabel: widget.dividerSemanticsLabel,
          onResize: (delta) => _onResize(delta, context),
          onResizeEnd: _persist,
        ),
        Expanded(child: widget.detail),
      ],
    );
  }
}
