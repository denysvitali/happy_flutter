import 'dart:convert';

import '../api/socket_io_client.dart';
import '../sync/invalidate_sync.dart';
import 'message_outbox.dart';
import 'sync_service.dart';

class SyncDomainHealthSnapshot {
  const SyncDomainHealthSnapshot({
    required this.domain,
    required this.revision,
    this.running = false,
    this.pending = false,
    this.lastSuccessAtMs,
    this.lastFailureAtMs,
    this.lastFailureKind,
  });

  final SyncDomain domain;
  final int revision;
  final bool running;
  final bool pending;
  final int? lastSuccessAtMs;
  final int? lastFailureAtMs;
  final String? lastFailureKind;

  Map<String, Object?> toRedactedJson() => <String, Object?>{
    'domain': domain.name,
    'revision': revision,
    'running': running,
    'pending': pending,
    'lastSuccessAtMs': lastSuccessAtMs,
    'lastFailureAtMs': lastFailureAtMs,
    'lastFailureKind': lastFailureKind,
  };
}

/// Metadata-only sync health report suitable for clipboard bug reports.
///
/// It deliberately excludes URLs, ids, paths, payloads, disconnect prose,
/// message bodies, and outbox entries. Only bounded counters/categories and
/// timestamps are retained.
class SyncHealthSnapshot {
  const SyncHealthSnapshot({
    required this.capturedAtMs,
    required this.initialized,
    required this.ready,
    required this.networkOnline,
    required this.connectionStatus,
    required this.socketGeneration,
    required this.reconnectAttempt,
    required this.pendingOutboxCount,
    required this.deadLetterCount,
    required this.domains,
    this.lastSocketEventAtMs,
  });

  factory SyncHealthSnapshot.capture({
    required bool networkOnline,
    required ConnectionStatus connectionStatus,
  }) {
    final service = Sync();
    final managers = service.isInitialized
        ? <SyncDomain, List<InvalidateSync>>{
            SyncDomain.sessions: <InvalidateSync>[service.sessionsSync],
            SyncDomain.messages: service.messagesSync.values.toList(),
            SyncDomain.machines: <InvalidateSync>[service.machinesSync],
            SyncDomain.settings: <InvalidateSync>[service.settingsSync],
            SyncDomain.profile: <InvalidateSync>[service.profileSync],
            SyncDomain.artifacts: <InvalidateSync>[service.artifactsSync],
            SyncDomain.gitStatus: <InvalidateSync>[
              service.sessionGitStatusSync,
            ],
          }
        : const <SyncDomain, List<InvalidateSync>>{};

    return SyncHealthSnapshot(
      capturedAtMs: DateTime.now().millisecondsSinceEpoch,
      initialized: service.isInitialized,
      ready: service.isReady,
      networkOnline: networkOnline,
      connectionStatus: connectionStatus.name,
      socketGeneration: socketIoClient.connectionGeneration,
      lastSocketEventAtMs: socketIoClient.lastEventAtMs,
      reconnectAttempt: socketIoClient.dialAttempt,
      pendingOutboxCount: messageOutbox.entries.length,
      deadLetterCount: messageOutbox.deadEntries.length,
      domains: <SyncDomainHealthSnapshot>[
        for (final domain in SyncDomain.values)
          _domainSnapshot(
            domain,
            service.domainChangeCounter(domain),
            managers[domain] ?? const <InvalidateSync>[],
          ),
      ],
    );
  }

  final int capturedAtMs;
  final bool initialized;
  final bool ready;
  final bool networkOnline;
  final String connectionStatus;
  final int socketGeneration;
  final int? lastSocketEventAtMs;
  final int reconnectAttempt;
  final int pendingOutboxCount;
  final int deadLetterCount;
  final List<SyncDomainHealthSnapshot> domains;

  String toRedactedText() =>
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'schema': 'happy.sync-health.redacted.v1',
        'capturedAtMs': capturedAtMs,
        'initialized': initialized,
        'ready': ready,
        'networkOnline': networkOnline,
        'connectionStatus': connectionStatus,
        'socketGeneration': socketGeneration,
        'lastSocketEventAtMs': lastSocketEventAtMs,
        'reconnectAttempt': reconnectAttempt,
        'pendingOutboxCount': pendingOutboxCount,
        'deadLetterCount': deadLetterCount,
        'domains': domains.map((domain) => domain.toRedactedJson()).toList(),
      });
}

SyncDomainHealthSnapshot _domainSnapshot(
  SyncDomain domain,
  int revision,
  List<InvalidateSync> managers,
) {
  int? latestSuccess;
  int? latestFailure;
  String? latestFailureKind;
  for (final manager in managers) {
    final success = manager.lastSuccessAtMs;
    if (success != null && (latestSuccess == null || success > latestSuccess)) {
      latestSuccess = success;
    }
    final failure = manager.lastFailureAtMs;
    if (failure != null && (latestFailure == null || failure > latestFailure)) {
      latestFailure = failure;
      latestFailureKind = manager.lastFailureKind;
    }
  }
  return SyncDomainHealthSnapshot(
    domain: domain,
    revision: revision,
    running: managers.any((manager) => manager.isRunning),
    pending: managers.any((manager) => manager.isPending),
    lastSuccessAtMs: latestSuccess,
    lastFailureAtMs: latestFailure,
    lastFailureKind: latestFailureKind,
  );
}
