import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import '../models/session.dart';
import 'logger_service.dart';
import 'opentelemetry_service.dart';

/// Counts only structural metadata in the resident message projection.
/// Bounds and identity tracking keep malformed/cyclic input harmless. Counts
/// Counts are exact for visited rows; `truncated` marks a partial observation.
class SidechainSnapshot {
  SidechainSnapshot._(
    this.counts,
    this.selectedFound,
    this.selectedToolUseId,
    this.selectedChildren,
  );

  static const maxRows = 8192;
  static const _maxDepth = 64;
  final Map<String, Object> counts;
  final bool selectedFound;
  final String? selectedToolUseId;
  final int selectedChildren;

  static SidechainSnapshot inspect(
    List<Map<String, dynamic>> messages, {
    String? selectedId,
  }) {
    final seen = HashSet<Map<String, dynamic>>.identity();
    final frames = <(Iterator<dynamic>, int)>[(messages.iterator, 0)];
    final anchors = <String, int>{};
    final linkedParents = <String>{};
    final flatParents = <String>[];
    var values = 0;
    var linked = 0;
    var grouped = 0;
    var agentAnchors = 0;
    var truncated = false;
    var selectedFound = false;
    String? selectedToolUseId;
    var selectedChildren = 0;
    while (frames.isNotEmpty) {
      final (iterator, depth) = frames.last;
      if (!iterator.moveNext()) {
        frames.removeLast();
        continue;
      }
      if (values++ >= maxRows) {
        truncated = true;
        break;
      }
      final row = iterator.current;
      if (row is! Map<String, dynamic> || !seen.add(row)) continue;
      if (depth > 0) grouped++;
      final parent = row['parentToolUseId'];
      if (parent is String && parent.isNotEmpty) {
        linked++;
        linkedParents.add(parent);
        if (depth == 0) flatParents.add(parent);
      }
      final isAnchor =
          row['kind'] == 'tool-call' &&
          (row['name'] == 'Agent' || row['name'] == 'Task');
      if (isAnchor) {
        final anchorIndex = agentAnchors++;
        for (final key in ['id', 'toolUseId', 'uuid']) {
          final value = row[key];
          if (value is String && value.isNotEmpty) anchors[value] = anchorIndex;
        }
      }
      final children = row['children'];
      if (selectedId != null &&
          !selectedFound &&
          ['id', 'toolUseId', 'uuid'].any((key) => row[key] == selectedId)) {
        selectedFound = true;
        final toolUseId = row['toolUseId'];
        selectedToolUseId = toolUseId is String ? toolUseId : null;
        selectedChildren = children is List ? children.length : 0;
      }
      if (children is List && children.isNotEmpty) {
        if (depth + 1 >= _maxDepth) {
          truncated = true;
        } else {
          frames.add((children.iterator, depth + 1));
        }
      }
    }
    final matched = <int>{
      for (final parent in linkedParents)
        if (anchors.containsKey(parent)) anchors[parent]!,
    };
    return SidechainSnapshot._(
      {
        'resident_top_level_rows': messages.length,
        'visited_rows': seen.length,
        'linked_rows': linked,
        'grouped_children': grouped,
        'flat_linked_rows': flatParents.length,
        'flat_unmatched_links': flatParents
            .where((parent) => !anchors.containsKey(parent))
            .length,
        'agent_anchors': agentAnchors,
        'matched_agent_anchors': matched.length,
        'truncated': truncated,
      },
      selectedFound,
      selectedToolUseId,
      selectedChildren,
    );
  }
}

/// No retained message data; bounded session timestamps reset with the runtime.
class SidechainDiagnosticGate {
  static const maxSessions = 32;
  final _lastEmission = <String, DateTime>{};
  int? _generation;
  DateTime? _windowStartedAt;
  int _windowEmissions = 0;

  int get trackedSessions => _lastEmission.length;

  void reset() {
    _lastEmission.clear();
    _generation = null;
    _windowStartedAt = null;
    _windowEmissions = 0;
  }

