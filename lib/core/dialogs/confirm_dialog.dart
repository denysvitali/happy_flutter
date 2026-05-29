import 'package:flutter/material.dart';

import '../i18n/app_localizations.dart';

/// Shows a confirmation dialog and resolves to `true` if confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? content,
  String? confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
}) async {
  final l10n = context.l10n;
  final cs = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: content == null ? null : Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelLabel ?? l10n.commonCancel),
        ),
        TextButton(
          style: isDestructive
              ? TextButton.styleFrom(foregroundColor: cs.error)
              : null,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel ?? l10n.commonConfirm),
        ),
      ],
    ),
  );
  return result ?? false;
}
