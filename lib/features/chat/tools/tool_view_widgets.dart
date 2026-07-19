import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'elapsed_time.dart';
import 'tool_status_indicator.dart' show ToolState;
import 'tool_view_helpers.dart';

/// Header row for a tool card — icon, title, status badge, elapsed time,
/// check flash, and expand/collapse chevron.
class ToolHeader extends StatelessWidget {
  const ToolHeader({
    required this.toolIcon,
    required this.toolTitle,
    required this.state,
    required this.hasContent,
    required this.showCheckFlash,
    required this.chevronAnim,
    required this.hasPermissionRequest,
    super.key,
    this.status,
    this.subtitle,
    this.createdAt,
    this.statusIcon,
    this.accentColor,
  });

  /// The leading icon widget for this tool type.
  final Widget toolIcon;

  /// The resolved display title for this tool.
  final String toolTitle;

  /// Optional inline status text shown after the title.
  final String? status;

  /// Optional subtitle shown below the title.
  final String? subtitle;

  /// The current execution state.
  final ToolState state;

  /// Unix-ms timestamp when the tool started (for elapsed time).
  final int? createdAt;

  /// Optional status icon override (error/denied/cancelled).
  final Widget? statusIcon;

  /// Accent for the tool family, independent from execution state.
  final Color? accentColor;

  /// Whether this tool card has expandable content.
  final bool hasContent;

  /// Whether to show the green check-circle flash animation.
  final bool showCheckFlash;

  /// The chevron rotation animation (0 = collapsed, 0.5 = expanded).
  final Animation<double> chevronAnim;

