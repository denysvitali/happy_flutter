import 'package:flutter/material.dart';

import '../i18n/app_localizations.dart';
import 'app_dialog.dart';
import 'package:happy_flutter/core/theme/app_button_style.dart';

/// Shows a confirmation dialog and resolves to `true` if confirmed.
///
/// This is the app's single yes/no dialog shape: a sentence-case [title],
/// optional [content] (or a richer [body] widget), then Cancel on the left
/// and the confirming verb ([confirmLabel], e.g. "Delete") on the right as a
/// [FilledButton]. [isDestructive] paints the confirm button with
/// [ColorScheme.error] for irreversible or disruptive actions.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? content,
  Widget? body,
  String? confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
  bool barrierDismissible = true,
}) async {
  assert(
    content == null || body == null,
    'Pass either content or body, not both.',
  );
  final l10n = context.l10n;
  final result = await showAppDialog<bool>(
    context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) {
      final cs = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: body ?? (content == null ? null : Text(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelLabel ?? l10n.commonCancel),
          ),
          FilledButton(
            style: isDestructive ? AppButtonStyle.destructiveFilled(cs) : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel ?? l10n.commonConfirm),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
