import 'package:flutter/material.dart';

import '../../../core/components/avatar.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/friend.dart';
import '../../../core/theme/app_tokens.dart';

/// Embedded friend detail pane shown in the tablet master-detail layout.
///
/// Renders a thin panel header with a close action and a centered card
/// summarizing the friend, plus a button that opens the full profile route.
class FriendDetailPanel extends StatelessWidget {
  const FriendDetailPanel({
    required this.friend,
    required this.onClose,
    required this.onOpenProfile,
    super.key,
  });

  final UserProfile friend;
  final VoidCallback onClose;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final name = friend.name ?? friend.id;
    final subtitle = friend.bio ?? '@${friend.username}';

    return Material(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.55),
                  width: AppBorder.hairline,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  tooltip:
                      MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Column(
                        children: [
                          Avatar(
                            id: friend.id,
                            imageUrl: friend.avatarUrl,
                            size: AppSpacing.xxxl + AppSpacing.xxl,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          FilledButton.icon(
                            onPressed: onOpenProfile,
                            icon: const Icon(Icons.open_in_new),
                            label: Text(l10n.profileUserProfile),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