  /// Whether a permission request is currently pending.
  final bool hasPermissionRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? stateColor(state, theme.colorScheme);
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.sm),
          topRight: Radius.circular(AppRadius.sm),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.smd),
              border: Border.all(
                color: accent.withValues(alpha: 0.28),
                width: 0.5,
              ),
            ),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Center(child: toolIcon),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        toolTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: AppFontSize.md,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (status != null)
                      Text(
                        ' $status',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w400,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.9,
                      ),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Status badge pill
          if (!hasPermissionRequest && state != ToolState.completed) ...[
            const SizedBox(width: AppSpacing.sm - 2),
            ToolStatusBadge(state: state),
          ],
          // Elapsed time while running
          if (state == ToolState.running && createdAt != null) ...[
            const SizedBox(width: AppSpacing.sm - 2),
            ToolDuration(startTime: createdAt!),
          ],
          // Status icon / check flash
          const SizedBox(width: AppSpacing.sm - 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: showCheckFlash
                ? Icon(
                    Icons.check_circle,
                    key: const ValueKey('flash'),
                    size: 20,
                    color: AppColors.success,
                  )
                : (statusIcon != null
                      ? SizedBox(
                          key: const ValueKey('status'),
                          child: statusIcon,
                        )
                      : const SizedBox.shrink(key: ValueKey('empty'))),
          ),
          // Expand/collapse chevron
          if (hasContent) ...[
            const SizedBox(width: AppSpacing.sm - 2),
            RotationTransition(
              turns: chevronAnim,
              child: Icon(
                Icons.expand_more,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact status pill showing the execution state.
///
/// Exceptional and transitional states include text so they never depend on
/// colour alone. Completion is the expected state, so it uses a quiet check
/// rather than repeating "Succeeded" throughout tool-heavy conversations.
class ToolStatusBadge extends StatelessWidget {
  const ToolStatusBadge({required this.state, super.key});

  /// The current execution state.
  final ToolState state;

  @override
  Widget build(BuildContext context) {
    final bg = stateColor(state, Theme.of(context).colorScheme);

    final icon = switch (state) {
      ToolState.completed => Icons.check_rounded,
      ToolState.error => Icons.error_outline_rounded,
      ToolState.running => Icons.autorenew_rounded,
      ToolState.pending => Icons.schedule_rounded,
    };
    final label = switch (state) {
      ToolState.completed => null,
      ToolState.error => 'Failed',
      _ => statusBadgeLabel(state),
    };
    final isCompleted = state == ToolState.completed;

    return Container(
      height: 24,
      width: isCompleted ? 24 : null,
      padding: isCompleted
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: bg.withValues(alpha: 0.35), width: 0.5),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: bg),
          if (label != null) ...[
            const SizedBox(width: AppSpacing.xxs),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: bg,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Elapsed time label — only visible while the tool is running.
class ToolDuration extends StatelessWidget {
  const ToolDuration({required this.startTime, super.key});

  /// The Unix-ms timestamp when the tool started.
  final int startTime;

  @override
  Widget build(BuildContext context) {
    return ElapsedTimeWidget(startTime: startTime);
  }
}

/// A [CircularProgressIndicator] whose opacity pulses via [animation].
class PulsingProgressIndicator extends StatelessWidget {
  const PulsingProgressIndicator({
    required this.animation,
    required this.size,
    super.key,
  });

  /// The pulsing opacity animation (0.3 -> 1.0 loop).
  final Animation<double> animation;

  /// Diameter of the indicator in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: animation,
        child: SizedBox(
          width: size,
          height: size,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// Wraps tool output in a height-constrained container with a
/// "Show more" / "Show less" toggle button.
///
/// When collapsed the content is clipped at [_kCollapsedHeight]
/// logical pixels. Tapping the toggle reveals or hides the full
/// output with an animated transition.
///
/// When [scrollable] is true the child is expected to contain its own
/// scrolling (e.g. [ToolOutputScrollFrame]). In that mode the widget
/// never expands to the child's intrinsic height; instead it provides
/// bounded heights and lets the child scroll internally.
class CollapsibleOutput extends StatefulWidget {
  /// Default maximum height when expanded in scrollable mode.
  static const double defaultExpandedMaxHeight = 600;

  const CollapsibleOutput({
    required this.toolId,
    required this.child,
    super.key,
    this.scrollable = false,
    this.expandedMaxHeight = defaultExpandedMaxHeight,
  });

  /// Unique identifier used to track expansion state.
  final String toolId;

  /// The output content widget to wrap.
  final Widget child;

  /// Whether [child] contains its own scrollable viewport.
  ///
  /// When true the widget provides bounded heights
  /// ([_kCollapsedHeight] and [expandedMaxHeight]) instead of
  /// expanding to the child's full intrinsic height.
  final bool scrollable;

  /// Maximum height when expanded and [scrollable] is true.
  final double expandedMaxHeight;

  @override
  State<CollapsibleOutput> createState() => _CollapsibleOutputState();
}

class _CollapsibleOutputState extends State<CollapsibleOutput> {
  static const double _kCollapsedHeight = 200;

  bool _expanded = false;
  final GlobalKey _contentKey = GlobalKey();
  double? _contentHeight;
  bool _measureScheduled = false;
  int _measureAttempts = 0;

  @override
  void initState() {
    super.initState();
    _scheduleMeasureContent();
  }

  @override
  void didUpdateWidget(CollapsibleOutput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child || oldWidget.toolId != widget.toolId) {
      _contentHeight = null;
      _measureAttempts = 0;
      _scheduleMeasureContent();
    }
  }

  void _scheduleMeasureContent() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      _measureContent();
    });
  }

  void _measureContent() {
    if (!mounted) return;

    final renderObject = _contentKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      if (_measureAttempts < 3) {
        _measureAttempts++;
        _scheduleMeasureContent();
      }
      return;
    }

    _measureAttempts = 0;
    final height = renderObject.size.height;
    if (_contentHeight != height) {
      setState(() {
        _contentHeight = height;
      });
    }
  }

  bool get _needsCollapsing =>
      _contentHeight != null && _contentHeight! > _kCollapsedHeight;

  double get _expandedHeight =>
      widget.scrollable ? widget.expandedMaxHeight : _contentHeight!;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The content is always wrapped in a KeyedSubtree carrying [_contentKey].
    // This is a [GlobalKey], so whichever branch we render below, Flutter
    // *reparents* the same element (and its State) instead of tearing it down
    // and rebuilding. That is essential: tool output panes nest a stateful
    // [ToolOutputScrollFrame] whose ScrollControllers live in its State. If the
    // subtree were remounted — e.g. when streaming output crosses the collapse
    // threshold and we flip between the bare and collapsible layouts — those
    // controllers would be recreated at offset 0, snapping the user's scroll
    // position back to the top. Keeping one stable element preserves it.
    final keyedChild = KeyedSubtree(key: _contentKey, child: widget.child);

    // If the content fits within the threshold, render it
    // directly without any collapse mechanism.
    if (!_needsCollapsing) {
      return keyedChild;
    }

    final targetHeight = _expanded ? _expandedHeight : _kCollapsedHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: AppDuration.normal,
          curve: AppCurve.standard,
          height: targetHeight,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          // Scrollable children get the bounded viewport directly so their
          // inner SingleChildScrollView can actually scroll. We further wrap
          // them in a SingleChildScrollView here so any non-scrollable
          // descendants (e.g. the title Column inside a ToolSectionView) can
          // also overflow gracefully instead of asserting on a hard clip.
          // `primary: false` keeps this wrapper off the ambient
          // PrimaryScrollController so it never contends with the chat list.
          //
          // Non-scrollable children render at their natural unbounded height
          // (via OverflowBox) and are clipped by the AnimatedContainer; that
          // path is unchanged.
          child: widget.scrollable
              ? SingleChildScrollView(
                  primary: false,
                  physics: const ClampingScrollPhysics(),
                  child: keyedChild,
                )
              : OverflowBox(
                  maxHeight: double.infinity,
                  alignment: Alignment.topLeft,
                  child: keyedChild,
                ),
        ),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _expanded ? 'Show less' : 'Show more',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Internal type alias — kept here for cross-file use within the tools package.
// ---------------------------------------------------------------------------

/// Signature for tool-specific view builder functions used in [ToolView].
typedef ToolViewBuilder =
    Widget Function(
      Map<String, dynamic> tool,
      Map<String, dynamic>? metadata,
      String? sessionId,
    );
