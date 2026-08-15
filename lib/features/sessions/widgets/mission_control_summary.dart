import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import 'mission_control_types.dart';

/// Compact filters for the actionable Mission Control queue.
///
/// Zero-count lanes and the non-actionable quiet lane stay out of the way.
/// When only one actionable lane exists, the filters disappear because they
/// would not change the result set.
class MissionControlFilters extends StatelessWidget {
  const MissionControlFilters({
    required this.counts,
    required this.selectedLane,
    required this.onSelectLane,
    super.key,
  });

  final Map<MissionLane, int> counts;
  final MissionLane? selectedLane;
  final ValueChanged<MissionLane?> onSelectLane;

  @override
  Widget build(BuildContext context) {
    final visibleLanes = [
      MissionLane.blocked,
      MissionLane.error,
      MissionLane.unread,
      MissionLane.live,
    ].where((lane) => counts[lane]! > 0).toList();
    if (visibleLanes.length < 2) return const SizedBox.shrink();

    final total = visibleLanes.fold<int>(0, (sum, lane) => sum + counts[lane]!);
    return SizedBox(
      height: AppTouchTarget.min,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: visibleLanes.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _FocusFilterChip(
              key: const ValueKey('mission-filter-all'),
              label: context.l10n.missionControlFilterAll,
              count: total,
              selected: selectedLane == null,
              onTap: () => onSelectLane(null),
            );
          }
          final lane = visibleLanes[index - 1];
          final selected = selectedLane == lane;
          return _FocusFilterChip(
            key: ValueKey('mission-filter-${lane.name}'),
            label: missionLaneLabel(context, lane),
            count: counts[lane]!,
            lane: lane,
            selected: selected,
            onTap: () => onSelectLane(selected ? null : lane),
          );
        },
      ),
    );
  }
}

class _FocusFilterChip extends StatelessWidget {
  const _FocusFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    super.key,
    this.lane,
  });

  final String label;
  final int count;
  final MissionLane? lane;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = lane == null ? cs.primary : missionLaneColor(context, lane!);
    final icon = lane == null
        ? Icons.view_list_rounded
        : missionLaneIcon(lane!);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
              child: Center(
                child: AnimatedContainer(
                  duration: reduceMotion ? Duration.zero : AppDuration.fast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withValues(alpha: 0.12)
                        : cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: selected
                          ? color.withValues(alpha: 0.45)
                          : cs.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected ? Icons.check_rounded : icon,
                        size: AppIconSize.sm,
                        color: selected ? color : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: selected ? color : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      SizedBox(
                        width: 20,
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: selected ? color : cs.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
