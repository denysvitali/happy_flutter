import 'package:flutter/material.dart';

import '../../../core/components/app_badge.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import 'mission_control_types.dart';

/// Useful status choices, including a selected lane that became empty.
class SessionBoardFilters extends StatelessWidget {
  const SessionBoardFilters({
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
    final total = counts.values.fold<int>(0, (sum, count) => sum + count);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusFilter(
            key: const ValueKey('board-filter-all'),
            label: context.l10n.missionControlFilterAll,
            count: total,
            selected: selectedLane == null,
            onTap: () => onSelectLane(null),
          ),
          for (final lane in MissionLane.values)
            if ((counts[lane] ?? 0) > 0 || selectedLane == lane)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: _StatusFilter(
                  key: ValueKey('board-filter-${lane.name}'),
                  label: missionLaneTitle(context, lane),
                  count: counts[lane] ?? 0,
                  lane: lane,
                  selected: selectedLane == lane,
                  onTap: () => onSelectLane(lane),
                ),
              ),
        ],
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    super.key,
    this.lane,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final MissionLane? lane;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count',
      onTap: onTap,
      child: ExcludeSemantics(
        child: ChoiceChip(
          visualDensity: VisualDensity.compact,
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onTap(),
          avatar: Icon(
            selected
                ? Icons.check_rounded
                : lane == null
                ? Icons.view_list_rounded
                : missionLaneIcon(lane!),
            size: AppIconSize.sm,
            color: selected ? cs.onSecondaryContainer : cs.onSurfaceVariant,
          ),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: AppText.label(
                    theme,
                    selected ? cs.onSecondaryContainer : cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              AppBadge(label: '$count', labelStyle: AppText.badge(theme)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact disclosure footer after a long section's visible rows.
class SessionBoardPreviewControl extends StatelessWidget {
  const SessionBoardPreviewControl({
    required this.label,
    required this.expanded,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: true,
        expanded: expanded,
        label: label,
        onTap: onTap,
        child: ExcludeSemantics(
          child: TextButton.icon(
            onPressed: onTap,
            icon: Icon(
              expanded ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
              size: AppIconSize.md,
            ),
            label: Text(label),
          ),
        ),
      ),
    ),
  );
}

class SessionBoardEmptyLane extends StatelessWidget {
  const SessionBoardEmptyLane({
    required this.lane,
    required this.onShowAll,
    super.key,
  });

  final MissionLane lane;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) => Padding(
    padding: AppScreenPadding.standard,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            context.l10n.sessionsBoardEmptyLane(
              missionLaneTitle(context, lane),
            ),
            style: AppText.title(Theme.of(context)),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: onShowAll,
          child: Text(context.l10n.sessionsBoardShowAll),
        ),
      ],
    ),
  );
}