  bool shouldEmit(String sessionId, int generation, DateTime now) {
    if (_generation != generation) {
      reset();
      _generation = generation;
    }
    final previous = _lastEmission[sessionId];
    if (previous != null &&
        !now.isBefore(previous) &&
        now.difference(previous) < const Duration(seconds: 30)) {
      return false;
    }
    final window = _windowStartedAt;
    if (window == null ||
        now.isBefore(window) ||
        now.difference(window) >= const Duration(seconds: 30)) {
      _windowStartedAt = now;
      _windowEmissions = 0;
    }
    // A rotating set of sessions must not bypass the cap by evicting keys.
    if (_windowEmissions >= maxSessions) return false;
    _windowEmissions++;
    _lastEmission.remove(sessionId);
    _lastEmission[sessionId] = now;
    while (_lastEmission.length > maxSessions) {
      _lastEmission.remove(_lastEmission.keys.first);
    }
    return true;
  }
}

/// Metadata-only Loki/Jaeger breadcrumbs; counters bypass log throttling.
class SidechainDiagnostics {
  static final _groupingGate = SidechainDiagnosticGate();
  static final _pendingScreens = <SidechainDiagnostics>{};
  static int _runtimeEpoch = 0;
  int _screenEpoch = _runtimeEpoch;
  final _screenGate = SidechainDiagnosticGate();
  bool _screenOpened = false;
  String? _screenSignature;
  Timer? _screenTimer;
  Map<String, Object?>? _screenPending;

  /// Cancel delayed screen reports and forget IDs/timestamps across accounts.
  static void resetRuntime() {
    _runtimeEpoch++;
    _groupingGate.reset();
    for (final reporter in _pendingScreens.toList()) {
      reporter.dispose();
    }
  }

  static String? _bounded(String? value) => value == null
      ? null
      : value.length > 256
      ? value.substring(0, 256)
      : value;

  static Map<String, Object?> _metadata(
    String sessionId,
    Metadata? metadata,
  ) => {
    'session_id': _bounded(sessionId),
    'machine_id': _bounded(metadata?.machineId),
    'cli_version': _bounded(metadata?.version),
    'child_steps_capability': metadata?.primeAgentChildStepsVersion == null
        ? 'unknown'
        : 'known',
    'child_steps_version': metadata?.primeAgentChildStepsVersion,
    'child_steps_revision': _bounded(metadata?.primeAgentChildStepsRevision),
    // This client observes its resident projection, never the full transcript.
    'resident_only': true,
  };

  void recordIngress({
    required String source,
    required List<Map<String, dynamic>> incoming,
    Metadata? metadata,
  }) {
    final input = SidechainSnapshot.inspect(incoming);
    final otel = OpenTelemetryService();
    final labels = <String, Object?>{
      'source': source == 'socket' ? 'socket' : 'http',
      'capability': metadata?.primeAgentChildStepsVersion == null
          ? 'unknown'
          : 'known',
    };
    otel.recordCount(
      'app.sidechain.incoming_linked_rows',
      value: input.counts['linked_rows']! as int,
      attributes: labels,
      description: 'Linked row observations at ingestion, including repeats',
    );
    if (input.counts['truncated'] == true) {
      otel.recordCount('app.sidechain.ingress_truncated', attributes: labels);
    }
  }

  void recordGrouping({
    required String sessionId,
    required int runtimeGeneration,
    required String source,
    required List<Map<String, dynamic>> incoming,
    required List<Map<String, dynamic>> resident,
    bool hasUnloadedHistoryGap = false,
    bool groupingApplied = true,
    Metadata? metadata,
  }) {
    if (!_groupingGate.shouldEmit(
      sessionId,
      runtimeGeneration,
      DateTime.now(),
    )) {
      return;
    }
    final input = SidechainSnapshot.inspect(incoming);
    final snapshot = SidechainSnapshot.inspect(resident);
    final labels = <String, Object?>{
      'source': source == 'socket' ? 'socket' : 'http',
      'capability': metadata?.primeAgentChildStepsVersion == null
          ? 'unknown'
          : 'known',
    };
    OpenTelemetryService().recordCount(
      'app.sidechain.grouping_reports',
      attributes: labels,
    );
    _emit('grouping', {
      ..._metadata(sessionId, metadata),
      ...snapshot.counts,
      'source': labels['source'],
      'incoming_rows': incoming.length,
      'incoming_linked_rows': input.counts['linked_rows'],
      'incoming_truncated': input.counts['truncated'],
      'unloaded_history_gap': hasUnloadedHistoryGap,
      'grouping_applied': groupingApplied,
    });
  }

