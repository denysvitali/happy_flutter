import 'dart:async';

import '../models/session.dart';
import 'logger_service.dart';
import 'notification_service.dart';
import 'session_activity_coordinator.dart';
import 'sync_service.dart';

/// Top-level singleton wired up from sync lifecycle helpers alongside
/// [sessionActivityCoordinator].
final StuckAgentSentinel stuckAgentSentinel = StuckAgentSentinel();

/// Classification of a thinking session's health.
enum SentinelVerdict {
  /// Session is not thinking — nothing to watch.
  idle,

  /// Session is thinking and showed progress recently.
  progressing,

  /// Session is blocked on a permission request — the permission
  /// notification already covers "agent needs you", so the sentinel
  /// stays quiet.
  awaitingPermission,

  /// Session is thinking but produced no observable progress for at
  /// least the stall threshold — the user should intervene.
  stalled,
}

/// Watches thinking sessions and raises an actionable "agent is stuck"
/// notification when one stops making observable progress.
///
/// Progress is inferred from two signals:
///  1. A tool/thinking-state change (`agentStateVersion` / `thinkingAt`).
///  2. Message activity via [Sync.onSessionMessagesChanged].
///
/// A session that is `thinking == true` with neither signal for
/// [stallThreshold] is classified [SentinelVerdict.stalled] and gets a
/// one-shot high-importance notification with Nudge / Abort actions
/// (see [NotificationService.showStuckAgentNotification]). The alert is
/// cancelled and re-armed as soon as progress resumes, and never fires
/// for the session the user is currently viewing or for sessions
/// blocked on a permission request (those already notify).
///
/// Like [SessionActivityCoordinator], this is a standalone object so
/// the behaviour is testable without the full Sync singleton.
class StuckAgentSentinel {
  StuckAgentSentinel({
    this.stallThreshold = const Duration(minutes: 10),
    Duration checkInterval = const Duration(seconds: 60),
    DateTime Function()? now,
    String? Function()? visibleSessionResolver,
    Future<void> Function(StuckAlert alert)? showAlert,
    Future<void> Function(String sessionId)? cancelAlert,
  }) : _checkInterval = checkInterval,
       _now = now ?? DateTime.now,
       _visibleSession =
           visibleSessionResolver ??
           (() => sessionActivityCoordinator.visibleSessionId),
       _showAlert = showAlert ?? _defaultShowAlert,
       _cancelAlert = cancelAlert ?? _defaultCancelAlert;

  /// How long a thinking session may go without progress before it is
  /// considered stuck.
  final Duration stallThreshold;

  final Duration _checkInterval;
  final DateTime Function() _now;
  final String? Function() _visibleSession;
  final Future<void> Function(StuckAlert alert) _showAlert;
  final Future<void> Function(String sessionId) _cancelAlert;

  StreamSubscription<void>? _domainSub;
  StreamSubscription<String>? _messagesSub;
  Timer? _checkTimer;

  final Map<String, _TrackedSession> _tracked = <String, _TrackedSession>{};

  static Future<void> _defaultShowAlert(StuckAlert alert) =>
      NotificationService.instance.showStuckAgentNotification(
        sessionId: alert.sessionId,
        toolName: alert.toolName,
        stalledFor: alert.stalledFor,
        sessionName: alert.sessionName,
      );

  static Future<void> _defaultCancelAlert(String sessionId) =>
      NotificationService.instance.cancelStuckAgentNotification(sessionId);

  /// Begin watching [sync] for stalled sessions.
  void attach(Sync sync) {
    _domainSub?.cancel();
    _domainSub = sync.onDomainChanged
        .where((domain) => domain == SyncDomain.sessions)
        .listen((_) => reconcile(sync.sessions.values));
    _messagesSub?.cancel();
    _messagesSub = sync.onSessionMessagesChanged.listen(recordProgress);
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(
      _checkInterval,
      (_) => reconcile(sync.sessions.values),
    );
  }

  /// Stop watching and clear any raised alerts.
  Future<void> detach() async {
    await _domainSub?.cancel();
    _domainSub = null;
    await _messagesSub?.cancel();
    _messagesSub = null;
    _checkTimer?.cancel();
    _checkTimer = null;
    final alerted = _tracked.entries
        .where((e) => e.value.alerted)
        .map((e) => e.key)
        .toList(growable: false);
    _tracked.clear();
    for (final sessionId in alerted) {
      await _guardedCancel(sessionId);
    }
  }

  /// Visible for tests — session ids currently being watched.
  Iterable<String> get debugTrackedSessions => _tracked.keys;

  /// Visible for tests — session ids with a raised stuck alert.
  Iterable<String> get debugAlertedSessions =>
      _tracked.entries.where((e) => e.value.alerted).map((e) => e.key);

