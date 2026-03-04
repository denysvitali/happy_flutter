import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Empty sessions view — clean, minimal design.
class EmptySessionsView extends StatelessWidget {
  const EmptySessionsView({super.key, this.onNewSession});

  /// Callback invoked when the user taps "New Session".
  /// If null, the button is not shown.
  final VoidCallback? onNewSession;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.computer_outlined,
              size: 56,
              color: cs.onSurfaceVariant.withValues(alpha: AppOpacity.medium),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.sessionNoSessionsYet,
              style: theme.textTheme.titleSmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.emptyMainScreenInstallCli,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              l10n.emptyMainScreenRunIt,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              l10n.emptyMainScreenScanQrCode,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            if (onNewSession != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              FilledButton.tonal(
                onPressed: onNewSession,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(160, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: Text(l10n.sessionNewSession),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
