import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/wire_parsers.dart';

import '../tool_section_view.dart';
import 'file_diff_view.dart';

/// View for displaying Edit tool diffs.
///
/// Shows the file path prominently, then a unified diff with red/green
/// highlighting for removed/added lines, collapsed by default for
/// large diffs.
class EditView extends StatelessWidget {
  /// Creates an [EditView].
  const EditView({
    required this.tool,
    super.key,
    this.metadata,
    this.sessionId,
  });

  /// The tool call data.
  final Map<String, dynamic> tool;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  /// Session ID for file viewer navigation.
  final String? sessionId;

  ({String oldText, String newText}) _textsFromDiff(String diff) {
    final oldLines = <String>[];
    final newLines = <String>[];
    for (final line in diff.split('\n')) {
      if (line.startsWith('+++') ||
          line.startsWith('---') ||
          line.startsWith('@@') ||
          line.startsWith('diff --git') ||
          line.startsWith('index ')) {
        continue;
      }
      if (line.startsWith('+')) {
        newLines.add(line.substring(1));
      } else if (line.startsWith('-')) {
        oldLines.add(line.substring(1));
      } else if (line.startsWith(' ')) {
        final content = line.substring(1);
        oldLines.add(content);
        newLines.add(content);
      }
    }
    return (oldText: oldLines.join('\n'), newText: newLines.join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    final input = WireParsers.asMap(tool['input']) ?? {};
    final filePath =
        input['filePath'] as String? ??
        input['path'] as String? ??
        input['file_path'] as String? ??
        '';
    final diff = input['diff'] as String? ?? '';
    var oldString =
        input['old_string'] as String? ?? input['oldContent'] as String? ?? '';
    var newString =
        input['new_string'] as String? ?? input['newContent'] as String? ?? '';

    if (oldString.isEmpty && newString.isEmpty && diff.isNotEmpty) {
      final parsed = _textsFromDiff(diff);
      oldString = parsed.oldText;
      newString = parsed.newText;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ToolSectionView(
        title: context.l10n.toolSectionDiff,
        child: FileDiffView(
          oldText: oldString,
          newText: newString,
          filePath: filePath,
          icon: Icons.edit_document,
          collapseThreshold: 16,
          onPathTap: filePath.isNotEmpty && sessionId != null
              ? () => context.pushNamed(
                  'session-file',
                  pathParameters: {'sessionId': sessionId!},
                  extra: {'path': filePath},
                )
              : null,
        ),
      ),
    );
  }
}
