import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/socket_io_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/services/server_config.dart';
import '../../core/theme/app_tokens.dart';

/// Server settings screen — view and update the server URL
/// with live connection status indicator.
class ServerSettingsScreen extends ConsumerStatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  ConsumerState<ServerSettingsScreen> createState() =>
      _ServerSettingsScreenState();
}

class _ServerSettingsScreenState
    extends ConsumerState<ServerSettingsScreen> {
  late TextEditingController _urlController;
  bool _isVerifying = false;
  bool? _isConnected;
  String? _errorText;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    final current = getServerUrl();
    _urlController = TextEditingController(text: current);
    // Kick off a background connectivity check
    _checkConnectivity(current);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity(String url) async {
    if (url.isEmpty) {
      return;
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isVerifying = true;
      _statusMessage = l10n.serverCheckingConnection;
    });
    final result = await verifyServerUrl(url);
    if (!mounted) {
      return;
    }
    setState(() {
      _isVerifying = false;
      _isConnected = result.isValid;
      _statusMessage = result.isValid
          ? l10n.serverConnected
          : (result.errorMessage ?? l10n.serverConnectionFailed);
    });
  }

  Future<void> _handleSave() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _errorText =
            AppLocalizations.of(context).serverUrlCannotBeEmpty;
      });
      return;
    }

    final validation = validateServerUrl(url);
    if (!validation.valid) {
      setState(() => _errorText = validation.error);
      return;
    }

    final l10n = AppLocalizations.of(context);
    setState(() {
      _errorText = null;
      _isVerifying = true;
      _statusMessage = l10n.serverVerifyingServer;
      _isConnected = null;
    });

    final result = await verifyServerUrl(url);
    if (!mounted) {
      return;
    }

    setState(() {
      _isVerifying = false;
      _isConnected = result.isValid;
      _statusMessage = result.isValid
          ? l10n.serverConnected
          : (result.errorMessage ?? l10n.serverConnectionFailed);
    });

    if (!result.isValid) {
      setState(() {
        _errorText = _statusMessage;
      });
      return;
    }

    setServerUrl(url);
    await ApiClient().refreshServerUrl();
    socketIoClient.refreshServerUrl(url);

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).settingsServerSaved),
      ),
    );
  }

  void _handleReset() {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          AppLocalizations.of(dialogContext).settingsServerResetToDefault,
        ),
        content: Text(
          AppLocalizations.of(dialogContext).settingsServerResetConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(dialogContext).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              AppLocalizations.of(dialogContext).settingsServerResetToDefault,
            ),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true || !mounted) {
        return;
      }
      setServerUrl(null);
      await ApiClient().refreshServerUrl();
      final defaultUrl = getServerUrl();
      socketIoClient.refreshServerUrl(defaultUrl);
      if (!mounted) {
        return;
      }
      _urlController.text = defaultUrl;
      setState(() {
        _errorText = null;
        _isConnected = null;
        _statusMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).settingsServerResetSuccess,
          ),
        ),
      );
      unawaited(_checkConnectivity(defaultUrl));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isCustom = isUsingCustomServer();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.serverTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    _buildStatusIcon(theme),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.settingsServer,
                            style: theme.textTheme.titleSmall,
                          ),
                          if (_statusMessage != null)
                            Text(
                              _statusMessage!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _isConnected ?? false
                                    ? theme.colorScheme.primary
                                    : _isConnected == false
                                        ? theme.colorScheme.error
                                        : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // URL label
            Text(
              l10n.serverCustomUrlSectionLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // URL TextField
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: defaultServerUrl,
                errorText: _errorText,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.dns_outlined),
                suffixIcon: _urlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _urlController.clear();
                          setState(() => _errorText = null);
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() => _errorText = null),
            ),

            const SizedBox(height: AppSpacing.sm),

            if (isCustom)
              Text(
                l10n.serverCurrentlyUsingCustomUrl,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),

            const SizedBox(height: AppSpacing.xxl),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isVerifying ? null : _handleReset,
                    child: Text(l10n.settingsServerResetToDefault),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: _isVerifying ? null : _handleSave,
                    child: _isVerifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(l10n.settingsServerSaveVerify),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Footer info
            Text(
              'This is an advanced feature. Changing the server URL will'
              ' disconnect you from the current server.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(ThemeData theme) {
    if (_isVerifying) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.colorScheme.primary,
        ),
      );
    }
    if (_isConnected ?? false) {
      return Icon(
        Icons.check_circle,
        color: theme.colorScheme.primary,
        size: 24,
      );
    }
    if (_isConnected == false) {
      return Icon(
        Icons.error_outline,
        color: theme.colorScheme.error,
        size: 24,
      );
    }
    return Icon(
      Icons.dns_outlined,
      color: theme.colorScheme.onSurfaceVariant,
      size: 24,
    );
  }
}
