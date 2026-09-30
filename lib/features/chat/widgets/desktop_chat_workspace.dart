import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// Desktop presentation preferences are local to the chat. They never change
/// the mobile tool setting or the message projection's durable data.
class DesktopChatWorkspace extends StatefulWidget {
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
  State<DesktopChatWorkspace> createState() => _DesktopChatWorkspaceState();
}

class _DesktopChatWorkspaceState extends State<DesktopChatWorkspace> {
  bool _showTools = false;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < AppBreakpoint.desktop) {
      return widget.builder(!widget.searching && widget.mobileHideToolCalls);
    }
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final conversation = Column(
      children: [
        Material(
          color: cs.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: l10n.desktopToolCallsCollapsed,
                    child: Text(
                      l10n.desktopConversation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.searching
                      ? null
                      : () => setState(() => _showTools = !_showTools),
                  icon: Icon(
                    _showTools ? Icons.unfold_less : Icons.terminal,
                    size: 18,
                  ),
                  label: Text(
                    widget.searching
                        ? l10n.desktopSearchToolsVisible
                        : _showTools
                        ? l10n.settingsHideToolCalls
                        : l10n.desktopShowToolCalls,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: widget.builder(!widget.searching && !_showTools),
            ),
          ),
        ),
      ],
    );
    // Only allocate inspector space after an explicit selection. Flex sizes
    // use the actual chat pane, including when nested beside the session list.
    // Keep the conversation under the same parent when the inspector opens
    // or closes, so drafts, focus, scroll and expanded rows stay mounted.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: conversation),
        if (widget.inspector case final inspector?) ...[
          VerticalDivider(width: 1, color: cs.outlineVariant),
          Expanded(flex: 2, child: inspector),
        ],
      ],
    );
  }
}
