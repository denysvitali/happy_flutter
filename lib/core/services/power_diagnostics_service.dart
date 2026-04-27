import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../api/socket_io_client.dart';
import 'http_request_logger.dart';
import 'performance_context_service.dart';

enum PowerDiagnosticEventType { lifecycle, socket, http, sync, outbox }

class PowerDiagnosticEvent {
  const PowerDiagnosticEvent({
    required this.timestamp,
    required this.type,
    required this.message,
    this.route,
  });

  final DateTime timestamp;
  final PowerDiagnosticEventType type;
  final String message;
  final String? route;

  String toFormattedString() {
    final routeText = route == null ? '' : ' route=$route';
    return '${timestamp.toIso8601String()} '
        '[${type.name}] $message$routeText';
  }
}

class PowerDiagnosticsSnapshot {
  const PowerDiagnosticsSnapshot({
    required this.startedAt,
    required this.generatedAt,
    required this.lifecycleTransitions,
    required this.resumeCount,
    required this.suspendCount,
    required this.rapidLifecycleWarnings,
    required this.socketConnects,
    required this.socketDisconnects,
    required this.socketErrors,
    required this.socketEvents,
    required this.socketSends,
    required this.socketAckCalls,
    required this.httpRequests,
    required this.httpFailures,
    required this.httpSlowRequests,
    required this.httpRequestBytes,
    required this.httpResponseBytes,
    required this.syncInvalidations,
    required this.globalSyncInvalidations,
    required this.outboxSchedules,
    required this.outboxAttempts,
    required this.outboxFailures,
    required this.recentEvents,
  });

  final DateTime startedAt;
  final DateTime generatedAt;
  final int lifecycleTransitions;
  final int resumeCount;
  final int suspendCount;
  final int rapidLifecycleWarnings;
  final int socketConnects;
  final int socketDisconnects;
  final int socketErrors;
  final int socketEvents;
  final int socketSends;
  final int socketAckCalls;
  final int httpRequests;
  final int httpFailures;
  final int httpSlowRequests;
  final int httpRequestBytes;
  final int httpResponseBytes;
  final int syncInvalidations;
  final int globalSyncInvalidations;
  final int outboxSchedules;
  final int outboxAttempts;
  final int outboxFailures;
  final List<PowerDiagnosticEvent> recentEvents;

  Duration get runtime => generatedAt.difference(startedAt);

  String get runtimeLabel {
    final seconds = runtime.inSeconds;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m ${secs}s';
    if (minutes > 0) return '${minutes}m ${secs}s';
    return '${secs}s';
  }
}

class PowerDiagnosticsService extends ChangeNotifier {
  factory PowerDiagnosticsService() => _instance;
  PowerDiagnosticsService._();

  static final PowerDiagnosticsService _instance = PowerDiagnosticsService._();

  static const int _maxEvents = 300;
  static const int _notifyDebounceMs = 1000;

  final Queue<PowerDiagnosticEvent> _events = Queue<PowerDiagnosticEvent>();
  DateTime _startedAt = DateTime.now();
  Timer? _notifyTimer;
  bool _disposed = false;

  int _lifecycleTransitions = 0;
  int _resumeCount = 0;
  int _suspendCount = 0;
  int _rapidLifecycleWarnings = 0;
  int _socketConnects = 0;
  int _socketDisconnects = 0;
  int _socketErrors = 0;
  int _socketEvents = 0;
  int _socketSends = 0;
  int _socketAckCalls = 0;
  int _httpRequests = 0;
  int _httpFailures = 0;
  int _httpSlowRequests = 0;
  int _httpRequestBytes = 0;
  int _httpResponseBytes = 0;
  int _syncInvalidations = 0;
  int _globalSyncInvalidations = 0;
  int _outboxSchedules = 0;
  int _outboxAttempts = 0;
  int _outboxFailures = 0;

