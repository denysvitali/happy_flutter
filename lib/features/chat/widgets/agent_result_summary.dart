import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../markdown/markdown_view.dart';

/// Coerces a tool-call `result` (string, content-block list, or map) into
/// plain text. Returns null when there is nothing displayable.
///
/// Used by the agent conversation screen as a last-resort completion summary
/// when a container tool call (e.g. an `Agent`/`Task` whose sidechain
/// transcript failed to group) finished with no renderable children.
String? resultAsText(dynamic result) {
  if (result == null) return null;
  if (result is String) return result.isEmpty ? null : result;
  if (result is List) {
    final parts = <String>[];
    for (final block in result) {
      if (block is Map) {
        final text = block['text'];
        if (text is String && text.isNotEmpty) parts.add(text);
      } else if (block is String && block.isNotEmpty) {
        parts.add(block);
      }
    }
    final joined = parts.join('\n');
    return joined.isEmpty ? null : joined;
  }
  if (result is Map) {
    final text = result['text'];
    if (text is String && text.isNotEmpty) return text;
  }
  return null;
}

/// Compact, scrollable completion summary shown in the agent conversation
/// screen when a finished container tool call has no transcript children to
/// render but does carry a tool result.
class AgentResultSummary extends StatelessWidget {
  /// Creates an [AgentResultSummary].
  const AgentResultSummary({required this.text, super.key});

  /// The coerced result text to render as markdown.
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: SimpleMarkdownView(markdown: text),
      ),
    );
  }
}
