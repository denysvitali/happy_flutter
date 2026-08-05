import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/machine.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/session_ui_state_notifier.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_status.dart';
import '../../../core/utils/session_utils.dart';
import 'session_headers.dart';

/// How a session is triaged in Mission Control.
enum MissionLane {
  /// A permission request is pending — the agent is blocked on the user.
  blocked,

  /// Unread messages the user has not seen.
  unread,

  /// The agent is working right now.
  live,

  /// Nothing is happening.
  quiet,
}

/// Triages [session] into the lane that decides where it renders.
MissionLane missionLaneFor(Session session, SessionUiEntry entry) {
  final status = getSessionStatus(session);
  if (status.state == SessionState.permissionRequired) {
    return MissionLane.blocked;
  }
  if (entry.unreadCount > 0) return MissionLane.unread;
  if (status.state == SessionState.thinking) return MissionLane.live;
  return MissionLane.quiet;
}

/// A session that moved inside this window counts as recent; it is what
/// the per-workspace "N recent" hint reports.
const missionControlRecentWindow = Duration(hours: 3);

/// Last-activity timestamp for [session], preferring the message cache.
int missionLastActivityAt(Session session, SessionUiEntry entry) {
  return entry.lastMessageTimestamp ??
      session.lastMessageAt ??
      (session.activeAt > session.updatedAt
          ? session.activeAt
          : session.updatedAt);
}

Color _laneColor(MissionLane lane, ColorScheme cs) {
  return switch (lane) {
    MissionLane.blocked => cs.error,
    MissionLane.unread => cs.primary,
    MissionLane.live => cs.tertiary,
    MissionLane.quiet => cs.outlineVariant,
  };
}

/// Sessions triage view: whatever needs you at the top, then every
/// workspace as a single dense line.
///
/// The design goal is one screen, not a scroll. A workspace renders as
/// its name, one dot per session coloured by lane, and its counts —
/// roughly 32px each, so 25 workspaces fit without paging. Only a
/// workspace holding live or unread work opens itself; the rest expand
/// on tap.
class MissionControlView extends StatefulWidget {
  const MissionControlView({
    required this.activeSessions,
    required this.inactiveSessions,
    required this.machines,
    required this.uiState,
    required this.attentionCardBuilder,
    required this.rowBuilder,
    super.key,
    this.scrollController,
  });

  final List<Session> activeSessions;
  final List<Session> inactiveSessions;
  final Map<String, Machine> machines;
  final SessionUiState uiState;

  /// Builds the prominent card used for sessions that need the user.
  final Widget Function(Session session, SessionUiEntry entry)
  attentionCardBuilder;

  /// Builds a compact row used inside workspace groups.
  final Widget Function(Session session, SessionUiEntry entry) rowBuilder;

  final ScrollController? scrollController;

  @override
  State<MissionControlView> createState() => _MissionControlViewState();
}

class _MissionControlViewState extends State<MissionControlView> {
  /// Workspaces the user opened or closed by hand. Everything else
  /// follows the auto rule: open only when it holds live/unread work.
  final Map<String, bool> _overrides = <String, bool>{};

  SessionUiEntry _entry(String id) =>
      widget.uiState.bySessionId[id] ?? SessionUiEntry.empty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final now = DateTime.now().millisecondsSinceEpoch;

    final lanes = <String, MissionLane>{};
    final counts = <MissionLane, int>{
      for (final lane in MissionLane.values) lane: 0,
    };
    final attention = <Session>[];
    final live = <Session>[];
    for (final session in widget.activeSessions) {
      final lane = missionLaneFor(session, _entry(session.id));
      lanes[session.id] = lane;
      counts[lane] = counts[lane]! + 1;
      switch (lane) {
        case MissionLane.blocked:
        case MissionLane.unread:
          attention.add(session);
        case MissionLane.live:
          live.add(session);
        case MissionLane.quiet:
          break;
      }
    }
    // Blocked before unread: a stalled agent costs more than an unseen
    // reply. Recency ordering inside each lane comes from the input.
    attention.sort((a, b) => lanes[a.id]!.index.compareTo(lanes[b.id]!.index));
    // Already rendered up top; a workspace shows them as dots only, so
    // the same session never appears twice on screen.
    final promoted = {
      for (final session in [...attention, ...live]) session.id,
    };

