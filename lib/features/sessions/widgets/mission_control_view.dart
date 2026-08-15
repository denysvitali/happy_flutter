import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/machine.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/session_ui_state_notifier.dart';
import '../../../core/services/logger_service.dart' show logger;
import '../../../core/services/mission_triage_storage.dart';
import '../../../core/services/opentelemetry_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/performance_buckets.dart';
import '../../../core/utils/session_utils.dart';
import 'mission_control_summary.dart';
import 'mission_control_types.dart';
import 'mission_control_workspace_list.dart';
import 'session_headers.dart';

export 'mission_control_action_tile.dart' show MissionActionRow;
export 'mission_control_types.dart'
    show
        MissionLane,
        formatElapsedShort,
        missionLaneFor,
        missionShortHost,
        missionShortPath;

/// Max rows shown in either action section before a disclosure control.
const missionControlActionPreview = 4;

/// Above this collection size, persistent activity pulses are replaced with
/// static status indicators. A single repeating ticker schedules frames for
/// the entire screen; large Mission Control collections otherwise render at
/// the display refresh rate even while the user is idle.
const missionControlAnimatedSessionLimit = 50;

bool missionControlShouldAnimateActivity(int sessionCount) {
  return sessionCount <= missionControlAnimatedSessionLimit;
}

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

/// Action-first session dashboard.
///
/// Mission Control answers two questions in order: what needs the user, and
/// where work is happening. Workspace rows always drill into folder detail;
/// they never expand a second session archive inline.
class MissionControlView extends StatefulWidget {
  const MissionControlView({
    required this.activeSessions,
    required this.inactiveSessions,
    required this.machines,
    required this.uiState,
    required this.actionCardBuilder,
    required this.onOpenWorkspace,
    super.key,
    this.scrollController,
    this.triage = const MissionTriageState(),
    this.onMarkRead,
    this.onTogglePin,
    this.onToggleSnooze,
    this.onToggleMuteFolder,
  });

  final List<Session> activeSessions;
  final List<Session> inactiveSessions;
  final Map<String, Machine> machines;
  final SessionUiState uiState;
  final MissionTriageState triage;

  /// Builds one session tile while preserving parent-owned navigation,
  /// selection, swipe actions, and long-press behavior.
  final Widget Function(
    Session session,
    SessionUiEntry entry,
    MissionLane lane, {
    required bool animateActivity,
    required bool highlighted,
  })
  actionCardBuilder;

  final void Function(SessionFolderHeader header) onOpenWorkspace;
  final ScrollController? scrollController;

  final void Function(String sessionId)? onMarkRead;
  final void Function(String sessionId)? onTogglePin;
  final void Function(String sessionId, bool snooze)? onToggleSnooze;
  final void Function(String folderKey)? onToggleMuteFolder;

  @override
  State<MissionControlView> createState() => _MissionControlViewState();
}

class _MissionControlViewState extends State<MissionControlView> {
  bool _showAllActions = false;
  bool _showQuiet = false;
  MissionLane? _selectedLane;
  final Map<String, int> _sessionSlots = {};
  final Map<String, int> _workspaceSlots = {};
  int _nextSessionSlot = 0;
  int _nextWorkspaceSlot = 0;
  int _lastModelTraceAtMs = 0;
  int _lastSlowModelLogAtMs = 0;

  /// Actionable session ids the user has already seen since the view last
  /// showed them quiet. Rows entering the actionable set after that get a
  /// subtle tint; the slot order itself never moves.
  final Set<String> _seenActionIds = {};
  bool _queueSeeded = false;

  static const int _telemetryThrottleMs = 30000;

  SessionUiEntry _entry(String id) =>
      widget.uiState.bySessionId[id] ?? SessionUiEntry.empty;

  void _markSeen(String sessionId) {
    if (_seenActionIds.add(sessionId)) {
      setState(() {});
    }
  }

  void _selectLane(MissionLane? lane) {
    setState(() {
      _selectedLane = lane;
      _showAllActions = false;
    });
  }

  void _ensureSessionSlots(Map<String, MissionLane> lanes) {
    _sessionSlots.removeWhere((id, _) => !lanes.containsKey(id));
    // Seed slots by urgency on first sight, then never reshuffle them. Sync
    // can reorder activeSessions on every activity update; treating that
    // transport order as presentation order makes the dashboard jump.
    for (final lane in MissionLane.values) {
      for (final session in widget.activeSessions) {
        if (lanes[session.id] == lane &&
            !_sessionSlots.containsKey(session.id)) {
          _sessionSlots[session.id] = _nextSessionSlot++;
        }
      }
    }
  }

