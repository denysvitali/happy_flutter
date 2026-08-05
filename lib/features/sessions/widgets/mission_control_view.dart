import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/machine.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/session_ui_state_notifier.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_status.dart';
import '../../../core/utils/session_utils.dart';
import 'session_cards.dart';
import 'session_headers.dart';

/// How a session is triaged in Mission Control.
enum MissionLane {
  /// Permission request pending — agent blocked on the user.
  blocked,

  /// Unread messages the user has not seen.
  unread,

  /// Agent working right now.
  live,

  /// Nothing happening.
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

Color _laneColor(MissionLane lane, ColorScheme cs) {
  return switch (lane) {
    MissionLane.blocked => cs.error,
    MissionLane.unread => cs.primary,
    MissionLane.live => cs.tertiary,
    MissionLane.quiet => cs.outlineVariant,
  };
}

/// Max action rows shown before a "… +n" fold. Keeps the radar on one
/// screen even when many sessions pile up.
const missionControlActionPreview = 6;

/// A workspace with no hot sessions and no activity inside this window
/// is quiet — folded behind the quiet drawer by default.
const missionControlQuietWindow = Duration(hours: 3);

/// Last-activity timestamp for [session], preferring the message cache.
int missionLastActivityAt(Session session, SessionUiEntry entry) {
  return entry.lastMessageTimestamp ??
      session.lastMessageAt ??
      (session.activeAt > session.updatedAt
          ? session.activeAt
          : session.updatedAt);
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

/// Shortens a display path to its last two segments:
/// `~/git/fw-analyzer/.firmware` → `fw-analyzer/.firmware`.
String missionShortPath(String displayPath) {
  final segments = displayPath
      .split('/')
      .where((segment) => segment.isNotEmpty && segment != '~')
      .toList();
  if (segments.isEmpty) return displayPath;
  if (segments.length == 1) return segments.single;
  return segments.sublist(segments.length - 2).join('/');
}

/// Short host for the workspace line.
///
/// Kubernetes pod names like `workspace@workspace-denys-local-6589…`
/// collapse to the first meaningful token (`workspace`). Bare hosts
/// (`root@OpenWrt`) and short names pass through.
String missionShortHost(String machineName) {
  var name = machineName.trim();
  if (name.isEmpty) return name;
  // Drop trailing parenthetical flavour, e.g. `root@happy (go)`.
  final paren = name.indexOf(' (');
  if (paren > 0) name = name.substring(0, paren);
  // Prefer the host side of user@host.
  final at = name.lastIndexOf('@');
  if (at >= 0 && at < name.length - 1) {
    name = name.substring(at + 1);
  }
  // k8s pods: `workspace-denys-local-6589959b66-pzg66` → `workspace-denys`.
  // Any name with 3+ dash segments and length > 16 is treated the same —
  // the tail is almost always a hash, never the part the user reads.
  final parts = name.split('-').where((p) => p.isNotEmpty).toList();
  if (parts.length >= 3 && name.length > 16) {
    return parts.take(2).join('-');
  }
  return name;
}

/// Action-first session radar.
///
/// Design rule: the list is what needs you, not the archive.
/// - Blocked / unread / live sessions render as action rows at the top.
/// - Workspaces are one-line status only. Tap opens the existing folder
///   detail — never expands sessions inline (that was the scroll dump).
/// - Quiet workspaces (no hot sessions, no activity in 3h) hide behind
///   a single "N quiet" drawer.
class MissionControlView extends StatefulWidget {
  const MissionControlView({
    required this.activeSessions,
    required this.inactiveSessions,
    required this.machines,
    required this.uiState,
    required this.attentionCardBuilder,
    required this.liveCardBuilder,
    required this.onOpenWorkspace,
    super.key,
    this.scrollController,
  });

  final List<Session> activeSessions;
  final List<Session> inactiveSessions;
  final Map<String, Machine> machines;
  final SessionUiState uiState;

  /// Prominent card for blocked / unread sessions.
  final Widget Function(Session session, SessionUiEntry entry)
  attentionCardBuilder;

  /// Dense live-session card: name + elapsed + activity on one surface.
  final Widget Function(Session session, SessionUiEntry entry, int now)
  liveCardBuilder;

  /// Opens the existing folder-detail drill-in for a workspace.
  final void Function(SessionFolderHeader header) onOpenWorkspace;

  final ScrollController? scrollController;

  @override
  State<MissionControlView> createState() => _MissionControlViewState();
}

class _MissionControlViewState extends State<MissionControlView> {
  bool _showAllActions = false;
  bool _showQuiet = false;

  Timer? _tick;
  int _now = DateTime.now().millisecondsSinceEpoch;

  SessionUiEntry _entry(String id) =>
      widget.uiState.bySessionId[id] ?? SessionUiEntry.empty;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(MissionControlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    final needed = widget.activeSessions.any(
      (session) =>
          missionLaneFor(session, _entry(session.id)) == MissionLane.live,
    );
    if (needed && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _now = DateTime.now().millisecondsSinceEpoch);
        }
      });
    } else if (!needed && _tick != null) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final lanes = <String, MissionLane>{};
    final counts = <MissionLane, int>{
      for (final lane in MissionLane.values) lane: 0,
    };
    final blocked = <Session>[];
    final unread = <Session>[];
    final live = <Session>[];
    for (final session in widget.activeSessions) {
      final lane = missionLaneFor(session, _entry(session.id));
      lanes[session.id] = lane;
      counts[lane] = counts[lane]! + 1;
      switch (lane) {
        case MissionLane.blocked:
          blocked.add(session);
        case MissionLane.unread:
          unread.add(session);
        case MissionLane.live:
          live.add(session);
        case MissionLane.quiet:
          break;
      }
    }
    // Action stack: blocked first (stalled agent), then unread, then live.
    final actions = [...blocked, ...unread, ...live];
    final shownActions = !_showAllActions &&
            actions.length > missionControlActionPreview
        ? actions.sublist(0, missionControlActionPreview)
        : actions;
    final hiddenActions = actions.length - shownActions.length;

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

    final active = <SessionFolderGroup>[];
    final quiet = <SessionFolderGroup>[];
    for (final group in workspaces) {
      final all = [...group.activeSessions, ...group.inactiveSessions];
      final hot = all.any(
        (session) =>
            (lanes[session.id] ?? MissionLane.quiet) != MissionLane.quiet,
      );
      final recent = all.any(
        (session) =>
            _now - missionLastActivityAt(session, _entry(session.id)) <=
            missionControlQuietWindow.inMilliseconds,
      );
      if (hot || recent) {
        active.add(group);
      } else {
        quiet.add(group);
      }
    }

    final items = <Widget>[
      _Radar(
        blocked: counts[MissionLane.blocked]!,
        unread: counts[MissionLane.unread]!,
        working: counts[MissionLane.live]!,
        idle: counts[MissionLane.quiet]!,
      ),
    ];

    if (actions.isEmpty && workspaces.isEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
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
    } else if (actions.isNotEmpty) {
      final attentionShown = <Session>[];
      final liveShown = <Session>[];
      for (final session in shownActions) {
        if (lanes[session.id] == MissionLane.live) {
          liveShown.add(session);
        } else {
          attentionShown.add(session);
        }
      }
      for (final session in attentionShown) {
        items.add(
          widget.attentionCardBuilder(session, _entry(session.id)),
        );
      }
      if (liveShown.isNotEmpty) {
        items.add(
          _LiveGroup(
            children: [
              for (final session in liveShown)
                widget.liveCardBuilder(
                  session,
                  _entry(session.id),
                  _now,
                ),
            ],
          ),
        );
      }
      if (hiddenActions > 0 || _showAllActions) {
        items.add(
          _MoreRow(
            label: _showAllActions
                ? l10n.machineShowLess
                : l10n.missionControlMoreActions(hiddenActions),
            onTap: () => setState(() => _showAllActions = !_showAllActions),
          ),
        );
      }
    }

    if (active.isNotEmpty || quiet.isNotEmpty) {
      items
        ..add(
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
        )
        ..add(
          _WorkspaceList(
            groups: [
              ...active,
              if (_showQuiet) ...quiet,
            ],
            lanes: lanes,
            onOpen: widget.onOpenWorkspace,
          ),
        );
      if (quiet.isNotEmpty) {
        items.add(
          _QuietDrawer(
            count: quiet.length,
            open: _showQuiet,
            onTap: () => setState(() => _showQuiet = !_showQuiet),
          ),
        );
      }
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

/// Fleet counts — only non-zero lanes.
class _Radar extends StatelessWidget {
  const _Radar({
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
    if (blocked + unread + working + idle == 0) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xxs,
        children: [
          if (blocked > 0)
            _RadarChip(
              label: l10n.missionControlStatBlocked,
              count: blocked,
              color: cs.error,
              pulse: true,
            ),
          if (unread > 0)
            _RadarChip(
              label: l10n.missionControlStatUnread,
              count: unread,
              color: cs.primary,
              pulse: false,
            ),
          if (working > 0)
            _RadarChip(
              label: l10n.missionControlStatWorking,
              count: working,
              color: cs.tertiary,
              pulse: true,
            ),
          if (idle > 0)
            _RadarChip(
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

class _RadarChip extends StatelessWidget {
  const _RadarChip({
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LaneDot(color: color, pulse: pulse),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          '$count',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: AppFontSize.xs,
            color: color,
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
    );
  }
}

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

/// Rounded surface for the live-session stack.
class _LiveGroup extends StatelessWidget {
  const _LiveGroup({required this.children});

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
        border: Border.all(
          color: cs.tertiary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// "… +n" / "Show less" toggle used for action overflow and quiet
/// workspaces.
class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: AppFontSize.xs,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Quiet-workspace drawer: one row under the list, same surface language.
class _QuietDrawer extends StatelessWidget {
  const _QuietDrawer({
    required this.count,
    required this.open,
    required this.onTap,
  });

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        0,
      ),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  size: AppIconSize.sm,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    open
                        ? l10n.machineShowLess
                        : l10n.missionControlQuietWorkspaces(count),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: AppFontSize.xs,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
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

/// One surface holding every visible workspace line.
class _WorkspaceList extends StatelessWidget {
  const _WorkspaceList({
    required this.groups,
    required this.lanes,
    required this.onOpen,
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
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < groups.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
            _WorkspaceLine(
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

/// One workspace, one line. Tap drills into folder detail — never
/// expands sessions here.
class _WorkspaceLine extends StatelessWidget {
  const _WorkspaceLine({
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

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.smd,
          AppSpacing.sm,
          AppSpacing.smd,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: missionShortPath(header.displayPath),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    TextSpan(
                      text: '  ${missionShortHost(header.machineName)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: AppFontSize.xxs,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
            for (final lane in [
              MissionLane.blocked,
              MissionLane.unread,
              MissionLane.live,
            ])
              if (counts[lane]! > 0)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: _LaneCount(
                    count: counts[lane]!,
                    color: _laneColor(lane, cs),
                    pulse: lane != MissionLane.unread,
                  ),
                ),
            // Fixed width so 1 / 11 / 89 all share one right edge.
            // 3 tabular digits + chevron; path/machine eat the rest.
            SizedBox(
              width: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${sessions.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: AppFontSize.xxs,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: AppIconSize.sm,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LaneCount extends StatelessWidget {
  const _LaneCount({
    required this.count,
    required this.color,
    required this.pulse,
  });

  final int count;
  final Color color;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LaneDot(color: color, pulse: pulse, size: 5),
        const SizedBox(width: 3),
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

/// Dense live-session card: status, name, elapsed, optional activity.
///
/// Public so the parent can wrap selection + dismissible around it.
class MissionLiveCard extends StatelessWidget {
  const MissionLiveCard({
    required this.session,
    required this.entry,
    required this.now,
    required this.onTap,
    required this.onLongPress,
    super.key,
    this.selected = false,
  });

  final Session session;
  final SessionUiEntry entry;
  final int now;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final since =
        entry.lastMessageTimestamp ?? session.lastMessageAt ?? session.activeAt;
    final activity = getSessionActivity(context, session);
    final preview = entry.lastMessagePreview;
    final subtitle = activity?.label ??
        (preview != null && preview.isNotEmpty ? preview : null);

    return Material(
      color: selected ? cs.primary.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              _LaneDot(color: cs.tertiary, pulse: true, size: 7),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getSessionName(session),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: AppFontSize.xxs,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                formatElapsedShort(now - since),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.tertiary,
                  fontWeight: FontWeight.w700,
                  fontSize: AppFontSize.xs,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
