import 'package:flutter/material.dart';

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

/// Quiet rows shown before a long Quiet lane folds behind "Show more".
const int statusBoardQuietPreview = 5;

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
    this.machineId,
    this.dimmed = false,
    this.collapseAfter,
  });

  final String key;
  final String title;
  final String? subtitle;

  /// Leading header icon; [statusColor] renders a dot instead.
  final IconData? icon;
  final Color? statusColor;
  final Color? accent;
  final List<SessionBoardRow> rows;

  /// Machine the section represents; enables "new session here".
  final String? machineId;

  /// Offline machines render muted.
  final bool dimmed;

  /// Rows shown before the rest fold behind a "Show N more" row.
  final int? collapseAfter;
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

Map<MissionLane, int> _laneCounts(Iterable<SessionBoardRow> rows) {
  final counts = <MissionLane, int>{};
  for (final row in rows) {
    counts[row.lane] = (counts[row.lane] ?? 0) + 1;
  }
  return counts;
}

/// Groups live sessions by what they are doing right now: blocked on the
/// user, failed, unread results, working, then quiet. A long Quiet lane
/// folds so the actionable lanes stay on screen.
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
          title: missionLaneTitle(context, lane),
          icon: missionLaneIcon(lane),
          accent: missionLaneColor(context, lane),
          rows: rows..sort(_byActivity),
          collapseAfter: lane == MissionLane.quiet
              ? statusBoardQuietPreview
              : null,
        ),
  ];
}

/// Groups live sessions by the computer running them. Online machines come
/// first, then the most recently active; rows inside a machine are ordered
/// by urgency. Online machines without sessions stay listed so a new
/// session can start there in one tap.
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
  final nowMs = DateTime.now().millisecondsSinceEpoch;
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
  for (final machine in machines.values) {
    if (groups.containsKey(machine.id) || !machine.isOnlineAt(nowMs)) {
      continue;
    }
    groups[machine.id] = [];
    names[machine.id] = machine.displayLabel;
  }

  // Short hosts read better ("workspace-denys" over a pod name), but two
  // machines must never collapse to the same label.
  final shortNames = {
    for (final entry in names.entries) entry.key: missionShortHost(entry.value),
  };
  final shortCounts = <String, int>{};
  for (final short in shortNames.values) {
    shortCounts[short] = (shortCounts[short] ?? 0) + 1;
  }
  String titleFor(String key) {
    final short = shortNames[key]!;
    return short.isEmpty || shortCounts[short]! > 1 ? names[key]! : short;
  }

  bool isOnline(String key) => machines[key]?.isOnlineAt(nowMs) ?? false;
  int lastActivity(List<SessionBoardRow> rows) => rows
      .map((row) => missionLastActivityAt(row.session, row.entry))
      .fold(0, (a, b) => a > b ? a : b);

  final keys = groups.keys.toList()
    ..sort((a, b) {
      final availability = (isOnline(b) ? 1 : 0) - (isOnline(a) ? 1 : 0);
      if (availability != 0) return availability;
      final occupied =
          (groups[b]!.isEmpty ? 0 : 1) - (groups[a]!.isEmpty ? 0 : 1);
      if (occupied != 0) return occupied;
      final activity = lastActivity(
        groups[b]!,
      ).compareTo(lastActivity(groups[a]!));
      return activity != 0 ? activity : names[a]!.compareTo(names[b]!);
    });

  return [
    for (final key in keys)
      SessionBoardSection(
        key: 'machine-$key',
        title: titleFor(key),
        subtitle: [
          if (machines.containsKey(key))
            isOnline(key) ? l10n.machineOnline : l10n.machineOffline,
          if (groups[key]!.isEmpty)
            l10n.sessionsMachineIdle
          else
            missionLaneSummary(context, _laneCounts(groups[key]!)) ??
                l10n.missionControlSessionCount(groups[key]!.length),
        ].join(' · '),
        statusColor: isOnline(key) ? online : cs.outline,
        machineId: machines.containsKey(key) && isOnline(key) ? key : null,
        dimmed: machines.containsKey(key) && !isOnline(key),
        rows: groups[key]!..sort(_byLaneThenActivity),
      ),
  ];
}

/// Sectioned session list shared by the Status board and Machines layouts.
class SessionBoardView extends StatefulWidget {
  const SessionBoardView({
    required this.sections,
    required this.rowBuilder,
    super.key,
    this.scrollController,
    this.showAllClear = false,
    this.onNewSession,
  });

  final List<SessionBoardSection> sections;
  final Widget Function(SessionBoardRow row) rowBuilder;
  final ScrollController? scrollController;

  /// Leads with an "All clear" note when no section needs the user.
  final bool showAllClear;

  /// Starts a session on the given machine.
  final ValueChanged<String>? onNewSession;

  @override
  State<SessionBoardView> createState() => _SessionBoardViewState();
}

