import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/services/inbox_state_storage.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/utils.dart' show formatRelativeTime;
import '../../sessions/widgets/session_cards.dart' show buildSessionAvatar;
import '../inbox_providers.dart';
import 'inbox_kind_style.dart';

/// One email-style Inbox row: sender, subject, preview and status.
class InboxListTile extends StatelessWidget {
  const InboxListTile({
    required this.item,
    required this.state,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final InboxItem item;
  final InboxMessageState state;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final unread = !state.read && !state.done;
    final message = item.message;
    final kind = InboxKindStyle.of(context, message.kind);
    final needsReply = inboxItemNeedsReply(item, state);
    final time = formatRelativeTime(
      DateTime.fromMillisecondsSinceEpoch(message.createdAt),
      compact: true,
      useYesterdayLabel: true,
      l10n: l10n,
    );
    final weight = unread ? FontWeight.w700 : FontWeight.w500;
    final snippet = inboxSnippet(message.body);

    return Semantics(
      selected: selected,
      button: true,
      label: [
        if (unread) l10n.inboxUnread,
        item.sessionName,
        kind.label,
        message.subject,
        time,
      ].where((s) => s.isNotEmpty).join(', '),
      excludeSemantics: true,
      child: Material(
        color: selected ? cs.secondaryContainer : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: AppSpacing.md,
                  child: unread
                      ? Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.lg),
                          child: Container(
                            width: AppSpacing.sm,
                            height: AppSpacing.sm,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    buildSessionAvatar(
                      sessionId: item.sessionId,
                      avatarId: item.avatarId,
                      sessionFlavor: item.flavor,
                      size: AppAvatarSize.medium,
                      showFlavorIcon: true,
                      hasDraft: false,
                    ),
                    Positioned(
                      right: -AppSpacing.xs,
                      bottom: -AppSpacing.xs,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xxs),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          kind.icon,
                          size: AppIconSize.sm,
                          color: kind.color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.sessionName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.title(
                                theme,
                              ).copyWith(fontWeight: weight),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            time,
                            style:
                                AppText.secondary(
                                  theme,
                                  unread ? cs.primary : null,
                                ).copyWith(
                                  fontWeight: unread ? FontWeight.w600 : null,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        message.subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: weight,
                          color: cs.onSurface,
                        ),
                      ),
                      if (snippet.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          snippet,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.secondary(theme),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          InboxKindPill(kind: message.kind),
                          if (needsReply)
                            InboxPill(
                              label: l10n.inboxNeedsReply,
                              color: cs.error,
                              icon: Icons.reply_rounded,
                            )
                          else if (state.replied)
                            InboxPill(
                              label: l10n.inboxReplied,
                              color: cs.onSurfaceVariant,
                              icon: Icons.done_all_rounded,
                            ),
                          if (item.archived)
                            InboxPill(
                              label: l10n.inboxArchivedSession,
                              color: cs.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
