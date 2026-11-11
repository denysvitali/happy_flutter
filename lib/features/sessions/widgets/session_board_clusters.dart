part of 'session_board_view.dart';

/// A run of rows inside a section that belong to one project.
class SessionBoardCluster {
  const SessionBoardCluster({
    required this.key,
    required this.title,
    required this.count,
    required this.color,
  });

  final String key;
  final String title;

  /// Rows of the section in this cluster, including folded ones.
  final int count;

  /// The project's identity hue, shared with the Projects board.
  final Color color;
}

/// Orders [rows] as project runs: projects by their latest activity, rows
/// inside a project newest first. Each row carries its project label and a
/// quiet-row line that no longer needs to repeat the workspace.
List<SessionBoardRow> _clusterByProject(
  BuildContext context,
  List<SessionBoardRow> rows,
  SessionProjectIndex index,
) {
  final l10n = context.l10n;
  final ordered = rows..sort(_byActivity);
  final groups = <String, List<SessionBoardRow>>{};
  final projects = <String, SessionProject>{};
  for (final row in ordered) {
    final project = index.projectOf(row.session);
    projects[project.key] = project;
    // Rows arrive newest first, so groups form in project-recency order.
    (groups[project.key] ??= []).add(row);
  }
  // Labels only pay for themselves when conversations actually repeat a
  // project; one session per project reads better as a plain timeline.
  if (groups.values.every((group) => group.length == 1)) return ordered;
  return [
    for (final group in groups.entries)
      for (final row in group.value)
        SessionBoardRow(
          row.session,
          row.entry,
          row.lane,
          runtime: _runtimeMark(l10n, row.session),
          cluster: SessionBoardCluster(
            key: group.key,
            title: projects[group.key]!.name.isEmpty
                ? l10n.sessionsProjectUnknown
                : projects[group.key]!.name,
            count: group.value.length,
            color: agentAccentForSeed(group.key, Theme.of(context).brightness),
          ),
        ),
  ];
}

/// Row context under a project label: pods are marked, and a row without
/// an update names its agent and branch rather than the project again.
SessionRuntimeMark _runtimeMark(
  AppLocalizations l10n,
  Session session, {
  String? host,
  bool mixed = false,
}) {
  final metadata = session.metadata;
  final branch = metadata?.gitBranch ?? metadata?.repoRef;
  return SessionRuntimeMark(
    icon: session.isKubernetesSession
        ? Icons.cloud_outlined
        : mixed && host != null
        ? Icons.computer_outlined
        : null,
    label: session.isKubernetesSession
        ? l10n.sessionsProjectRuntimePod
        : l10n.sessionsProjectRuntimeHost(host ?? ''),
    detail: [
      missionHarnessName(l10n, metadata?.flavor),
      if (branch != null && branch.isNotEmpty) branch,
    ].join(' · '),
  );
}

/// Header of a project run inside a board section.
///
/// The tile carries the project's identity hue, the same one Mission
/// Control and the Projects board use, so a project is recognizable by
/// color before its name is read.
class SessionBoardClusterLabel extends StatelessWidget {
  const SessionBoardClusterLabel({required this.cluster, super.key});

  final SessionBoardCluster cluster;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      header: true,
      label: cluster.title,
      value: context.l10n.missionControlSessionCount(cluster.count),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Container(
                width: AppIconSize.tab,
                height: AppIconSize.tab,
                decoration: BoxDecoration(
                  color: workspaceIdentityContainer(context, cluster.color),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Icon(
                  Icons.folder_rounded,
                  size: AppIconSize.sm,
                  color: cluster.color,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  cluster.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title(theme, cs.onSurface),
                ),
              ),
              if (cluster.count > 1) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${cluster.count}',
                  style: AppText.secondary(theme, cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
