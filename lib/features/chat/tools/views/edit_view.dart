import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/diff_view_widget.dart'
    as dw show DiffView;

/// View for displaying Edit tool diffs.
///
/// Shows the file path prominently, then a unified diff with red/green
/// highlighting for removed/added lines, collapsed by default for
/// large diffs.
class EditView extends StatefulWidget {
  /// The tool call data.
  final Map<String, dynamic> tool;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  const EditView({super.key, required this.tool, this.metadata});

  @override
  State<EditView> createState() => _EditViewState();
}

class _EditViewState extends State<EditView> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final input =
        widget.tool['input'] as Map<String, dynamic>? ?? {};
    final filePath = input['path'] as String? ??
        input['file_path'] as String? ??
        '';
    final oldString = input['old_string'] as String? ?? '';
    final newString = input['new_string'] as String? ?? '';

    // Estimate line count to decide whether to collapse.
    final oldLines =
        oldString.isEmpty ? 0 : oldString.split('\n').length;
    final newLines =
        newString.isEmpty ? 0 : newString.split('\n').length;
    final totalLines = oldLines + newLines;
    final isShort = totalLines <= 16;
    final show = isShort || _expanded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── File path header ────────────────────────────
          if (filePath.isNotEmpty)
            _FilePathHeader(filePath: filePath),
          const SizedBox(height: 6),

          // ── Expand/collapse toggle for large diffs ──────
          if (!isShort)
            GestureDetector(
              onTap: () =>
                  setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _expanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _expanded
                          ? 'Hide diff'
                          : 'Show diff ($totalLines lines)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Diff ────────────────────────────────────────
          if (show)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: dw.DiffView(
                oldText: oldString,
                newText: newString,
                showLineNumbers: true,
                showPlusMinusSymbols: true,
                contextLines: 3,
              ),
            ),
        ],
      ),
    );
  }
}

/// Displays a file path as a prominent pill-style label with a file icon.
class _FilePathHeader extends StatelessWidget {
  final String filePath;

  const _FilePathHeader({required this.filePath});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Split into directory prefix and filename for styling.
    final lastSlash = filePath.lastIndexOf('/');
    final dir =
        lastSlash >= 0 ? filePath.substring(0, lastSlash + 1) : '';
    final filename = lastSlash >= 0
        ? filePath.substring(lastSlash + 1)
        : filePath;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outlineVariant, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.edit_document,
            size: 14,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  if (dir.isNotEmpty)
                    TextSpan(
                      text: dir,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  TextSpan(
                    text: filename,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface,
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Backward-compatible DiffView shim used by other tool views.
///
/// Wraps [dw.DiffView] with the legacy parameter names used by
/// earlier views in this package.
class DiffView extends StatelessWidget {
  /// Old text content.
  final String oldText;

  /// New text content.
  final String newText;

  /// Whether to show line numbers.
  final bool showLineNumbers;

  /// Whether to show +/- prefix symbols.
  final bool showPlusMinus;

  const DiffView({
    super.key,
    required this.oldText,
    required this.newText,
    this.showLineNumbers = true,
    this.showPlusMinus = true,
  });

  @override
  Widget build(BuildContext context) {
    return dw.DiffView(
      oldText: oldText,
      newText: newText,
      showLineNumbers: showLineNumbers,
      showPlusMinusSymbols: showPlusMinus,
      contextLines: 3,
    );
  }
}
