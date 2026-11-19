import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_sheet.dart';
import '../../../core/dialogs/app_dialog.dart';
import '../../../core/dialogs/confirm_dialog.dart';
import '../../../core/folders/session_folders_doc.dart';
import '../../../core/folders/session_folders_tree.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/folder_rule_localization.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/session_folders_notifier.dart';
import '../../../core/providers/sessions_notifier.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/snack.dart';

/// Submits [edit]; a refusal against the shown tree is reported at once.
bool _submit(BuildContext context, WidgetRef ref, FolderEdit edit) {
  final rule = ref.read(sessionFolderOperationsProvider.notifier).edit(edit);
  if (rule == null) return true;
  if (context.mounted) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnack(folderRuleMessage(context.l10n, rule), tone: SnackTone.error);
  }
  return false;
}

/// Creates a folder under [parent] (or at [anchor]'s top level).
Future<void> createFolderFlow(
  BuildContext context,
  WidgetRef ref, {
  String? parent,
  String? anchor,
}) async {
  final l10n = context.l10n;
  final id = newFolderId();
  final name = await showFolderNameDialog(
    context,
    title: parent == null ? l10n.foldersNew : l10n.foldersNewSubfolder,
    confirmLabel: l10n.commonCreate,
    validate: (value) => _probe(
      ref,
      CreateFolder(id: id, name: value, parent: parent, anchor: anchor),
    ),
  );
  if (name == null || !context.mounted) return;
  _submit(
    context,
    ref,
    CreateFolder(id: id, name: name, parent: parent, anchor: anchor),
  );
}

Future<void> renameFolderFlow(
  BuildContext context,
  WidgetRef ref,
  String folderId,
) async {
  final folder = ref.read(sessionFolderDocProvider).folders[folderId];
  if (folder == null) return;
  final l10n = context.l10n;
  final name = await showFolderNameDialog(
    context,
    title: l10n.foldersRename,
    initial: folder.name,
    confirmLabel: l10n.commonSave,
    validate: (value) => _probe(ref, RenameFolder(id: folderId, name: value)),
  );
  if (name == null || !context.mounted) return;
  _submit(context, ref, RenameFolder(id: folderId, name: name));
}

Future<void> moveFolderFlow(
  BuildContext context,
  WidgetRef ref,
  String folderId,
) async {
  final tree = ref.read(sessionFolderTreeProvider);
  final folder = tree.folder(folderId);
  if (folder == null) return;
  final l10n = context.l10n;
  final pick = await showFolderPicker(
    context,
    title: l10n.foldersMovePickerTitle(folder.name),
    targets: tree.moveTargetsFor(folderId),
    current: tree.parentOf(folderId),
    noneLabel: l10n.foldersTopLevel,
  );
  if (pick == null || !context.mounted) return;
  _submit(context, ref, MoveFolder(id: folderId, parent: pick.folderId));
}

Future<void> deleteFolderFlow(
  BuildContext context,
  WidgetRef ref,
  String folderId,
) async {
  final folder = ref.read(sessionFolderDocProvider).folders[folderId];
  if (folder == null) return;
  final l10n = context.l10n;
  final confirmed = await showConfirmDialog(
    context,
    title: l10n.foldersDelete,
    content: l10n.foldersDeleteConfirm(folder.name),
    confirmLabel: l10n.commonDelete,
    isDestructive: true,
  );
  if (!confirmed || !context.mounted) return;
  _submit(context, ref, DeleteFolder(folderId));
}

/// "Move to folder…" for [sessionIds]: only folders anchored at the
/// sessions' parent session are offered (top-level sessions: account
/// level), plus "No folder".
Future<void> moveSessionsToFolderFlow(
  BuildContext context,
  WidgetRef ref,
  Iterable<String> sessionIds,
) async {
  final catalog = ref.read(sessionsNotifierProvider);
  final parents = <String, String?>{
    for (final id in sessionIds)
      if (catalog[id] case final Session session)
        id: session.metadata?.parentSessionId,
  };
  if (parents.isEmpty) return;
  final tree = ref.read(sessionFolderTreeProvider);
  final parentIds = parents.values.toSet();
  final current = {for (final id in parents.keys) tree.folderOfSession(id)};
  final pick = await showFolderPicker(
    context,
    title: context.l10n.foldersPickerTitle,
    // Sessions with different parents share no folder.
    targets: parentIds.length == 1
        ? tree.targetsFor(parentIds.single)
        : const <FolderTarget>[],
    current: current.length == 1 ? current.single : '',
    noneLabel: context.l10n.foldersNoFolder,
  );
  if (pick == null || !context.mounted) return;
  _submit(
    context,
    ref,
    AssignSessions(parents: parents, folderId: pick.folderId),
  );
}

FolderRule? _probe(WidgetRef ref, FolderEdit edit) {
  if (ref.read(sessionFoldersProvider).readOnly) return FolderRule.readOnly;
  try {
    edit.apply(ref.read(sessionFolderDocProvider));
    return null;
  } on FolderRuleException catch (e) {
    return e.rule;
  }
}

/// Asks for a folder name; [validate] reports the rule a value breaks.
Future<String?> showFolderNameDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required FolderRule? Function(String value) validate,
  String initial = '',
}) => showAppDialog<String>(
  context,
  builder: (_) => _FolderNameDialog(
    title: title,
    confirmLabel: confirmLabel,
    validate: validate,
    initial: initial,
  ),
);

class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({
    required this.title,
    required this.confirmLabel,
    required this.validate,
    required this.initial,
  });

  final String title;
  final String confirmLabel;
  final FolderRule? Function(String value) validate;
  final String initial;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  FolderRule? _error;
  bool _touched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final rule = widget.validate(_controller.text);
    if (rule != null) {
      setState(() {
        _touched = true;
        _error = rule;
      });
      return;
    }
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = _error;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: maxSessionFolderNameLength,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: l10n.foldersName,
          errorText: _touched && error != null
              ? folderRuleMessage(l10n, error)
              : null,
        ),
        onChanged: (value) {
          if (!_touched) return;
          setState(() => _error = widget.validate(value));
        },
        onSubmitted: (_) => _confirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _confirm, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// A picker answer; a null [folderId] is [showFolderPicker]'s none option.
typedef FolderPick = ({String? folderId});

/// Lists [targets] by full path plus a none option ([noneLabel]).
/// [current] marks the selected entry (null: none; '' : nothing).
/// Resolves to null when dismissed.
Future<FolderPick?> showFolderPicker(
  BuildContext context, {
  required String title,
  required List<FolderTarget> targets,
  required String noneLabel,
  String? current = '',
}) => showAppSheet<FolderPick>(
  context,
  isScrollControlled: true,
  builder: (sheetContext) {
    final theme = Theme.of(sheetContext);
    final cs = theme.colorScheme;
    Widget tile({
      required String label,
      required String? id,
      required IconData icon,
    }) {
      final selected = current == id;
      return ListTile(
        leading: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
        title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: selected ? Icon(Icons.check, color: cs.primary) : null,
        selected: selected,
        onTap: () => Navigator.pop(sheetContext, (folderId: id)),
      );
    }

    final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.7;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  tile(
                    label: noneLabel,
                    id: null,
                    icon: Icons.folder_off_outlined,
                  ),
                  for (final target in targets)
                    tile(
                      label: target.path,
                      id: target.id,
                      icon: Icons.folder_outlined,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  },
);
