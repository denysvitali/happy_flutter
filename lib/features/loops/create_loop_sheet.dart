import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/theme/app_tokens.dart';

/// Bottom sheet for creating a new scheduled prompt (loop).
///
/// Pre-fills the cron expression, prompt, and recurring toggle from the
/// `/loop` slash-command parser when the sheet is opened from chat
/// (see `_chat_screen_actions._handleLoopCommand`).
class CreateLoopSheet extends ConsumerStatefulWidget {
  const CreateLoopSheet({
    required this.sessionId,
    this.initialExpression,
    this.initialPrompt,
    this.initialRecurring = true,
    super.key,
  });

  final String sessionId;
  final String? initialExpression;
  final String? initialPrompt;
  final bool initialRecurring;

  @override
  ConsumerState<CreateLoopSheet> createState() => _CreateLoopSheetState();
}

class _CreateLoopSheetState extends ConsumerState<CreateLoopSheet> {
  late final TextEditingController _intervalController;
  late final TextEditingController _promptController;
  late bool _recurring;
  bool _submitting = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _intervalController = TextEditingController(
      text: widget.initialExpression ?? '',
    );
    _promptController = TextEditingController(text: widget.initialPrompt ?? '');
    _recurring = widget.initialRecurring;
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  bool _validate() {
    final interval = _intervalController.text.trim();
    if (interval.isEmpty) {
      setState(() => _validationError = 'validation_required_interval');
      return false;
    }
    if (!_isValidCron(interval)) {
      setState(() => _validationError = 'validation_invalid_cron');
      return false;
    }
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() => _validationError = 'validation_required_prompt');
      return false;
    }
    setState(() => _validationError = null);
    return true;
  }

  /// Hand-rolled validator: 5 whitespace-separated fields, each matching
  /// the standard cron subset `* | */N | N | N-N | N,N | N-N/N`.
  bool _isValidCron(String expression) {
    final parts = expression.trim().split(RegExp(r'\s+'));
    if (parts.length != 5) return false;
    final field = RegExp(r'^\*(/\d+)?$|^\d+$|^\d+-\d+(/\d+)?$|^\d+(,\d+)+$');
    for (final part in parts) {
      if (!field.hasMatch(part)) return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() => _submitting = true);
    final l10n = context.l10n;
    try {
      final loop = await ref
          .read(loopsNotifierProvider.notifier)
          .createLoop(
            sessionId: widget.sessionId,
            expression: _intervalController.text.trim(),
            prompt: _promptController.text.trim(),
            recurring: _recurring,
          );
      if (!mounted) return;
      Navigator.of(context).pop(loop);
    } catch (e, st) {
      logger.warning('[CreateLoopSheet] submit failed: $e', e, st);
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.loopsScheduleFailed}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: AppSpacing.xxl * 2,
                  height: AppSpacing.xs / 2,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.loopsCreateTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _intervalController,
                decoration: InputDecoration(
                  labelText: l10n.loopsIntervalLabel,
                  hintText: l10n.loopsIntervalHint,
                  border: const OutlineInputBorder(),
                ),
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _promptController,
                decoration: InputDecoration(
                  labelText: l10n.loopsPromptLabel,
                  hintText: l10n.loopsPromptHint,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                minLines: 3,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.loopsRecurringLabel),
                value: _recurring,
                onChanged: _submitting
                    ? null
                    : (v) => setState(() => _recurring = v),
              ),
              if (_validationError != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _validationErrorMessage(_validationError!, l10n),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(l10n.loopsCancelButton),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: AppSpacing.lg,
                            height: AppSpacing.lg,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.schedule),
                    label: Text(l10n.loopsScheduleButton),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _validationErrorMessage(String key, AppLocalizations l10n) {
    switch (key) {
      case 'validation_required_interval':
        return l10n.loopsValidationRequiredInterval;
      case 'validation_required_prompt':
        return l10n.loopsValidationRequiredPrompt;
      case 'validation_invalid_cron':
        return l10n.loopsValidationInvalidCron;
    }
    return key;
  }
}
