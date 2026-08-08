import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/socket_io_client.dart'
    show ConnectionStatus, socketIoClient;
import '../../../core/components/settings_section.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/server_config.dart';
import '../../../core/services/sync_health_snapshot.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/clipboard_utils.dart';

class SettingsHealthSection extends ConsumerWidget {
  const SettingsHealthSection({
    required this.sessionTotal,
    required this.onlineSessions,
    required this.machineTotal,
    required this.onlineMachines,
    super.key,
  });

  final int sessionTotal;
  final int onlineSessions;
  final int machineTotal;
  final int onlineMachines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final syncState = ref.watch(syncStateNotifierProvider);
    final isOnline = ref.watch(networkNotifierProvider);
    final connected = connectionStatus == ConnectionStatus.connected;
    final syncReady = sync.isReady && connected && isOnline;
    final syncInitialized = sync.isInitialized;
    final syncColor = syncReady
        ? AppColors.success
        : syncInitialized
        ? AppColors.warning
        : AppColors.error;
    final syncSubtitle = syncReady
        ? syncState.isSyncing
              ? l10n.settingsHealthApplyingUpdates
              : l10n.settingsHealthReady
        : !isOnline
        ? l10n.settingsHealthOffline
        : connected && syncInitialized
        ? l10n.settingsHealthLoading
        : l10n.settingsHealthReconnecting;
    final machineSubtitle = machineTotal == 0
        ? l10n.settingsHealthNoMachines
        : l10n.settingsHealthMachinesOnline(onlineMachines, machineTotal);

    return SettingsSection(
      title: l10n.settingsHealthStatus,
      children: [
        SettingsRow(
          icon: Icons.sync,
          iconColor: syncColor,
          title: syncReady
              ? l10n.settingsHealthSyncReady
              : l10n.settingsHealthSyncAttention,
          subtitle: syncSubtitle,
          trailing: Icon(
            syncReady ? Icons.check_circle : Icons.error_outline,
            color: syncColor,
          ),
          onTap: () => _showConnectionDiagnostics(
            context,
            isOnline: isOnline,
            status: connectionStatus,
            syncReady: syncReady,
          ),
        ),
        SettingsRow(
          icon: Icons.chat_bubble_outline,
          iconColor: AppColors.iosBlue,
          title: l10n.settingsSessions,
          subtitle: l10n.settingsHealthSessionsOnline(
            onlineSessions,
            sessionTotal,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.goNamed('sessions'),
        ),
        SettingsRow(
          icon: Icons.computer_outlined,
          iconColor: machineTotal == 0 ? AppColors.warning : AppColors.success,
          title: l10n.settingsMachines,
          subtitle: machineSubtitle,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushNamed('machines'),
        ),
        SettingsRow(
          icon: Icons.person_outline,
          iconColor: AppColors.iosBlue,
          title: l10n.settingsHealthAccountRecovery,
          subtitle: l10n.settingsHealthAccountRecoverySubtitle,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushNamed('account'),
        ),
      ],
    );
  }

