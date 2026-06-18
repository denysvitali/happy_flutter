import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/provider_usage.dart';

/// Result of [RenameProviderDialog].
///
/// `null` = the user cancelled (or dismissed the dialog). A non-null result
/// means the user pressed Save; the inner [name] is `null` when the field was
/// submitted empty (clear-label intent) or a trimmed string otherwise.
class RenameProviderOutcome {
  const RenameProviderOutcome(this.name);

  final String? name;
}

/// Dialog for renaming a configured provider account.
///
/// The account name is optional: submitting an empty value clears the custom
/// label so the card falls back to showing the vendor name only.
class RenameProviderDialog extends StatefulWidget {
  const RenameProviderDialog({
    required this.accountId,
    required this.currentName,
    required this.type,
    super.key,
  });

  final String accountId;
  final String? currentName;
  final ProviderUsageType type;

  @override
  State<RenameProviderDialog> createState() => _RenameProviderDialogState();
}

class _RenameProviderDialogState extends State<RenameProviderDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    // Whitespace-only is treated as "clear"; empty/null trim collapses here.
    final trimmed = _nameController.text.trim();
    Navigator.of(context).pop<RenameProviderOutcome>(
      RenameProviderOutcome(trimmed.isEmpty ? null : trimmed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.providersRenameAccount),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.providersAccountNameLabel,
          hintText: l10n.providersAccountNameHint,
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

/// Helper to show the rename dialog and return the chosen outcome.
///
/// Returns `null` when the user cancels, otherwise an outcome whose [name] is
/// either the trimmed new label or `null` if the field was submitted empty.
Future<RenameProviderOutcome?> showRenameProviderDialog(
  BuildContext context, {
  required String accountId,
  required String? currentName,
  required ProviderUsageType type,
}) {
  return showDialog<RenameProviderOutcome>(
    context: context,
    builder: (_) => RenameProviderDialog(
      accountId: accountId,
      currentName: currentName,
      type: type,
    ),
  );
}
