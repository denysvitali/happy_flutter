import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/app_banner.dart';
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
/// After a successful update, the daemon automatically restarts sessions onto
/// the new binary; the banner shows an informational dialog confirming this.
class AgentUpdateBanner extends ConsumerStatefulWidget {
  const AgentUpdateBanner({
    required this.machineId,
    required this.machineName,
    required this.isOnline,
    this.topSpacing = 0,
    super.key,
  });

  /// Space above the banner, applied only while it is visible so a hidden
  /// banner leaves no gap in the parent list.
  final double topSpacing;

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
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.machineAgentsRestartSkip),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: widget.topSpacing),
          if (_loading && updatable.isEmpty)
            AppBanner(
              tone: AppBadgeTone.info,
              leading: const SizedBox.square(
                dimension: AppIconSize.md,
                child: AppCircularProgressIndicator(strokeWidth: 2),
              ),
              message: l10n.machineAgentsChecking,
            )
          else
            for (final (i, entry) in updatable.indexed) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              AppBanner(
                tone: AppBadgeTone.info,
                icon: Icons.system_update_alt_rounded,
                title: l10n.machineAgentsBannerTitle(entry.key.displayName),
                message: l10n.machineAgentsBannerSubtitle(
                  entry.value.version ?? l10n.machineAgentsUnknown,
                  entry.value.latestVersion ?? l10n.machineAgentsUnknown,
                ),
                footer: Row(
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
              ),
            ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppBanner(tone: AppBadgeTone.danger, message: _error),
          ],
        ],
      ),
    );
  }
}
