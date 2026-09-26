import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/provider_versions.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_circular_progress_indicator.dart';

/// Per-machine banner shown above [MachineProviderVersions] when a coding
/// agent on this machine has an update available. The user can update from the
/// banner or dismiss it until the next check.
///
/// After a successful update, the banner prompts the user to restart sessions
/// so they pick up the new binary. The daemon handles the actual restart.
class AgentUpdateBanner extends ConsumerStatefulWidget {
  const AgentUpdateBanner({
    required this.machineId,
    required this.machineName,
    required this.isOnline,
    super.key,
  });

  final String machineId;
  final String machineName;
  final bool isOnline;

  @override
  ConsumerState<AgentUpdateBanner> createState() => _AgentUpdateBannerState();
}

class _AgentUpdateBannerState extends ConsumerState<AgentUpdateBanner> {
  Map<CodingAgent, ProviderVersion> _versions = {};
  bool _loading = false;
  String? _error;
  final Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  @override
  void didUpdateWidget(covariant AgentUpdateBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.machineId != widget.machineId) {
      _dismissed.clear();
      _loadVersions();
    }
  }

  Future<void> _loadVersions() async {
    if (!widget.isOnline) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await sync.machineGetProviderVersions(
        machineId: widget.machineId,
        refresh: false,
      );
      if (!mounted) return;
      if (response.success) {
        setState(() {
          _versions = {for (final p in response.providers) p.provider: p};
          _error = null;
        });
      } else {
        setState(() => _error = response.error);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateProvider(CodingAgent agent) async {
    final l10n = context.l10n;
    setState(() => _loading = true);
    try {
      final response = await sync.machineUpdateProvider(
        machineId: widget.machineId,
        provider: agent,
      );
      if (!mounted) return;
      if (response.success) {
        setState(() {
          if (response.provider != null) {
            _versions[agent] = response.provider!;
          }
          _dismissed.remove(agent.wireValue);
        });
        final provider = _versions[agent];
        if (provider != null && provider.version != null) {
          _showRestartDialog(agent, provider.version!);
        }
      } else {
        setState(
          () => _error = response.error ?? l10n.machineAgentsUpdateFailed,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showRestartDialog(CodingAgent agent, String version) {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.machineAgentsRestartTitle),
        content: Text(
          l10n.machineAgentsRestartMessage(
            agent.displayName,
            version,
            widget.machineName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.machineAgentsRestartSkip),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.machineAgentsRestartSessions),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final updatable = <MapEntry<CodingAgent, ProviderVersion>>[];
    for (final agent in CodingAgent.values) {
      final v = _versions[agent];
      if (v == null || !v.installed || !v.updateAvailable || !v.canUpdate) {
        continue;
      }
      if (_dismissed.contains(agent.wireValue)) continue;
      updatable.add(MapEntry(agent, v));
    }

    if (updatable.isEmpty && !_loading && _error == null) {
      return const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppDuration.normal,
      curve: AppCurve.standard,
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading && updatable.isEmpty)
              Row(
                children: [
                  const SizedBox.square(
                    dimension: 16,
                    child: AppCircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(l10n.machineAgentsChecking),
                ],
              )
            else ...[
              for (final entry in updatable) ...[
                Row(
                  children: [
                    Icon(
                      Icons.system_update_alt_rounded,
                      size: 18,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.machineAgentsBannerTitle(entry.key.displayName),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  l10n.machineAgentsBannerSubtitle(
                    entry.value.version ?? l10n.machineAgentsUnknown,
                    entry.value.latestVersion ?? l10n.machineAgentsUnknown,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() => _dismissed.add(entry.key.wireValue));
                      },
                      child: Text(l10n.machineAgentsBannerDismiss),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    FilledButton.tonal(
                      onPressed: () => _updateProvider(entry.key),
                      child: Text(l10n.machineAgentsBannerUpdate),
                    ),
                  ],
                ),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
