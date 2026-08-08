import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/clipboard_utils.dart';
import '../../../core/utils/snack.dart';

/// Shows the backup key in a dialog with a copy button.
Future<void> showBackupKeyDialog(BuildContext context) async {
  final l10n = context.l10n;
  final confirmed = await _confirmSensitiveAction(
    context,
    title: l10n.accountRevealBackupKeyTitle,
    message: l10n.accountRevealBackupKeyWarning,
    action: l10n.accountRevealAction,
  );
  if (!confirmed || !context.mounted) return;
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  final errorPrefix = context.l10n.commonError;
  try {
    final key = await AuthService().generateBackupKey();
    if (!context.mounted) return;
    unawaited(
      showDialog(
        context: context,
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(l10n.accountBackupKey),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.accountBackupKeyDialogContent,
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: SelectableText(
                    key,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: AppFontSize.lg,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.commonClose),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await _copySecretWithExpiry(key);
                  if (!context.mounted) return;
                  context.showSnack(
                    '${l10n.accountBackupKeyCopied} '
                    '${l10n.accountClipboardExpiry}',
                  );
                },
                icon: const Icon(Icons.content_copy),
                label: Text(l10n.commonCopy),
              ),
            ],
          );
        },
      ),
    );
  } catch (e) {
    scaffoldMessenger.showSnackBar(SnackBar(content: Text('$errorPrefix: $e')));
  }
}

/// Copies the backup key to clipboard and shows a snackbar.
Future<void> copyBackupKeyToClipboard(BuildContext context) async {
  final l10n = context.l10n;
  final confirmed = await _confirmSensitiveAction(
    context,
    title: l10n.accountCopyBackupKeyTitle,
    message: l10n.accountCopyBackupKeyWarning,
    action: l10n.accountCopyKeyAction,
  );
  if (!confirmed || !context.mounted) return;
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  final copiedMsg = context.l10n.accountBackupKeyCopiedToClipboard;
  final errorPrefix = context.l10n.commonError;
  try {
    final key = await AuthService().generateBackupKey();
    await _copySecretWithExpiry(key);
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('$copiedMsg ${l10n.accountClipboardExpiry}')),
    );
  } catch (e) {
    scaffoldMessenger.showSnackBar(SnackBar(content: Text('$errorPrefix: $e')));
  }
}

Future<bool> _confirmSensitiveAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.security_outlined),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

Future<void> _copySecretWithExpiry(String secret) async {
  await setClipboardTextSafely(secret);
  Timer(const Duration(seconds: 60), () async {
    final current = await Clipboard.getData(Clipboard.kTextPlain);
    if (current?.text == secret) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  });
}
