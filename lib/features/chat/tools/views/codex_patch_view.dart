import 'package:flutter/material.dart';
import '../tool_section_view.dart';
import 'package:happy_flutter/core/utils/path_utils.dart';

/// File change model for CodexPatch results.
class FileChange {
  final String path;
  final bool hasAdd;
  final bool hasModify;
  final bool hasDelete;

  FileChange({
    required this.path,
    required this.hasAdd,
    required this.hasModify,
    required this.hasDelete,
  });

  String get displayName => path.split('/').lastOrNull ?? path;
}

/// View for displaying CodexPatch tool with file changes summary.
class CodexPatchView extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  const CodexPatchView({super.key, required this.tool, this.metadata});

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final changes = input['changes'] as Map<String, dynamic>?;
    final autoApproved = input['auto_approved'] as bool?;

    if (changes == null || changes.isEmpty) {
      return const SizedBox.shrink();
    }

    final parsedChanges = _parseChanges(changes);

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with auto-approve info
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.edit_note,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${parsedChanges.length} file${parsedChanges.length != 1 ? 's' : ''} to modify',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (autoApproved == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Auto-approved',
                      style: TextStyle(
                        fontSize: 11,
                        color: const Color(0xFF34C759),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // File changes list
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: parsedChanges.map((change) {
                return _buildChangeItem(context, change);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<FileChange> _parseChanges(Map<String, dynamic> changes) {
    final result = <FileChange>[];

    for (final entry in changes.entries) {
      final path = entry.key;
      final changeData = entry.value as Map<String, dynamic>;

      final add = changeData['add'] as Map<String, dynamic>?;
      final modify = changeData['modify'] as Map<String, dynamic>?;
      final delete = changeData['delete'] as Map<String, dynamic>?;

      result.add(FileChange(
        path: path,
        hasAdd: add != null,
        hasModify: modify != null,
        hasDelete: delete != null,
      ));
    }

    return result;
  }

  Widget _buildChangeItem(BuildContext context, FileChange change) {
    final theme = Theme.of(context);

    // Determine icon and color based on change type
    IconData icon;
    Color iconColor;

    if (change.hasAdd && !change.hasModify) {
      icon = Icons.add_circle;
      iconColor = const Color(0xFF1A7F37);
    } else if (change.hasDelete && !change.hasModify) {
      icon = Icons.delete_forever;
      iconColor = const Color(0xFFCF2222);
    } else {
      icon = Icons.edit;
      iconColor = theme.colorScheme.primary;
    }

    // Determine operation text
    final operations = <String>[];
    if (change.hasAdd) operations.add('add');
    if (change.hasModify) operations.add('modify');
    if (change.hasDelete) operations.add('delete');

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(
                    change.displayName,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    operations.join(', '),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
