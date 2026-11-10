part of 'session_board_view.dart';

/// Active rows shown before a busy project folds behind "Show more".
const int projectBoardPreview = 6;

/// Projects up to this size stay fully visible.
const int projectBoardFoldThreshold = 8;

/// Archived conversations previewed per project.
const int projectBoardArchivedPreview = 3;

/// Groups sessions by project: one section per repository (or folder name)
/// no matter which machine or Kubernetes pod runs each session.
///
/// Projects waiting on the user come first, then the most recently active.
/// The subtitle says what the project is doing and where it runs; rows are
/// marked with their runtime whenever a project spans more than one place.
/// With [archived] the sections preview a project's past conversations.
List<SessionBoardSection> buildProjectSections(
  BuildContext context,
  List<Session> sessions,
  Map<String, Machine> machines,
  SessionUiState uiState, {
  required SessionProjectIndex index,
  bool archived = false,
}) {
  final l10n = context.l10n;
  final groups = <String, List<SessionBoardRow>>{};
  final projects = <String, SessionProject>{};
  final pods = <String, int>{};
  final hosts = <String, Set<String>>{};
  final hostBySessionId = <String, String>{};

  for (final session in sessions) {
    final project = index.projectOf(session);
    projects[project.key] = project;
    if (session.isKubernetesSession) {
      pods[project.key] = (pods[project.key] ?? 0) + 1;
    } else {
      final machine = machines[session.metadata?.machineId];
      final host = missionShortHost(
        machine?.displayLabel ?? session.metadata?.host ?? '',
      );
      if (host.isNotEmpty) {
        hostBySessionId[session.id] = host;
        (hosts[project.key] ??= {}).add(host);
      }
    }
  }

  for (final session in sessions) {
    final key = index.projectOf(session).key;
    final entry = _entryFor(uiState, session.id);
    final podCount = pods[key] ?? 0;
    final hostCount = hosts[key]?.length ?? 0;
    final host = hostBySessionId[session.id];
    // A project in one place names it once, in the header. Pods are always
    // marked: they are the sessions that live outside the user's machines.
    final mixed = hostCount + (podCount > 0 ? 1 : 0) > 1;
    final runtime = _runtimeMark(l10n, session, host: host, mixed: mixed);
    (groups[key] ??= []).add(
      SessionBoardRow(
        session,
        entry,
        archived ? MissionLane.quiet : missionLaneFor(session, entry),
        runtime: runtime,
      ),
    );
  }

  bool needsUser(List<SessionBoardRow> rows) =>
      rows.any((row) => row.lane.index <= MissionLane.unread.index);
  int lastActivity(List<SessionBoardRow> rows) => rows
      .map((row) => missionLastActivityAt(row.session, row.entry))
      .fold(0, (a, b) => a > b ? a : b);
  final latest = {
    for (final entry in groups.entries) entry.key: lastActivity(entry.value),
  };
  final keys = groups.keys.toList()
    ..sort((a, b) {
      if (!archived) {
        final attention =
            (needsUser(groups[b]!) ? 1 : 0) - (needsUser(groups[a]!) ? 1 : 0);
        if (attention != 0) return attention;
      }
      final activity = latest[b]!.compareTo(latest[a]!);
      return activity != 0 ? activity : a.compareTo(b);
    });

  String places(String key) {
    final podCount = pods[key] ?? 0;
    final names = (hosts[key] ?? const <String>{}).toList()..sort();
    return [
      if (podCount > 0) l10n.sessionsProjectPods(podCount),
      if (names.length > 2)
        l10n.sessionsProjectMachines(names.length)
      else
        ...names,
    ].join(' · ');
  }

  return [
    for (final key in keys)
      () {
        final rows = groups[key]!;
        final project = projects[key]!;
        final where = places(key);
        final summary = archived
            ? null
            : missionLaneSummary(context, _laneCounts(rows));
        return SessionBoardSection(
          key: 'project-$key',
          title: project.name.isEmpty
              ? l10n.sessionsProjectUnknown
              : project.name,
          // Archived sections keep the plain "name  count" heading.
          subtitle: archived || (summary == null && where.isEmpty)
              ? null
              : [?summary, if (where.isNotEmpty) where].join(' · '),
          icon: project.repository != null
              ? Icons.source_rounded
              : Icons.folder_rounded,
          iconColor: workspaceIdentityColor(context, key),
          rows: rows..sort(archived ? _byActivity : _byLaneThenActivity),
          collapseAfter: archived
              ? (rows.length > projectBoardArchivedPreview
                    ? projectBoardArchivedPreview
                    : null)
              : rows.length > projectBoardFoldThreshold
              ? projectBoardPreview
              : null,
        );
      }(),
  ];
}
