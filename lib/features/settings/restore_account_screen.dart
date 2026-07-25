import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/app_loading_indicator.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/auth.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/backup_key_utils.dart';
import '../../core/routing/safe_pop.dart';
import '../../core/utils/snack.dart';

/// Account restoration screen
class RestoreAccountScreen extends ConsumerStatefulWidget {
  const RestoreAccountScreen({super.key});

  @override
  ConsumerState<RestoreAccountScreen> createState() =>
      _RestoreAccountScreenState();
}

class _RestoreAccountScreenState extends ConsumerState<RestoreAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.accountRestoreAccount),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => safePop<void>(context),
        ),
      ),
      body: Padding(
        padding: AppScreenPadding.settings,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.accountRestoreInstruction,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: context.l10n.accountBackupKeyLabel,
                  hintText: context.l10n.accountBackupKeyHint,
                  prefixIcon: const Icon(Icons.key),
                  border: const OutlineInputBorder(),
                ),
                validator: _validateKey,
                enabled: !_isLoading,
                maxLength: 35,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Builder(
                builder: (context) {
                  final cs = Theme.of(context).colorScheme;
                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: cs.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: cs.onErrorContainer),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            _error ?? '',
                            style: TextStyle(color: cs.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              height: AppTouchTarget.comfortable,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _restoreAccount,
                child: _isLoading
                    ? const AppLoadingIndicator(
                        size: AppSpacing.xl,
                        strokeWidth: 2,
                      )
                    : Text(context.l10n.accountRestoreAccount),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: AppTouchTarget.comfortable,
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => _pasteFromClipboard(context),
                child: Text(context.l10n.accountPasteFromClipboard),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateKey(String? value) {
    final l10n = context.l10n;
    if (value == null || value.isEmpty) {
      return l10n.accountEnterBackupKey;
    }
    if (!BackupKeyUtils.isValidKey(value)) {
      return l10n.accountInvalidKeyFormat;
    }
    return null;
  }

  void _pasteFromClipboard(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      setState(() {
        _controller.text = data.text ?? '';
      });
    }
  }

  Future<void> _restoreAccount() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await AuthService().restoreAccount(_controller.text.trim());
      if (mounted) {
        unawaited(ref.read(authStateNotifierProvider.notifier).checkAuth());
        if (mounted) {
          safePop<void>(context);
          if (mounted) {
            context.showSnack(context.l10n.accountRestoredSuccess);
          }
        }
      }
    } catch (e) {
      setState(() {
        _error = _formatError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatError(dynamic e) {
    if (e is AuthForbiddenError) {
      return 'Access denied. Please try again.';
    } else if (e is AuthRequestError) {
      return e.message;
    }
    return 'Failed to restore account: $e';
  }
}
