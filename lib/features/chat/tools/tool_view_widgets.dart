import 'package:flutter/material.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'elapsed_time.dart';
import 'tool_status_indicator.dart';
import 'tool_view_helpers.dart';

/// Outer chrome for a boxed tool result card (bash, read, diff, patch…).
///
/// Shared so the seven views that draw this box can't drift apart.
BoxDecoration toolCardDecoration(ColorScheme cs) => BoxDecoration(
  color: cs.surface,
  borderRadius: BorderRadius.circular(AppRadius.sm),
  border: Border.all(color: cs.outlineVariant),
);

/// Chrome for the title bar that sits at the top of a [toolCardDecoration]
/// card: matching top corner radius plus a hairline separator underneath.
BoxDecoration toolCardHeaderDecoration(ColorScheme cs) => BoxDecoration(
  color: cs.surfaceContainer,
  borderRadius: const BorderRadius.only(
    topLeft: Radius.circular(AppRadius.sm),
    topRight: Radius.circular(AppRadius.sm),
  ),
  border: Border(bottom: BorderSide(color: cs.outlineVariant)),
);

/// Padding used inside a [toolCardHeaderDecoration] title bar.
const EdgeInsets toolCardHeaderPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.smd,
  vertical: AppSpacing.xsm,
);

/// Compact single-line header for a tool row — icon, title, optional inline
/// status and subtitle, state-specific trailing, and expand/collapse chevron.
///
/// The header is deliberately chromeless: it paints no background or border
/// of its own. [ToolView] places it on a tinted surface when the tool state
/// deserves emphasis (running / error / pending permission), otherwise the
/// row sits directly on the chat background so a run of tool calls reads as
/// a timeline rather than a wall of boxes.
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
    this.subtitleMonospace = false,
    this.createdAt,
    this.statusIcon,
    this.statusLabel,
    this.expanded = false,
    this.onTap,
    this.onLongPress,
    this.onOpenDetails,
  });

  /// The leading icon widget for this tool type.
  final Widget toolIcon;

  /// The resolved display title for this tool.
  final String toolTitle;

  /// Optional inline status text shown after the title.
  final String? status;

  /// Optional subtitle shown after the title on the same line.
  final String? subtitle;

  /// Whether the subtitle is a command or path rendered in monospace.
  final bool subtitleMonospace;

  /// The current execution state.
  final ToolState state;

  /// Unix-ms timestamp when the tool started (for elapsed time).
  final int? createdAt;

  /// Optional status icon override (error/denied/cancelled).
  final Widget? statusIcon;

  /// Optional status label paired with [statusIcon].
  final String? statusLabel;

  /// Whether this tool card has expandable content.
  final bool hasContent;

  /// Whether to show the green check-circle flash animation.
  final bool showCheckFlash;

  /// The chevron rotation animation (0 = collapsed, 0.5 = expanded).
  final Animation<double> chevronAnim;

  /// Whether a permission request is currently pending.
  final bool hasPermissionRequest;

  /// Whether inline tool output is expanded.
  final bool expanded;

  /// Primary header action. This normally toggles inline output.
  final VoidCallback? onTap;

  /// Existing long-press details action.
  final VoidCallback? onLongPress;

  /// Explicit alternative to [onLongPress] for opening tool details.
  final VoidCallback? onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: AppFontSize.md,
    );
    final statusStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w400,
      fontSize: AppFontSize.md,
      color: colorScheme.onSurfaceVariant,
    );
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: AppFontSize.sm,
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
      fontFamily: subtitleMonospace ? 'monospace' : null,
      fontFamilyFallback: subtitleMonospace
          ? const ['Courier New', 'Courier']
          : null,
    );

    final cueLabel = hasPermissionRequest
        ? context.l10n.toolStateApprovalNeeded
        : statusLabel ??
              switch (state) {
                ToolState.running => context.l10n.toolStateRunning,
                ToolState.completed => context.l10n.toolStateDone,
                ToolState.error => context.l10n.toolStateFailed,
                ToolState.pending => context.l10n.toolStateQueued,
              };
    final semanticLabel = <String>[
      toolTitle,
      ?status,
      ?subtitle,
      cueLabel,
    ].join(', ');

    List<Widget> titleChildren() => [
      SizedBox(width: 18, height: 18, child: Center(child: toolIcon)),
      const SizedBox(width: AppSpacing.smd),
      Expanded(
        // One line, one RichText: title, status and subtitle share a baseline.
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: toolTitle, style: titleStyle),
              if (status != null)
                TextSpan(text: ' $status', style: statusStyle),
              if (subtitle != null)
                TextSpan(text: '  $subtitle', style: subtitleStyle),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ];

    List<Widget> stateChildren() => [
      _ToolStateCue(
        state: state,
        label: cueLabel,
        statusIcon: statusIcon,
        needsApproval: hasPermissionRequest,
        showCheckFlash: showCheckFlash,
      ),
      if (state == ToolState.running && createdAt != null) ...[
        const SizedBox(width: AppSpacing.xs),
        ToolDuration(startTime: createdAt!),
      ],
      if (hasContent) ...[
        const SizedBox(width: AppSpacing.xs),
        RotationTransition(
          turns: chevronAnim,
          child: Icon(
            Icons.expand_more,
            size: AppIconSize.lg,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: onTap != null,
              enabled: onTap != null,
              expanded: hasContent ? expanded : null,
              label: semanticLabel,
              hint: hasContent
                  ? (expanded
                        ? context.l10n.toolOutputCollapseHint
                        : context.l10n.toolOutputExpandHint)
                  : onTap != null
                  ? context.l10n.toolDetailsOpenHint
                  : null,
              onTap: onTap,
              onLongPress: onLongPress,
              child: ExcludeSemantics(
                child: InkWell(
                  key: const ValueKey('tool-header-primary-action'),
                  onTap: onTap,
                  onLongPress: onLongPress,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppTouchTarget.min,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.smd,
                        vertical: AppSpacing.xsm,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final textScale = MediaQuery.textScalerOf(
                            context,
                          ).scale(1);
                          final stackState =
                              textScale > 1.3 || constraints.maxWidth < 280;
                          if (stackState) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(children: titleChildren()),
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: stateChildren(),
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              ...titleChildren(),
                              const SizedBox(width: AppSpacing.sm),
                              ...stateChildren(),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (onOpenDetails != null)
            IconButton(
              key: const ValueKey('tool-header-details-action'),
              onPressed: onOpenDetails,
              tooltip: context.l10n.toolDetailsView,
              constraints: const BoxConstraints(
                minWidth: AppTouchTarget.min,
                minHeight: AppTouchTarget.min,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
            ),
        ],
      ),
    );
  }
}

class _ToolStateCue extends StatelessWidget {
  const _ToolStateCue({
    required this.state,
    required this.label,
    required this.needsApproval,
    required this.showCheckFlash,
    this.statusIcon,
  });

  final ToolState state;
  final String label;
  final bool needsApproval;
  final bool showCheckFlash;
  final Widget? statusIcon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = needsApproval
        ? AppColors.warning
        : switch (state) {
            ToolState.running => colorScheme.primary,
            ToolState.completed => AppColors.success,
            ToolState.error => colorScheme.error,
            ToolState.pending => colorScheme.onSurfaceVariant,
          };
    final icon = needsApproval
        ? Icons.security_rounded
        : switch (state) {
            ToolState.running => Icons.autorenew_rounded,
            ToolState.completed =>
              showCheckFlash
                  ? Icons.check_circle_rounded
                  : Icons.check_circle_outline_rounded,
            ToolState.error => Icons.error_outline_rounded,
            ToolState.pending => Icons.schedule_rounded,
          };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: AppMotion.duration(context, AppDuration.normal),
          child:
              statusIcon ??
              Icon(icon, key: ValueKey<IconData>(icon), size: 16, color: color),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppFontSize.xs,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Compact status pill showing the execution state.
///
/// Every state includes text and an icon so meaning never depends on colour.
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
      ToolState.completed => context.l10n.toolStateDone,
      ToolState.error => context.l10n.toolStateFailed,
      ToolState.running => context.l10n.toolStateRunning,
      ToolState.pending => context.l10n.toolStateQueued,
    };

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 7),
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
  const CollapsibleOutput({
    required this.toolId,
    required this.child,
    super.key,
    this.scrollable = false,
    this.expandedMaxHeight = defaultExpandedMaxHeight,
  });

  /// Default maximum height when expanded in scrollable mode.
  static const double defaultExpandedMaxHeight = 600;

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
          duration: AppMotion.duration(context, AppDuration.normal),
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
        Semantics(
          key: const ValueKey('tool-output-disclosure'),
          button: true,
          expanded: _expanded,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: AppTouchTarget.min,
                minHeight: AppTouchTarget.min,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: AppIconSize.md,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _expanded
                        ? context.l10n.toolOutputShowLess
                        : context.l10n.toolOutputShowMore,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
