import 'package:flutter/material.dart';
import 'package:happy_flutter/core/utils/path_utils.dart';
import 'package:happy_flutter/core/utils/wire_parsers.dart';

import '../tool_section_view.dart';
import 'file_diff_view.dart';

/// View for displaying Gemini edit tool (lowercase 'edit').
class GeminiEditView extends StatelessWidget {
  /// Creates a [GeminiEditView].
  const GeminiEditView({
    required this.tool,
    super.key,
    this.metadata,
  });

  /// The tool data map containing input and result.
  final Map<String, dynamic> tool;

  /// Optional metadata for path resolution.
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final input = WireParsers.asMap(tool['input']) ?? {};

    String? filePath;
    String? oldText;
    String? newText;

    // Check toolCall.content[0].path
    if (input['toolCall'] is Map<String, dynamic>) {
      final toolCall = input['toolCall'] as Map<String, dynamic>;
      final content = toolCall['content'];
      if (content is List && content.isNotEmpty) {
        final first = WireParsers.asMap(content[0]);
        filePath = first?['path'] as String?;
      }
      // Check toolCall.title
      final title = toolCall['title'] as String?;
      if (title != null && filePath == null) {
        if (title.startsWith('Writing to ')) {
          filePath = title.replaceFirst('Writing to ', '');
        }
      }
      oldText = toolCall['oldText'] as String? ??
          toolCall['old_string'] as String?;
      newText = toolCall['newText'] as String? ??
          toolCall['new_string'] as String?;
    }

    // Check input[0].path (array format)
    if (filePath == null) {
      final inputList = input['input'];
      if (inputList is List && inputList.isNotEmpty) {
        final first = WireParsers.asMap(inputList[0]);
        filePath = first?['path'] as String?;
      }
    }

    // Check direct fields
    filePath ??= input['path'] as String?;
    oldText ??= input['oldText'] as String?;
    newText ??= input['newText'] as String?;

    final resolvedPath = filePath != null
        ? resolvePath(filePath, metadata)
        : 'Unknown';

    final trimmedOld = _trimIndent(oldText ?? '');
    final trimmedNew = _trimIndent(newText ?? '');

    if (trimmedOld.isEmpty && trimmedNew.isEmpty) {
      return const SizedBox.shrink();
    }

    return ToolSectionView(
      child: FileDiffView(
        oldText: trimmedOld,
        newText: trimmedNew,
        filePath: resolvedPath,
        icon: Icons.edit_document,
        collapseThreshold: 16,
      ),
    );
  }

  String _trimIndent(String text) {
    if (text.isEmpty) return '';
    final lines = text.split('\n');
    if (lines.length == 1) return text.trim();
    final minIndent = lines
        .where((l) => l.trim().isNotEmpty)
        .map((l) => l.length - l.trimLeft().length)
        .reduce((a, b) => a < b ? a : b);
    return lines.map((l) {
      if (l.trim().isEmpty) return l;
      return l.length > minIndent ? l.substring(minIndent) : l;
    }).join('\n');
  }
}
