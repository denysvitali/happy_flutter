import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tools = (widget.data['tools'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    if (tools.isEmpty) return const SizedBox.shrink();

    final completed = tools.where(_isCompleted).length;
    final pending = tools.where(_isPending).length;
    final total = tools.length;
    final summary = pending > 0
        ? '$completed of $total tools complete, $pending pending'
        : '$completed tool${completed == 1 ? '' : 's'} complete';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.sm),
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
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
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
