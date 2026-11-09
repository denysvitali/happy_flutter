part of 'session_board_view.dart';

/// Groups live sessions by the agent harness running them (Claude, Codex,
/// …). The busiest harness comes first; rows inside a harness are ordered
/// by urgency, so blocked work stays at the top of each group.
List<SessionBoardSection> buildAgentSections(
  BuildContext context,
  List<Session> sessions,
  SessionUiState uiState,
) {
  final l10n = context.l10n;
  final groups = <String, List<SessionBoardRow>>{};
  for (final session in sessions) {
    final entry = _entryFor(uiState, session.id);
    final key = missionHarnessKey(session.metadata?.flavor);
    (groups[key] ??= []).add(
      SessionBoardRow(session, entry, missionLaneFor(session, entry)),
    );
  }
  final keys = groups.keys.toList()
    ..sort((a, b) {
      final size = groups[b]!.length.compareTo(groups[a]!.length);
      if (size != 0) return size;
      return missionHarnessName(l10n, a).compareTo(missionHarnessName(l10n, b));
    });
  return [
    for (final key in keys)
      SessionBoardSection(
        key: 'agent-$key',
        title: missionHarnessName(l10n, key),
        subtitle:
            missionLaneSummary(context, _laneCounts(groups[key]!)) ??
            l10n.missionControlSessionCount(groups[key]!.length),
        icon: Icons.smart_toy_outlined,
        rows: groups[key]!..sort(_byLaneThenActivity),
      ),
  ];
}

/// Groups live sessions by when they were last active: Today, Yesterday,
/// This week, This month, Older. Rows are newest first, so this reads as
/// a plain timeline rather than a triage board.
List<SessionBoardSection> buildRecentSections(
  BuildContext context,
  List<Session> sessions,
  SessionUiState uiState, {
  DateTime? now,
}) {
  final l10n = context.l10n;
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekAgo = today.subtract(const Duration(days: 7));
  final monthStart = DateTime(clock.year, clock.month);
  DateGroup groupFor(int activityMs) {
    final at = DateTime.fromMillisecondsSinceEpoch(activityMs);
    final day = DateTime(at.year, at.month, at.day);
    if (!day.isBefore(today)) return DateGroup.today;
    if (!day.isBefore(yesterday)) return DateGroup.yesterday;
    if (day.isAfter(weekAgo)) return DateGroup.thisWeek;
    if (!day.isBefore(monthStart)) return DateGroup.thisMonth;
    return DateGroup.older;
  }

  final groups = <DateGroup, List<SessionBoardRow>>{};
  for (final session in sessions) {
    final entry = _entryFor(uiState, session.id);
    final group = groupFor(missionLastActivityAt(session, entry));
    (groups[group] ??= []).add(
      SessionBoardRow(session, entry, missionLaneFor(session, entry)),
    );
  }
  String title(DateGroup group) => switch (group) {
    DateGroup.today => l10n.sessionsToday,
    DateGroup.yesterday => l10n.sessionsYesterday,
    DateGroup.thisWeek => l10n.sessionsThisWeek,
    DateGroup.thisMonth => l10n.sessionsThisMonth,
    DateGroup.older => l10n.sessionsOlder,
  };
  return [
    for (final group in DateGroup.values)
      if (groups[group] case final rows?)
        SessionBoardSection(
          key: 'recent-${group.name}',
          title: title(group),
          subtitle: l10n.missionControlSessionCount(rows.length),
          icon: Icons.schedule_outlined,
          rows: rows..sort(_byActivity),
          collapseAfter:
              group == DateGroup.older &&
                  rows.length > statusBoardQuietFoldThreshold
              ? statusBoardQuietPreview
              : null,
        ),
  ];
}

/// Groups live sessions by where they run: Kubernetes session pods by pod
/// state (failed, starting, running, paused), then sessions running
/// directly on a machine. Rows inside a group are ordered by urgency.
List<SessionBoardSection> buildKubernetesSections(
  BuildContext context,
  List<Session> sessions,
  SessionUiState uiState,
) {
  final l10n = context.l10n;
  const podOrder = [
    SessionPodDisplayState.failed,
    SessionPodDisplayState.scheduling,
    SessionPodDisplayState.ready,
    SessionPodDisplayState.paused,
  ];
  final pods = <SessionPodDisplayState, List<SessionBoardRow>>{};
  final local = <SessionBoardRow>[];
  for (final session in sessions) {
    final entry = _entryFor(uiState, session.id);
    final row = SessionBoardRow(session, entry, missionLaneFor(session, entry));
    if (!session.isKubernetesSession) {
      local.add(row);
      continue;
    }
    final state = session.podDisplayState;
    if (state == SessionPodDisplayState.archived) continue;
    (pods[state] ??= []).add(row);
  }
  return [
    for (final state in podOrder)
      if (pods[state] case final rows?)
        SessionBoardSection(
          key: 'kubernetes-${state.name}',
          title:
              '${l10n.kubernetesTitle} · '
              '${kubernetesPodStateLabel(l10n, state)}',
          subtitle:
              missionLaneSummary(context, _laneCounts(rows)) ??
              l10n.missionControlSessionCount(rows.length),
          icon: Icons.cloud_outlined,
          rows: rows..sort(_byLaneThenActivity),
        ),
    if (local.isNotEmpty)
      SessionBoardSection(
        key: 'kubernetes-local',
        title: l10n.kubernetesLocalSessions,
        subtitle:
            missionLaneSummary(context, _laneCounts(local)) ??
            l10n.missionControlSessionCount(local.length),
        icon: Icons.computer_outlined,
        rows: local..sort(_byLaneThenActivity),
        collapseAfter: local.length > statusBoardQuietFoldThreshold
            ? statusBoardQuietPreview
            : null,
      ),
  ];
}
