import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Responsive chat layout with desktop grouping and mobile tool preferences.
class DesktopChatWorkspace extends StatelessWidget {
  const DesktopChatWorkspace({
    required this.mobileHideToolCalls,
    required this.builder,
    this.inspector,
    this.searching = false,
    super.key,
  });

  final bool mobileHideToolCalls;
  final Widget Function(bool collapseTools) builder;
  final Widget? inspector;

  /// Search addresses individual tool IDs rather than collapsed summaries.
  final bool searching;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < AppBreakpoint.desktop) {
      return builder(!searching && mobileHideToolCalls);
    }
    final cs = Theme.of(context).colorScheme;
    final conversation = ColoredBox(
      color: Color.alphaBlend(
        cs.surfaceContainerLowest.withValues(alpha: 0.18),
        cs.surface,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: builder(!searching),
        ),
      ),
    );
    // Only allocate inspector space after an explicit selection. Flex sizes
    // use the actual chat pane, including when nested beside the session list.
    // Keep the conversation under the same parent when the inspector opens
    // or closes, so drafts, focus, scroll and expanded rows stay mounted.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: conversation),
        if (inspector case final detail?) ...[
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.7),
          ),
          Expanded(
            flex: 2,
            child: ColoredBox(color: cs.surface, child: detail),
          ),
        ],
      ],
    );
  }
}
