import 'package:flutter/material.dart';

import '../../../core/components/settings_section.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/rpc/rpc_types.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/snack.dart';
import '../../../core/widgets/app_linear_progress_indicator.dart';

/// Shows and edits the git author/committer identity of one machine.
///
/// The daemon hands it to every session it starts afterwards. Kubernetes
/// pods and sandboxed sessions have no git config of their own, so without
/// it their first commit fails with "Author identity unknown".
class MachineGitIdentity extends StatefulWidget {
  const MachineGitIdentity({
    required this.machineId,
    required this.isOnline,
    super.key,
  });

  final String machineId;
  final bool isOnline;

  @override
  State<MachineGitIdentity> createState() => _MachineGitIdentityState();
}

enum _LoadState { idle, loading, loaded, unsupported, failed }

class _MachineGitIdentityState extends State<MachineGitIdentity> {
  GitIdentityResponse? _identity;
  _LoadState _state = _LoadState.idle;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isOnline) Future<void>.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant MachineGitIdentity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.machineId != widget.machineId) {
      _generation++;
      _identity = null;
      _state = _LoadState.idle;
      if (widget.isOnline) Future<void>.microtask(_load);
    } else if (widget.isOnline &&
        !oldWidget.isOnline &&
        _state != _LoadState.loaded) {
      Future<void>.microtask(_load);
    }
  }

  Future<void> _load() async {
    if (!mounted || !widget.isOnline || _state == _LoadState.loading) return;
    final generation = ++_generation;
    setState(() => _state = _LoadState.loading);
    _LoadState next;
    GitIdentityResponse? identity;
    try {
      final response = await sync.machineGetGitIdentity(
        machineId: widget.machineId,
      );
      identity = response.success ? response : null;
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
      _identity = identity ?? _identity;
    });
  }

  Future<void> _edit() async {
    final generation = _generation;
    final saved = await showDialog<GitIdentityResponse>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          GitIdentityDialog(machineId: widget.machineId, initial: _identity),
    );
    if (saved == null || !mounted || generation != _generation) return;
    setState(() {
      _identity = saved;
      _state = _LoadState.loaded;
    });
    context.showSnack(
      saved.source == GitIdentitySource.settings
          ? context.l10n.gitIdentitySaved
          : context.l10n.gitIdentityRemoved,
    );
  }

  String _subtitle(AppLocalizations l10n) {
    final identity = _identity;
    if (identity != null && identity.isConfigured) {
      final label = '${identity.name} <${identity.email}>';
      return identity.source == GitIdentitySource.config
          ? l10n.gitIdentityFromConfig(label)
          : label;
    }
    if (!widget.isOnline) return l10n.gitIdentityOffline;
    return switch (_state) {
      _LoadState.idle || _LoadState.loading => l10n.gitIdentityLoading,
      _LoadState.unsupported => l10n.gitIdentityUnsupported,
      _LoadState.failed => l10n.gitIdentityLoadFailed,
      _LoadState.loaded => l10n.gitIdentityNotSet,
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
      title: l10n.gitIdentityTitle,
      description: l10n.gitIdentityDescription,
      children: [
        SettingsNavRow(
          key: const ValueKey('machine-git-identity'),
          icon: Icons.commit_rounded,
          title: l10n.gitIdentityRowTitle,
          subtitle: _subtitle(l10n),
          onTap: _onTap,
        ),
      ],
    );
  }
}

/// Edits one machine's git identity and returns the daemon's confirmed value.
class GitIdentityDialog extends StatefulWidget {
  const GitIdentityDialog({required this.machineId, this.initial, super.key});

  final String machineId;
  final GitIdentityResponse? initial;

  @override
  State<GitIdentityDialog> createState() => _GitIdentityDialogState();
}

class _GitIdentityDialogState extends State<GitIdentityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  bool _busy = false;
  String? _error;

  /// Only an identity stored from the app can be removed from the app.
  bool get _canRemove => widget.initial?.source == GitIdentitySource.settings;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _email = TextEditingController(text: widget.initial?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool remove}) async {
    if (_busy) return;
    if (!remove && !(_formKey.currentState?.validate() ?? false)) return;
    final fallback = context.l10n.gitIdentitySaveFailed;
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      final response = await sync.machineSetGitIdentity(
        machineId: widget.machineId,
        name: remove ? '' : _name.text,
        email: remove ? '' : _email.text,
      );
      if (response.success) {
        if (mounted) Navigator.pop(context, response);
        return;
      }
      // The daemon's validation message names the offending field.
      final detail = response.error?.trim() ?? '';
      error = detail.isEmpty ? fallback : detail;
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
        title: Text(l10n.gitIdentityTitle),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('git-identity-name'),
                  controller: _name,
                  enabled: !_busy,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(
                    labelText: l10n.gitIdentityName,
                    hintText: l10n.gitIdentityNameHint,
                  ),
                  validator: (value) =>
                      switch (validateGitIdentityName(value ?? '')) {
                        GitIdentityFieldError.required =>
                          l10n.gitIdentityNameRequired,
                        GitIdentityFieldError.invalid =>
                          l10n.gitIdentityNameInvalid,
                        null => null,
                      },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const ValueKey('git-identity-email'),
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  onFieldSubmitted: (_) => _submit(remove: false),
                  decoration: InputDecoration(
                    labelText: l10n.gitIdentityEmail,
                    hintText: l10n.gitIdentityEmailHint,
                  ),
                  validator: (value) =>
                      switch (validateGitIdentityEmail(value ?? '')) {
                        GitIdentityFieldError.required =>
                          l10n.gitIdentityEmailRequired,
                        GitIdentityFieldError.invalid =>
                          l10n.gitIdentityEmailInvalid,
                        null => null,
                      },
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.gitIdentityAppliesToNew,
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
        actions: [
          if (_canRemove)
            TextButton(
              onPressed: _busy ? null : () => _submit(remove: true),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: Text(l10n.gitIdentityRemove),
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

enum GitIdentityFieldError { required, invalid }

final RegExp _controlChars = RegExp(r'[\x00-\x1F\x7F]');
final RegExp _emailShape = RegExp(r'^[^@\s<>]+@[^@\s<>]+$');

/// Mirrors the daemon's rule: git rejects `<`, `>` and control characters.
GitIdentityFieldError? validateGitIdentityName(String value) {
  final name = value.trim();
  if (name.isEmpty) return GitIdentityFieldError.required;
  if (name.contains('<') ||
      name.contains('>') ||
      name.contains(_controlChars)) {
    return GitIdentityFieldError.invalid;
  }
  return null;
}

/// A shape check only; the daemon has the final say on the address.
GitIdentityFieldError? validateGitIdentityEmail(String value) {
  final email = value.trim();
  if (email.isEmpty) return GitIdentityFieldError.required;
  if (!_emailShape.hasMatch(email) || email.contains(_controlChars)) {
    return GitIdentityFieldError.invalid;
  }
  return null;
}