  /// Record message-level activity for [sessionId] — resets the stall
  /// clock and clears a raised alert.
  void recordProgress(String sessionId) {
    final tracked = _tracked[sessionId];
    if (tracked == null) return;
    tracked.lastProgressAt = _now();
    if (tracked.alerted) {
      tracked.alerted = false;
      unawaited(_guardedCancel(sessionId));
    }
  }

  /// Classify [session] without mutating tracking state.
  SentinelVerdict evaluate(Session session) {
    if (session.thinking != true) return SentinelVerdict.idle;
    if (_hasPendingPermission(session)) {
      return SentinelVerdict.awaitingPermission;
    }
    final tracked = _tracked[session.id];
    if (tracked == null) return SentinelVerdict.progressing;
    final reference = tracked.fingerprint == _fingerprint(session)
        ? tracked.lastProgressAt
        : _now();
    final stalled = _now().difference(reference) >= stallThreshold;
    return stalled ? SentinelVerdict.stalled : SentinelVerdict.progressing;
  }

  /// Re-derive tracking state and raise/clear alerts for [sessions].
  void reconcile(Iterable<Session> sessions) {
    final now = _now();
    final seen = <String>{};
    for (final session in sessions) {
      seen.add(session.id);
      _reconcileSession(session, now);
    }
    final stale = _tracked.keys
        .where((id) => !seen.contains(id))
        .toList(growable: false);
    for (final id in stale) {
      _drop(id);
    }
  }

  void _reconcileSession(Session session, DateTime now) {
    if (session.thinking != true) {
      _drop(session.id);
      return;
    }
    final fingerprint = _fingerprint(session);
    final tracked = _tracked.putIfAbsent(
      session.id,
      () => _TrackedSession(fingerprint: fingerprint, lastProgressAt: now),
    );
    if (tracked.fingerprint != fingerprint) {
      tracked
        ..fingerprint = fingerprint
        ..lastProgressAt = now;
      if (tracked.alerted) {
        tracked.alerted = false;
        unawaited(_guardedCancel(session.id));
      }
      return;
    }
    if (tracked.alerted) return;
    if (_hasPendingPermission(session)) return;
    if (session.id == _visibleSession()) return;
    final stalledFor = now.difference(tracked.lastProgressAt);
    if (stalledFor < stallThreshold) return;
    tracked.alerted = true;
    unawaited(
      _guardedShow(
        StuckAlert(
          sessionId: session.id,
          toolName: _currentToolName(session),
          stalledFor: stalledFor,
          sessionName:
              session.metadata?.summary?.text ??
              session.metadata?.path?.split('/').last,
        ),
      ),
    );
  }

  void _drop(String sessionId) {
    final tracked = _tracked.remove(sessionId);
    if (tracked != null && tracked.alerted) {
      unawaited(_guardedCancel(sessionId));
    }
  }

  Future<void> _guardedShow(StuckAlert alert) async {
    try {
      await _showAlert(alert);
    } catch (e, st) {
      logger.warning('StuckAgentSentinel.show failed: $e', e, st);
    }
  }

  Future<void> _guardedCancel(String sessionId) async {
    try {
      await _cancelAlert(sessionId);
    } catch (e, st) {
      logger.warning('StuckAgentSentinel.cancel failed: $e', e, st);
    }
  }

  static bool _hasPendingPermission(Session session) {
    final requests = session.agentState?.requests;
    return requests != null && requests.isNotEmpty;
  }

  // Do not include activeAt/updatedAt: heartbeat writes can advance those
  // timestamps while a wedged agent makes no user-visible progress.
  static String _fingerprint(Session session) =>
      '${session.agentStateVersion}:${session.thinkingAt}';

  static String _currentToolName(Session session) {
    final requests = session.agentState?.requests;
    if (requests != null && requests.isNotEmpty) {
      final keys = requests.keys.toList()..sort();
      final tool = requests[keys.first]?.tool;
      if (tool != null && tool.isNotEmpty) return tool;
    }
    return 'Thinking…';
  }
}

/// Payload describing a raised stuck-agent alert. Public so tests can
/// capture what the sentinel asked the notification layer to show.
class StuckAlert {
  const StuckAlert({
    required this.sessionId,
    required this.toolName,
    required this.stalledFor,
    this.sessionName,
  });

  final String sessionId;
  final String toolName;
  final Duration stalledFor;
  final String? sessionName;
}

class _TrackedSession {
  _TrackedSession({required this.fingerprint, required this.lastProgressAt});

  String fingerprint;
  DateTime lastProgressAt;
  bool alerted = false;
}
