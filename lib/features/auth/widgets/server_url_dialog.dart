import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_text.dart';
import 'package:happy_flutter/core/components/app_banner.dart';
import 'package:happy_flutter/core/components/app_badge.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/socket_io_client.dart';
import '../../../core/components/app_loading_indicator.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/server_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/clipboard_utils.dart';
import '../../../core/utils/package_info_cache.dart';

/// Dialog for configuring the server URL.
class ServerUrlDialog extends StatefulWidget {
  const ServerUrlDialog({
    required this.initialUrl,
    required this.defaultUrl,
    this.verifyUrl = verifyServerUrl,
    super.key,
  });

  final String initialUrl;
  final String defaultUrl;

  /// Reachability check, called only after the shared URL policy accepts input.
  final Future<ServerUrlVerificationResult> Function(String) verifyUrl;

  @override
  State<ServerUrlDialog> createState() => _ServerUrlDialogState();
}

class _ServerUrlDialogState extends State<ServerUrlDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  String? _errorText;
  String? _detailedError;
  String? _errorType;
  bool _isVerifying = false;
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
    unawaited(_loadAppVersion());
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfoCache.get();
      if (!mounted) return;
      setState(() => _appVersion = '${info.version}+${info.buildNumber}');
    } catch (error) {
      logger.warning('Could not load server dialog app version', error);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clearErrors() {
    if (_errorText != null || _detailedError != null) {
      setState(() {
        _errorText = null;
        _detailedError = null;
        _errorType = null;
      });
    }
  }

  Future<void> _save() async {
    final url = _controller.text.trim();
    final validation = validateServerUrl(url);
    if (!validation.valid) {
      setState(() {
        _errorText = validation.error;
        final uri = Uri.tryParse(url);
        _detailedError =
            '${validation.error}\n'
            'Scheme: ${jsonEncode(uri?.scheme)}\n'
            'Hostname: ${jsonEncode(uri?.host)}';
        _errorType = 'Validation';
      });
      return;
    }

    setState(() {
      _errorText = null;
      _detailedError = null;
      _errorType = null;
      _isVerifying = true;
    });

    final result = await widget.verifyUrl(url);
    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (!result.isValid) {
      setState(() {
        _detailedError = result.errorMessage;
        _errorType = result.errorType;
      });
      return;
    }

    setServerUrl(url);
    unawaited(ApiClient().refreshServerUrl());
    socketIoClient.refreshServerUrl(url);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.authServerUrlSaved),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDefault = widget.initialUrl == widget.defaultUrl;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xxxl + AppSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.xxl,
              AppSpacing.xxl,
              0,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.dns_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: AppSpacing.xxl,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.settingsServerUrl,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText: l10n.settingsServerUrlLabel,
                        hintText: widget.defaultUrl,
                        prefixIcon: const Icon(Icons.link_outlined),
                        errorText: _errorText,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.smd),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.smd),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline
                                .withValues(alpha: AppOpacity.half),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.smd),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: AppBorder.thick,
                          ),
                        ),
                        suffixIcon: _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                tooltip: 'Clear',
                                onPressed: () {
                                  _controller.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.url,
                      autofillHints: const [AutofillHints.url],
                      onChanged: (_) {
                        _clearErrors();
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_appVersion != null) ...[
                      Text(
                        'Happy $_appVersion',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (_detailedError != null) ...[
                      _ErrorDetailBox(
                        errorType: _errorType,
                        errorMessage: _detailedError!,
                        l10n: l10n,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: AppOpacity.half),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppRadius.xl),
                bottomRight: Radius.circular(AppRadius.xl),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.commonCancel),
                ),
                if (!isDefault) ...[
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: () {
                      setServerUrl(null);
                      ApiClient().refreshServerUrl();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.settingsServerResetSuccess),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                    child: Text(l10n.settingsServerResetToDefault),
                  ),
                ],
                const SizedBox(width: AppSpacing.md),
                FilledButton(
                  onPressed: _isVerifying ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, AppTouchTarget.comfortable),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.smd),
                    ),
                  ),
                  child: _isVerifying
                      ? AppLoadingIndicator(
                          size: AppSpacing.lg,
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        )
                      : Text(l10n.settingsServerSaveVerify),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Red error-detail panel used inside
/// [ServerUrlDialog].
class _ErrorDetailBox extends StatelessWidget {
  const _ErrorDetailBox({
    required this.errorMessage,
    required this.l10n,
    this.errorType,
  });

  final String? errorType;
  final String errorMessage;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppToneColors.of(context, AppBadgeTone.danger);
    return AppBanner(
      tone: AppBadgeTone.danger,
      title: l10n.authConnectionFailed,
      trailing: errorType == null
          ? null
          : AppBadge(
              label: errorType!,
              tone: AppBadgeTone.danger,
              showToneIcon: false,
            ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(
            errorMessage,
            style: AppText.mono(theme, colors.foreground),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () async {
                await setClipboardTextSafely(errorMessage);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.authErrorDetailsCopied),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.content_copy, size: AppIconSize.md),
              label: Text(l10n.commonCopy),
              style: TextButton.styleFrom(foregroundColor: colors.foreground),
            ),
          ),
        ],
      ),
    );
  }
}
