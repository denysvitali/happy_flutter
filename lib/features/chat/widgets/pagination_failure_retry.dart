import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// Inline recovery UI for a failed older-message page request.
class PaginationFailureRetry extends StatelessWidget {
  const PaginationFailureRetry({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          children: [
            Text(
              context.l10n.chatFailedToLoadMessages,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            TextButton.icon(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppTouchTarget.min),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
