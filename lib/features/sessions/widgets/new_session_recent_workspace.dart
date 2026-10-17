part of 'new_session_dialog.dart';

class _RecentWorkspacePicker extends ConsumerWidget {
  const _RecentWorkspacePicker({
    required this.machineId,
    required this.selectedPath,
    required this.onSelected,
  });

  final String? machineId;
  final String? selectedPath;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions =
        ref
            .watch(sessionsNotifierProvider)
            .values
            .where(
              (session) =>
                  machineId != null &&
                  session.metadata?.machineId == machineId &&
                  session.metadata?.runtimeKind != 'kubernetes' &&
                  (session.metadata?.path?.trim().isNotEmpty ?? false),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final paths = sessions
        .map((session) => session.metadata!.path!)
        .toSet()
        .where((path) => path != selectedPath)
        .take(3)
        .toList();
    if (paths.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        context.l10n.newSessionRecentWorkspace,
        style: AppText.secondary(Theme.of(context)),
      ),
      children: [
        for (final path in paths)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.folder_outlined),
            title: Text(path, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => onSelected(path),
          ),
      ],
    );
  }
}
