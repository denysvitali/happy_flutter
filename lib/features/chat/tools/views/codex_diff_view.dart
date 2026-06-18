import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/tool_view_buttons.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/theme/diff_theme.dart';
import 'package:happy_flutter/core/ui/diff/diff_types.dart';
import 'package:happy_flutter/core/ui/diff/diff_view.dart';
import 'package:happy_flutter/core/utils/wire_parsers.dart';

import '../tool_section_view.dart';
import '../tool_view_colors.dart';

/// View for displaying CodexDiff tool with proper unified diff rendering.
class CodexDiffView extends StatelessWidget {
  const CodexDiffView({required this.tool, super.key, this.metadata});

  /// The tool data map containing input and result.
  final Map<String, dynamic> tool;

  /// Optional metadata for path resolution.
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final input = WireParsers.asMap(tool['input']) ?? {};
    final unifiedDiff = input['unified_diff'] as String?;

    if (unifiedDiff == null || unifiedDiff.isEmpty) {
      return const SizedBox.shrink();
    }

    final parsed = _parseUnifiedDiff(unifiedDiff);

    return ToolSectionView(child: _DiffContainer(parsed: parsed));
  }

  _ParsedDiff _parseUnifiedDiff(String unifiedDiff) {
    final lines = unifiedDiff.split('\n');
    final oldLines = <String>[];
    final newLines = <String>[];
    String? fileName;
    var inHunk = false;

    for (final line in lines) {
      if (line.startsWith('+++ b/') || line.startsWith('+++ ')) {
        fileName = line.replaceFirst(RegExp(r'^\+\+\+ (b/)?'), '');
        continue;
      }
      if (line.startsWith('diff --git') ||
          line.startsWith('index ') ||
          line.startsWith('---') ||
          line.startsWith('new file mode') ||
          line.startsWith('deleted file mode')) {
        continue;
      }
      if (line.startsWith('@@')) {
        inHunk = true;
        continue;
      }
      if (inHunk) {
        if (line.startsWith('+')) {
          newLines.add(line.substring(1));
        } else if (line.startsWith('-')) {
          oldLines.add(line.substring(1));
        } else if (line.startsWith(' ')) {
          final content = line.substring(1);
          oldLines.add(content);
          newLines.add(content);
        } else if (line == r'\ No newline at end of file') {
          continue;
        } else if (line.isEmpty) {
          oldLines.add('');
          newLines.add('');
        }
      }
    }

    return _ParsedDiff(
      oldText: oldLines.join('\n'),
      newText: newLines.join('\n'),
      fileName: fileName,
      rawDiff: unifiedDiff,
    );
  }
}

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class _ParsedDiff {
  const _ParsedDiff({
    required this.oldText,
    required this.newText,
    required this.rawDiff,
    this.fileName,
  });
  final String oldText;
  final String newText;
  final String? fileName;
  final String rawDiff;
}

// ---------------------------------------------------------------------------
// Container widget (stateful for expand/collapse)
// ---------------------------------------------------------------------------

class _DiffContainer extends StatefulWidget {
  const _DiffContainer({required this.parsed});
  final _ParsedDiff parsed;

  @override
  State<_DiffContainer> createState() => _DiffContainerState();
}

class _DiffContainerState extends State<_DiffContainer> {
  static const int _collapsedThreshold = 60;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = ToolViewColors.of(context);
    final p = widget.parsed;

    final oldLines = p.oldText.isEmpty ? 0 : p.oldText.split('\n').length;
    final newLines = p.newText.isEmpty ? 0 : p.newText.split('\n').length;
    final totalLines = oldLines + newLines;
    final isShort = totalLines <= _collapsedThreshold;
    final show = isShort || _expanded;

    // Split filename into dir + file for styling.
    String? dir;
    String? filename;
    if (p.fileName != null) {
      final lastSlash = p.fileName!.lastIndexOf('/');
      if (lastSlash >= 0) {
        dir = p.fileName!.substring(0, lastSlash + 1);
        filename = p.fileName!.substring(lastSlash + 1);
      } else {
        filename = p.fileName;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // -- Header bar
          _DiffHeaderBar(
            dir: dir,
            filename: filename,
            rawDiff: p.rawDiff,
            oldCount: oldLines,
            newCount: newLines,
          ),

          // -- Expand/collapse toggle
          if (!isShort)
            _ExpandToggle(
              expanded: _expanded,
              totalLines: totalLines,
              onToggle: () => setState(() => _expanded = !_expanded),
            ),

          // -- Diff content
          if (show) _DiffBody(oldText: p.oldText, newText: p.newText),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header bar
// ---------------------------------------------------------------------------

class _DiffHeaderBar extends StatelessWidget {
  const _DiffHeaderBar({
    required this.rawDiff,
    required this.oldCount,
    required this.newCount,
    this.dir,
    this.filename,
  });
  final String? dir;
  final String? filename;
  final String rawDiff;
  final int oldCount;
  final int newCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = ToolViewColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.headerBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.sm),
          topRight: Radius.circular(AppRadius.sm),
        ),
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.difference_outlined, size: 14, color: c.mutedText),
          const SizedBox(width: 6),
          if (filename != null) ...[
            if (dir != null)
              Text(
                dir!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: AppFontSize.sm,
                  color: c.mutedText,
                ),
              ),
            Text(
              filename!,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: AppFontSize.sm,
                color: c.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else
            Text(
              'diff',
              style: theme.textTheme.labelSmall?.copyWith(
                color: c.mutedText,
                fontFamily: 'monospace',
              ),
            ),
          const Spacer(),
          // Stats badges
          _StatBadge(label: '-$oldCount', color: c.red),
          const SizedBox(width: 6),
          _StatBadge(label: '+$newCount', color: c.green),
          const SizedBox(width: 8),
          ToolViewCopyButton(text: rawDiff, iconSize: 14),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: AppFontSize.sm,
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expand toggle
// ---------------------------------------------------------------------------

class _ExpandToggle extends StatelessWidget {
  const _ExpandToggle({
    required this.expanded,
    required this.totalLines,
    required this.onToggle,
  });
  final bool expanded;
  final int totalLines;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = ToolViewColors.of(context);

    return InkWell(
      onTap: onToggle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.border)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 14,
              color: c.blue,
            ),
            const SizedBox(width: 4),
            Text(
              expanded ? 'Hide diff' : 'Show diff ($totalLines lines)',
              style: TextStyle(
                fontSize: AppFontSize.sm,
                color: c.blue,
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
// Diff body: line-by-line rendering with proper highlights
// ---------------------------------------------------------------------------

class _DiffBody extends StatelessWidget {
  const _DiffBody({required this.oldText, required this.newText});
  final String oldText;
  final String newText;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      clipBehavior: Clip.hardEdge,
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(AppRadius.sm),
        bottomRight: Radius.circular(AppRadius.sm),
      ),
      child: DiffView(
        oldText: oldText,
        newText: newText,
        config: DiffViewConfig(
          showLineNumbers: true,
          showPlusMinusSymbols: true,
          showDiffStats: false,
          contextLines: 3,
          theme: context.diffTheme.asLegacy(),
        ),
      ),
    );
  }
}

