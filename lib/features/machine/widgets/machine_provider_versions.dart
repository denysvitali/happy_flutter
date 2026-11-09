import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/socket_io_client.dart';
import '../../../core/components/app_banner.dart';
import '../../../core/components/settings_section.dart';
import '../../../core/dialogs/confirm_dialog.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/provider_versions.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_colors.dart' show AppOpacity;
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_circular_progress_indicator.dart';
import 'package:happy_flutter/core/theme/app_text.dart';

import '../../sessions/harness_logo.dart';

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
    final cs = theme.colorScheme;
    return SettingsSection(
      title: l10n.machineAgentsTitle,
      description: widget.isOnline
          ? l10n.machineAgentsDescription
          : l10n.machineAgentsOffline,
      children: [
        for (final agent in CodingAgent.values) _providerRow(agent),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppBanner(tone: AppBadgeTone.danger, message: _error),
          ),
        SettingsRow(
          key: const ValueKey('check-provider-versions'),
          icon: Icons.refresh_rounded,
          title: _checking
              ? l10n.machineAgentsChecking
              : l10n.machineAgentsCheck,
          onTap: widget.isOnline && !_busy ? _check : null,
          semanticsButton: true,
          semanticsEnabled: widget.isOnline && !_busy,
          trailing: _checking
              ? const SizedBox.square(
                  dimension: AppIconSize.md,
                  child: AppCircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.chevron_right,
                  size: AppSpacing.xl,
                  color: cs.onSurface.withValues(alpha: AppOpacity.medium),
                ),
        ),
      ],
    );
  }

  Widget _providerRow(CodingAgent agent) {
    final provider = _versions[agent];
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final running = provider?.isUpdating == true || _startingProvider == agent;
    final canUpdate =
        provider != null &&
        provider.installed &&
        provider.canUpdate &&
        provider.updateAvailable;
    final secondary = AppText.secondary(theme, cs.onSurfaceVariant);
    final warning = AppToneColors.of(context, AppBadgeTone.warning).foreground;
    final success = AppToneColors.of(context, AppBadgeTone.success).foreground;

    // One status line under the versions: what the user should know now.
    Widget? status;
    if (provider != null) {
      if (running) {
        status = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: AppIconSize.xs,
              child: AppCircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(l10n.machineAgentsUpdating, style: secondary),
          ],
        );
      } else if (provider.updateStatus == 'failed') {
        status = Text(
          provider.updateError ?? l10n.machineAgentsUpdateFailed,
          style: AppText.secondary(theme, cs.error),
        );
      } else if (provider.updateStatus == 'succeeded' &&
          !provider.updateAvailable) {
        status = Text(
          l10n.machineAgentsUpdated,
          style: AppText.secondary(theme, success),
        );
      } else if (provider.installed &&
          provider.version != null &&
          provider.latestVersion != null &&
          provider.error == null) {
        status = Text(
          provider.updateAvailable
              ? l10n.machineAgentsUpdateAvailable
              : l10n.machineAgentsUpToDate,
          style: AppText.secondary(
            theme,
            provider.updateAvailable ? warning : success,
          ),
        );
      }
    }

    return Padding(
      key: ValueKey('provider-${agent.wireValue}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: kSettingsIconContainerSize,
            height: kSettingsIconContainerSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: HarnessLogo(flavor: agent.wireValue, size: AppIconSize.lg),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agent.displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (provider != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Wrap(
                    children: [
                      Text(
                        provider.installed
                            ? l10n.machineAgentsInstalled(
                                provider.version ?? l10n.machineAgentsUnknown,
                              )
                            : l10n.machineAgentsNotInstalled,
                        style: secondary,
                      ),
                      if (provider.latestVersion != null) ...[
                        Text(' · ', style: secondary),
                        Text(
                          l10n.machineAgentsLatest(provider.latestVersion!),
                          style: secondary,
                        ),
                      ],
                    ],
                  ),
                  if (status != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    status,
                  ],
                  if (provider.error != null)
                    Text(
                      provider.error!,
                      style: AppText.secondary(theme, cs.error),
                    ),
                  if (provider.updateMessage != null)
                    Text(provider.updateMessage!, style: secondary)
                  else if (provider.installed &&
                      provider.updateAvailable &&
                      !provider.canUpdate)
                    Text(l10n.machineAgentsManagedElsewhere, style: secondary),
                ] else ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(l10n.machineAgentsNotChecked, style: secondary),
                ],
              ],
            ),
          ),
          if (canUpdate && !running) ...[
            const SizedBox(width: AppSpacing.sm),
            FilledButton.tonal(
              key: ValueKey('update-provider-${agent.wireValue}'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              ),
              onPressed: widget.isOnline && !_busy && _error == null
                  ? () => _update(provider)
                  : null,
              child: Text(l10n.machineAgentsUpdate),
            ),
          ],
        ],
      ),
    );
  }
}
