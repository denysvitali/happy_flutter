import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/socket_io_client.dart';
import '../../../core/components/app_card.dart';
import '../../../core/components/app_section_header.dart';
import '../../../core/dialogs/confirm_dialog.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/provider_versions.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_circular_progress_indicator.dart';

/// Checks and updates the coding agents installed on one connected machine.
class MachineProviderVersions extends StatefulWidget {
  const MachineProviderVersions({
    required this.machineId,
    required this.machineName,
    required this.isOnline,
    super.key,
  });

  final String machineId;
  final String machineName;
  final bool isOnline;

  @override
  State<MachineProviderVersions> createState() =>
      _MachineProviderVersionsState();
}

class _MachineProviderVersionsState extends State<MachineProviderVersions> {
  Map<CodingAgent, ProviderVersion> _versions = {};
  Timer? _pollTimer;
  bool _checking = false;
  bool _confirming = false;
  CodingAgent? _startingProvider;
  String? _error;
  int _generation = 0;
  int _requestSerial = 0;

  bool get _hasRunningUpdate => _versions.values.any((v) => v.isUpdating);
  bool get _busy =>
      _checking ||
      _confirming ||
      _startingProvider != null ||
      (_hasRunningUpdate && _error == null);

  @override
  void didUpdateWidget(covariant MachineProviderVersions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.machineId != widget.machineId) {
      _generation++;
      _pollTimer?.cancel();
      _versions = {};
      _checking = false;
      _confirming = false;
      _startingProvider = null;
      _error = null;
    } else if (!widget.isOnline) {
      _pollTimer?.cancel();
    } else if (!oldWidget.isOnline && _hasRunningUpdate) {
      _schedulePoll();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  bool _isCurrent(int generation) => mounted && generation == _generation;

  bool _isCurrentRequest(int generation, int request) =>
      _isCurrent(generation) && request == _requestSerial;

  Future<void> _check() async {
    if (!widget.isOnline || _busy) return;
    await _loadVersions(refresh: true);
  }

  Future<void> _loadVersions({required bool refresh}) async {
    if (!widget.isOnline) return;
    final generation = _generation;
    final request = ++_requestSerial;
    _pollTimer?.cancel();
    if (refresh) {
      setState(() {
        _checking = true;
        _error = null;
      });
    }
    try {
      final response = await sync.machineGetProviderVersions(
        machineId: widget.machineId,
        refresh: refresh,
      );
      if (!_isCurrentRequest(generation, request)) return;
      if (!response.success || response.providers.isEmpty) {
        setState(() {
          _error =
              response.error ??
              (_hasRunningUpdate
                  ? context.l10n.machineAgentsUpdateUncertain
                  : context.l10n.machineAgentsCheckFailed);
        });
        return;
      }
      setState(() {
        _versions = {
          for (final provider in response.providers)
            provider.provider: provider,
        };
        _error = null;
      });
      _schedulePoll();
    } catch (error) {
      if (!_isCurrentRequest(generation, request)) return;
      setState(() {
        _error = _describeError(error, duringUpdate: _hasRunningUpdate);
      });
    } finally {
      if (_isCurrentRequest(generation, request) && _checking) {
        setState(() => _checking = false);
      }
    }
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    if (!widget.isOnline || !_hasRunningUpdate) return;
    _pollTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_loadVersions(refresh: false));
    });
  }

  Future<void> _update(ProviderVersion provider) async {
    if (!widget.isOnline || _busy || _error != null) return;
    final generation = _generation;
    setState(() => _confirming = true);
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.machineAgentsUpdateConfirmTitle(
        provider.provider.displayName,
      ),
      content: context.l10n.machineAgentsUpdateConfirm(
        provider.provider.displayName,
        widget.machineName,
      ),
      confirmLabel: context.l10n.machineAgentsUpdate,
    );
    if (!_isCurrent(generation)) return;
    setState(() => _confirming = false);
    if (!confirmed || !widget.isOnline) return;

    setState(() => _startingProvider = provider.provider);
    try {
      final response = await sync.machineUpdateProvider(
        machineId: widget.machineId,
        provider: provider.provider,
      );
      if (!_isCurrent(generation)) return;
      final updated = response.provider;
      if (updated != null && updated.provider == provider.provider) {
        setState(() => _versions[provider.provider] = updated);
      }
      if (!response.success ||
          updated == null ||
          updated.provider != provider.provider) {
        setState(() {
          _error = response.error ?? context.l10n.machineAgentsUpdateFailed;
        });
        return;
      }
      _schedulePoll();
    } catch (error) {
      if (!_isCurrent(generation)) return;
      setState(() => _error = _describeError(error, duringUpdate: true));
    } finally {
      if (_isCurrent(generation)) {
        setState(() => _startingProvider = null);
      }
    }
  }

  String _describeError(Object error, {required bool duringUpdate}) {
    final l10n = context.l10n;
    if (error is RpcException) {
      if (error.code == RpcErrorCode.methodUnsupported) {
        return l10n.machineAgentsUnsupported;
      }
      if (error.code == RpcErrorCode.protocolUnsupported) {
        return l10n.machineAgentsProtocolUnsupported;
      }
      if (error.code == RpcErrorCode.handlerOffline) {
        return duringUpdate
            ? l10n.machineAgentsUpdateUncertain
            : l10n.machineAgentsOffline;
      }
    }
    if (error is SocketNotConnectedException && !duringUpdate) {
      return l10n.machineAgentsOffline;
    }
    return duringUpdate
        ? l10n.machineAgentsUpdateUncertain
        : l10n.machineAgentsCheckFailed;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(title: l10n.machineAgentsTitle),
        const SizedBox(height: AppSpacing.xs),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isOnline
                    ? l10n.machineAgentsDescription
                    : l10n.machineAgentsOffline,
                style: theme.textTheme.bodyMedium,
              ),
              for (final agent in CodingAgent.values) ...[
                const SizedBox(height: AppSpacing.md),
                _providerRow(agent),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('check-provider-versions'),
                  onPressed: widget.isOnline && !_busy ? _check : null,
                  icon: _checking
                      ? const SizedBox.square(
                          dimension: 16,
                          child: AppCircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(
                    _checking
                        ? l10n.machineAgentsChecking
                        : l10n.machineAgentsCheck,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _providerRow(CodingAgent agent) {
    final provider = _versions[agent];
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final running = provider?.isUpdating == true || _startingProvider == agent;
    final canUpdate =
        provider != null &&
        provider.installed &&
        provider.canUpdate &&
        provider.updateAvailable;
    return Column(
      key: ValueKey('provider-${agent.wireValue}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          agent.displayName,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (provider != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            provider.installed
                ? l10n.machineAgentsInstalled(
                    provider.version ?? l10n.machineAgentsUnknown,
                  )
                : l10n.machineAgentsNotInstalled,
          ),
          if (provider.latestVersion != null)
            Text(l10n.machineAgentsLatest(provider.latestVersion!)),
          if (running)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  const SizedBox.square(
                    dimension: 14,
                    child: AppCircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(l10n.machineAgentsUpdating),
                ],
              ),
            )
          else if (provider.updateStatus == 'failed')
            Text(
              provider.updateError ?? l10n.machineAgentsUpdateFailed,
              style: TextStyle(color: theme.colorScheme.error),
            )
          else if (provider.updateStatus == 'succeeded' &&
              !provider.updateAvailable)
            Text(l10n.machineAgentsUpdated)
          else if (provider.installed &&
              provider.version != null &&
              provider.latestVersion != null &&
              provider.error == null)
            Text(
              provider.updateAvailable
                  ? l10n.machineAgentsUpdateAvailable
                  : l10n.machineAgentsUpToDate,
            ),
          if (provider.error != null)
            Text(
              provider.error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          if (provider.updateMessage != null)
            Text(provider.updateMessage!, style: theme.textTheme.bodySmall)
          else if (provider.installed &&
              provider.updateAvailable &&
              !provider.canUpdate)
            Text(
              l10n.machineAgentsManagedElsewhere,
              style: theme.textTheme.bodySmall,
            ),
          if (canUpdate && !running)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: FilledButton.tonal(
                key: ValueKey('update-provider-${agent.wireValue}'),
                onPressed: widget.isOnline && !_busy && _error == null
                    ? () => _update(provider)
                    : null,
                child: Text(l10n.machineAgentsUpdate),
              ),
            ),
        ],
      ],
    );
  }
}
