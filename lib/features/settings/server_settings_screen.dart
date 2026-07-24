import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/socket_io_client.dart';
import '../../core/components/app_card.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/services/server_config.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/snack.dart';

class ServerSettingsScreen extends ConsumerStatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  ConsumerState<ServerSettingsScreen> createState() =>
      _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends ConsumerState<ServerSettingsScreen> {
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
        _errorText = AppLocalizations.of(context).serverUrlCannotBeEmpty;
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
    context.showSnack(AppLocalizations.of(context).settingsServerSaved);
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
      context.showSnack(
        AppLocalizations.of(context).settingsServerResetSuccess,
      );
      unawaited(_checkConnectivity(defaultUrl));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isCustom = isUsingCustomServer();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.serverTitle)),
      body: SingleChildScrollView(
        padding: AppScreenPadding.settings,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
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
                                  ? cs.primary
                                  : _isConnected == false
                                  ? cs.error
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xs,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                l10n.serverCustomUrlSectionLabel.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
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
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Text(
                  l10n.serverCurrentlyUsingCustomUrl,
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.primary),
                ),
              ),
            const SizedBox(height: AppSpacing.xxl),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.settingsServerSaveVerify),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: Text(
                'This is an advanced feature. Changing'
                ' the server URL will disconnect you'
                ' from the current server.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(ThemeData theme) {
    final cs = theme.colorScheme;
    if (_isVerifying) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
      );
    }
    if (_isConnected ?? false) {
      return Icon(Icons.check_circle_rounded, color: cs.primary, size: 24);
    }
    if (_isConnected == false) {
      return Icon(Icons.error_outline, color: cs.error, size: 24);
    }
    return Icon(Icons.dns_outlined, color: cs.onSurfaceVariant, size: 24);
  }
}
