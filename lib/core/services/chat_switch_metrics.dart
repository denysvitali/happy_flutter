import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'opentelemetry_service.dart';

typedef ChatSwitchMetricSink =
    void Function(
      String name,
      Duration duration,
      Map<String, Object?> attributes,
    );

/// Measures the interaction users actually perceive when opening a chat.
///
/// The generic navigation observer only measures route bookkeeping. This
/// tracker starts at the tap (where available), records the first presented
/// route frame, and remains open until message content or a confirmed empty
/// state has painted.
class ChatSwitchMetrics {
  factory ChatSwitchMetrics() => _instance;
  ChatSwitchMetrics._();

  static final ChatSwitchMetrics _instance = ChatSwitchMetrics._();
  static const Duration _timeout = Duration(seconds: 15);

  final Map<String, _ChatSwitchAttempt> _attempts = {};

  @visibleForTesting
  static ChatSwitchMetricSink? debugMetricSink;

  void begin(String sessionId, {required String source}) {
    for (final attempt in _attempts.values.toList(growable: false)) {
      _finish(attempt, outcome: 'superseded', contentSource: 'none');
    }
    _attempts.clear();
    _start(sessionId, source: source, tapObserved: true);
  }

  /// Covers deep links and entry points that have not yet adopted [begin].
  /// These samples remain useful, but carry `tap_observed=false` so they do
  /// not pollute the tap-to-content SLO.
  void ensureStarted(String sessionId, {String source = 'direct_route'}) {
    if (_attempts.containsKey(sessionId)) return;
    _start(sessionId, source: source, tapObserved: false);
  }

  void markFirstFrame(
    String sessionId, {
    required String state,
    required bool hadInMemoryMessages,
    required int messageCount,
  }) {
    final attempt = _attempts[sessionId];
    if (attempt == null || attempt.firstFrameRecorded) return;
    attempt
      ..firstFrameRecorded = true
      ..firstFrameState = _boundedState(state);
    final attributes = <String, Object?>{
      'source': attempt.source,
      'tap_observed': attempt.tapObserved,
      'state': attempt.firstFrameState,
      'had_in_memory_messages': hadInMemoryMessages,
      'message_count_bucket': _messageCountBucket(messageCount),
    };
    _record(
      'app.chat.switch.first_frame',
      attempt.stopwatch.elapsed,
      attributes,
    );
    attempt.span
      ?..setAttribute(
        'chat.switch.first_frame_ms',
        attempt.stopwatch.elapsedMilliseconds,
      )
      ..setAttribute('chat.switch.first_frame_state', attempt.firstFrameState);
  }

  void markContentReady(
    String sessionId, {
    required String contentSource,
    required int messageCount,
  }) {
    final attempt = _attempts.remove(sessionId);
    if (attempt == null) return;
    _finish(
      attempt,
      outcome: messageCount == 0 ? 'empty' : 'content',
      contentSource: _boundedContentSource(contentSource),
      messageCount: messageCount,
    );
  }

  void cancel(String sessionId) {
    final attempt = _attempts.remove(sessionId);
    if (attempt == null) return;
    _finish(attempt, outcome: 'cancelled', contentSource: 'none');
  }

  void _start(
    String sessionId, {
    required String source,
    required bool tapObserved,
  }) {
    final normalizedSource = _boundedSource(source);
    final attempt = _ChatSwitchAttempt(
      source: normalizedSource,
      tapObserved: tapObserved,
      span: OpenTelemetryService().startTrace(
        'chat.switch',
        attributes: <String, Object?>{
          'session.id': sessionId,
          'navigation.source': normalizedSource,
          'tap.observed': tapObserved,
        },
      ),
    );
    attempt.timeout = Timer(_timeout, () {
      if (!identical(_attempts.remove(sessionId), attempt)) return;
      _finish(attempt, outcome: 'timeout', contentSource: 'none');
    });
    _attempts[sessionId] = attempt;
  }

  void _finish(
    _ChatSwitchAttempt attempt, {
    required String outcome,
    required String contentSource,
    int messageCount = 0,
  }) {
    attempt.timeout?.cancel();
    attempt.stopwatch.stop();
    final attributes = <String, Object?>{
      'source': attempt.source,
      'tap_observed': attempt.tapObserved,
      'outcome': outcome,
      'content_source': contentSource,
      'first_frame_state': attempt.firstFrameState,
      'message_count_bucket': _messageCountBucket(messageCount),
    };
    _record(
      'app.chat.switch.content_ready',
      attempt.stopwatch.elapsed,
      attributes,
    );
    attempt.span
      ?..setAttribute('chat.switch.outcome', outcome)
      ..setAttribute('chat.switch.content_source', contentSource)
      ..setAttribute(
        'chat.switch.content_ready_ms',
        attempt.stopwatch.elapsedMilliseconds,
      )
      ..setAttribute('message.count', messageCount)
      ..end(ok: outcome != 'timeout');
  }

  static void _record(
    String name,
    Duration duration,
    Map<String, Object?> attributes,
  ) {
    debugMetricSink?.call(name, duration, attributes);
    OpenTelemetryService().recordDuration(
      name,
      duration,
      attributes: attributes,
      description: name.endsWith('first_frame')
          ? 'Tap or route start until the first chat frame is presented'
          : 'Tap or route start until chat content has painted',
    );
  }

  static String _boundedSource(String source) => switch (source) {
    'sessions_list' ||
    'tablet_master_detail' ||
    'sidebar' ||
    'machine_detail' ||
    'recent_sessions' ||
    'goal_loops' ||
    'new_session' ||
    'command_palette' ||
    'artifact_detail' ||
    'sent_session' ||
    'notification' ||
    'direct_route' => source,
    _ => 'other',
  };

  static String _boundedState(String state) => switch (state) {
    'content' || 'loading' || 'empty' => state,
    _ => 'unknown',
  };

  static String _boundedContentSource(String source) => switch (source) {
    'memory' || 'cache' || 'network' || 'empty' => source,
    _ => 'unknown',
  };

  static String _messageCountBucket(int count) => switch (count) {
    <= 0 => '0',
    <= 25 => '1_25',
    <= 50 => '26_50',
    <= 200 => '51_200',
    _ => '201_plus',
  };
}

class _ChatSwitchAttempt {
  _ChatSwitchAttempt({
    required this.source,
    required this.tapObserved,
    required this.span,
  });

  final String source;
  final bool tapObserved;
  final OTelSpan? span;
  final Stopwatch stopwatch = Stopwatch()..start();
  Timer? timeout;
  bool firstFrameRecorded = false;
  String firstFrameState = 'unknown';
}