    final unreadLookup = <String, int>{
      for (final e in widget.uiState.bySessionId.entries)
        e.key: e.value.unreadCount,
    };
    final tsLookup = <String, int?>{
      for (final e in widget.uiState.bySessionId.entries)
        e.key: e.value.lastMessageTimestamp,
    };
    final workspaces = groupAllSessionsByFolder(
      widget.activeSessions,
      widget.inactiveSessions,
      widget.machines,
      getLastMessageTimestamp: (id) => tsLookup[id],
      getUnreadCount: (id) => unreadLookup[id] ?? 0,
    );

    final items = <Widget>[
      _SummaryLine(
        blocked: counts[MissionLane.blocked]!,
        unread: counts[MissionLane.unread]!,
        working: counts[MissionLane.live]!,
        idle: counts[MissionLane.quiet]!,
      ),
    ];

    if (attention.isEmpty && live.isEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xxs,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Text(
            l10n.missionControlAllQuiet,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: AppFontSize.xs,
            ),
          ),
        ),
      );
    }

    for (final session in attention) {
      items.add(widget.attentionCardBuilder(session, _entry(session.id)));
    }

    if (live.isNotEmpty) {
      items.add(
        _MissionGroup(
          children: [
            for (final session in live)
              _LiveRow(
                session: session,
                entry: _entry(session.id),
                child: widget.rowBuilder(session, _entry(session.id)),
              ),
          ],
        ),
      );
    }

    if (workspaces.isNotEmpty) {
      items.add(
        SectionHeader(
          title: l10n.missionControlWorkspaces,
          trailing: Text(
            '${workspaces.length}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: AppFontSize.xs,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      );
      final rows = <Widget>[];
      for (final group in workspaces) {
        final sessions = [...group.activeSessions, ...group.inactiveSessions];
        final laneStrip = [
          for (final session in sessions)
            lanes[session.id] ?? MissionLane.quiet,
        ];
        final hot = laneStrip.any((lane) => lane != MissionLane.quiet);
        final recentCount = sessions
            .where(
              (session) =>
                  now - missionLastActivityAt(session, _entry(session.id)) <=
                  missionControlRecentWindow.inMilliseconds,
            )
            .length;
        final key = group.header.folderKey;
        final expanded = _overrides[key] ?? hot;
        rows
          ..add(
            _WorkspaceLine(
              header: group.header,
              lanes: laneStrip,
              recentCount: recentCount,
              expanded: expanded,
              onTap: () => setState(() => _overrides[key] = !expanded),
            ),
          )
          ..addAll([
            if (expanded)
              for (final session in sessions)
                if (!promoted.contains(session.id))
                  widget.rowBuilder(session, _entry(session.id)),
          ]);
      }
      items.add(_MissionGroup(children: rows));
    }

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      itemCount: items.length,
      itemBuilder: (ctx, i) => items[i],
    );
  }
}