  PowerDiagnosticsSnapshot snapshot() {
    return PowerDiagnosticsSnapshot(
      startedAt: _startedAt,
      generatedAt: DateTime.now(),
      lifecycleTransitions: _lifecycleTransitions,
      resumeCount: _resumeCount,
      suspendCount: _suspendCount,
      rapidLifecycleWarnings: _rapidLifecycleWarnings,
      socketConnects: _socketConnects,
      socketDisconnects: _socketDisconnects,
      socketErrors: _socketErrors,
      socketEvents: _socketEvents,
      socketSends: _socketSends,
      socketAckCalls: _socketAckCalls,
      httpRequests: _httpRequests,
      httpFailures: _httpFailures,
      httpSlowRequests: _httpSlowRequests,
      httpRequestBytes: _httpRequestBytes,
      httpResponseBytes: _httpResponseBytes,
      syncInvalidations: _syncInvalidations,
      globalSyncInvalidations: _globalSyncInvalidations,
      outboxSchedules: _outboxSchedules,
      outboxAttempts: _outboxAttempts,
      outboxFailures: _outboxFailures,
      recentEvents: List.unmodifiable(_events),
    );
  }

  void reset() {
    _startedAt = DateTime.now();
    _events.clear();
    _lifecycleTransitions = 0;
    _resumeCount = 0;
    _suspendCount = 0;
    _rapidLifecycleWarnings = 0;
    _socketConnects = 0;
    _socketDisconnects = 0;
    _socketErrors = 0;
    _socketEvents = 0;
    _socketSends = 0;
    _socketAckCalls = 0;
    _httpRequests = 0;
    _httpFailures = 0;
    _httpSlowRequests = 0;
    _httpRequestBytes = 0;
    _httpResponseBytes = 0;
    _syncInvalidations = 0;
    _globalSyncInvalidations = 0;
    _outboxSchedules = 0;
    _outboxAttempts = 0;
    _outboxFailures = 0;
    _notifySoon();
  }

  void recordLifecycle(String state, {bool rapidCycle = false}) {
    _lifecycleTransitions++;
    if (state == 'resumed') _resumeCount++;
    if (state == 'paused' || state == 'hidden') _suspendCount++;
    if (rapidCycle) _rapidLifecycleWarnings++;
    _addEvent(
      PowerDiagnosticEventType.lifecycle,
      rapidCycle ? '$state rapid-cycle' : state,
    );
  }

