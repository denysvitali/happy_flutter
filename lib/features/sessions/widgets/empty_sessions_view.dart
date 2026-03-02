import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.computer_outlined,
              size: 48,
              color: cs.onSurfaceVariant.withValues(alpha: 0.25),
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
            const SizedBox(height: 2),
            Text(
              l10n.emptyMainScreenRunIt,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              l10n.emptyMainScreenScanQrCode,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton.tonal(
              onPressed: () => _showNewSessionDialog(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size(160, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: Text(l10n.sessionNewSession),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewSessionDialog(BuildContext context) {
    // This is a bit of a hack - we need to access the _SessionsListContent
    // state to show the dialog. For now, we'll use a static method approach.
    // The dialog showing logic should ideally be moved to a service or
    // the parent widget should pass down a callback.
    showDialog(
      context: context,
      builder: (context) => const _NewSessionDialogPlaceholder(),
    );
  }
}

/// Placeholder for the new session dialog.
/// This should be replaced with the actual NewSessionDialog
/// from sessions_screen.dart.
/// or the dialog should be extracted to its own file.
class _NewSessionDialogPlaceholder extends StatelessWidget {
  const _NewSessionDialogPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Session'),
      content: const Text('New session dialog should be shown here.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
