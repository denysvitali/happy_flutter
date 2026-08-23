import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/session.dart';
import 'live_activity_service.dart';
import 'logger_service.dart';
import 'notification_service.dart';
import 'sync_service.dart';

/// Top-level singleton wired up from `main.dart` once Sync is ready.
///
/// Screens that need to mark themselves visible to suppress the
/// activity notification (e.g. ChatScreen) call
/// [SessionActivityCoordinator.setVisibleSession] on this instance.
final SessionActivityCoordinator sessionActivityCoordinator =
    SessionActivityCoordinator();

/// Drives the "session activity" live notification (and optional iOS
/// Live Activity) based on session state changes.
///
/// One ongoing notification is shown per session that is currently
/// `thinking == true` and not the session the user is actively
/// viewing. The notification is refreshed periodically so the elapsed
/// timer stays roughly accurate, and is cancelled as soon as the
/// session stops thinking (or the user opens it).
///
/// This coordinator is intentionally a separate object so the
/// behaviour is testable without spinning up the full Sync singleton.
class SessionActivityCoordinator {
  SessionActivityCoordinator({
    NotificationService? notificationService,
    LiveActivityService? liveActivityService,
    Duration refreshInterval = const Duration(seconds: 15),
  }) : _notifications = notificationService ?? NotificationService.instance,
       _liveActivity = liveActivityService ?? LiveActivityService.instance,
       _refreshInterval = refreshInterval;

  final NotificationService _notifications;
  final LiveActivityService _liveActivity;
  final Duration _refreshInterval;

  StreamSubscription<void>? _sub;
  Timer? _refreshTimer;

  /// sessionId → state we last reflected in a notification.
  final Map<String, _ActivitySnapshot> _active = <String, _ActivitySnapshot>{};

  /// The session the user is currently looking at — we suppress
  /// activity notifications for it (the in-app UI already shows the
  /// running state).
  String? visibleSessionId;

  /// Mark [sessionId] as visible (or `null` when leaving the chat
  /// screen) and immediately cancel any activity notification for it.
  ///
  /// Mirrors [Sync.onSessionVisible]'s contract — call sites that
  /// already invoke that method should also call this so the live
  /// notification disappears the moment the user opens the chat.
  Future<void> setVisibleSession(String? sessionId) async {
    visibleSessionId = sessionId;
    if (sessionId != null && _active.containsKey(sessionId)) {
      await _apply(ActivityDecision.end(sessionId));
    }
  }

  /// Begin watching [sync] for changes.
  void attach(Sync sync) {
    _sub?.cancel();
    _sub = sync.onDomainChanged
        .where((domain) => domain == SyncDomain.sessions)
        .listen((_) => _reconcile(sync));
    _refreshTimer?.cancel();
    // Web notifications are hard no-ops (NotificationService returns early
    // on kIsWeb), so the periodic elapsed-time refresh is pure allocation
    // churn there. The domain-change subscription above still reconciles.
    if (!kIsWeb) {
      _refreshTimer = Timer.periodic(_refreshInterval, (_) => _reconcile(sync));
    }
  }

  /// Stop watching and cancel any active activity notifications.
  Future<void> detach() async {
    await _sub?.cancel();
    _sub = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    final ids = _active.keys.toList(growable: false);
    _active.clear();
    for (final sessionId in ids) {
      await _notifications.cancelSessionActivityNotification(sessionId);
      await _liveActivity.end(sessionId);
    }
  }

  /// Visible for tests — returns the currently-tracked session ids.
  Iterable<String> get debugTrackedSessions => _active.keys;

  /// Visible for tests — derive a snapshot directly from a session
  /// without subscribing to a Sync instance.
  ActivityDecision computeDecision(Session session) =>
      _decisionFor(session, visibleSessionId);

  /// Visible for tests — apply a decision (start/update/end) without
  /// the full Sync wiring.
  Future<void> applyDecision(ActivityDecision decision) => _apply(decision);

  void _reconcile(Sync sync) {
    final sessions = sync.sessions.values.toList(growable: false);
    final stillRunning = <String>{};
    for (final session in sessions) {
      final decision = _decisionFor(session, visibleSessionId);
      if (decision.action == ActivityAction.show) {
        stillRunning.add(session.id);
      }
      // Fire and forget — errors are logged inside the methods.
      unawaited(_apply(decision));
    }
    // Clean up tracked sessions that no longer exist (deleted).
    final stale = _active.keys
        .where((id) => !sessions.any((s) => s.id == id))
        .toList(growable: false);
    for (final id in stale) {
      unawaited(_apply(ActivityDecision.end(id)));
    }
  }

