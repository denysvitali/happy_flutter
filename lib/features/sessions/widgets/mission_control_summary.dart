import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import 'mission_control_type.dart';
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
    final foreground = selected ? color : cs.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count',
      child: ExcludeSemantics(
        child: ChoiceChip(
          visualDensity: VisualDensity.compact,
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onTap(),
          avatar: Icon(
            selected ? Icons.check_rounded : icon,
            size: AppIconSize.sm,
            color: foreground,
          ),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: MissionType.label(theme, foreground)),
              const SizedBox(width: AppSpacing.xs),
              SizedBox(
                width: 20,
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: MissionType.badge(theme, foreground),
                ),
              ),
            ],
          ),
          selectedColor: color.withValues(alpha: 0.12),
          backgroundColor: cs.surfaceContainerLow,
          side: BorderSide(
            color: selected ? color.withValues(alpha: 0.45) : cs.outlineVariant,
          ),
        ),
      ),
    );
  }
}
