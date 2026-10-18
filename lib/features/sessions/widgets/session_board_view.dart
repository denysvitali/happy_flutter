import 'package:flutter/material.dart';

import '../../../core/components/app_badge.dart';
import '../../../core/components/app_status_dot.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/machine.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/session_ui_state_notifier.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import 'mission_control_types.dart';
import 'mission_control_view.dart' show missionLastActivityAt;
import 'mission_heartbeat.dart';
import 'unread_focus_cards.dart' show UnreadFocusListGroup;

/// One titled group of sessions on a board layout.
class SessionBoardSection {
  const SessionBoardSection({
    required this.key,
    required this.title,
    required this.rows,
    this.subtitle,
    this.icon,
    this.statusColor,
    this.accent,
  });

  final String key;
  final String title;
  final String? subtitle;

  /// Leading header icon; [statusColor] renders a dot instead.
  final IconData? icon;
  final Color? statusColor;
  final Color? accent;
  final List<SessionBoardRow> rows;
}

/// A session placed on a board, with the lane its row renders in.
class SessionBoardRow {
  const SessionBoardRow(this.session, this.entry, this.lane);

  final Session session;
  final SessionUiEntry entry;
  final MissionLane lane;
}

SessionUiEntry _entryFor(SessionUiState uiState, String id) =>
    uiState.bySessionId[id] ?? SessionUiEntry.empty;

int _byLaneThenActivity(SessionBoardRow a, SessionBoardRow b) {
  final lane = a.lane.index.compareTo(b.lane.index);
  if (lane != 0) return lane;
  return _byActivity(a, b);
}

int _byActivity(SessionBoardRow a, SessionBoardRow b) {
  final activity = missionLastActivityAt(
    b.session,
    b.entry,
  ).compareTo(missionLastActivityAt(a.session, a.entry));
  return activity != 0 ? activity : a.session.id.compareTo(b.session.id);
}

/// Groups live sessions by what they are doing right now: blocked on the
/// user, failed, unread results, working, then quiet.
List<SessionBoardSection> buildStatusBoardSections(
  BuildContext context,
  List<Session> sessions,
  SessionUiState uiState,
) {
  final byLane = <MissionLane, List<SessionBoardRow>>{};
  for (final session in sessions) {
    final entry = _entryFor(uiState, session.id);
    final lane = missionLaneFor(session, entry);
    (byLane[lane] ??= []).add(SessionBoardRow(session, entry, lane));
  }
  return [
    for (final lane in MissionLane.values)
      if (byLane[lane] case final rows?)
        SessionBoardSection(
          key: 'lane-${lane.name}',
          title: missionLaneLabel(context, lane),
          icon: missionLaneIcon(lane),
          accent: missionLaneColor(context, lane),
          rows: rows..sort(_byActivity),
        ),
  ];
}

/// Groups live sessions by the computer running them. Online machines come
/// first, then the most recently active; rows inside a machine are ordered
/// by urgency.
List<SessionBoardSection> buildMachineSections(
  BuildContext context,
  List<Session> sessions,
  Map<String, Machine> machines,
  SessionUiState uiState,
) {
  final l10n = context.l10n;
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final online =
      theme.extension<AppColorScheme>()?.success ?? Colors.green.shade600;
  final groups = <String, List<SessionBoardRow>>{};
  final names = <String, String>{};
  for (final session in sessions) {
    final metadata = session.metadata;
    final machineId = metadata?.machineId;
    final host = metadata?.host ?? '';
    final key = machineId != null && machineId.isNotEmpty
        ? machineId
        : host.isNotEmpty
        ? 'host:$host'
        : 'unknown';
    final machine = machineId == null ? null : machines[machineId];
    names[key] ??=
        machine?.displayLabel ??
        (host.isNotEmpty ? host : l10n.sessionsUnknownMachine);
    final entry = _entryFor(uiState, session.id);
    (groups[key] ??= []).add(
      SessionBoardRow(session, entry, missionLaneFor(session, entry)),
    );
  }

  final nowMs = DateTime.now().millisecondsSinceEpoch;
  bool isOnline(String key) => machines[key]?.isOnlineAt(nowMs) ?? false;
  int lastActivity(List<SessionBoardRow> rows) => rows
      .map((row) => missionLastActivityAt(row.session, row.entry))
      .fold(0, (a, b) => a > b ? a : b);

  final keys = groups.keys.toList()
    ..sort((a, b) {
      final availability = (isOnline(b) ? 1 : 0) - (isOnline(a) ? 1 : 0);
      if (availability != 0) return availability;
      final activity = lastActivity(
        groups[b]!,
      ).compareTo(lastActivity(groups[a]!));
      return activity != 0 ? activity : names[a]!.compareTo(names[b]!);
    });

  return [
    for (final key in keys)
      SessionBoardSection(
        key: 'machine-$key',
        title: names[key]!,
        subtitle: machines.containsKey(key)
            ? (isOnline(key) ? l10n.machineOnline : l10n.machineOffline)
            : null,
        statusColor: isOnline(key) ? online : cs.outline,
        rows: groups[key]!..sort(_byLaneThenActivity),
      ),
  ];
}

/// Sectioned session list shared by the Status board and Machines layouts.
class SessionBoardView extends StatelessWidget {
  const SessionBoardView({
    required this.sections,
    required this.rowBuilder,
    super.key,
    this.scrollController,
  });

  final List<SessionBoardSection> sections;
  final Widget Function(SessionBoardRow row) rowBuilder;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final live = sections.any(
      (section) => section.rows.any((row) => row.lane != MissionLane.quiet),
    );
    return MissionClock(
      active: live,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.only(
          top: AppSpacing.xs,
          bottom: AppSpacing.lg,
        ),
        addAutomaticKeepAlives: false,
        itemCount: sections.length,
        itemBuilder: (context, i) {
          final section = sections[i];
          return Column(
            key: ValueKey(section.key),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BoardSectionHeader(section: section),
              UnreadFocusListGroup(
                children: [
                  for (final row in section.rows)
                    KeyedSubtree(
                      key: ValueKey('board-${row.session.id}'),
                      child: rowBuilder(row),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BoardSectionHeader extends StatelessWidget {
  const _BoardSectionHeader({required this.section});

  final SessionBoardSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = section.accent ?? cs.onSurfaceVariant;
    final statusColor = section.statusColor;
    final subtitle = section.subtitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          if (statusColor != null)
            AppStatusDot(color: statusColor, size: AppSpacing.sm)
          else if (section.icon != null)
            Icon(section.icon, size: AppIconSize.sm, color: accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    section.title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label(theme, accent),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    subtitle,
                    style: AppText.secondary(theme, cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppBadge(
            label: '${section.rows.length}',
            foregroundColor: accent,
            backgroundColor: accent.withValues(alpha: 0.10),
            labelStyle: AppText.badge(theme, accent),
          ),
        ],
      ),
    );
  }
}
