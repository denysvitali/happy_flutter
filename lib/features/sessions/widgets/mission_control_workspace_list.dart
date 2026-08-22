import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_utils.dart';
import 'mission_control_types.dart';

/// Lazily built workspace pulse sliver used by Mission Control.
class MissionWorkspaceList extends StatelessWidget {
  const MissionWorkspaceList({
    required this.groups,
    required this.lanes,
    required this.onOpen,
    super.key,
    this.isMutedFolder,
    this.onToggleMute,
  });

  final List<SessionFolderGroup> groups;
  final Map<String, MissionLane> lanes;
  final void Function(SessionFolderHeader header) onOpen;
  final bool Function(String folderKey)? isMutedFolder;
  final void Function(String folderKey)? onToggleMute;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SliverToBoxAdapter();
    final cs = Theme.of(context).colorScheme;
    final side = BorderSide(color: cs.outlineVariant);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final group = groups[index];
            final first = index == 0;
            final last = index == groups.length - 1;
            return Container(
              key: ValueKey('mission-workspace-${group.header.folderKey}'),
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.vertical(
                  top: first
                      ? const Radius.circular(AppRadius.lg)
                      : Radius.zero,
                  bottom: last
                      ? const Radius.circular(AppRadius.lg)
                      : Radius.zero,
                ),
                border: Border(
                  left: side,
                  top: first ? side : BorderSide.none,
                  right: side,
                  bottom: last ? side : BorderSide.none,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!first)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 58,
                      color: cs.outlineVariant,
                    ),
                  _WorkspaceTile(
                    group: group,
                    lanes: lanes,
                    muted: isMutedFolder?.call(group.header.folderKey) ?? false,
                    onTap: () => onOpen(group.header),
                    onLongPress: onToggleMute == null
                        ? null
                        : () => onToggleMute!(group.header.folderKey),
                  ),
                ],
              ),
            );
          },
          childCount: groups.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          addSemanticIndexes: true,
        ),
      ),
    );
  }
}

class _WorkspaceTile extends StatelessWidget {
  const _WorkspaceTile({
    required this.group,
    required this.lanes,
    required this.onTap,
    this.muted = false,
    this.onLongPress,
  });

  final SessionFolderGroup group;
  final Map<String, MissionLane> lanes;
  final VoidCallback onTap;
  final bool muted;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final counts = <MissionLane, int>{
      for (final lane in MissionLane.values) lane: 0,
    };
    var sessionCount = 0;
    for (final session in group.activeSessions.followedBy(
      group.inactiveSessions,
    )) {
      sessionCount++;
      final lane = lanes[session.id] ?? MissionLane.quiet;
      counts[lane] = counts[lane]! + 1;
    }
    final header = group.header;
    final leadingLane = [
      MissionLane.blocked,
      MissionLane.error,
      MissionLane.unread,
      MissionLane.live,
    ].firstWhere((lane) => counts[lane]! > 0, orElse: () => MissionLane.quiet);
    // Lane composition replaces the raw "X active • Y archived" counts —
    // nobody triages by archive size, and the ambiguous dot badge was the
    // only place the leading lane was visible.
    final laneDetails = [
      for (final lane in [
        MissionLane.blocked,
        MissionLane.error,
        MissionLane.unread,
        MissionLane.live,
      ])
        if (counts[lane]! > 0)
          '${counts[lane]} ${missionLaneLabel(context, lane)}',
    ];
    final breakdown = muted
        ? l10n.missionControlMutedLabel
        : laneDetails.isNotEmpty
        ? laneDetails.join(' · ')
        : l10n.missionControlSessionCount(sessionCount);
    final semantics = [
      header.displayPath,
      header.machineName,
      breakdown,
    ].where((value) => value.isNotEmpty).join(', ');

    return Semantics(
      button: true,
      label: semantics,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: missionLaneContainerColor(context, leadingLane),
                        borderRadius: BorderRadius.circular(AppRadius.smd),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            muted
                                ? Icons.notifications_off_outlined
                                : Icons.folder_outlined,
                            size: AppIconSize.lg,
                            color: missionLaneColor(context, leadingLane),
                          ),
                          if (leadingLane != MissionLane.quiet && !muted)
                            Positioned(
                              right: AppSpacing.xsm,
                              top: AppSpacing.xsm,
                              child: _WorkspaceStatusDot(
                                color: missionLaneColor(context, leadingLane),
                                size: 4,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.smd),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            missionShortPath(header.displayPath),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            '${missionShortHost(header.machineName)}'
                            '  ·  $breakdown',
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
                    const SizedBox(width: AppSpacing.xs),
                    SizedBox(
                      width: 58,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!muted) ...[
                            _WorkspaceSignal(
                              lane: leadingLane,
                              count: counts[leadingLane]!,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          Icon(
                            Icons.chevron_right_rounded,
                            size: AppIconSize.lg,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
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

class _WorkspaceSignal extends StatelessWidget {
  const _WorkspaceSignal({required this.lane, required this.count});

  final MissionLane lane;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (lane == MissionLane.quiet) {
      return const SizedBox(width: 22);
    }
    final theme = Theme.of(context);
    final color = missionLaneColor(context, lane);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WorkspaceStatusDot(color: color, size: 5),
        const SizedBox(width: AppSpacing.xxxs),
        Text(
          '$count',
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: AppFontSize.xxs,
            fontWeight: FontWeight.w700,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// A status dot with no ticker, animation controller, blur, or shadow.
///
/// Workspace rows can number in the dozens, so using `AppStatusDot` here
/// would allocate a ticker per dot even when `pulse` is false.
class _WorkspaceStatusDot extends StatelessWidget {
  const _WorkspaceStatusDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