class _SessionBoardViewState extends State<SessionBoardView> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final sections = widget.sections;
    final live = sections.any(
      (section) => section.rows.any((row) => row.lane != MissionLane.quiet),
    );
    final allClear =
        widget.showAllClear &&
        !sections.any(
          (section) => section.rows.any(
            (row) =>
                row.lane == MissionLane.blocked ||
                row.lane == MissionLane.error ||
                row.lane == MissionLane.unread,
          ),
        );
    final leading = allClear ? 1 : 0;
    return MissionClock(
      active: live,
      child: ListView.builder(
        controller: widget.scrollController,
        padding: const EdgeInsets.only(
          top: AppSpacing.xs,
          bottom: AppSpacing.xxl,
        ),
        addAutomaticKeepAlives: false,
        itemCount: sections.length + leading,
        itemBuilder: (context, i) {
          if (i < leading) return const SessionsAllClearNote();
          final section = sections[i - leading];
          return _buildSection(context, section);
        },
      ),
    );
  }

  Widget _buildSection(BuildContext context, SessionBoardSection section) {
    final limit = section.collapseAfter;
    // Folding a single row behind "Show 1 more" costs the same space.
    final foldable = limit != null && section.rows.length > limit + 1;
    final expanded = _expanded.contains(section.key);
    final visible = foldable && !expanded
        ? section.rows.take(limit)
        : section.rows;
    final machineId = section.machineId;
    final onNewSession = widget.onNewSession;
    return Column(
      key: ValueKey(section.key),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SessionGroupHeader(
          title: section.title,
          count: section.rows.length,
          subtitle: section.subtitle,
          icon: section.icon,
          statusColor: section.statusColor,
          accent: section.accent,
          dimmed: section.dimmed,
          // An idle machine already offers the action as its only row.
          onNewSession:
              machineId != null &&
                  onNewSession != null &&
                  section.rows.isNotEmpty
              ? () => onNewSession(machineId)
              : null,
        ),
        Opacity(
          opacity: section.dimmed ? 0.6 : 1,
          child: UnreadFocusListGroup(
            children: [
              for (final row in visible)
                KeyedSubtree(
                  key: ValueKey('board-${row.session.id}'),
                  child: widget.rowBuilder(row),
                ),
              if (section.rows.isEmpty)
                SessionBoardHintRow(
                  icon: Icons.add_rounded,
                  label: context.l10n.sessionsMachineNewSession,
                  onTap: machineId != null && onNewSession != null
                      ? () => onNewSession(machineId)
                      : null,
                ),
              if (foldable)
                SessionBoardHintRow(
                  icon: expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  label: expanded
                      ? context.l10n.sessionsBoardShowLess
                      : context.l10n.sessionsBoardShowMore(
                          section.rows.length - limit,
                        ),
                  onTap: () => setState(() {
                    if (!_expanded.remove(section.key)) {
                      _expanded.add(section.key);
                    }
                  }),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Heading above a grouped session list: icon or status dot, sentence-case
/// title and either an inline count or a second summary line.
class SessionGroupHeader extends StatelessWidget {
  const SessionGroupHeader({
    required this.title,
    super.key,
    this.count,
    this.subtitle,
    this.icon,
    this.statusColor,
    this.accent,
    this.dimmed = false,
    this.onNewSession,
  });

  final String title;
  final int? count;
  final String? subtitle;
  final IconData? icon;
  final Color? statusColor;
  final Color? accent;
  final bool dimmed;
  final VoidCallback? onNewSession;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = this.accent ?? cs.onSurface;
    final statusColor = this.statusColor;
    final subtitle = this.subtitle;
    final count = this.count;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        onNewSession != null ? AppSpacing.xs : AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          if (statusColor != null)
            SizedBox.square(
              dimension: AppIconSize.sm,
              child: Center(
                child: AppStatusDot(color: statusColor, size: AppSpacing.sm),
              ),
            )
          else if (icon != null)
            Icon(icon, size: AppIconSize.sm, color: accent),
          if (statusColor != null || icon != null)
            const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: subtitle == null
                ? Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: title),
                        if (count != null)
                          TextSpan(
                            text: '  $count',
                            style: AppText.secondary(
                              theme,
                              cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title(theme, accent),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title(
                          theme,
                          dimmed ? cs.onSurfaceVariant : accent,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.secondary(theme, cs.onSurfaceVariant),
                      ),
                    ],
                  ),
          ),
          if (onNewSession != null)
            IconButton(
              onPressed: onNewSession,
              tooltip: context.l10n.sessionsMachineNewSession,
              icon: Icon(Icons.add_rounded, color: cs.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// Muted full-width action row inside a board group.
class SessionBoardHintRow extends StatelessWidget {
  const SessionBoardHintRow({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = onTap == null ? cs.onSurfaceVariant : cs.primary;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.smd,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              SizedBox(
                width: AppControlSize.sm,
                child: Icon(icon, size: AppIconSize.md, color: color),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(child: Text(label, style: AppText.label(theme, color))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reassurance shown above an all-quiet status board.
class SessionsAllClearNote extends StatelessWidget {
  const SessionsAllClearNote({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final success =
        theme.extension<AppColorScheme>()?.success ?? Colors.green.shade600;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: AppIconSize.md,
            color: success,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            context.l10n.sessionsBoardAllClear,
            style: AppText.title(theme, cs.onSurface),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.l10n.sessionsBoardAllClearHint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.secondary(theme, cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