  ActivityDecision _decisionFor(Session session, String? visibleId) {
    final shouldShow = session.thinking == true && session.id != visibleId;
    if (!shouldShow) {
      return _active.containsKey(session.id)
          ? ActivityDecision.end(session.id)
          : ActivityDecision.noop(session.id);
    }
    final toolName = _currentToolName(session);
    final startedAt = DateTime.fromMillisecondsSinceEpoch(
      session.thinkingAt ?? session.activeAt,
    );
    final sessionName =
        session.metadata?.summary?.text ??
        session.metadata?.path?.split('/').last;
    return ActivityDecision.show(
      sessionId: session.id,
      toolName: toolName,
      startedAt: startedAt,
      sessionName: sessionName,
    );
  }

  static String _currentToolName(Session session) {
    final requests = session.agentState?.requests;
    if (requests != null && requests.isNotEmpty) {
      // Pick a stable representative: first by key sort.
      final keys = requests.keys.toList()..sort();
      final tool = requests[keys.first]?.tool;
      if (tool != null && tool.isNotEmpty) return tool;
    }
    return 'Thinking…';
  }

  Future<void> _apply(ActivityDecision decision) async {
    switch (decision.action) {
      case ActivityAction.show:
        final snapshot = _ActivitySnapshot(
          toolName: decision.toolName!,
          startedAt: decision.startedAt!,
          sessionName: decision.sessionName,
        );
        final previous = _active[decision.sessionId];
        _active[decision.sessionId] = snapshot;
        try {
          await _notifications.showSessionActivityNotification(
            sessionId: decision.sessionId,
            toolName: snapshot.toolName,
            startedAt: snapshot.startedAt,
            sessionName: snapshot.sessionName,
          );
          if (previous == null) {
            await _liveActivity.start(
              sessionId: decision.sessionId,
              toolName: snapshot.toolName,
              startedAt: snapshot.startedAt,
              sessionName: snapshot.sessionName,
            );
          } else {
            await _liveActivity.update(
              sessionId: decision.sessionId,
              toolName: snapshot.toolName,
              elapsed: DateTime.now().difference(snapshot.startedAt),
            );
          }
        } catch (e, st) {
          logger.warning('SessionActivityCoordinator.show failed: $e', e, st);
        }
        break;
      case ActivityAction.end:
        _active.remove(decision.sessionId);
        try {
          await _notifications.cancelSessionActivityNotification(
            decision.sessionId,
          );
          await _liveActivity.end(decision.sessionId);
        } catch (e, st) {
          logger.warning('SessionActivityCoordinator.end failed: $e', e, st);
        }
        break;
      case ActivityAction.noop:
        break;
    }
  }
}

class _ActivitySnapshot {
  _ActivitySnapshot({
    required this.toolName,
    required this.startedAt,
    this.sessionName,
  });
  final String toolName;
  final DateTime startedAt;
  final String? sessionName;
}

/// Action the coordinator wants the notification layer to perform
/// for a particular session.
enum ActivityAction { show, end, noop }

/// Public for test inspection. Describes what the coordinator wants
/// the notification layer to do for a single session.
class ActivityDecision {
  ActivityDecision._({
    required this.action,
    required this.sessionId,
    this.toolName,
    this.startedAt,
    this.sessionName,
  });

  factory ActivityDecision.show({
    required String sessionId,
    required String toolName,
    required DateTime startedAt,
    String? sessionName,
  }) => ActivityDecision._(
    action: ActivityAction.show,
    sessionId: sessionId,
    toolName: toolName,
    startedAt: startedAt,
    sessionName: sessionName,
  );

  factory ActivityDecision.end(String sessionId) =>
      ActivityDecision._(action: ActivityAction.end, sessionId: sessionId);

  factory ActivityDecision.noop(String sessionId) =>
      ActivityDecision._(action: ActivityAction.noop, sessionId: sessionId);

  final ActivityAction action;
  final String sessionId;
  final String? toolName;
  final DateTime? startedAt;
  final String? sessionName;

  bool get isShow => action == ActivityAction.show;
  bool get isEnd => action == ActivityAction.end;
  bool get isNoop => action == ActivityAction.noop;
}
