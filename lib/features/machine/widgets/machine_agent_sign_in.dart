import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/components/settings_section.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/rpc/rpc_types.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/clipboard_feedback.dart';
import '../../../core/utils/snack.dart';
import '../../../core/widgets/app_linear_progress_indicator.dart';

/// Signs a machine's coding agents in from the app.
///
/// Codex runs its device-code flow on the daemon (the resulting login is
/// what every Codex session on the machine uses). Claude Code's shared
/// credentials only exist for Kubernetes machines ([showClaude]).
class MachineAgentSignIn extends StatefulWidget {
  const MachineAgentSignIn({
    required this.machineId,
    required this.isOnline,
    required this.showClaude,
    super.key,
  });

  final String machineId;
  final bool isOnline;
  final bool showClaude;

  @override
  State<MachineAgentSignIn> createState() => _MachineAgentSignInState();
}

class _MachineAgentSignInState extends State<MachineAgentSignIn> {
  CodexAuthResponse? _codex;
  bool? _claudeAuthenticated;

  @override
  void initState() {
    super.initState();
    if (widget.isOnline) Future<void>.microtask(_refresh);
  }

  @override
  void didUpdateWidget(covariant MachineAgentSignIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline &&
        (!oldWidget.isOnline || oldWidget.machineId != widget.machineId)) {
      Future<void>.microtask(_refresh);
    }
  }

  Future<void> _refresh() async {
    final machineId = widget.machineId;
    await Future.wait([
      sync
          .machineCodexAuthStatus(machineId: machineId)
          .then((codex) {
            if (mounted && machineId == widget.machineId) {
              setState(() => _codex = codex);
            }
          })
          // Older daemons lack codex-auth-status; the row stays generic.
          .catchError((Object _) {}),
      if (widget.showClaude)
        sync
            .machineClaudeAuthStatus(machineId: machineId)
            .then((claude) {
              if (mounted && machineId == widget.machineId) {
                setState(() => _claudeAuthenticated = claude.authenticated);
              }
            })
            .catchError((Object _) {}),
    ]);
  }

  String _codexSubtitle(AppLocalizations l10n) {
    final codex = _codex;
    if (codex == null) return l10n.codexAuthHelp;
    if (!codex.authenticated) return l10n.codexAuthSignedOut;
    if (codex.authMode == 'apiKey') return l10n.codexAuthApiKey;
    final who = codex.email.isEmpty ? 'ChatGPT' : codex.email;
    return codex.planType.isEmpty
        ? l10n.codexAuthSignedInAs(who)
        : l10n.codexAuthSignedInAsPlan(who, _planLabel(codex.planType));
  }

  Future<void> _openCodex() async {
    final signedIn = await showDialog<CodexAuthResponse>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CodexAuthDialog(machineId: widget.machineId),
    );
    if (!mounted) return;
    if (signedIn != null) {
      setState(() => _codex = signedIn);
      context.showSnack(
        signedIn.email.isEmpty
            ? context.l10n.codexAuthDone
            : context.l10n.codexAuthDoneAs(signedIn.email),
      );
    }
    unawaited(_refresh());
  }

  Future<void> _openClaude() async {
    final signedIn = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ClaudeAuthDialog(machineId: widget.machineId),
    );
    if (!mounted) return;
    if (signedIn == true) {
      setState(() => _claudeAuthenticated = true);
      context.showSnack(context.l10n.claudeAuthDone);
    }
    unawaited(_refresh());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsSection(
      title: l10n.agentSignInTitle,
      children: [
        SettingsNavRow(
          icon: Icons.login,
          title: l10n.codexAuthTitle,
          subtitle: _codexSubtitle(l10n),
          onTap: widget.isOnline ? _openCodex : null,
        ),
        if (widget.showClaude)
          SettingsNavRow(
            icon: Icons.key_outlined,
            title: l10n.claudeAuthSharedCredentials,
            subtitle: switch (_claudeAuthenticated) {
              true => l10n.claudeAuthSignedIn,
              false => l10n.claudeAuthSignedOut,
              null => l10n.claudeAuthSharedCredentialsHelp,
            },
            onTap: widget.isOnline ? _openClaude : null,
          ),
      ],
    );
  }
}

String _planLabel(String plan) => switch (plan) {
  'plus' => 'Plus',
  'pro' => 'Pro',
  'prolite' => 'Pro Lite',
  'team' => 'Team',
  'business' => 'Business',
  'enterprise' => 'Enterprise',
  'edu' => 'Edu',
  'free' => 'Free',
  'go' => 'Go',
  _ => plan,
};

