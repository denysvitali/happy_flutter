import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/session.dart';
import '../utils/performance_buckets.dart';
import 'live_activity_service.dart';
import 'logger_service.dart';
import 'notification_service.dart';
import 'opentelemetry_service.dart';
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
    Duration eventReconcileCooldown = const Duration(seconds: 1),
  }) : _notifications = notificationService ?? NotificationService.instance,
       _liveActivity = liveActivityService ?? LiveActivityService.instance,
       _refreshInterval = refreshInterval,
       _eventReconcileCooldown = eventReconcileCooldown;

  final NotificationService _notifications;
  final LiveActivityService _liveActivity;
  final Duration _refreshInterval;
  final Duration _eventReconcileCooldown;

  StreamSubscription<void>? _sub;
  Timer? _refreshTimer;
  Timer? _pendingEventReconcile;
  DateTime _lastEventReconcileAt = DateTime.fromMillisecondsSinceEpoch(0);
  Sync? _sync;

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
    _sync = sync;
    _sub?.cancel();
    _sub = sync.onDomainChanged
        .where((domain) => domain == SyncDomain.sessions)
        .listen((_) => _onSessionsDomainEvent());
    _refreshTimer?.cancel();
    // Web notifications are hard no-ops (NotificationService returns early
    // on kIsWeb), so the periodic elapsed-time refresh is pure allocation
    // churn there. The domain-change subscription above still reconciles.
    if (!kIsWeb) {
      _refreshTimer = Timer.periodic(
        _refreshInterval,
        (_) => _refreshTrackedActivities(),
      );
    }
  }

  void _refreshTrackedActivities() {
    // Domain events perform discovery immediately. The periodic pass exists
    // only to refresh elapsed labels for notifications already being shown,
    // so an idle catalog needs no recurring O(session count) walk.
    if (_active.isEmpty) return;
    _reconcileCatalog();
  }

  /// Coalesce sessions-domain events into at most one full-catalog walk per
  /// cooldown window (leading edge + trailing catch-up).
  ///
  /// During a streaming turn `update-session` events carry fresh
  /// `activeAt`/`lastSeq` per token batch, each bumping `SyncDomain.sessions`
  /// up to ~10x/s after Sync's debounce. This listener used to copy and walk
  /// the whole catalog — and re-post one platform notification per thinking
  /// session — on every wave: sustained UI-isolate work plus notification
  /// flooding scaling with catalog size (freeze audit 2026-08-25: chat
  /// frozen frames concentrate ~10x in the 251+ session bucket).
  /// Notification start/end may now lag a state change by up to one
  /// cooldown; elapsed-time freshness is unchanged via [_refreshInterval].
  void _onSessionsDomainEvent() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastEventReconcileAt);
    if (elapsed >= _eventReconcileCooldown) {
      _pendingEventReconcile?.cancel();
      _pendingEventReconcile = null;
      _lastEventReconcileAt = now;
      _reconcileCatalog();
      return;
    }
    _pendingEventReconcile ??= Timer(
      _eventReconcileCooldown - elapsed,
      () {
        _pendingEventReconcile = null;
        _lastEventReconcileAt = DateTime.now();
        _reconcileCatalog();
      },
    );
  }

  void _reconcileCatalog() {
    final sync = _sync;
    if (sync == null) return;
    final stopwatch = Stopwatch()..start();
    _reconcile(sync);
    OpenTelemetryService().recordDuration(
      'app.session.catalog_reconcile',
      stopwatch.elapsed,
      attributes: {
        'source': 'activity_coordinator',
        'session_count_bucket': collectionSizeBucket(sync.sessionsView.length),
      },
      description: 'Full-catalog activity-notification reconcile walk',
    );
  }

  /// Stop watching and cancel any active activity notifications.
  Future<void> detach() async {
    await _sub?.cancel();
    _sub = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _pendingEventReconcile?.cancel();
    _pendingEventReconcile = null;
    _sync = null;
    final ids = _active.keys.toList(growable: false);
    _active.clear();
    for (final sessionId in ids) {
      await _notifications.cancelSessionActivityNotification(sessionId);
      await _liveActivity.end(sessionId);
    }
  }

  /// Visible for tests — returns the currently-tracked session ids.
  Iterable<String> get debugTrackedSessions => _active.keys;

  /// Visible for tests — how many full-catalog walks have run, so tests can
  /// assert coalescing rather than infer it from notification side effects.
  int debugReconcileCount = 0;

  /// Visible for tests — how many times the platform notification was
  /// (re-)posted, so tests can assert unchanged presentations are skipped.
  int debugNotificationPosts = 0;

  /// Visible for tests — derive a snapshot directly from a session
  /// without subscribing to a Sync instance.
  ActivityDecision computeDecision(Session session) =>
      _decisionFor(session, visibleSessionId);

  /// Visible for tests — apply a decision (start/update/end) without
  /// the full Sync wiring.
  Future<void> applyDecision(ActivityDecision decision) => _apply(decision);

  void _reconcile(Sync sync) {
    debugReconcileCount++;
    // Iterate the live view directly — a defensive toList() here copied the
    // entire 251+-session catalog on every reconcile.
    final sessions = sync.sessionsView.values;
    final seen = <String>{};
    for (final session in sessions) {
      seen.add(session.id);
      final decision = _decisionFor(session, visibleSessionId);
      // Noop means "nothing to present and nothing tracked" — calling
      // _apply for it spawned an unawaited future per session per wave.
      if (decision.isNoop) continue;
      // Fire and forget — errors are logged inside the methods.
      unawaited(_apply(decision));
    }
    // Clean up tracked sessions that no longer exist (deleted). O(active +
    // catalog) via the seen set, not the old O(active × catalog) nested any().
    final stale = _active.keys
        .where((id) => !seen.contains(id))
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
        final previous = _active[decision.sessionId];
        // Presentation dedup: while a turn streams, every coalesced
        // reconcile re-derives the same show decision for a thinking
        // session. Re-posting the platform notification each time re-encoded
        // and re-published identical content up to once per second per
        // session; the periodic [_refreshInterval] timer keeps the elapsed
        // label fresh instead. Keeping the first snapshot also pins
        // startedAt so the elapsed clock does not drift forward when the
        // server refreshes activeAt mid-turn.
        if (previous != null &&
            previous.toolName == decision.toolName &&
            previous.sessionName == decision.sessionName) {
          return;
        }
        final snapshot = _ActivitySnapshot(
          toolName: decision.toolName!,
          startedAt: decision.startedAt!,
          sessionName: decision.sessionName,
        );
        _active[decision.sessionId] = snapshot;
        debugNotificationPosts++;
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
