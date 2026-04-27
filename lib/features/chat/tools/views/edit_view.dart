import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/components/diff_view_widget.dart'
    as dw
    show DiffView;
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/wire_parsers.dart';
import 'bash_view.dart' show FilePillChip;

/// View for displaying Edit tool diffs.
///
/// Shows the file path prominently, then a unified diff with red/green
/// highlighting for removed/added lines, collapsed by default for
/// large diffs.
class EditView extends StatefulWidget {
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

  @override
  State<EditView> createState() => _EditViewState();
}

class _EditViewState extends State<EditView> {
  bool _expanded = false;

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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final input = WireParsers.asMap(widget.tool['input']) ?? {};
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

    // Estimate line count to decide whether to collapse.
    final removedLines = oldString.isEmpty ? 0 : oldString.split('\n').length;
    final addedLines = newString.isEmpty ? 0 : newString.split('\n').length;
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
                Flexible(
                  child: FilePillChip(
                    path: filePath,
                    onTap: widget.sessionId != null
                        ? () => context.pushNamed(
                            'session-file',
                            pathParameters: {'sessionId': widget.sessionId!},
                            extra: {'path': filePath},
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (removedLines > 0)
                  _LineDeltaBadge(count: removedLines, isAddition: false),
                if (removedLines > 0 && addedLines > 0)
                  const SizedBox(width: AppSpacing.xs),
                if (addedLines > 0)
                  _LineDeltaBadge(count: addedLines, isAddition: true),
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
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs, left: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      _expanded ? 'Hide diff' : 'Show diff ($totalLines lines)',
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
            duration: AppDuration.normal,
            curve: AppCurve.standard,
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
  const _LineDeltaBadge({required this.count, required this.isAddition});

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
        horizontal: AppSpacing.xsm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: AppBorder.hairline,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppFontSize.xxs,
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
    required this.oldText,
    required this.newText,
    super.key,
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