// ─────────────────────────────────────────────────────────────────────────────
// Codex: device code — open the link, enter the code, the daemon finishes.
// ─────────────────────────────────────────────────────────────────────────────

class _CodexAuthDialog extends StatefulWidget {
  const _CodexAuthDialog({required this.machineId});
  final String machineId;

  @override
  State<_CodexAuthDialog> createState() => _CodexAuthDialogState();
}

class _CodexAuthDialogState extends State<_CodexAuthDialog> {
  static const _pollInterval = Duration(seconds: 2);

  CodexAuthResponse? _account;
  CodexAuthResponse? _flow;
  String? _error;
  bool _busy = true;
  Timer? _poll;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final account = await sync.machineCodexAuthStatus(
        machineId: widget.machineId,
      );
      if (!mounted) return;
      if (!account.authenticated) {
        await _begin();
        return;
      }
      setState(() => _account = account);
    } catch (error) {
      if (mounted) setState(() => _error = _describe(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _begin({bool force = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final flow = await sync.machineBeginCodexAuth(
        machineId: widget.machineId,
        force: force,
      );
      if (!mounted) return;
      setState(() => _flow = flow);
      _poll?.cancel();
      _poll = Timer.periodic(_pollInterval, (_) => _checkFlow());
      final uri = Uri.tryParse(flow.verificationUrl);
      if (uri != null) {
        unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
      }
    } catch (error) {
      if (mounted) setState(() => _error = _describe(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _checking = false;

  Future<void> _checkFlow() async {
    final flowId = _flow?.flowId;
    if (flowId == null || _checking || _closed) return;
    _checking = true;
    try {
      final status = await sync.machineCodexAuthStatus(
        machineId: widget.machineId,
        flowId: flowId,
      );
      if (!mounted || _closed) return;
      if (status.status == 'authenticated') {
        _poll?.cancel();
        _closed = true;
        Navigator.of(context).pop(status);
        return;
      }
      if (!status.isPending) {
        _poll?.cancel();
        setState(() {
          _flow = null;
          _error = switch (status.status) {
            'expired' || 'not_found' => context.l10n.codexAuthExpired,
            'cancelled' => context.l10n.codexAuthCancelled,
            _ =>
              status.error.isEmpty
                  ? context.l10n.codexAuthFailed
                  : status.error,
          };
        });
      }
    } catch (_) {
      // Transient RPC failures are retried on the next tick.
    } finally {
      _checking = false;
    }
  }

  void _close() {
    _closed = true;
    _poll?.cancel();
    final flow = _flow;
    if (flow != null && flow.isPending) {
      unawaited(
        sync
            .machineCancelCodexAuth(
              machineId: widget.machineId,
              flowId: flow.flowId,
            )
            .then((_) {}, onError: (Object _) {}),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final flow = _flow;
    final account = _account;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: AlertDialog(
        title: Text(l10n.codexAuthTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (flow != null) ...[
                Text(l10n.codexAuthStepOpen),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(flow.verificationUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(Uri.parse(flow.verificationUrl).host),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.codexAuthStepCode),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SelectableText(
                      flow.userCode,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.commonCopyCode,
                      icon: const Icon(Icons.copy),
                      onPressed: () => copyWithFeedback(context, flow.userCode),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.codexAuthWaiting,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                const AppLinearProgressIndicator(),
              ] else if (account != null && _error == null) ...[
                Text(
                  account.authMode == 'apiKey'
                      ? l10n.codexAuthApiKey
                      : account.planType.isEmpty
                      ? l10n.codexAuthSignedInAs(
                          account.email.isEmpty ? 'ChatGPT' : account.email,
                        )
                      : l10n.codexAuthSignedInAsPlan(
                          account.email.isEmpty ? 'ChatGPT' : account.email,
                          _planLabel(account.planType),
                        ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.codexAuthAgainHelp, style: theme.textTheme.bodySmall),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              if (_busy) ...[
                const SizedBox(height: AppSpacing.md),
                const AppLinearProgressIndicator(),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _close,
            child: Text(flow != null ? l10n.commonCancel : l10n.commonClose),
          ),
          if (flow == null)
            FilledButton(
              onPressed: _busy ? null : () => _begin(force: true),
              child: Text(
                account != null && _error == null
                    ? l10n.codexAuthAgain
                    : l10n.codexAuthBegin,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Claude Code: open the link, paste the code back, the daemon finishes.
// ─────────────────────────────────────────────────────────────────────────────

class _ClaudeAuthDialog extends StatefulWidget {
  const _ClaudeAuthDialog({required this.machineId});
  final String machineId;

  @override
  State<_ClaudeAuthDialog> createState() => _ClaudeAuthDialogState();
}

class _ClaudeAuthDialogState extends State<_ClaudeAuthDialog> {
  static const _pollInterval = Duration(seconds: 2);
  static const _completionBudget = Duration(minutes: 2);

  final _responseController = TextEditingController();
  String? _flowId;
  String? _authorizationUrl;
  String? _status;
  String? _error;
  bool _busy = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_checkStatus);
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() => _busy = true);
    try {
      final response = await sync.machineClaudeAuthStatus(
        machineId: widget.machineId,
      );
      if (!mounted) return;
      setState(() {
        _status = response.authenticated ? 'authenticated' : response.status;
      });
    } catch (_) {
      // An old daemon may not implement status yet. Begin surfaces a useful
      // error if the user chooses to authenticate.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _begin() async {
    setState(() {
      _busy = true;
      _error = null;
      _responseController.clear();
    });
    try {
      final response = await sync.machineBeginClaudeAuth(
        machineId: widget.machineId,
        force: true,
      );
      if (!mounted) return;
      setState(() {
        _flowId = response.flowId;
        _authorizationUrl = response.authorizationUrl;
        _status = response.status;
      });
      final uri = Uri.tryParse(response.authorizationUrl);
      if (uri != null) {
        unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
      }
    } catch (error) {
      if (mounted) setState(() => _error = _describe(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    final flowId = _flowId;
    final authResponse = _responseController.text.trim();
    if (flowId == null || authResponse.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var response = await sync.machineCompleteClaudeAuth(
        machineId: widget.machineId,
        flowId: flowId,
        authResponse: authResponse,
      );
      // A slow token exchange keeps running on the daemon; follow it.
      final deadline = DateTime.now().add(_completionBudget);
      while (mounted &&
          !_closed &&
          response.status == 'completing' &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(_pollInterval);
        response = await sync.machineClaudeAuthStatus(
          machineId: widget.machineId,
          flowId: flowId,
        );
      }
      if (!mounted || _closed) return;
      if (response.authenticated) {
        _closed = true;
        Navigator.of(context).pop(true);
        return;
      }
      _failFlow(
        response.error.isNotEmpty
            ? response.error
            : context.l10n.claudeAuthFailed,
      );
    } catch (error) {
      if (mounted) _failFlow(_describe(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A rejected or expired response ends the daemon's flow; offer a new one
  /// instead of leaving a Complete button that can never succeed.
  void _failFlow(String message) {
    setState(() {
      _error = message;
      _flowId = null;
      _authorizationUrl = null;
      _status = null;
    });
  }

  void _close() {
    _closed = true;
    final flowId = _flowId;
    if (flowId != null && !_busy) {
      unawaited(
        sync
            .machineCancelClaudeAuth(
              machineId: widget.machineId,
              flowId: flowId,
            )
            .then((_) {}, onError: (Object _) {}),
      );
    }
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authenticated = _status == 'authenticated';
    final url = _authorizationUrl;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _close();
      },
      child: AlertDialog(
        title: Text(l10n.claudeAuthTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                authenticated && url == null
                    ? l10n.claudeAuthAuthenticated
                    : l10n.claudeAuthInstructions,
              ),
              if (url != null) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => launchUrl(
                          Uri.parse(url),
                          mode: LaunchMode.externalApplication,
                        ),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.claudeAuthOpenLink),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _responseController,
                  enabled: !_busy,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _complete(),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.claudeAuthResponse,
                    hintText: l10n.claudeAuthResponseHint,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: AppSpacing.md),
                const AppLinearProgressIndicator(),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : _close,
            child: Text(url != null ? l10n.commonCancel : l10n.commonClose),
          ),
          if (url == null)
            FilledButton(
              onPressed: _busy ? null : _begin,
              child: Text(
                authenticated ? l10n.claudeAuthAgain : l10n.claudeAuthBegin,
              ),
            )
          else
            FilledButton(
              onPressed: _busy || _responseController.text.trim().isEmpty
                  ? null
                  : _complete,
              child: Text(l10n.claudeAuthComplete),
            ),
        ],
      ),
    );
  }
}

String _describe(Object error) {
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}
