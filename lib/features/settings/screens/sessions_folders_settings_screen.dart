import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/settings_section.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_tokens.dart';

/// Settings screen for managing session folders.
class SessionsFoldersSettingsScreen extends ConsumerStatefulWidget {
  const SessionsFoldersSettingsScreen({super.key});

  @override
  ConsumerState<SessionsFoldersSettingsScreen> createState() =>
      _SessionsFoldersSettingsScreenState();
}

class _SessionsFoldersSettingsScreenState
    extends ConsumerState<SessionsFoldersSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(settingsNotifierProvider.notifier);
    final folders = ref.watch(
      settingsNotifierProvider.select((s) => s.folders),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sessionsFolders),
      ),
      body: ListView(
        padding: AppScreenPadding.settings,
        children: [
          SettingsSection(
            title: l10n.sessionsFolders,
            children: [
              if (folders.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    l10n.sessionsFoldersEmpty,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ...folders.map((folder) => _FolderTile(
                      folder: folder,
                      onRename: (newName) {
                        _renameFolder(notifier, folders, folder, newName);
                      },
                      onDelete: () {
                        _deleteFolder(notifier, folders, folder);
                      },
                    )),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: OutlinedButton.icon(
              onPressed: () => _addFolder(notifier, folders),
              icon: const Icon(Icons.add),
              label: Text(l10n.sessionsFoldersAdd),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addFolder(
    dynamic notifier,
    List<String> folders,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.sessionsFoldersAdd),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.sessionsFoldersName,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(l10n.commonAdd),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      await notifier.updateSetting('folders', [...folders, result]);
    }
  }

  Future<void> _renameFolder(
    dynamic notifier,
    List<String> folders,
    String oldFolder,
    String newName,
  ) async {
    if (newName.isEmpty || newName == oldFolder) return;
    final newFolders = folders.map((f) => f == oldFolder ? newName : f).toList();
    await notifier.updateSetting('folders', newFolders);
  }

  Future<void> _deleteFolder(
    dynamic notifier,
    List<String> folders,
    String folder,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.commonDelete),
          content: Text(l10n.sessionsFoldersDeleteConfirm(folder)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );

    if (confirmed ?? false) {
      await notifier.updateSetting(
        'folders',
        folders.where((f) => f != folder).toList(),
      );
    }
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.folder,
    required this.onRename,
    required this.onDelete,
  });

  final String folder;
  final void Function(String) onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(folder),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showRenameDialog(context),
            tooltip: 'Rename',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context) async {
    final controller = TextEditingController(text: folder);
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.sessionsFoldersRename),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.sessionsFoldersName,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(l10n.commonSave),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && result != folder) {
      onRename(result);
    }
  }
}
