import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_color_scheme.dart';
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
    final summary = total == 0
        ? context.l10n.chatActivityThinking
        : _summary.describe(context.l10n);
    final needsAttention = _summary.failed > 0 || _summary.approvals > 0;

    final appCs = theme.extension<AppColorScheme>() ?? AppColorScheme.dark();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.55,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            side: BorderSide(
              color: appCs.glassBorder,
              width: AppBorder.hairline,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          // TODO(l10n): localize 'Expand tool list' / 'Collapse tool list'
          child: Semantics(
            button: true,
            label: _expanded ? 'Collapse tool list' : 'Expand tool list',
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 2,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      total == 0
                          ? Icons.psychology_outlined
                          : needsAttention
                          ? Icons.error_outline_rounded
                          : Icons.build_circle_outlined,
                      size: 20,
                      color: needsAttention
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        summary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Queued rows may remain pending after a turn ends.
                    // Their count is useful, but only executing tools
                    // justify a continuously animated spinner.
                    if (running > 0) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: AppCircularProgressIndicator(strokeWidth: 1.6),
                      ),
                    ],
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
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