  void _ensureWorkspaceSlots(
    List<SessionFolderGroup> workspaces,
    Map<String, MissionLane> lanes,
  ) {
    final currentKeys = {
      for (final group in workspaces) group.header.folderKey,
    };
    _workspaceSlots.removeWhere((key, _) => !currentKeys.contains(key));
    final unseen =
        workspaces
            .where(
              (group) => !_workspaceSlots.containsKey(group.header.folderKey),
            )
            .toList()
          ..sort((a, b) => _compareWorkspacePriority(a, b, lanes));
    for (final group in unseen) {
      _workspaceSlots[group.header.folderKey] = _nextWorkspaceSlot++;
    }
  }

  int _compareSessionSlots(Session a, Session b) {
    return _sessionSlots[a.id]!.compareTo(_sessionSlots[b.id]!);
  }

  /// Queue order: pinned sessions first, then stable first-seen slots.
  /// Pinning is the only reordering Mission Control ever does — everything
  /// else keeps its slot so concurrent updates don't shuffle the deck.
  int _compareQueueSlots(Session a, Session b) {
    final pinnedA = widget.triage.isPinned(a.id) ? 0 : 1;
    final pinnedB = widget.triage.isPinned(b.id) ? 0 : 1;
    if (pinnedA != pinnedB) return pinnedA.compareTo(pinnedB);
    return _compareSessionSlots(a, b);
  }

