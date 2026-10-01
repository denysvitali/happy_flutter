import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/app_inline_row.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/tool_input_extractor.dart';
import '../../../core/utils/tool_result_parser.dart';
import '../../../core/wire/wire_parsers.dart';
import '../tool_work_summary.dart';
import 'message_detail_sheet.dart';

/// A quiet, on-demand review of the last turn, using existing tool details
/// for diffs and command output instead of duplicating those renderers.
class TurnReviewBar extends StatelessWidget {
  const TurnReviewBar({
    required this.turn,
    required this.onOpenTool,
    super.key,
  });
  final ChatTurnWork turn;
  final ValueChanged<Map<String, dynamic>> onOpenTool;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final failed = turn.summary.failed > 0;
    final detail = turn.summary.describe(l10n);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: AppInlineRow(
        dense: true,
        primaryActionKey: const ValueKey('turn-review-bar'),
        onTap: () => _openReview(context),
        leading: Icon(
          failed ? Icons.error_outline : Icons.task_alt,
          color: failed ? cs.error : cs.primary,
        ),
        trailing: const Icon(Icons.chevron_right),
        child: Row(
          children: [
            Flexible(
              child: Text(
                l10n.chatReviewTurn,
                style: AppInlineText.chromeStrong(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: Text(
                detail,
                style: AppInlineText.chrome(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openReview(BuildContext context) {
    final l10n = context.l10n;
    final summary = turn.summary;
    final answer = turn.answer?['content'] as String?;
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.75,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.chatReviewTurn,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: l10n.commonClose,
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (answer != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.chatReviewAnswer),
                subtitle: Text(
                  answer.characters.take(320).toString(),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.open_in_full),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showRawMarkdownSheet(context, answer);
                },
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(l10n.chatReviewNoAnswer),
              ),
            if (summary.changedFiles.isNotEmpty) ...[
              _heading(context, l10n.chatReviewFiles),
              for (final entry in summary.changedFiles.entries)
                _toolTile(
                  sheetContext,
                  entry.value,
                  entry.key,
                  Icons.difference_outlined,
                ),
            ],
            if (summary.failures.isNotEmpty) ...[
              _heading(context, l10n.chatReviewFailures),
              for (final tool in summary.failures)
                _toolTile(
                  sheetContext,
                  tool,
                  _toolLabel(tool),
                  Icons.error_outline,
                  color: cs.error,
                ),
            ],
            if (summary.commandTools.isNotEmpty) ...[
              _heading(context, l10n.chatReviewCommands),
              Text(
                l10n.chatReviewCommandsHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              for (final tool in summary.commandTools)
                _toolTile(sheetContext, tool, _toolLabel(tool), Icons.terminal),
            ],
          ],
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
    child: Text(label, style: Theme.of(context).textTheme.titleSmall),
  );

  String _toolLabel(Map<String, dynamic> tool) {
    final input = WireParsers.asMap(tool['input']);
    final command = input == null ? null : extractCommand(input);
    return command ?? tool['name']?.toString() ?? '';
  }

  Widget _toolTile(
    BuildContext context,
    Map<String, dynamic> tool,
    String label,
    IconData icon, {
    Color? color,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: color),
    title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
    subtitle: Text(switch (ToolWorkSummary.isCommand(
              ToolWorkSummary.family(tool),
            ) &&
            (parseExitCode(tool['result']) ?? 0) != 0
        ? 'error'
        : tool['state']) {
      'completed' => context.l10n.toolStateDone,
      'error' => context.l10n.toolStateFailed,
      'running' => context.l10n.chatWorkRunningCommands,
      'canceled' => context.l10n.chatWorkCanceled(1),
      _ => context.l10n.toolStateQueued,
    }),
    trailing: const Icon(Icons.chevron_right),
    onTap: tool['id'] is String
        ? () {
            Navigator.pop(context);
            onOpenTool(tool);
          }
        : null,
  );
}
