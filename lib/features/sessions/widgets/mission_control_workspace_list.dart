import 'package:flutter/material.dart';

import '../../../core/components/app_status_dot.dart';
import '../../../core/models/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_utils.dart';
import 'mission_control_types.dart';
import 'session_headers.dart';

/// Workspace pulse list used by Mission Control.
class MissionWorkspaceList extends StatelessWidget {
  const MissionWorkspaceList({
    required this.groups,
    required this.lanes,
    required this.onOpen,
    super.key,
  });

  final List<SessionFolderGroup> groups;
  final Map<String, MissionLane> lanes;
  final void Function(SessionFolderHeader header) onOpen;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < groups.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 58,
                color: cs.outlineVariant,
              ),
            _WorkspaceTile(
              header: groups[i].header,
              sessions: [
                ...groups[i].activeSessions,
                ...groups[i].inactiveSessions,
              ],
              lanes: lanes,
              onTap: () => onOpen(groups[i].header),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceTile extends StatelessWidget {
  const _WorkspaceTile({
    required this.header,
    required this.sessions,
    required this.lanes,
    required this.onTap,
  });

  final SessionFolderHeader header;
  final List<Session> sessions;
  final Map<String, MissionLane> lanes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final counts = <MissionLane, int>{
      for (final lane in MissionLane.values) lane: 0,
    };
    for (final session in sessions) {
      final lane = lanes[session.id] ?? MissionLane.quiet;
      counts[lane] = counts[lane]! + 1;
    }
    final leadingLane = [
      MissionLane.blocked,
      MissionLane.unread,
      MissionLane.live,
    ].firstWhere((lane) => counts[lane]! > 0, orElse: () => MissionLane.quiet);
    final breakdown = folderBreakdownLabel(context, header);
    final laneDetails = [
      for (final lane in [
        MissionLane.blocked,
        MissionLane.unread,
        MissionLane.live,
      ])
        if (counts[lane]! > 0)
          '${counts[lane]} ${missionLaneLabel(context, lane)}',
    ];
    final semantics = [
      header.displayPath,
      header.machineName,
      breakdown,
      ...laneDetails,
    ].where((value) => value.isNotEmpty).join(', ');

    return Semantics(
      button: true,
      label: semantics,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
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
                      child: Icon(
                        leadingLane == MissionLane.quiet
                            ? Icons.folder_outlined
                            : missionLaneIcon(leadingLane),
                        size: AppIconSize.lg,
                        color: missionLaneColor(context, leadingLane),
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
                    _WorkspaceSignals(counts: counts),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: AppIconSize.lg,
                      color: cs.onSurfaceVariant,
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

class _WorkspaceSignals extends StatelessWidget {
  const _WorkspaceSignals({required this.counts});

  final Map<MissionLane, int> counts;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final lane in [
          MissionLane.blocked,
          MissionLane.unread,
          MissionLane.live,
        ])
          if (counts[lane]! > 0)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: _SignalCount(lane: lane, count: counts[lane]!),
            ),
      ],
    );
  }
}

class _SignalCount extends StatelessWidget {
  const _SignalCount({required this.lane, required this.count});

  final MissionLane lane;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = missionLaneColor(context, lane);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppStatusDot(color: color, pulse: lane != MissionLane.unread, size: 5),
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
