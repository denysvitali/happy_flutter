import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/app_loading_indicator.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/services/logger_service.dart';
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
    return AlertDialog(
      title: Text(l10n.authSignInWithSecretKey),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.authSecretKeyInstruction),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              labelText: l10n.authSecretKeyLabel,
              hintText: l10n.authSecretKeyHint,
              errorText: _errorText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppRadius.pill,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppRadius.pill,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppRadius.pill,
                ),
                borderSide: BorderSide(
                  color:
                      Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppRadius.pill,
                ),
                borderSide: const BorderSide(
                  color: Colors.red,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppRadius.pill,
                ),
                borderSide: const BorderSide(
                  color: Colors.red,
                  width: 2,
                ),
              ),
            ),
            maxLines: 2,
            minLines: 1,
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  final clip = await Clipboard.getData(
                    Clipboard.kTextPlain,
                  );
                  final text = clip?.text?.trim();
                  if (text == null || text.isEmpty) return;
                  _controller.text = text;
                  setState(() => _errorText = null);
                },
          child: Text(l10n.authPaste),
        ),
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const AppLoadingIndicator(
                  size: 16,
                  strokeWidth: 2,
                  color: Colors.white,
                )
              : Text(l10n.authSignIn),
        ),
      ],
    );
  }
}
