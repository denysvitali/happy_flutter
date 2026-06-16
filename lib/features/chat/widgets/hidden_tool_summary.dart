import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../tools/tool_status_indicator.dart';
import '../tools/tool_view.dart';

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
  List<Map<String, dynamic>> _cachedTools = const [];
  int _cachedCompleted = 0;
  int _cachedPending = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rawTools = widget.data['tools'];
    if (!identical(rawTools, _cachedToolsRef)) {
      _cachedToolsRef = rawTools;
      _cachedTools = (rawTools as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      _cachedCompleted = _cachedTools.where(_isCompleted).length;
      _cachedPending = _cachedTools.where(_isPending).length;
    }
    final tools = _cachedTools;
    if (tools.isEmpty) return const SizedBox.shrink();

    final completed = _cachedCompleted;
    final pending = _cachedPending;
    final total = tools.length;
    final summary = pending > 0
        ? '$completed of $total tools complete, $pending pending'
        : '$completed tool${completed == 1 ? '' : 's'} complete';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.sm),
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
                      Icons.build_circle_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
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
                    if (pending > 0) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.6),
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
                      for (final tool in tools)
                        ToolView(
                          tool: tool,
                          metadata: widget.metadata,
                          sessionId: widget.sessionId,
                          isSessionOnline: widget.isSessionOnline,
                          onPress: _onToolPress(tool),
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

  bool _isCompleted(Map<String, dynamic> tool) {
    final state = parseToolState(tool['state'] as String?);
    return state == ToolState.completed;
  }

  bool _isPending(Map<String, dynamic> tool) {
    final state = parseToolState(tool['state'] as String?);
    return state == ToolState.pending || state == ToolState.running;
  }
}
