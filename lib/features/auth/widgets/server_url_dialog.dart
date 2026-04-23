import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clipboard_utils.dart';
import '../../../core/api/socket_io_client.dart';
import '../../../core/components/app_loading_indicator.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/services/server_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Dialog for configuring the server URL.
class ServerUrlDialog extends StatefulWidget {
  const ServerUrlDialog({
    required this.initialUrl,
    required this.defaultUrl,
    super.key,
  });

  final String initialUrl;
  final String defaultUrl;

  @override
  State<ServerUrlDialog> createState() =>
      _ServerUrlDialogState();
}

class _ServerUrlDialogState
    extends State<ServerUrlDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  String? _errorText;
  String? _detailedError;
  String? _errorType;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialUrl,
    );
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
        _detailedError = null;
        _errorType = null;
      });
      return;
    }

    setState(() {
      _errorText = null;
      _detailedError = null;
      _errorType = null;
      _isVerifying = true;
    });

    final result = await verifyServerUrl(url);
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
          content: Text(
            context.l10n.authServerUrlSaved,
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDefault =
        widget.initialUrl == widget.defaultUrl;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xxxl + AppSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(AppRadius.xl),
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
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                  size: AppSpacing.xxl,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.settingsServerUrl,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText:
                            l10n.settingsServerUrlLabel,
                        hintText: widget.defaultUrl,
                        prefixIcon: const Icon(
                          Icons.link_outlined,
                        ),
                        errorText: _errorText,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            AppRadius.smd,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            AppRadius.smd,
                          ),
                          borderSide: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(
                              alpha: AppOpacity.half,
                            ),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            AppRadius.smd,
                          ),
                          borderSide: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .primary,
                            width: AppBorder.thick,
                          ),
                        ),
                        suffixIcon:
                            _controller.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                    ),
                                    tooltip: 'Clear',
                                    onPressed: () {
                                      _controller.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                      ),
                      keyboardType: TextInputType.url,
                      autofillHints: const [
                        AutofillHints.url,
                      ],
                      onChanged: (_) {
                        _clearErrors();
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_detailedError != null) ...[
                      _ErrorDetailBox(
                        errorType: _errorType,
                        errorMessage: _detailedError!,
                        l10n: l10n,
                      ),
                      const SizedBox(
                        height: AppSpacing.md,
                      ),
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
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(
                alpha: AppOpacity.half,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft:
                    Radius.circular(AppRadius.xl),
                bottomRight:
                    Radius.circular(AppRadius.xl),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context),
                  child: Text(l10n.commonCancel),
                ),
                if (!isDefault) ...[
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: () {
                      setServerUrl(null);
                      ApiClient().refreshServerUrl();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n
                                .settingsServerResetSuccess,
                          ),
                          duration:
                              const Duration(seconds: 3),
                        ),
                      );
                    },
                    child: Text(
                      l10n.settingsServerResetToDefault,
                    ),
                  ),
                ],
                const SizedBox(width: AppSpacing.md),
                FilledButton(
                  onPressed:
                      _isVerifying ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(
                      0,
                      AppTouchTarget.comfortable,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        AppRadius.smd,
                      ),
                    ),
                  ),
                  child: _isVerifying
                      ? AppLoadingIndicator(
                          size: AppSpacing.lg,
                          strokeWidth: 2,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary,
                        )
                      : Text(
                          l10n.settingsServerSaveVerify,
                        ),
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
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius:
            BorderRadius.circular(AppRadius.smd),
        border: Border.all(
          color: cs.error.withValues(
            alpha: AppOpacity.medium,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: cs.onErrorContainer,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.authConnectionFailed,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onErrorContainer,
                  ),
                ),
              ),
              if (errorType != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: cs.error.withValues(
                      alpha: AppOpacity.soft,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      AppRadius.xs,
                    ),
                  ),
                  child: Text(
                    errorType!,
                    style: textTheme.labelSmall
                        ?.copyWith(
                      color: cs.onErrorContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            errorMessage,
            style: TextStyle(
              color: cs.onErrorContainer,
              fontSize: AppFontSize.sm,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () async {
                  await setClipboardTextSafely(errorMessage);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.authErrorDetailsCopied,
                      ),
                      duration:
                          const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.content_copy,
                  size: AppSpacing.lg,
                ),
                label: Text(
                  l10n.commonCopy,
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: cs.onErrorContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