  void recordScreen({
    required String sessionId,
    required String selectedMessageId,
    required List<Map<String, dynamic>> resident,
    required int renderedChildren,
    bool renderedChildrenTruncated = false,
    bool hasUnloadedHistoryGap = false,
    Map<String, dynamic>? selected,
    Metadata? metadata,
  }) {
    if (_screenEpoch != _runtimeEpoch) {
      dispose();
      _screenEpoch = _runtimeEpoch;
    }
    final snapshot = SidechainSnapshot.inspect(
      resident,
      selectedId: selectedMessageId,
    );
    final selectedToolUseId = selected?['toolUseId'];
    final attributes = <String, Object?>{
      ..._metadata(sessionId, metadata),
      ...snapshot.counts,
      'selected_message_id': _bounded(selectedMessageId),
      'selected_tool_use_id': _bounded(
        selectedToolUseId is String
            ? selectedToolUseId
            : snapshot.selectedToolUseId,
      ),
      'selected_found': snapshot.selectedFound,
      'selected_resident_children': snapshot.selectedChildren,
      'rendered_children': renderedChildren,
      'rendered_children_truncated': renderedChildrenTruncated,
      'empty': renderedChildren == 0,
      'unloaded_history_gap': hasUnloadedHistoryGap,
    };
    final signature = jsonEncode(attributes);
    if (_screenSignature == signature) return;
    _screenSignature = signature;
    attributes['event'] = !_screenOpened
        ? 'open'
        : renderedChildren == 0
        ? 'empty'
        : 'changed';
    _screenOpened = true;
    _screenPending = attributes;
    // Retain only the latest primitive counts/IDs, never message maps. Flush a
    // final fast change even when no later ingress event opens the gate.
    if (_screenGate.shouldEmit(sessionId, 0, DateTime.now())) {
      _flushScreen();
    } else {
      _pendingScreens.add(this);
      while (_pendingScreens.length > SidechainDiagnosticGate.maxSessions) {
        _pendingScreens.first.dispose();
      }
      _screenTimer ??= Timer(const Duration(seconds: 30), () {
        _screenGate.shouldEmit(sessionId, 0, DateTime.now());
        _flushScreen();
      });
    }
  }

  void _flushScreen() {
    _pendingScreens.remove(this);
    _screenTimer?.cancel();
    _screenTimer = null;
    final attributes = _screenPending;
    _screenPending = null;
    if (attributes == null) return;
    OpenTelemetryService().recordCount(
      'app.sidechain.child_screen_reports',
      attributes: {'event': attributes['event'], 'empty': attributes['empty']},
    );
    _emit('child_screen', attributes);
  }

  /// The mounted screen owns this reporter and cancels pending work on exit.
  void dispose() {
    _pendingScreens.remove(this);
    _screenTimer?.cancel();
    _screenTimer = null;
    _screenPending = null;
    _screenSignature = null;
    _screenOpened = false;
    _screenGate.reset();
  }

  void _emit(String stage, Map<String, Object?> attributes) {
    final span = OpenTelemetryService().startTrace(
      'app.sidechain.$stage',
      attributes: attributes,
    );
    final payload = {
      'stage': stage,
      ...attributes,
      if (span != null) 'trace_id': span.spanContext.traceId.toString(),
    };
    logger.infoTelemetry('[sidechain] ${jsonEncode(payload)}');
    span?.end();
  }
}
