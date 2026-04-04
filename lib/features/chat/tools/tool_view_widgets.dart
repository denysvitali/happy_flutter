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
          SizedBox(
            width: 24,
            height: 24,
            child: Align(alignment: Alignment.centerLeft, child: toolIcon),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        toolTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          fontFamilyFallback: const [
                            'Courier New',
                            'Courier',
                          ],
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
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Status badge pill
          if (!hasPermissionRequest) ...[
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

/// Compact status pill showing Running / ✓ / ✕ / Pending.
///
/// 20px tall pill with 0.15-opacity background and matching colour.
/// Completed and error states show an icon; others show text.
class ToolStatusBadge extends StatelessWidget {
  const ToolStatusBadge({required this.state, super.key});

  /// The current execution state.
  final ToolState state;

  @override
  Widget build(BuildContext context) {
    final bg = stateColor(state, Theme.of(context).colorScheme);

    final Widget child;
    if (state == ToolState.completed) {
      child = Icon(Icons.check, size: 12, color: bg);
    } else if (state == ToolState.error) {
      child = Icon(Icons.close, size: 12, color: bg);
    } else {
      child = Text(
        statusBadgeLabel(state),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: bg,
          letterSpacing: 0.2,
        ),
      );
    }

    return Container(
      height: 20,
      width: (state == ToolState.completed || state == ToolState.error)
          ? 20
          : null,
      padding: (state == ToolState.completed || state == ToolState.error)
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: bg.withValues(alpha: 0.35), width: 0.5),
      ),
      alignment: Alignment.center,
      child: child,
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
class CollapsibleOutput extends StatefulWidget {
  const CollapsibleOutput({
    required this.toolId,
    required this.child,
    super.key,
  });

  /// Unique identifier used to track expansion state.
  final String toolId;

  /// The output content widget to wrap.
  final Widget child;

  @override
  State<CollapsibleOutput> createState() => _CollapsibleOutputState();
}

class _CollapsibleOutputState extends State<CollapsibleOutput> {
  static const double _kCollapsedHeight = 200;

  bool _expanded = false;
  final GlobalKey _contentKey = GlobalKey();
  double? _contentHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureContent();
    });
  }

  void _measureContent() {
    final box =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && mounted) {
      setState(() {
        _contentHeight = box.size.height;
      });
    }
  }

  bool get _needsCollapsing =>
      _contentHeight != null && _contentHeight! > _kCollapsedHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If the content fits within the threshold, render it
    // directly without any collapse mechanism.
    if (!_needsCollapsing) {
      return KeyedSubtree(
        key: _contentKey,
        child: widget.child,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: AppDuration.normal,
          curve: AppCurve.standard,
          constraints: BoxConstraints(
            maxHeight: _expanded ? _contentHeight! : _kCollapsedHeight,
          ),
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: widget.child,
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
      List<Map<String, dynamic>>? messages,
      String? sessionId,
    );
