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

/// Sessions triage view: what is blocked on you, what is running right
/// now, and everything else folded into its workspace.
///
/// It merges the two things the folder and unread-focus views each did
/// well — grouping by working directory and surfacing what needs the
/// user — into one screen that answers "where do I look next?".
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

  /// Builds the prominent card used in the "Waiting on you" lane.
  final Widget Function(Session session, SessionUiEntry entry)
  attentionCardBuilder;

  /// Builds a compact row used inside workspace groups.
  final Widget Function(Session session, SessionUiEntry entry) rowBuilder;

  final ScrollController? scrollController;

  @override
  State<MissionControlView> createState() => _MissionControlViewState();
}

class _MissionControlViewState extends State<MissionControlView> {
  final Set<String> _collapsedWorkspaces = <String>{};
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Keeps the live-lane elapsed timers moving while anything is running.
  void _syncTicker({required bool hasLive}) {
    if (hasLive && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!hasLive && _tick != null) {
      _tick?.cancel();
      _tick = null;
    }
  }

  SessionUiEntry _entry(String id) =>
      widget.uiState.bySessionId[id] ?? SessionUiEntry.empty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final blocked = <Session>[];
    final unread = <Session>[];
    final live = <Session>[];
    var quiet = 0;
    for (final session in widget.activeSessions) {
      switch (missionLaneFor(session, _entry(session.id))) {
        case MissionLane.blocked:
          blocked.add(session);
        case MissionLane.unread:
          unread.add(session);
        case MissionLane.live:
          live.add(session);
        case MissionLane.quiet:
          quiet++;
      }
    }
    // Blocked first: an agent waiting on approval is stalled, unread is not.
    final attention = [...blocked, ...unread];

    // The ticker only exists while something is actually running.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncTicker(hasLive: live.isNotEmpty),
    );

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
      _StatusStrip(
        blocked: blocked.length,
        unread: unread.length,
        live: live.length,
        quiet: quiet,
      ),
    ];

    if (attention.isEmpty && live.isEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            l10n.missionControlAllQuiet,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    if (attention.isNotEmpty) {
      items.add(
        SectionHeader(
          title: l10n.missionControlWaiting,
          trailing: _CountPill(count: attention.length, emphasised: true),
        ),
      );
      for (final session in attention) {
        items.add(widget.attentionCardBuilder(session, _entry(session.id)));
      }
    }

    if (live.isNotEmpty) {
      items
        ..add(const SizedBox(height: AppSpacing.xs))
        ..add(
          SectionHeader(
            title: l10n.missionControlLive,
            trailing: _CountPill(count: live.length, emphasised: false),
          ),
        );
      for (final session in live) {
        items.add(
          _LiveTile(
            session: session,
            entry: _entry(session.id),
            child: widget.rowBuilder(session, _entry(session.id)),
          ),
        );
      }
    }

    if (workspaces.isNotEmpty) {
      items
        ..add(const SizedBox(height: AppSpacing.xs))
        ..add(
          SectionHeader(
            title: l10n.missionControlWorkspaces,
            trailing: _CountPill(
              count: workspaces.length,
              emphasised: false,
            ),
          ),
        );
      for (final group in workspaces) {
        final key = group.header.folderKey;
        items.add(
          _WorkspaceGroup(
            header: group.header,
            collapsed: _collapsedWorkspaces.contains(key),
            onToggle: () => setState(() {
              if (!_collapsedWorkspaces.remove(key)) {
                _collapsedWorkspaces.add(key);
              }
            }),
            rows: [
              for (final session in [
                ...group.activeSessions,
                ...group.inactiveSessions,
              ])
                widget.rowBuilder(session, _entry(session.id)),
            ],
          ),
        );
      }
    }

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.lg),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      itemCount: items.length,
      itemBuilder: (ctx, i) => items[i],
    );
  }
}

/// One-glance fleet summary: blocked, unread, running, quiet.
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.blocked,
    required this.unread,
    required this.live,
    required this.quiet,
  });

  final int blocked;
  final int unread;
  final int live;
  final int quiet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxs,
      ),
      child: Row(
        children: [
          _Stat(
            label: l10n.missionControlStatBlocked,
            count: blocked,
            color: cs.error,
            pulse: blocked > 0,
          ),
          _Stat(
            label: l10n.missionControlStatUnread,
            count: unread,
            color: cs.primary,
            pulse: false,
          ),
          _Stat(
            label: l10n.missionControlStatWorking,
            count: live,
            color: cs.tertiary,
            pulse: live > 0,
          ),
          _Stat(
            label: l10n.missionControlStatIdle,
            count: quiet,
            color: cs.onSurfaceVariant,
            pulse: false,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
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
    final dot = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : color.withValues(alpha: 0.35),
      ),
    );
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xs,
          horizontal: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (pulse) _PulsingDot(child: dot) else dot,
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  '$count',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: active ? color : theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: AppFontSize.xxs,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.child});

  final Widget child;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
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

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, required this.emphasised});

  final int count;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (!emphasised) {
      return Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          fontSize: AppFontSize.xs,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: cs.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: AppFontSize.xxs,
        ),
      ),
    );
  }
}

/// A running session: the row plus a live activity bar and elapsed time.
class _LiveTile extends StatelessWidget {
  const _LiveTile({
    required this.session,
    required this.entry,
    required this.child,
  });

  final Session session;
  final SessionUiEntry entry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final activity = getSessionActivity(context, session);
    final since =
        entry.lastMessageTimestamp ?? session.lastMessageAt ?? session.activeAt;
    final elapsed = DateTime.now().millisecondsSinceEpoch - since;

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
          child,
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    activity?.label ?? context.l10n.sessionActivityWorking,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.tertiary,
                      fontSize: AppFontSize.xs,
                    ),
                  ),
                ),
                Text(
                  formatElapsedShort(elapsed),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: AppFontSize.xs,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          _ActivityBar(color: cs.tertiary),
        ],
      ),
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

/// Indeterminate sweep under a running session — the visual signal that
/// something is happening without the user opening the chat.
class _ActivityBar extends StatefulWidget {
  const _ActivityBar({required this.color});

  final Color color;

  @override
  State<_ActivityBar> createState() => _ActivityBarState();
}

class _ActivityBarState extends State<_ActivityBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final barWidth = width * 0.3;
              final travel = width + barWidth;
              return Stack(
                children: [
                  Positioned(
                    left: _controller.value * travel - barWidth,
                    width: barWidth,
                    top: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.color.withValues(alpha: 0),
                            widget.color,
                            widget.color.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// A working directory with its sessions, collapsible in place — the
/// folder view without the drill-down.
class _WorkspaceGroup extends StatelessWidget {
  const _WorkspaceGroup({
    required this.header,
    required this.collapsed,
    required this.onToggle,
    required this.rows,
  });

  final SessionFolderHeader header;
  final bool collapsed;
  final VoidCallback onToggle;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    collapsed
                        ? Icons.folder_outlined
                        : Icons.folder_open_outlined,
                    size: AppIconSize.sm,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          header.displayPath,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${header.machineName} · '
                          '${header.sessionCount}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: AppFontSize.xs,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (header.unreadCount > 0)
                    _CountPill(count: header.unreadCount, emphasised: true),
                  Icon(
                    collapsed ? Icons.expand_more : Icons.expand_less,
                    size: AppIconSize.sm,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (!collapsed)
            for (var i = 0; i < rows.length; i++) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
              rows[i],
            ],
        ],
      ),
    );
  }
}
