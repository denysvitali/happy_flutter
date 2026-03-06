import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/diff_view_widget.dart'
    as dw show DiffView;
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
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
    final removedLines =
        oldString.isEmpty ? 0 : oldString.split('\n').length;
    final addedLines =
        newString.isEmpty ? 0 : newString.split('\n').length;
    final totalLines = removedLines + addedLines;
    final isShort = totalLines <= 16;
    final show = isShort || _expanded;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── File path pill chip + line count badges ─────
          if (filePath.isNotEmpty) ...[
            Row(
              children: [
                Flexible(child: FilePillChip(path: filePath)),
                const SizedBox(width: AppSpacing.sm),
                if (removedLines > 0)
                  _LineDeltaBadge(
                    count: removedLines,
                    isAddition: false,
                  ),
                if (removedLines > 0 && addedLines > 0)
                  const SizedBox(width: AppSpacing.xs),
                if (addedLines > 0)
                  _LineDeltaBadge(
                    count: addedLines,
                    isAddition: true,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // ── Diff section label ──────────────────────────
          _EditSectionLabel(label: context.l10n.toolSectionDiff),
          const SizedBox(height: AppSpacing.xs),

          // ── Expand/collapse toggle for large diffs ──────
          if (!isShort)
            GestureDetector(
              onTap: () =>
                  setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: AppSpacing.xs,
                  left: 2,
                ),
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
                    const SizedBox(width: AppSpacing.xs),
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
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: show
                ? ClipRRect(
                    clipBehavior: Clip.hardEdge,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: dw.DiffView(
                      oldText: oldString,
                      newText: newString,
                      showLineNumbers: true,
                      showPlusMinusSymbols: true,
                      contextLines: 3,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Small badge showing +N or -N line delta in green or red.
class _LineDeltaBadge extends StatelessWidget {
  const _LineDeltaBadge({
    required this.count,
    required this.isAddition,
  });

  final int count;
  final bool isAddition;

  static const _addGreen = Color(0xFF1A7F37);
  static const _removeRed = Color(0xFFCF222E);

  @override
  Widget build(BuildContext context) {
    final color = isAddition ? _addGreen : _removeRed;
    final label = isAddition ? '+$count' : '-$count';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          fontFamily: 'monospace',
          fontFamilyFallback: const ['Courier New', 'Courier'],
        ),
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