  int _compareWorkspaceSlots(SessionFolderGroup a, SessionFolderGroup b) {
    return _workspaceSlots[a.header.folderKey]!.compareTo(
      _workspaceSlots[b.header.folderKey]!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final modelStopwatch = Stopwatch()..start();
    final sessionCount =
        widget.activeSessions.length + widget.inactiveSessions.length;
    final modelSpan = _startModelTrace(sessionCount);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final now = DateTime.now().millisecondsSinceEpoch;

    final lanes = <String, MissionLane>{};
    final counts = <MissionLane, int>{
      for (final lane in MissionLane.values) lane: 0,
    };
    final blocked = <Session>[];
    final errored = <Session>[];
    final unread = <Session>[];
    final working = <Session>[];
    for (final session in widget.activeSessions) {
      // Snoozed sessions stay out of the queue entirely — they read as
      // quiet until the snooze lapses or the user unsnoozes them.
      final lane = widget.triage.isSnoozed(session.id, nowMs: now)
          ? MissionLane.quiet
          : missionLaneFor(session, _entry(session.id));
      lanes[session.id] = lane;
      counts[lane] = counts[lane]! + 1;
      switch (lane) {
        case MissionLane.blocked:
          blocked.add(session);
        case MissionLane.error:
          errored.add(session);
        case MissionLane.unread:
          unread.add(session);
        case MissionLane.live:
          working.add(session);
        case MissionLane.quiet:
          break;
      }
    }
    _ensureSessionSlots(lanes);
    blocked.sort(_compareSessionSlots);
    errored.sort(_compareSessionSlots);
    unread.sort(_compareSessionSlots);
    working.sort(_compareSessionSlots);

    // Highlight tracking: the first build seeds everything currently
    // actionable as seen; afterwards a session earns a tint by becoming
    // actionable again after a quiet spell, and loses it on interaction.
    if (!_queueSeeded) {
      _queueSeeded = true;
      lanes.forEach((id, lane) {
        if (lane != MissionLane.quiet) _seenActionIds.add(id);
      });
    } else {
      lanes.forEach((id, lane) {
        if (lane == MissionLane.quiet) _seenActionIds.add(id);
      });
    }
    bool isHighlighted(String id, MissionLane lane) =>
        lane != MissionLane.quiet && !_seenActionIds.contains(id);

    final selectedLane = _selectedLane != null && counts[_selectedLane]! > 0
        ? _selectedLane
        : null;
    final actions = [...blocked, ...errored, ...unread, ...working]
      ..sort(_compareQueueSlots);
    final filteredActions = selectedLane == null
        ? actions
        : actions
              .where((session) => lanes[session.id] == selectedLane)
              .toList();
    final shownActions =
        !_showAllActions && filteredActions.length > missionControlActionPreview
        ? filteredActions.sublist(0, missionControlActionPreview)
        : filteredActions;

    final workspaces = groupAllSessionsByFolder(
      widget.activeSessions,
      widget.inactiveSessions,
      widget.machines,
      getLastMessageTimestamp: (id) =>
          widget.uiState.bySessionId[id]?.lastMessageTimestamp,
      getUnreadCount: (id) => widget.uiState.bySessionId[id]?.unreadCount ?? 0,
    );
    _ensureWorkspaceSlots(workspaces, lanes);

    final activeWorkspaces = <SessionFolderGroup>[];
    final quietWorkspaces = <SessionFolderGroup>[];
    for (final group in workspaces) {
      // A muted workspace is parked in the quiet drawer no matter how hot
      // it gets; unmuting (long-press) restores normal classification.
      final muted = widget.triage.isMuted(group.header.folderKey);
      var hot = false;
      var recent = false;
      for (final session in group.activeSessions.followedBy(
        group.inactiveSessions,
      )) {
        if ((lanes[session.id] ?? MissionLane.quiet) != MissionLane.quiet) {
          hot = true;
        }
        if (!recent &&
            now - missionLastActivityAt(session, _entry(session.id)) <=
                missionControlQuietWindow.inMilliseconds) {
          recent = true;
        }
      }
      if (!muted && (hot || recent)) {
        activeWorkspaces.add(group);
      } else {
        quietWorkspaces.add(group);
      }
    }
    activeWorkspaces.sort(_compareWorkspaceSlots);
    quietWorkspaces.sort(_compareWorkspaceSlots);
    _recordModelBuild(
      stopwatch: modelStopwatch,
      span: modelSpan,
      sessionCount: sessionCount,
      workspaceCount: workspaces.length,
    );

    final slivers = <Widget>[];
    final animateActivity = missionControlShouldAnimateActivity(sessionCount);

    if (filteredActions.isNotEmpty) {
      final tone =
          selectedLane ??
          (counts[MissionLane.blocked]! > 0
              ? MissionLane.blocked
              : counts[MissionLane.error]! > 0
              ? MissionLane.error
              : counts[MissionLane.unread]! > 0
              ? MissionLane.unread
              : MissionLane.live);
      slivers.add(
        SliverToBoxAdapter(
          child: RepaintBoundary(
            child: _ActionSection(
              title: l10n.missionControlFocusQueue,
              count: actions.length,
              lane: tone,
              counts: counts,
              selectedLane: selectedLane,
              onSelectLane: _selectLane,
              hiddenCount: filteredActions.length - shownActions.length,
              expanded: _showAllActions,
              onToggle: () {
                setState(() => _showAllActions = !_showAllActions);
              },
              children: [
                for (final session in shownActions)
                  Listener(
                    onPointerDown: (_) => _markSeen(session.id),
                    child: KeyedSubtree(
                      key: ValueKey('mission-action-${session.id}'),
                      child: widget.actionCardBuilder(
                        session,
                        _entry(session.id),
                        lanes[session.id]!,
                        animateActivity: animateActivity,
                        highlighted: isHighlighted(
                          session.id,
                          lanes[session.id]!,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (activeWorkspaces.isNotEmpty || quietWorkspaces.isNotEmpty) {
      final visibleWorkspaces = [
        ...activeWorkspaces,
        if (_showQuiet) ...quietWorkspaces,
      ];
      slivers
        ..add(
          SliverToBoxAdapter(
            child: SectionHeader(
              title: l10n.missionControlWorkspacePulse,
              trailing: _CountBadge(
                count: workspaces.length,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        )
        ..add(
          MissionWorkspaceList(
            groups: visibleWorkspaces,
            lanes: lanes,
            onOpen: widget.onOpenWorkspace,
            isMutedFolder: widget.triage.isMuted,
            onToggleMute: widget.onToggleMuteFolder,
          ),
        );
      if (quietWorkspaces.isNotEmpty) {
        slivers.add(
          SliverToBoxAdapter(
            child: _QuietDrawer(
              count: quietWorkspaces.length,
              open: _showQuiet,
              onTap: () => setState(() => _showQuiet = !_showQuiet),
            ),
          ),
        );
      }
    }

    return CustomScrollView(
      controller: widget.scrollController,
      slivers: [
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
      ],
    );
  }

  OTelSpan? _startModelTrace(int sessionCount) {
    if (sessionCount < 11) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastModelTraceAtMs < _telemetryThrottleMs) return null;
    _lastModelTraceAtMs = now;
    return OpenTelemetryService().startTrace(
      'sessions.mission_control.model',
      attributes: {
        'session.count': sessionCount,
        'session.count_bucket': collectionSizeBucket(sessionCount),
        'activity.animation.enabled': missionControlShouldAnimateActivity(
          sessionCount,
        ),
      },
    );
  }

  void _recordModelBuild({
    required Stopwatch stopwatch,
    required OTelSpan? span,
    required int sessionCount,
    required int workspaceCount,
  }) {
    stopwatch.stop();
    final duration = stopwatch.elapsed;
    OpenTelemetryService().recordDuration(
      'app.sessions.mission_control_model',
      duration,
      attributes: {
        'session_count_bucket': collectionSizeBucket(sessionCount),
        'workspace_count_bucket': collectionSizeBucket(workspaceCount),
        'activity_animation': missionControlShouldAnimateActivity(sessionCount)
            ? 'enabled'
            : 'disabled',
      },
      description: 'Time to group and prioritize Mission Control sessions',
    );
    span
      ?..setAttribute('workspace.count', workspaceCount)
      ..setAttribute('work.duration_us', duration.inMicroseconds)
      ..end();

    final now = DateTime.now().millisecondsSinceEpoch;
    if (duration.inMilliseconds >= 16 &&
        now - _lastSlowModelLogAtMs >= _telemetryThrottleMs) {
      _lastSlowModelLogAtMs = now;
      logger.warning(
        '[Perf] Mission Control model '
        'sessions=$sessionCount workspaces=$workspaceCount '
        'elapsedMs=${duration.inMilliseconds}',
      );
    }
  }
}

int _compareWorkspacePriority(
  SessionFolderGroup a,
  SessionFolderGroup b,
  Map<String, MissionLane> lanes,
) {
  int rank(SessionFolderGroup group) {
    var result = MissionLane.values.length;
    for (final session in group.activeSessions.followedBy(
      group.inactiveSessions,
    )) {
      final lane = lanes[session.id] ?? MissionLane.quiet;
      final laneRank = switch (lane) {
        MissionLane.blocked => 0,
        MissionLane.error => 1,
        MissionLane.unread => 2,
        MissionLane.live => 3,
        MissionLane.quiet => 4,
      };
      if (laneRank < result) result = laneRank;
    }
    return result;
  }

  final rankOrder = rank(a).compareTo(rank(b));
  if (rankOrder != 0) return rankOrder;
  return b.header.latestActivityAt.compareTo(a.header.latestActivityAt);
}

class _ActionSection extends StatelessWidget {
  const _ActionSection({
    required this.title,
    required this.count,
    required this.lane,
    required this.counts,
    required this.selectedLane,
    required this.onSelectLane,
    required this.children,
    required this.hiddenCount,
    required this.expanded,
    required this.onToggle,
  });

  final String title;
  final int count;
  final MissionLane lane;
  final Map<MissionLane, int> counts;
  final MissionLane? selectedLane;
  final ValueChanged<MissionLane?> onSelectLane;
  final List<Widget> children;
  final int hiddenCount;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = missionLaneColor(context, lane);
    final l10n = context.l10n;
    final reduceMotion = AppMotion.reduceMotion(context);
    final content = Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 58,
                color: cs.outlineVariant,
              ),
            children[i],
          ],
          if (hiddenCount > 0 || expanded) ...[
            Divider(height: 1, thickness: 1, color: cs.outlineVariant),
            _DisclosureButton(
              label: expanded
                  ? l10n.machineShowLess
                  : l10n.missionControlMoreActions(hiddenCount),
              expanded: expanded,
              onTap: onToggle,
            ),
          ],
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(missionLaneIcon(lane), size: AppIconSize.sm, color: color),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _CountBadge(count: count, color: color),
            ],
          ),
        ),
        MissionControlFilters(
          counts: counts,
          selectedLane: selectedLane,
          onSelectLane: onSelectLane,
        ),
        if (reduceMotion)
          content
        else
          AnimatedSize(
            duration: AppDuration.normal,
            curve: AppCurve.standard,
            alignment: Alignment.topCenter,
            child: content,
          ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 34,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xsm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontSize: AppFontSize.xs,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _DisclosureButton extends StatelessWidget {
  const _DisclosureButton({
    required this.label,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      button: true,
      expanded: expanded,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: AppFontSize.xs,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: AppMotion.duration(context, AppDuration.normal),
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: AppIconSize.md,
                        color: cs.onSurfaceVariant,
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
    final label = open
        ? l10n.machineShowLess
        : l10n.missionControlQuietWorkspaces(count);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Semantics(
        button: true,
        expanded: open,
        label: label,
        child: ExcludeSemantics(
          child: Material(
            color: cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              side: BorderSide(color: cs.outlineVariant),
            ),
            clipBehavior: Clip.hardEdge,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppTouchTarget.comfortable,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(
                          Icons.bedtime_outlined,
                          size: AppIconSize.md,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.smd),
                      Expanded(
                        child: Text(
                          label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: open ? 0.25 : 0,
                        duration: AppMotion.duration(
                          context,
                          AppDuration.normal,
                        ),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: AppIconSize.lg,
                          color: cs.onSurfaceVariant,
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
