import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/app_badge.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_nesting.dart';
import 'mission_control_types.dart';

/// Indent applied per nesting level: child avatars line up under the
/// parent's title instead of its avatar.
const double subSessionIndent = AppSpacing.xxl;

/// A session row followed by its agent-spawned sub-sessions.
///
/// The parent row is unchanged; a compact disclosure underneath names how
/// many sub-sessions exist and how many are working or need the user.
/// Expanding it renders [childBuilder] for each direct child, indented
/// behind a hairline guide. Grandchildren nest further because
/// [childBuilder] wraps its own children the same way.
class SubSessionGroup extends StatelessWidget {
  const SubSessionGroup({
    required this.parent,
    required this.parentRow,
    required this.children,
    required this.summary,
    required this.expanded,
    required this.onToggle,
    required this.childBuilder,
    super.key,
  });

  final Session parent;
  final Widget parentRow;
  final List<Session> children;
  final SubSessionSummary summary;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget Function(Session child) childBuilder;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return parentRow;
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        parentRow,
        SubSessionDisclosure(
          summary: summary,
          expanded: expanded,
          onToggle: onToggle,
        ),
        if (expanded)
          Padding(
            key: ValueKey('sub-sessions-${parent.id}'),
            padding: const EdgeInsetsDirectional.only(start: subSessionIndent),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(
                    color: cs.outlineVariant,
                    width: AppBorder.thin,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final child in children)
                    KeyedSubtree(
                      key: ValueKey('sub-session-${child.id}'),
                      child: childBuilder(child),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// "2 sub-sessions · 1 working · 1 needs you" toggle under a parent row.
class SubSessionDisclosure extends StatelessWidget {
  const SubSessionDisclosure({
    required this.summary,
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final SubSessionSummary summary;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final muted = cs.onSurfaceVariant;
    final style = AppText.secondary(theme, muted);
    final parts = <InlineSpan>[
      TextSpan(text: l10n.subSessionCount(summary.total)),
      if (summary.needsAttention > 0) ...[
        const TextSpan(text: ' · '),
        TextSpan(
          text: l10n.subSessionNeedsYou(summary.needsAttention),
          style: style.copyWith(
            color: missionLaneColor(context, MissionLane.blocked),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
      if (summary.working > 0) ...[
        const TextSpan(text: ' · '),
        TextSpan(
          text: l10n.subSessionWorking(summary.working),
          style: style.copyWith(
            color: missionLaneColor(context, MissionLane.live),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ];
    final action = expanded ? l10n.subSessionHide : l10n.subSessionShow;
    return Semantics(
      button: true,
      expanded: expanded,
      hint: action,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onToggle();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.xxxl),
          child: Padding(
            // Starts under the parent's title column.
            padding: const EdgeInsetsDirectional.only(
              start:
                  AppSpacing.smd +
                  missionAvatarSize +
                  missionRowTextGap -
                  AppSpacing.xxs,
              end: AppSpacing.smd,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.subdirectory_arrow_right_rounded,
                  size: AppIconSize.sm,
                  color: muted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text.rich(
                    TextSpan(style: style, children: parts),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Tooltip(
                  message: action,
                  child: AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: AppMotion.duration(context, AppDuration.fast),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: AppIconSize.md,
                      color: muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small pill marking a sub-session listed without its parent.
class SubSessionBadge extends StatelessWidget {
  const SubSessionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: context.l10n.subSessionBadge,
      outlined: true,
      leading: const Icon(Icons.subdirectory_arrow_right_rounded),
    );
  }
}
