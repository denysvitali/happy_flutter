import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/components/settings_section.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/rpc/rpc_types.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/snack.dart';
import '../../../core/widgets/app_linear_progress_indicator.dart';

/// Machine-level instructions, applied only when a Kubernetes Pod is created.
class MachineKubernetesClaudeMd extends StatefulWidget {
  const MachineKubernetesClaudeMd({
    required this.machineId,
    required this.isOnline,
    super.key,
  });

  final String machineId;
  final bool isOnline;

  @override
  State<MachineKubernetesClaudeMd> createState() =>
      _MachineKubernetesClaudeMdState();
}

enum _LoadState { idle, loading, loaded, unsupported, failed }

class _MachineKubernetesClaudeMdState extends State<MachineKubernetesClaudeMd> {
  KubernetesClaudeMdResponse? _instructions;
  _LoadState _state = _LoadState.idle;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isOnline) Future<void>.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant MachineKubernetesClaudeMd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.machineId != widget.machineId) {
      _generation++;
      _instructions = null;
      _state = _LoadState.idle;
      if (widget.isOnline) Future<void>.microtask(_load);
    } else if (widget.isOnline && !oldWidget.isOnline) {
      Future<void>.microtask(_load);
    }
  }

  Future<void> _load() async {
    if (!mounted || !widget.isOnline || _state == _LoadState.loading) return;
    final generation = ++_generation;
    setState(() => _state = _LoadState.loading);
    _LoadState next;
    KubernetesClaudeMdResponse? instructions;
    try {
      final response = await sync.machineGetKubernetesClaudeMd(
        machineId: widget.machineId,
      );
      instructions = response.success ? response : null;
      next = response.success ? _LoadState.loaded : _LoadState.failed;
    } on RpcException catch (error) {
      next = error.code == RpcErrorCode.methodUnsupported
          ? _LoadState.unsupported
          : _LoadState.failed;
    } catch (_) {
      next = _LoadState.failed;
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _state = next;
      _instructions = instructions ?? _instructions;
    });
  }

  Future<void> _edit() async {
    final generation = _generation;
    final saved = await showDialog<KubernetesClaudeMdResponse>(
      context: context,
      barrierDismissible: false,
      builder: (_) => KubernetesClaudeMdDialog(
        machineId: widget.machineId,
        initial: _instructions,
      ),
    );
    if (saved == null || !mounted || generation != _generation) return;
    setState(() {
      _instructions = saved;
      _state = _LoadState.loaded;
    });
    context.showSnack(
      saved.isConfigured
          ? context.l10n.kubernetesClaudeMdSaved
          : context.l10n.kubernetesClaudeMdRemoved,
    );
  }

  String _subtitle(AppLocalizations l10n) {
    if (!widget.isOnline) return l10n.kubernetesClaudeMdOffline;
    return switch (_state) {
      _LoadState.idle || _LoadState.loading => l10n.commonLoading,
      _LoadState.unsupported => l10n.kubernetesClaudeMdUnsupported,
      _LoadState.failed => l10n.kubernetesClaudeMdLoadFailed,
      _LoadState.loaded =>
        _instructions?.isConfigured == true
            ? l10n.kubernetesClaudeMdConfigured
            : l10n.kubernetesClaudeMdNotSet,
    };
  }

  VoidCallback? get _onTap {
    if (!widget.isOnline) return null;
    return switch (_state) {
      _LoadState.loaded => _edit,
      _LoadState.failed => _load,
      _LoadState.idle || _LoadState.loading || _LoadState.unsupported => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsSection(
      title: l10n.kubernetesClaudeMdTitle,
      description: l10n.kubernetesClaudeMdDescription,
      children: [
        SettingsNavRow(
          key: const ValueKey('machine-kubernetes-claude-md'),
          icon: Icons.description_outlined,
          title: l10n.kubernetesClaudeMdRowTitle,
          subtitle: _subtitle(l10n),
          onTap: _onTap,
        ),
      ],
    );
  }
}

/// Preserves Markdown exactly; the daemon is authoritative on validation.
class KubernetesClaudeMdDialog extends StatefulWidget {
  const KubernetesClaudeMdDialog({
    required this.machineId,
    this.initial,
    super.key,
  });

  final String machineId;
  final KubernetesClaudeMdResponse? initial;

  @override
  State<KubernetesClaudeMdDialog> createState() =>
      _KubernetesClaudeMdDialogState();
}

class _KubernetesClaudeMdDialogState extends State<KubernetesClaudeMdDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _content;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _content = TextEditingController(text: widget.initial?.content ?? '');
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool remove}) async {
    if (_busy) return;
    if (!remove && !(_formKey.currentState?.validate() ?? false)) return;
    final fallback = context.l10n.kubernetesClaudeMdSaveFailed;
    final unsupported = context.l10n.kubernetesClaudeMdUnsupported;
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      final response = await sync.machineSetKubernetesClaudeMd(
        machineId: widget.machineId,
        content: remove ? '' : _content.text,
      );
      if (response.success) {
        if (mounted) Navigator.pop(context, response);
        return;
      }
      final detail = response.error?.trim() ?? '';
      error = detail.isEmpty ? fallback : detail;
    } on RpcException catch (failure) {
      error = failure.code == RpcErrorCode.methodUnsupported
          ? unsupported
          : fallback;
    } catch (_) {
      error = fallback;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(l10n.kubernetesClaudeMdRowTitle),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const ValueKey('kubernetes-claude-md-content'),
                    controller: _content,
                    enabled: !_busy,
                    autofocus: true,
                    minLines: 8,
                    maxLines: 16,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: l10n.kubernetesClaudeMdContent,
                      hintText: l10n.kubernetesClaudeMdHint,
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      final content = value ?? '';
                      if (content.contains('\u0000')) {
                        return l10n.kubernetesClaudeMdInvalidText;
                      }
                      return kubernetesClaudeMdContentTooLarge(content)
                          ? l10n.kubernetesClaudeMdTooLarge
                          : null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.kubernetesClaudeMdAppliesToNew,
                    style: AppText.secondary(
                      theme,
                      theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _error!,
                      style: AppText.secondary(theme, theme.colorScheme.error),
                    ),
                  ],
                  if (_busy) ...[
                    const SizedBox(height: AppSpacing.md),
                    const AppLinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          if (widget.initial?.isConfigured == true)
            TextButton(
              onPressed: _busy ? null : () => _submit(remove: true),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: Text(l10n.commonClear),
            ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: _busy ? null : () => _submit(remove: false),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }
}

/// The daemon limits bytes, not characters (Markdown may contain Unicode).
bool kubernetesClaudeMdContentTooLarge(String content) =>
    utf8.encode(content).length > 64 * 1024;
