import 'package:flutter/material.dart';
import '../tool_section_view.dart';
import 'package:happy_flutter/core/utils/path_utils.dart';
import 'package:happy_flutter/core/ui/diff/diff_view.dart';
import 'package:happy_flutter/core/ui/diff/diff_types.dart';

/// View for displaying Gemini edit tool (lowercase 'edit').
class GeminiEditView extends StatefulWidget {
  /// The tool data map containing input and result.
  final Map<String, dynamic> tool;

  /// Optional metadata for path resolution.
  final Map<String, dynamic>? metadata;

  const GeminiEditView({
    super.key,
    required this.tool,
    this.metadata,
  });

  @override
  State<GeminiEditView> createState() => _GeminiEditViewState();
}

class _GeminiEditViewState extends State<GeminiEditView> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final input = widget.tool['input'] as Map<String, dynamic>? ?? {};

    String? filePath;
    String? oldText;
    String? newText;

    // Check toolCall.content[0].path
    if (input['toolCall'] is Map<String, dynamic>) {
      final toolCall = input['toolCall'] as Map<String, dynamic>;
      final content = toolCall['content'];
      if (content is List && content.isNotEmpty) {
        final first = content[0] as Map<String, dynamic>?;
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
        final first = inputList[0] as Map<String, dynamic>?;
        filePath = first?['path'] as String?;
      }
    }

    // Check direct fields
    filePath ??= input['path'] as String?;
    oldText ??= input['oldText'] as String?;
    newText ??= input['newText'] as String?;

    final resolvedPath = filePath != null
        ? resolvePath(filePath, widget.metadata)
        : 'Unknown';

    final trimmedOld = _trimIndent(oldText ?? '');
    final trimmedNew = _trimIndent(newText ?? '');
    final hasContent = trimmedOld.isNotEmpty || trimmedNew.isNotEmpty;

    final oldLines =
        trimmedOld.isEmpty ? 0 : trimmedOld.split('\n').length;
    final newLines =
        trimmedNew.isEmpty ? 0 : trimmedNew.split('\n').length;
    final totalLines = oldLines + newLines;
    final isShort = totalLines <= 16;
    final showDiff = !hasContent || isShort || _expanded;

    return ToolSectionView(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header bar ───────────────────────────────────
            _EditHeaderBar(
              resolvedPath: resolvedPath,
              hasContent: hasContent,
              oldLines: oldLines,
              newLines: newLines,
            ),

            // ── Expand / collapse ────────────────────────────
            if (hasContent && !isShort)
              _ExpandToggle(
                expanded: _expanded,
                totalLines: totalLines,
                onToggle: () =>
                    setState(() => _expanded = !_expanded),
              ),

            // ── Diff content ─────────────────────────────────
            if (hasContent && showDiff)
              _EditDiffBody(
                oldText: trimmedOld,
                newText: trimmedNew,
              ),
          ],
        ),
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

// ---------------------------------------------------------------------------
// Header bar
// ---------------------------------------------------------------------------

class _EditHeaderBar extends StatelessWidget {
  final String resolvedPath;
  final bool hasContent;
  final int oldLines;
  final int newLines;

  const _EditHeaderBar({
    required this.resolvedPath,
    required this.hasContent,
    required this.oldLines,
    required this.newLines,
  });

  @override
  Widget build(BuildContext context) {
    final lastSlash = resolvedPath.lastIndexOf('/');
    final dir = lastSlash >= 0
        ? resolvedPath.substring(0, lastSlash + 1)
        : '';
    final filename = lastSlash >= 0
        ? resolvedPath.substring(lastSlash + 1)
        : resolvedPath;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.edit_document,
            size: 14,
            color: Color(0xFF58A6FF),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  if (dir.isNotEmpty)
                    TextSpan(
                      text: dir,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFF8B949E),
                      ),
                    ),
                  TextSpan(
                    text: filename,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFFE6EDF3),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasContent) ...[
            const SizedBox(width: 8),
            Text(
              '-$oldLines',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFFF85149),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '+$newLines',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF3FB950),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expand toggle
// ---------------------------------------------------------------------------

class _ExpandToggle extends StatelessWidget {
  final bool expanded;
  final int totalLines;
  final VoidCallback onToggle;

  const _ExpandToggle({
    required this.expanded,
    required this.totalLines,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 7,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFF30363D)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 14,
              color: const Color(0xFF58A6FF),
            ),
            const SizedBox(width: 4),
            Text(
              expanded
                  ? 'Hide diff'
                  : 'Show diff ($totalLines lines)',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF58A6FF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Diff body
// ---------------------------------------------------------------------------

class _EditDiffBody extends StatelessWidget {
  final String oldText;
  final String newText;

  const _EditDiffBody({
    required this.oldText,
    required this.newText,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(8),
        bottomRight: Radius.circular(8),
      ),
      child: DiffView(
        oldText: oldText,
        newText: newText,
        config: const DiffViewConfig(
          showLineNumbers: true,
          showPlusMinusSymbols: true,
          showDiffStats: false,
          contextLines: 3,
          theme: DiffTheme(
            addedBg: Color(0xFF0D2818),
            addedText: Color(0xFF3FB950),
            removedBg: Color(0xFF2D1117),
            removedText: Color(0xFFF85149),
            contextBg: Colors.transparent,
            contextText: Color(0xFFE6EDF3),
            lineNumberBg: Color(0xFF161B22),
            lineNumberText: Color(0xFF484F58),
            hunkHeaderBg: Color(0xFF1C2128),
            hunkHeaderText: Color(0xFF8B949E),
            inlineAddedBg: Color(0xFF1A4328),
            inlineAddedText: Color(0xFF3FB950),
            inlineRemovedBg: Color(0xFF5A1E1E),
            inlineRemovedText: Color(0xFFF85149),
            leadingSpaceDot: Color(0xFF484F58),
          ),
        ),
      ),
    );
  }
}
