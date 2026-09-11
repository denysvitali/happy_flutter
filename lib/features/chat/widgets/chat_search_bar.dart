import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// In-conversation search field, rendered in the chat app bar.
///
/// Owns no state: the chat screen holds the query, the match list and the
/// selected index so that navigation can also scroll the transcript.
class ChatSearchBar extends StatelessWidget {
  const ChatSearchBar({
    required this.controller,
    required this.matchCount,
    required this.currentIndex,
    required this.onChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onClose,
    this.isSearchingOlderMessages = false,
    super.key,
  });

  final TextEditingController controller;

  /// Number of rows matching the current query.
  final int matchCount;

  /// Zero-based index of the selected match, or -1 when there is none.
  final int currentIndex;

  final ValueChanged<String> onChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onClose;

  /// True while older pages are being paged in to widen the search.
  final bool isSearchingOlderMessages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasMatches = matchCount > 0;
    final query = controller.text.trim();

    return Row(
      key: const ValueKey('chat-search-bar'),
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('chat-search-field'),
            controller: controller,
            onChanged: onChanged,
            autofocus: true,
            textInputAction: TextInputAction.search,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: context.l10n.chatSearchHint,
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: AppOpacity.half),
              ),
            ),
          ),
        ),
        if (query.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              hasMatches
                  ? context.l10n.chatSearchCounter(
                      currentIndex + 1,
                      matchCount,
                    )
                  : isSearchingOlderMessages
                  ? '…'
                  : context.l10n.chatSearchNoMatches,
              key: const ValueKey('chat-search-counter'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        _SearchAction(
          icon: Icons.keyboard_arrow_up_rounded,
          tooltip: context.l10n.chatSearchPrevious,
          onPressed: hasMatches ? onPrevious : null,
          semanticKey: 'chat-search-previous',
        ),
        _SearchAction(
          icon: Icons.keyboard_arrow_down_rounded,
          tooltip: context.l10n.chatSearchNext,
          onPressed: hasMatches ? onNext : null,
          semanticKey: 'chat-search-next',
        ),
        _SearchAction(
          icon: Icons.close_rounded,
          tooltip: context.l10n.chatSearchClose,
          onPressed: onClose,
          semanticKey: 'chat-search-close',
        ),
      ],
    );
  }
}

class _SearchAction extends StatelessWidget {
  const _SearchAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.semanticKey,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final String semanticKey;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: ValueKey(semanticKey),
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(
        minWidth: AppTouchTarget.min,
        minHeight: AppTouchTarget.min,
      ),
      padding: EdgeInsets.zero,
    );
  }
}