/// Rounded container that gives a run of dense rows one surface.
class _MissionGroup extends StatelessWidget {
  const _MissionGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
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
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// One-line fleet summary — four counts, no cards.
class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.blocked,
    required this.unread,
    required this.working,
    required this.idle,
  });

  final int blocked;
  final int unread;
  final int working;
  final int idle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxs,
      ),
      child: Row(
        children: [
          _SummaryStat(
            label: l10n.missionControlStatBlocked,
            count: blocked,
            color: cs.error,
            pulse: blocked > 0,
          ),
          _SummaryStat(
            label: l10n.missionControlStatUnread,
            count: unread,
            color: cs.primary,
            pulse: false,
          ),
          _SummaryStat(
            label: l10n.missionControlStatWorking,
            count: working,
            color: cs.tertiary,
            pulse: working > 0,
          ),
          _SummaryStat(
            label: l10n.missionControlStatIdle,
            count: idle,
            color: cs.onSurfaceVariant,
            pulse: false,
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.count,
    required this.color,
    required this.pulse,
  });

  final String label;
  final int count;
  final Color color;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = count > 0;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LaneDot(
            color: active ? color : color.withValues(alpha: 0.3),
            pulse: pulse,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: AppFontSize.xs,
              color: active ? color : theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: AppFontSize.xxs,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status dot, optionally breathing.
class _LaneDot extends StatelessWidget {
  const _LaneDot({required this.color, this.pulse = false, this.size = 6});

  final Color color;
  final bool pulse;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
    return pulse ? _Breathing(child: dot) : dot;
  }
}

class _Breathing extends StatefulWidget {
  const _Breathing({required this.child});

  final Widget child;

  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
      child: widget.child,
    );
  }
}

/// A running session: its row plus how long it has been working.
/// Refreshes once a second while mounted.
class _LiveRow extends StatefulWidget {
  const _LiveRow({
    required this.session,
    required this.entry,
    required this.child,
  });

  final Session session;
  final SessionUiEntry entry;
  final Widget child;

  @override
  State<_LiveRow> createState() => _LiveRowState();
}

class _LiveRowState extends State<_LiveRow> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final session = widget.session;
    final since =
        widget.entry.lastMessageTimestamp ??
        session.lastMessageAt ??
        session.activeAt;
    final elapsed = DateTime.now().millisecondsSinceEpoch - since;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.child,
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.xxs,
          ),
          child: Row(
            children: [
              _LaneDot(color: cs.tertiary, pulse: true),
              const SizedBox(width: AppSpacing.xs),
              Text(
                formatElapsedShort(elapsed),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.tertiary,
                  fontSize: AppFontSize.xxs,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Formats a running duration as `12s`, `4m 05s` or `1h 12m`.
String formatElapsedShort(int millis) {
  final seconds = (millis < 0 ? 0 : millis) ~/ 1000;
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  if (minutes < 60) {
    return '${minutes}m ${(seconds % 60).toString().padLeft(2, '0')}s';
  }
  return '${minutes ~/ 60}h ${minutes % 60}m';
}

/// One workspace on one line: name, a dot per session coloured by lane,
/// how many moved recently, and its unread count.
class _WorkspaceLine extends StatelessWidget {
  const _WorkspaceLine({
    required this.header,
    required this.lanes,
    required this.recentCount,
    required this.expanded,
    required this.onTap,
  });

  /// Beyond this the strip stops drawing dots and shows `+n`.
  static const maxDots = 10;

  final SessionFolderHeader header;
  final List<MissionLane> lanes;
  final int recentCount;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Loudest lane first, so a blocked session is never the dot that
    // falls off the end of the strip.
    final sorted = [...lanes]..sort((a, b) => a.index.compareTo(b.index));
    final shown = sorted.take(maxDots).toList();
    final overflow = sorted.length - shown.length;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.expand_more : Icons.chevron_right,
              size: AppIconSize.sm,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Flexible(
              child: Text(
                header.displayPath,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            for (final lane in shown)
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: _LaneDot(
                  color: _laneColor(lane, cs),
                  pulse: lane == MissionLane.blocked,
                  size: lane == MissionLane.quiet ? 4 : 6,
                ),
              ),
            if (overflow > 0)
              Text(
                '+$overflow',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: AppFontSize.xxs,
                  color: cs.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            const Spacer(),
            if (recentCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: Text(
                  context.l10n.missionControlRecentCount(recentCount),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: AppFontSize.xxs,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            if (header.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${header.unreadCount}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: AppFontSize.xxs,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