  void _showConnectionDiagnostics(
    BuildContext context, {
    required bool isOnline,
    required ConnectionStatus status,
    required bool syncReady,
  }) {
    final l10n = context.l10n;
    final health = SyncHealthSnapshot.capture(
      networkOnline: isOnline,
      connectionStatus: status,
    );
    final reason = socketIoClient.lastDisconnectReason;
    final disconnectedAt = socketIoClient.lastDisconnectAtMs;
    final disconnectedFor = disconnectedAt == null
        ? null
        : DateTime.now().millisecondsSinceEpoch - disconnectedAt;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.9,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.connectionDiagnosticsTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: ListView(
                    children: [
                      _DiagnosticLine(
                        label: l10n.connectionDiagnosticsNetwork,
                        value: isOnline
                            ? l10n.statusOnline
                            : l10n.statusOffline,
                      ),
                      _DiagnosticLine(
                        label: l10n.connectionDiagnosticsLiveUpdates,
                        value: _localizedConnectionStatus(l10n, status),
                      ),
                      _DiagnosticLine(
                        label: l10n.connectionDiagnosticsLastDisconnect,
                        value: reason == null
                            ? l10n.connectionDiagnosticsNoDisconnect
                            : _localizedFailure(l10n, reason),
                      ),
                      if (disconnectedFor != null)
                        _DiagnosticLine(
                          label: l10n.connectionDiagnosticsDisconnectedFor,
                          value: _formatElapsed(l10n, disconnectedFor),
                        ),
                      _DiagnosticLine(
                        label: l10n.connectionDiagnosticsReconnectAttempt,
                        value: '${health.reconnectAttempt}',
                      ),
                      _DiagnosticLine(
                        label: l10n.settingsHealthSocketGeneration,
                        value: '${health.socketGeneration}',
                      ),
                      _DiagnosticLine(
                        label: l10n.settingsHealthLastSocketEvent,
                        value: health.lastSocketEventAtMs == null
                            ? l10n.settingsHealthNoSocketEvent
                            : _formatElapsed(
                                l10n,
                                health.capturedAtMs -
                                    health.lastSocketEventAtMs!,
                              ),
                      ),
                      _DiagnosticLine(
                        label: l10n.settingsHealthOutbox,
                        value: l10n.settingsHealthOutboxCounts(
                          health.pendingOutboxCount,
                          health.deadLetterCount,
                        ),
                      ),
                      FutureBuilder<ServerUrlVerificationResult>(
                        future: verifyServerUrl(getServerUrl()),
                        builder: (context, snapshot) {
                          final result = snapshot.data;
                          final value = result == null
                              ? l10n.connectionDiagnosticsCheckingService
                              : result.serviceStatus == 'degraded'
                              ? l10n.connectionDiagnosticsServiceDegradedSafe
                              : result.isValid
                              ? l10n.statusOnline
                              : _localizedFailure(
                                  l10n,
                                  result.errorType ?? result.errorMessage,
                                );
                          return _DiagnosticLine(
                            label: l10n.connectionDiagnosticsService,
                            value: value,
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.settingsHealthSyncDomains,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      for (final domain in health.domains)
                        _DiagnosticLine(
                          label: _localizedDomain(l10n, domain.domain),
                          value: _localizedDomainHealth(l10n, health, domain),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await setClipboardTextSafely(
                            health.toRedactedText(),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result.success
                                    ? l10n.commonCopiedToClipboard
                                    : l10n.textSelectionFailedToCopy,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_outlined),
                        label: Text(l10n.settingsHealthCopyDiagnostics),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: syncReady
                            ? null
                            : () {
                                sync.forceReconnect(
                                  reason: 'settings_diagnostics',
                                );
                                Navigator.of(context).pop();
                              },
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          syncReady
                              ? l10n.statusOnline
                              : l10n.offlineBannerReconnectNow,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _localizedConnectionStatus(
    AppLocalizations l10n,
    ConnectionStatus status,
  ) => switch (status) {
    ConnectionStatus.connected => l10n.statusConnected,
    ConnectionStatus.connecting => l10n.statusConnecting,
    ConnectionStatus.disconnected => l10n.statusDisconnected,
    ConnectionStatus.error => l10n.statusError,
  };

  String _localizedFailure(AppLocalizations l10n, String? raw) {
    final normalized = raw?.toLowerCase() ?? '';
    if (normalized.contains('auth') || normalized.contains('401')) {
      return l10n.connectionDiagnosticsAuthenticationRequired;
    }
    if (normalized.contains('timeout')) {
      return l10n.connectionDiagnosticsTimedOut;
    }
    if (normalized.contains('closed') || normalized.contains('disconnect')) {
      return l10n.connectionDiagnosticsConnectionClosed;
    }
    return l10n.connectionDiagnosticsServiceUnavailable;
  }

  String _formatElapsed(AppLocalizations l10n, int milliseconds) {
    if (milliseconds < 0) return l10n.connectionDiagnosticsNoDisconnect;
    final seconds = milliseconds ~/ 1000;
    if (seconds < 60) return l10n.connectionDiagnosticsElapsedSeconds(seconds);
    final minutes = seconds ~/ 60;
    if (minutes < 60) return l10n.connectionDiagnosticsElapsedMinutes(minutes);
    return l10n.connectionDiagnosticsElapsedHoursMinutes(
      minutes ~/ 60,
      minutes % 60,
    );
  }

  String _localizedDomain(AppLocalizations l10n, SyncDomain domain) =>
      switch (domain) {
        SyncDomain.sessions => l10n.settingsHealthDomainSessions,
        SyncDomain.messages => l10n.settingsHealthDomainMessages,
        SyncDomain.machines => l10n.settingsHealthDomainMachines,
        SyncDomain.settings => l10n.settingsHealthDomainSettings,
        SyncDomain.profile => l10n.settingsHealthDomainProfile,
        SyncDomain.artifacts => l10n.settingsHealthDomainArtifacts,
        SyncDomain.gitStatus => l10n.settingsHealthDomainGitStatus,
        SyncDomain.friendRequests => l10n.settingsHealthDomainFriendRequests,
        SyncDomain.loops => l10n.settingsHealthDomainLoops,
        SyncDomain.workflows => l10n.settingsHealthDomainWorkflows,
      };

  String _localizedDomainHealth(
    AppLocalizations l10n,
    SyncHealthSnapshot snapshot,
    SyncDomainHealthSnapshot domain,
  ) {
    final state = domain.running
        ? l10n.settingsHealthDomainSyncing
        : domain.pending
        ? l10n.settingsHealthDomainQueued
        : _hasCurrentFailure(domain)
        ? l10n.settingsHealthDomainFailed(
            _localizedSyncFailure(l10n, domain.lastFailureKind),
          )
        : domain.lastSuccessAtMs == null
        ? l10n.settingsHealthDomainNoFreshness
        : l10n.settingsHealthDomainUpdated(
            _formatElapsed(
              l10n,
              snapshot.capturedAtMs - domain.lastSuccessAtMs!,
            ),
          );
    return l10n.settingsHealthDomainState(state, domain.revision);
  }

  bool _hasCurrentFailure(SyncDomainHealthSnapshot domain) =>
      domain.lastFailureAtMs != null &&
      (domain.lastSuccessAtMs == null ||
          domain.lastFailureAtMs! > domain.lastSuccessAtMs!);

  String _localizedSyncFailure(AppLocalizations l10n, String? failure) =>
      switch (failure) {
        'timeout' => l10n.connectionDiagnosticsTimedOut,
        'http' => l10n.connectionDiagnosticsServiceUnavailable,
        'decrypt' => l10n.settingsHealthFailureDecrypt,
        'disposed' => l10n.settingsHealthFailureInterrupted,
        'parse' => l10n.settingsHealthFailureInvalidData,
        _ => l10n.statusError,
      };
}

class _DiagnosticLine extends StatelessWidget {
  const _DiagnosticLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}
