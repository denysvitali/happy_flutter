import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import 'new_session_dialog.dart';

/// Empty sessions view — clean, minimal design.
class EmptySessionsView extends StatelessWidget {
  const EmptySessionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.computer_outlined,
              size: 56,
              color: cs.onSurfaceVariant
                  .withValues(alpha: AppOpacity.medium),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.sessionNoSessionsYet,
              style: theme.textTheme.titleSmall?.copyWith(
                color: cs.onSurfaceVariant
                    .withValues(alpha: AppOpacity.half),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.emptyMainScreenInstallCli,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant
                    .withValues(alpha: AppOpacity.half),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              l10n.emptyMainScreenRunIt,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant
                    .withValues(alpha: AppOpacity.half),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              l10n.emptyMainScreenScanQrCode,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant
                    .withValues(alpha: AppOpacity.half),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton.tonal(
              onPressed: () => _showNewSessionDialog(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size(160, 44),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: Text(l10n.sessionNewSession),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNewSessionDialog(
    BuildContext context,
  ) async {
    await showDialog<String>(
      context: context,
      builder: (context) => const NewSessionDialog(),
    );
  }
}
