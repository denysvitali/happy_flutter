import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/provider_usage.dart';
import '../../../core/theme/app_tokens.dart';

/// Result payload returned by [AddProviderDialog].
class ProviderAccountInput {
  const ProviderAccountInput({
    required this.type,
    required this.credentials,
    this.name,
  });

  final ProviderUsageType type;
  final ProviderCredentials credentials;
  final String? name;
}

/// Dialog for adding a new provider account.
class AddProviderDialog extends StatefulWidget {
  const AddProviderDialog({super.key});

  @override
  State<AddProviderDialog> createState() => _AddProviderDialogState();
}

class _AddProviderDialogState extends State<AddProviderDialog> {
  ProviderUsageType _selectedType = ProviderUsageType.kimi;
  final _nameController = TextEditingController();

  // Kimi
  final _kimiKeyController = TextEditingController();
  final _kimiBaseUrlController =
      TextEditingController(text: kimiDefaultBaseUrl);

  // MiniMax
  final _miniMaxCookieController = TextEditingController();
  final _miniMaxGroupIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _kimiKeyController.addListener(_onFieldChanged);
    _miniMaxCookieController.addListener(_onFieldChanged);
    _miniMaxGroupIdController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _kimiKeyController.removeListener(_onFieldChanged);
    _miniMaxCookieController.removeListener(_onFieldChanged);
    _miniMaxGroupIdController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _kimiKeyController.dispose();
    _kimiBaseUrlController.dispose();
    _miniMaxCookieController.dispose();
    _miniMaxGroupIdController.dispose();
    super.dispose();
  }

  void _submit() {
    final credentials = switch (_selectedType) {
      ProviderUsageType.kimi => ProviderCredentials.kimi(
          KimiCredentials(
            apiKey: _kimiKeyController.text.trim(),
            baseUrl: _kimiBaseUrlController.text.trim().isEmpty
                ? kimiDefaultBaseUrl
                : _kimiBaseUrlController.text.trim(),
          ),
        ),
      ProviderUsageType.minimax => ProviderCredentials.miniMax(
          MiniMaxCredentials(
            cookie: _miniMaxCookieController.text.trim(),
            groupId: _miniMaxGroupIdController.text.trim(),
          ),
        ),
      ProviderUsageType.claudeCode => ProviderCredentials.kimi(
          // Not implemented yet; guard with empty key.
          const KimiCredentials(apiKey: ''),
        ),
      ProviderUsageType.codex => ProviderCredentials.kimi(
          const KimiCredentials(apiKey: ''),
        ),
    };

    final input = ProviderAccountInput(
      type: _selectedType,
      credentials: credentials,
      name: _nameController.text.trim(),
    );
    Navigator.of(context).pop(input);
  }

  bool get _canSubmit {
    return switch (_selectedType) {
      ProviderUsageType.kimi => _kimiKeyController.text.trim().isNotEmpty,
      ProviderUsageType.minimax =>
          _miniMaxCookieController.text.trim().isNotEmpty &&
              _miniMaxGroupIdController.text.trim().isNotEmpty,
      ProviderUsageType.claudeCode || ProviderUsageType.codex => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.providersAddAccount),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<ProviderUsageType>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: l10n.providersTypeLabel,
              ),
              items: ProviderUsageType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(_typeLabel(type)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.providersAccountNameLabel,
                hintText: l10n.providersAccountNameHint,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ..._buildCredentialFields(context),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(l10n.commonAdd),
        ),
      ],
    );
  }

  List<Widget> _buildCredentialFields(BuildContext context) {
    final l10n = context.l10n;
    return switch (_selectedType) {
      ProviderUsageType.kimi => [
          TextField(
            controller: _kimiKeyController,
            decoration: InputDecoration(
              labelText: l10n.providersKimiApiKeyLabel,
              hintText: l10n.providersKimiApiKeyHint,
            ),
            obscureText: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _kimiBaseUrlController,
            decoration: InputDecoration(
              labelText: l10n.providersKimiBaseUrlLabel,
              hintText: l10n.providersKimiBaseUrlHint,
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
        ],
      ProviderUsageType.minimax => [
          TextField(
            controller: _miniMaxCookieController,
            decoration: InputDecoration(
              labelText: l10n.providersMiniMaxCookieLabel,
              hintText: l10n.providersMiniMaxCookieHint,
            ),
            obscureText: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _miniMaxGroupIdController,
            decoration: InputDecoration(
              labelText: l10n.providersMiniMaxGroupIdLabel,
              hintText: l10n.providersMiniMaxGroupIdHint,
            ),
          ),
        ],
      ProviderUsageType.claudeCode || ProviderUsageType.codex => [
          Text(l10n.providersNotImplemented),
        ],
    };
  }

  String _typeLabel(ProviderUsageType type) {
    return switch (type) {
      ProviderUsageType.kimi => 'Kimi',
      ProviderUsageType.minimax => 'MiniMax',
      ProviderUsageType.claudeCode => 'Claude Code',
      ProviderUsageType.codex => 'Codex',
    };
  }
}