  void recordSocketStatus(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        _socketConnects++;
      case ConnectionStatus.disconnected:
        _socketDisconnects++;
      case ConnectionStatus.error:
        _socketErrors++;
      case ConnectionStatus.connecting:
        break;
    }
    _addEvent(PowerDiagnosticEventType.socket, 'status=${status.name}');
  }

  void recordSocketError(String error) {
    _socketErrors++;
    _addEvent(PowerDiagnosticEventType.socket, 'error=$error');
  }

  void recordSocketEvent(String event, {String? updateType}) {
    _socketEvents++;
    final typeText = updateType == null ? '' : ' type=$updateType';
    _addEvent(PowerDiagnosticEventType.socket, 'event=$event$typeText');
  }

  void recordSocketSend(String event, {bool ack = false}) {
    if (ack) {
      _socketAckCalls++;
    } else {
      _socketSends++;
    }
    _addEvent(
      PowerDiagnosticEventType.socket,
      ack ? 'emitWithAck=$event' : 'send=$event',
    );
  }

  void recordHttpRequest(HttpRequestEntry entry) {
    _httpRequests++;
    _httpRequestBytes += entry.requestBytes ?? 0;
    _httpResponseBytes += entry.responseBytes ?? 0;
    final status = entry.statusCode;
    if (status != null && status >= 400) _httpFailures++;
    if ((entry.durationMs ?? 0) >= 1000) _httpSlowRequests++;
    _addEvent(
      PowerDiagnosticEventType.http,
      '${entry.method} ${entry.statusCode ?? '???'} '
      '${entry.durationMs ?? '-'}ms ${entry.path}',
    );
  }

  void recordSyncInvalidation(String name, {bool global = false}) {
    _syncInvalidations++;
    if (global) _globalSyncInvalidations++;
    _addEvent(
      PowerDiagnosticEventType.sync,
      global ? 'global invalidate $name' : 'invalidate $name',
    );
  }

  void recordOutboxSchedule({required String localId, required int delayMs}) {
    _outboxSchedules++;
    _addEvent(
      PowerDiagnosticEventType.outbox,
      'schedule localId=$localId delay=${delayMs}ms',
    );
  }

  void recordOutboxAttempt(String localId) {
    _outboxAttempts++;
    _addEvent(PowerDiagnosticEventType.outbox, 'attempt localId=$localId');
  }

  void recordOutboxFailure(String localId) {
    _outboxFailures++;
    _addEvent(PowerDiagnosticEventType.outbox, 'failure localId=$localId');
  }

  String exportText() {
    final s = snapshot();
    final buffer = StringBuffer()
      ..writeln('=== Power Diagnostics ===')
      ..writeln('Generated: ${s.generatedAt.toIso8601String()}')
      ..writeln('Started: ${s.startedAt.toIso8601String()}')
      ..writeln('Runtime: ${s.runtimeLabel}')
      ..writeln()
      ..writeln('Lifecycle')
      ..writeln('  transitions: ${s.lifecycleTransitions}')
      ..writeln('  resumes: ${s.resumeCount}')
      ..writeln('  suspends: ${s.suspendCount}')
      ..writeln('  rapidLifecycleWarnings: ${s.rapidLifecycleWarnings}')
      ..writeln()
      ..writeln('Socket')
      ..writeln('  connects: ${s.socketConnects}')
      ..writeln('  disconnects: ${s.socketDisconnects}')
      ..writeln('  errors: ${s.socketErrors}')
      ..writeln('  events: ${s.socketEvents}')
      ..writeln('  sends: ${s.socketSends}')
      ..writeln('  ackCalls: ${s.socketAckCalls}')
      ..writeln()
      ..writeln('HTTP')
      ..writeln('  requests: ${s.httpRequests}')
      ..writeln('  failures: ${s.httpFailures}')
      ..writeln('  slowRequests: ${s.httpSlowRequests}')
      ..writeln(
        '  requestBytes: ${HttpRequestEntry.formatBytes(s.httpRequestBytes)}',
      )
      ..writeln(
        '  responseBytes: ${HttpRequestEntry.formatBytes(s.httpResponseBytes)}',
      )
      ..writeln()
      ..writeln('Sync')
      ..writeln('  invalidations: ${s.syncInvalidations}')
      ..writeln('  globalInvalidations: ${s.globalSyncInvalidations}')
      ..writeln()
      ..writeln('Outbox')
      ..writeln('  schedules: ${s.outboxSchedules}')
      ..writeln('  attempts: ${s.outboxAttempts}')
      ..writeln('  failures: ${s.outboxFailures}')
      ..writeln()
      ..writeln('Recent Events');
    for (final event in s.recentEvents) {
      buffer.writeln('  ${event.toFormattedString()}');
    }
    return buffer.toString();
  }

  void _addEvent(PowerDiagnosticEventType type, String message) {
    _events.add(
      PowerDiagnosticEvent(
        timestamp: DateTime.now(),
        type: type,
        message: message,
        route: PerformanceContextService().currentRoute,
      ),
    );
    if (_events.length > _maxEvents) {
      _events.removeFirst();
    }
    _notifySoon();
  }

  void _notifySoon() {
    if (_disposed || !hasListeners || _notifyTimer != null) return;
    _notifyTimer = Timer(const Duration(milliseconds: _notifyDebounceMs), () {
      _notifyTimer = null;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _notifyTimer?.cancel();
    super.dispose();
  }
}

final powerDiagnostics = PowerDiagnosticsService();
