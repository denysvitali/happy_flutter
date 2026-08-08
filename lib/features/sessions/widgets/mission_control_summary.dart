import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_tokens.dart';
import 'mission_control_types.dart';

/// At-a-glance status deck for Mission Control.
class MissionControlSummary extends StatelessWidget {
  const MissionControlSummary({
    required this.counts,
    required this.selectedLane,
    required this.onSelectLane,
    super.key,
  });

  final Map<MissionLane, int> counts;
  final MissionLane? selectedLane;
  final ValueChanged<MissionLane> onSelectLane;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appColors = theme.extension<AppColorScheme>();
    final l10n = context.l10n;
    final blocked = counts[MissionLane.blocked]!;
    final unread = counts[MissionLane.unread]!;
    final working = counts[MissionLane.live]!;
    final attention = blocked + unread;
    final summary = attention > 0
        ? l10n.missionControlNeedsYou(attention)
        : working > 0
        ? l10n.missionControlWorkingNow(working)
        : l10n.missionControlAllQuiet;
    final signalColor = blocked > 0
        ? missionLaneColor(context, MissionLane.blocked)
        : unread > 0
        ? cs.primary
        : working > 0
        ? cs.tertiary
        : appColors?.success ?? cs.primary;
    final background = Color.alphaBlend(
      signalColor.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.1 : 0.06,
      ),
      cs.surfaceContainerLow,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: signalColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.smd),
                ),
                child: Icon(
                  Icons.radar_rounded,
                  size: AppIconSize.xl,
                  color: signalColor,
                ),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.sessionsViewStyleMissionControl,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: AppFontSize.xs,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: signalColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  blocked > 0
                      ? Icons.lock_clock_rounded
                      : unread > 0
                      ? Icons.mark_chat_unread_rounded
                      : working > 0
                      ? Icons.auto_awesome_rounded
                      : Icons.check_rounded,
                  color: signalColor,
                  size: AppIconSize.md,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(1);
              final columns = constraints.maxWidth < 310 || scale > 1.25
                  ? 2
                  : 4;
              final width = constraints.maxWidth / columns;
              return Container(
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(AppRadius.smd),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Wrap(
                  children: [
                    for (final lane in MissionLane.values)
                      SizedBox(
                        width: width,
                        child: _SummaryMetric(
                          lane: lane,
                          count: counts[lane]!,
                          selected: selectedLane == lane,
                          onTap: lane != MissionLane.quiet && counts[lane]! > 0
                              ? () => onSelectLane(lane)
                              : null,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.lane,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final MissionLane lane;
  final int count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = missionLaneColor(context, lane);
    final label = missionLaneLabel(context, lane);

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '$count $label',
      child: ExcludeSemantics(
        child: AnimatedContainer(
          key: ValueKey('mission-filter-${lane.name}'),
          duration: AppDuration.fast,
          constraints: const BoxConstraints(minHeight: 54),
          decoration: BoxDecoration(
            color: selected
                ? missionLaneContainerColor(context, lane)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.45)
                  : Colors.transparent,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.smd),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xsm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected
                              ? Icons.check_rounded
                              : missionLaneIcon(lane),
                          size: AppIconSize.sm,
                          color: color,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        SizedBox(
                          width: 24,
                          child: Text(
                            '$count',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: count == 0 ? cs.onSurfaceVariant : color,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: AppFontSize.xxs,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
