import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/diff_view_widget.dart'
    as dw show DiffView;
import 'bash_view.dart' show FilePillChip;

/// View for displaying Edit tool diffs.
///
/// Shows the file path prominently, then a unified diff with red/green
/// highlighting for removed/added lines, collapsed by default for
/// large diffs.
class EditView extends StatefulWidget {

  const EditView({required this.tool, super.key, this.metadata});
  /// The tool call data.
  final Map<String, dynamic> tool;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

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
          // ── File path pill chip ─────────────────────────
          if (filePath.isNotEmpty) ...[
            FilePillChip(path: filePath),
            const SizedBox(height: 8),
          ],

          // ── Diff section label ──────────────────────────
          _EditSectionLabel(label: 'DIFF'),
          const SizedBox(height: 4),

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

/// Small all-caps section label for edit view blocks.
class _EditSectionLabel extends StatelessWidget {
  const _EditSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
        letterSpacing: 0.8,
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Courier New', 'Courier'],
      ),
    );
  }
}

/// Backward-compatible DiffView shim used by other tool views.
///
/// Wraps [dw.DiffView] with the legacy parameter names used by
/// earlier views in this package.
class DiffView extends StatelessWidget {

  const DiffView({
    required this.oldText, required this.newText, super.key,
    this.showLineNumbers = true,
    this.showPlusMinus = true,
  });
  /// Old text content.
  final String oldText;

  /// New text content.
  final String newText;

  /// Whether to show line numbers.
  final bool showLineNumbers;

  /// Whether to show +/- prefix symbols.
  final bool showPlusMinus;

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
