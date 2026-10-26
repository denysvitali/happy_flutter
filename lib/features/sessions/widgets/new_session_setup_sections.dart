part of 'new_session_dialog.dart';

/// Keeps optional launch setup together after the workspace and agent choices.
class _NewSessionAdvancedOptions extends StatelessWidget {
  const _NewSessionAdvancedOptions({
    required this.isKubernetes,
    required this.sessionType,
    required this.spawnBackends,
    required this.selectedSpawnBackend,
    required this.onSessionTypeChanged,
    required this.onSpawnBackendSelected,
  });

  final bool isKubernetes;
  final String sessionType;
  final List<String> spawnBackends;
  final String selectedSpawnBackend;
  final ValueChanged<String> onSessionTypeChanged;
  final ValueChanged<String> onSpawnBackendSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ExpansionTile(
      key: const PageStorageKey('new-session-advanced'),
      dense: true,
      tilePadding: EdgeInsets.zero,
      title: Text(l10n.newSessionAdvanced),
      subtitle: Text(
        isKubernetes
            ? l10n.newSessionKubernetesSummary
            : sessionType == 'worktree'
            ? l10n.sessionsWorktree
            : l10n.newSessionLocalSummary,
      ),
      children: [
        if (!isKubernetes) ...[
          Text(l10n.newSessionWorktreeHint, style: AppText.secondary(theme)),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) => SegmentedButton<String>(
              direction:
                  constraints.maxWidth < 360 ||
                      MediaQuery.textScalerOf(context).scale(AppFontSize.base) >
                          AppFontSize.lg
                  ? Axis.vertical
                  : Axis.horizontal,
              segments: [
                ButtonSegment(
                  value: 'simple',
                  label: Text(l10n.sessionsSimple),
                  icon: const Icon(Icons.folder_outlined),
                ),
                ButtonSegment(
                  value: 'worktree',
                  label: Text(l10n.sessionsWorktree),
                  icon: const Icon(Icons.account_tree_outlined),
                ),
              ],
              selected: {sessionType},
              onSelectionChanged: (selection) =>
                  onSessionTypeChanged(selection.first),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (spawnBackends.length > 1) ...[
          _SpawnBackendPicker(
            backends: spawnBackends,
            selectedBackend: selectedSpawnBackend,
            onSelected: onSpawnBackendSelected,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}
