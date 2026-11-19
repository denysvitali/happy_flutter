part of 'new_session_dialog.dart';

/// Keeps optional launch setup together after the workspace and agent choices.
class _NewSessionAdvancedOptions extends StatelessWidget {
  const _NewSessionAdvancedOptions({
    required this.sessionType,
    required this.onSessionTypeChanged,
  });

  final String sessionType;
  final ValueChanged<String> onSessionTypeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ExpansionTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      key: const PageStorageKey('new-session-advanced'),
      tilePadding: kNewSessionTilePadding,
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      shape: const Border(),
      collapsedShape: const Border(),
      leading: const Icon(Icons.tune_rounded),
      title: Text(l10n.newSessionAdvanced),
      subtitle: Text(
        sessionType == 'worktree'
            ? l10n.sessionsWorktree
            : l10n.newSessionLocalSummary,
        style: AppText.secondary(theme),
      ),
      children: [
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
      ],
    );
  }
}

/// Optional account-level user folder for the new session. Hidden while
/// there are no folders (or they cannot be edited).
class _NewSessionFolderField extends ConsumerWidget {
  const _NewSessionFolderField({
    required this.folderId,
    required this.enabled,
    required this.onChanged,
  });

  final String? folderId;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tree = ref.watch(sessionFolderTreeProvider);
    final readOnly = ref.watch(
      sessionFoldersProvider.select((s) => s.readOnly),
    );
    final targets = tree.targetsFor(null);
    if (targets.isEmpty || readOnly) return const SizedBox.shrink();
    final current = folderId;
    final label = current != null && tree.isVisible(current)
        ? tree.path(current)
        : l10n.foldersNoFolder;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: NewSessionGroup(
        children: [
          ListTile(
            key: const Key('new-session-folder'),
            dense: true,
            contentPadding: kNewSessionTilePadding,
            leading: const Icon(Icons.folder_outlined),
            title: Text(l10n.foldersField),
            subtitle: Text(label, style: AppText.secondary(theme)),
            trailing: const Icon(Icons.chevron_right),
            enabled: enabled,
            onTap: () async {
              final pick = await showFolderPicker(
                context,
                title: l10n.foldersField,
                targets: targets,
                current: current,
                noneLabel: l10n.foldersNoFolder,
              );
              if (pick != null) onChanged(pick.folderId);
            },
          ),
        ],
      ),
    );
  }
}
