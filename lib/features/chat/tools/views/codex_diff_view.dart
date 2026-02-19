import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tool_section_view.dart';
import 'package:happy_flutter/core/ui/diff/diff_view.dart';
import 'package:happy_flutter/core/ui/diff/diff_types.dart';

/// View for displaying CodexDiff tool with proper unified diff rendering.
class CodexDiffView extends StatelessWidget {
  /// The tool data map containing input and result.
  final Map<String, dynamic> tool;

  /// Optional metadata for path resolution.
  final Map<String, dynamic>? metadata;

  const CodexDiffView({
    super.key,
    required this.tool,
    this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final unifiedDiff = input['unified_diff'] as String?;

    if (unifiedDiff == null || unifiedDiff.isEmpty) {
      return const SizedBox.shrink();
    }

    final parsed = _parseUnifiedDiff(unifiedDiff);

    return ToolSectionView(
      child: _DiffContainer(parsed: parsed),
    );
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
        } else if (line == '\\ No newline at end of file') {
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
  final String oldText;
  final String newText;
  final String? fileName;
  final String rawDiff;

  const _ParsedDiff({
    required this.oldText,
    required this.newText,
    required this.rawDiff,
    this.fileName,
  });
}

// ---------------------------------------------------------------------------
// Container widget (stateful for expand/collapse)
// ---------------------------------------------------------------------------

class _DiffContainer extends StatefulWidget {
  final _ParsedDiff parsed;

  const _DiffContainer({required this.parsed});

  @override
  State<_DiffContainer> createState() => _DiffContainerState();
}

class _DiffContainerState extends State<_DiffContainer> {
  static const int _collapsedThreshold = 60;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
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
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header bar ─────────────────────────────────────
          _DiffHeaderBar(
            dir: dir,
            filename: filename,
            rawDiff: p.rawDiff,
            oldCount: oldLines,
            newCount: newLines,
          ),

          // ── Expand/collapse toggle ──────────────────────────
          if (!isShort)
            _ExpandToggle(
              expanded: _expanded,
              totalLines: totalLines,
              onToggle: () =>
                  setState(() => _expanded = !_expanded),
            ),

          // ── Diff content ────────────────────────────────────
          if (show)
            _DiffBody(
              oldText: p.oldText,
              newText: p.newText,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header bar
// ---------------------------------------------------------------------------

class _DiffHeaderBar extends StatelessWidget {
  final String? dir;
  final String? filename;
  final String rawDiff;
  final int oldCount;
  final int newCount;

  const _DiffHeaderBar({
    this.dir,
    this.filename,
    required this.rawDiff,
    required this.oldCount,
    required this.newCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            Icons.difference_outlined,
            size: 14,
            color: Color(0xFF8B949E),
          ),
          const SizedBox(width: 6),
          if (filename != null) ...[
            if (dir != null)
              Text(
                dir!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFF8B949E),
                ),
              ),
            Text(
              filename!,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFFE6EDF3),
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else
            Text(
              'diff',
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF8B949E),
                fontFamily: 'monospace',
              ),
            ),
          const Spacer(),
          // Stats badges
          _StatBadge(
            label: '-$oldCount',
            color: const Color(0xFFF85149),
          ),
          const SizedBox(width: 6),
          _StatBadge(
            label: '+$newCount',
            color: const Color(0xFF3FB950),
          ),
          const SizedBox(width: 8),
          _CopyButton(text: rawDiff, iconSize: 14),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
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
// Diff body: line-by-line rendering with proper highlights
// ---------------------------------------------------------------------------

class _DiffBody extends StatelessWidget {
  final String oldText;
  final String newText;

  const _DiffBody({
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

// ---------------------------------------------------------------------------
// Copy button
// ---------------------------------------------------------------------------

class _CopyButton extends StatefulWidget {
  final String text;
  final double iconSize;

  const _CopyButton({required this.text, this.iconSize = 14});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _handleCopy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleCopy,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          _copied ? Icons.check : Icons.copy,
          key: ValueKey(_copied),
          size: widget.iconSize,
          color: _copied
              ? const Color(0xFF3FB950)
              : const Color(0xFF8B949E),
        ),
      ),
    );
  }
}
