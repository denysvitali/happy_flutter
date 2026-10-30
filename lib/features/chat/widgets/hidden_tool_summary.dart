import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_circular_progress_indicator.dart';
import '../tool_work_summary.dart';
import '../tools/tool_view.dart';
import 'thinking_block.dart';

class HiddenToolSummary extends StatefulWidget {
  const HiddenToolSummary({
    required this.data,
    super.key,
    this.metadata,
    this.sessionId,
    this.isSessionOnline = true,
  });

  final Map<String, dynamic> data;
  final Map<String, dynamic>? metadata;
  final String? sessionId;
  final bool isSessionOnline;

  @override
  State<HiddenToolSummary> createState() => _HiddenToolSummaryState();
}

class _HiddenToolSummaryState extends State<HiddenToolSummary> {
  bool _expanded = false;
  Object? _cachedToolsRef;
  Object? _cachedItemsRef;
  List<Map<String, dynamic>> _cachedTools = const [];
  List<Map<String, dynamic>> _cachedItems = const [];
  ToolWorkSummary _summary = ToolWorkSummary.fromTools(const []);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rawTools = widget.data['tools'];
    if (!identical(rawTools, _cachedToolsRef)) {
      _cachedToolsRef = rawTools;
      _cachedTools = (rawTools as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      _summary = ToolWorkSummary.fromTools(_cachedTools);
    }
    final tools = _cachedTools;
    // `items` holds everything collapsed into this row, in original
    // order — tool calls plus folded thinking blocks. Older producers
    // only set `tools`; fall back to it.
    final rawItems = widget.data['items'] ?? rawTools;
    if (!identical(rawItems, _cachedItemsRef)) {
      _cachedItemsRef = rawItems;
      _cachedItems = (rawItems as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    }
    final items = _cachedItems;
    if (items.isEmpty) return const SizedBox.shrink();

    final running = _summary.running;
    final total = tools.length;
    final l10n = context.l10n;
    final detail = _summary.describe(l10n);
    final summary = total == 0
        ? l10n.chatActivityThinking
        : detail.isEmpty
        ? l10n.convWorkSteps(total)
        : '${l10n.convWorkSteps(total)} \u00b7 $detail';
    final needsAttention = _summary.failed > 0 || _summary.approvals > 0;
    final done = total > 0 && _summary.pending == 0 && !needsAttention;
    final cs = theme.colorScheme;
    final ink = needsAttention ? cs.error : cs.onSurfaceVariant;

    // One quiet row, like a finished task chip: no fill, a hairline
    // outline, the step count first and the evidence after it. The full
    // transcript (real commands, diffs, exit codes) is one tap away.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(
              color: cs.onSurface.withValues(alpha: AppOpacity.subtle),
              width: AppBorder.thin,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            button: true,
            expanded: _expanded,
            label: _expanded ? l10n.convWorkCollapse : l10n.convWorkExpand,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppTouchTarget.min,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      // Only executing tools justify a spinner; queued rows
                      // left pending after a turn stay static.
                      if (running > 0)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: AppCircularProgressIndicator(strokeWidth: 1.6),
                        )
                      else
                        Icon(
                          total == 0
                              ? Icons.psychology_outlined
                              : needsAttention
                              ? Icons.error_outline_rounded
                              : done
                              ? Icons.check_circle_outline_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: AppIconSize.lg,
                          color: ink,
                        ),
                      const SizedBox(width: AppSpacing.smd),
                      Expanded(
                        child: Text(
                          summary,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: AppIconSize.lg,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: AppDuration.normal,
          curve: AppCurve.standard,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final item in items)
                        item['kind'] == 'tool-call'
                            ? ToolView(
                                tool: item,
                                metadata: widget.metadata,
                                sessionId: widget.sessionId,
                                isSessionOnline: widget.isSessionOnline,
                                onPress: _onToolPress(item),
                              )
                            : ThinkingBlock(
                                content: _thinkingText(item),
                                storageKey: item['id'] as String?,
                              ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  VoidCallback? _onToolPress(Map<String, dynamic> tool) {
    final sessionId = widget.sessionId;
    final messageId = tool['id'] as String?;
    if (sessionId == null || messageId == null) return null;
    return () {
      final isTask =
          tool['name'] == 'Task' ||
          tool['name'] == 'Agent' ||
          tool['name'] == 'Workflow';
      final route = isTask
          ? '/chat/$sessionId/agent/$messageId'
          : '/chat/$sessionId/message/$messageId';
      context.push(route, extra: tool);
    };
  }

  static String _thinkingText(Map<String, dynamic> item) {
    final content = item['content'] ?? item['text'] ?? '';
    return content is String ? content : content.toString();
  }
}
