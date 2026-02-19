import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/services/server_config.dart';

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
    setState(() {
      _isVerifying = true;
      _statusMessage = 'Checking connection...';
    });
    final result = await verifyServerUrl(url);
    if (!mounted) {
      return;
    }
    setState(() {
      _isVerifying = false;
      _isConnected = result.isValid;
      _statusMessage = result.isValid
          ? 'Connected'
          : (result.errorMessage ?? 'Connection failed');
    });
  }

  Future<void> _handleSave() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorText = 'Server URL cannot be empty');
      return;
    }

    final validation = validateServerUrl(url);
    if (!validation.valid) {
      setState(() => _errorText = validation.error);
      return;
    }

    setState(() {
      _errorText = null;
      _isVerifying = true;
      _statusMessage = 'Verifying server...';
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
          ? 'Connected'
          : (result.errorMessage ?? 'Connection failed');
    });

    if (!result.isValid) {
      setState(() {
        _errorText = _statusMessage;
      });
      return;
    }

    setServerUrl(url);
    await ApiClient().refreshServerUrl();

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
        content: const Text(
          'Reset the server URL to the default? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(dialogContext).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
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
      appBar: AppBar(title: const Text('Server')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildStatusIcon(theme),
                    const SizedBox(width: 12),
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
                                    ? Colors.green
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

            const SizedBox(height: 24),

            // URL label
            Text(
              'CUSTOM SERVER URL',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

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

            const SizedBox(height: 8),

            if (isCustom)
              Text(
                'Currently using a custom server URL.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isVerifying ? null : _handleReset,
                    child: Text(l10n.settingsServerResetToDefault),
                  ),
                ),
                const SizedBox(width: 12),
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

            const SizedBox(height: 24),

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
      return const Icon(Icons.check_circle, color: Colors.green, size: 24);
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
