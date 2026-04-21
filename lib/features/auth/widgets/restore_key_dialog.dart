import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/app_loading_indicator.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/backup_key_utils.dart';

/// Dialog for signing in with a backup / secret key.
class RestoreKeyDialog extends StatefulWidget {
  const RestoreKeyDialog({
    required this.onRestore,
    required this.formatError,
    super.key,
  });

  /// Called with the normalised key string; should throw
  /// on failure.
  final Future<void> Function(String normalized) onRestore;

  /// Formats a caught error object into a user-visible
  /// string.
  final String Function(dynamic) formatError;

  @override
  State<RestoreKeyDialog> createState() =>
      _RestoreKeyDialogState();
}

class _RestoreKeyDialogState
    extends State<RestoreKeyDialog> {
  final _controller = TextEditingController();
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _normalize(String input) {
    final s = input.replaceAll(RegExp(r'\s+'), '');
    if (s.isEmpty) return null;
    if (BackupKeyUtils.isValidKey(s)) return s;

    final hex = s.startsWith('0x') ? s.substring(2) : s;
    if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hex)) {
      try {
        final bytes = <int>[];
        for (var i = 0; i < hex.length; i += 2) {
          bytes.add(
            int.parse(
              hex.substring(i, i + 2),
              radix: 16,
            ),
          );
        }
        return BackupKeyUtils.encodeKey(
          Uint8List.fromList(bytes),
        );
      } catch (e, stack) {
        logger.error(
          'Failed to encode hex key',
          e,
          stack,
        );
      }
    }

    final b64 =
        s.replaceAll('-', '+').replaceAll('_', '/');
    final rem = b64.length % 4;
    final padded = rem == 0
        ? b64
        : b64.padRight(b64.length + (4 - rem), '=');
    try {
      final bytes = base64Decode(padded);
      if (bytes.length == 32) {
        return BackupKeyUtils.encodeKey(bytes);
      }
    } catch (e, stack) {
      logger.error(
        'Failed to decode base64 key',
        e,
        stack,
      );
    }
    return null;
  }

  Future<void> _submit() async {
    final input = _controller.text.trim();
    final l10n = context.l10n;
    if (input.isEmpty) {
      setState(
        () => _errorText = l10n.authPleaseEnterSecretKey,
      );
      return;
    }
    final normalized = _normalize(input);
    if (normalized == null) {
      setState(() {
        _errorText = l10n.authInvalidKey;
      });
      return;
    }

    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });
    try {
      await widget.onRestore(normalized);
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorText = widget.formatError(e),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppRadius.xl,
        ),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xxl,
        0,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
        0,
      ),
      actionsPadding: const EdgeInsets.all(
        AppSpacing.lg,
      ),
      title: Row(
        children: [
          Icon(
            Icons.key_outlined,
            color: scheme.primary,
            size: AppSpacing.xxl,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              l10n.authSignInWithSecretKey,
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            l10n.authSecretKeyInstruction,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
              color: scheme.onSurfaceVariant,
              height: AppLineHeight.normal,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              labelText: l10n.authSecretKeyLabel,
              hintText: l10n.authSecretKeyHint,
              errorText: _errorText,
              prefixIcon: Icon(
                Icons.vpn_key_outlined,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
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
                  color: scheme.outline.withValues(
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
                  color: scheme.primary,
                  width: AppBorder.thick,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  AppRadius.smd,
                ),
                borderSide: BorderSide(
                  color: scheme.error,
                ),
              ),
              focusedErrorBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  AppRadius.smd,
                ),
                borderSide: BorderSide(
                  color: scheme.error,
                  width: AppBorder.thick,
                ),
              ),
              suffixIcon: IconButton(
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        final clip =
                            await Clipboard.getData(
                          Clipboard.kTextPlain,
                        );
                        final text =
                            clip?.text?.trim();
                        if (text == null ||
                            text.isEmpty) {
                          return;
                        }
                        _controller.text = text;
                        setState(
                          () => _errorText = null,
                        );
                      },
                icon: Icon(
                  Icons.content_paste_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                tooltip: l10n.authPaste,
              ),
            ),
            maxLines: 1,
            minLines: 1,
            onChanged: (_) {
              if (_errorText != null) {
                setState(
                  () => _errorText = null,
                );
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: _isSubmitting
              ? null
              : () async {
                  final clip =
                      await Clipboard.getData(
                    Clipboard.kTextPlain,
                  );
                  final text =
                      clip?.text?.trim();
                  if (text == null ||
                      text.isEmpty) {
                    return;
                  }
                  _controller.text = text;
                  setState(
                    () => _errorText = null,
                  );
                },
          icon: const Icon(
            Icons.content_paste_rounded,
            size: 18,
          ),
          label: Text(l10n.authPaste),
        ),
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed:
              _isSubmitting ? null : _submit,
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
          child: _isSubmitting
              ? AppLoadingIndicator(
                  size: AppSpacing.lg,
                  strokeWidth: 2,
                  color: scheme.onPrimary,
                )
              : Text(l10n.authSignIn),
        ),
      ],
    );
  }
}
