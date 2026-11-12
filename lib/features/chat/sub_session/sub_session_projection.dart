import '../../../core/models/session.dart';
import '../../../core/utils/session_utils.dart'
    show isSessionOnline, sessionRepository;
import '../../../core/wire/happy_sub_session.dart';
import '../../../core/wire/wire_parsers.dart';

export '../../../core/wire/happy_sub_session.dart';

/// Outcome of one parent → child turn, as reported by happy-cli-go.
enum SubSessionTurnStatus {
  /// The call is posted and its result has not arrived.
  running,

  /// The child replied; `result` holds its final reply.
  completed,

  /// The child failed or the call was rejected.
  failed,

  /// The CLI could not observe the child's outcome.
  unknown,
}

/// Live state of the child session, read from the session store.
enum SubSessionChildState {
  /// The child session is not in the local store (yet).
  notLoaded,

  /// The child process is starting (e.g. its pod is scheduling).
  starting,

  /// The child is running a turn.
  working,

  /// The child is online and waiting for input.
  idle,

  /// The child's process is not connected.
  offline,

  /// The child's process reported a lifecycle error.
  stopped,

  /// The child session is archived.
  archived,
}

/// How long a turn may wait for a still-idle child before the agents
/// banner stops counting it as running. A child normally starts thinking
/// within seconds of a spawn or follow-up.
const Duration subSessionIdleGrace = Duration(seconds: 90);

/// Status of [call] from its merged state and the reported result status.
SubSessionTurnStatus subSessionTurnStatus(Map<String, dynamic> call) {
  final resultStatus = WireParsers.parseString(call['resultStatus']);
  if (resultStatus == 'unknown') return SubSessionTurnStatus.unknown;
  if (resultStatus == 'failed' || resultStatus == 'error') {
    return SubSessionTurnStatus.failed;
  }
  return switch (call['state']) {
    'completed' => SubSessionTurnStatus.completed,
    'error' => SubSessionTurnStatus.failed,
    _ => SubSessionTurnStatus.running,
  };
}

/// Live state of [child], or [SubSessionChildState.notLoaded] when absent.
SubSessionChildState subSessionChildState(Session? child) {
  if (child == null) return SubSessionChildState.notLoaded;
  if (child.thinking) return SubSessionChildState.working;
  final lifecycle = child.effectiveLifecycleState;
  if (lifecycle == 'starting') return SubSessionChildState.starting;
  if (child.hasLifecycleError && !child.isAliveDespiteLifecycleError) {
    return SubSessionChildState.stopped;
  }
  if (child.archived && !isSessionOnline(child)) {
    return SubSessionChildState.archived;
  }
  if (isSessionOnline(child) || child.active) return SubSessionChildState.idle;
  return SubSessionChildState.offline;
}

/// The child's final reply text from a merged result, or null.
String? subSessionReply(Map<String, dynamic> call) {
  final text = _resultText(call['result'])?.trim();
  return text == null || text.isEmpty ? null : text;
}

String? _resultText(dynamic result) {
  if (result is String) return result;
  if (result is Map) {
    for (final key in const ['text', 'content', 'result', 'output']) {
      final nested = _resultText(result[key]);
      if (nested != null) return nested;
    }
    return null;
  }
  if (result is List) {
    final parts = [
      for (final item in result)
        if (_resultText(item) case final String text) text,
    ];
    return parts.isEmpty ? null : parts.join('\n\n');
  }
  return null;
}

/// Short `owner/repo` (or folder) for [child], when known.
String? subSessionRepositoryLabel(Session? child) {
  if (child == null) return null;
  final repository = sessionRepository(child);
  if (repository != null) return repository.path;
  final path = child.metadata?.path;
  if (path == null || path.isEmpty) return null;
  final segments = path.split('/').where((s) => s.isNotEmpty);
  return segments.isEmpty ? null : segments.last;
}

/// Position of one turn inside the thread of calls to the same child.
class SubSessionTurnPosition {
  const SubSessionTurnPosition({required this.number, required this.count});

  /// 1-based turn number; 1 is the spawn, later numbers are follow-ups.
  final int number;

  /// Number of turns to the same child resident in the transcript.
  final int count;

  bool get isFollowUp => number > 1;
  bool get isLatest => number == count;
}

/// All happy-session turns of one parent transcript, grouped by child.
class SubSessionThreads {
  SubSessionThreads._(this._turnsByChild, this._childByCall);

  /// Indexes every happy-session call in [messages] (recursing into
  /// `children`). Turns to a child are ordered by `seq`, then `createdAt`,
  /// then transcript position.
  factory SubSessionThreads.fromMessages(List<dynamic> messages) {
    final found = <({Map<String, dynamic> call, int order})>[];
    final visited = <Map<String, dynamic>>{};
    void walk(List<dynamic> values, int depth) {
      if (depth > 8) return;
      for (final value in values) {
        if (value is! Map<String, dynamic> || !visited.add(value)) continue;
        if (isHappySubSessionSpawn(value)) {
          found.add((call: value, order: found.length));
        }
        final children = WireParsers.asList(value['children']);
        if (children != null) walk(children, depth + 1);
      }
    }

    walk(messages, 0);
    final byChild = <String, List<({Map<String, dynamic> call, int order})>>{};
    for (final entry in found) {
      final childId = happySubSessionChildId(entry.call);
      if (childId == null) continue;
      byChild.putIfAbsent(childId, () => []).add(entry);
    }
    final turnsByChild = <String, List<String>>{};
    final childByCall = <String, String>{};
    byChild.forEach((childId, entries) {
      entries.sort((a, b) {
        final bySeq = _num(a.call['seq']).compareTo(_num(b.call['seq']));
        if (bySeq != 0) return bySeq;
        final byTime = _num(
          a.call['createdAt'],
        ).compareTo(_num(b.call['createdAt']));
        if (byTime != 0) return byTime;
        return a.order.compareTo(b.order);
      });
      final keys = <String>[];
      for (final entry in entries) {
        final key = subSessionTurnKey(entry.call);
        if (key == null || childByCall.containsKey(key)) continue;
        keys.add(key);
        childByCall[key] = childId;
      }
      turnsByChild[childId] = List.unmodifiable(keys);
    });
    return SubSessionThreads._(turnsByChild, childByCall);
  }

  final Map<String, List<String>> _turnsByChild;
  final Map<String, String> _childByCall;

  /// Child session ids with at least one resident turn.
  Iterable<String> get childIds => _turnsByChild.keys;

  /// Position of [call] in its child's thread, or null when unindexed.
  SubSessionTurnPosition? positionOf(Map<String, dynamic> call) {
    final key = subSessionTurnKey(call);
    final childId = key == null ? null : _childByCall[key];
    if (childId == null) return null;
    final turns = _turnsByChild[childId]!;
    return SubSessionTurnPosition(
      number: turns.indexOf(key!) + 1,
      count: turns.length,
    );
  }
}

/// Stable identity of one turn: its call id, else its message id.
String? subSessionTurnKey(Map<String, dynamic> call) {
  for (final value in [call['toolUseId'], call['id']]) {
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
}

num _num(dynamic value) => value is num ? value : 0;

/// Whether a turn without a result should still count as running.
///
/// A result that never arrives must not keep the agents banner busy
/// forever. A turn stops counting once a later turn to the same child
/// exists ([superseded]), the child is archived or stopped, or the child
/// has stayed out of a turn for [subSessionIdleGrace] after the call.
bool isSubSessionTurnOpen(
  Map<String, dynamic> call, {
  required Session? child,
  required bool superseded,
  required int nowMs,
}) {
  if (subSessionTurnStatus(call) != SubSessionTurnStatus.running) {
    return false;
  }
  if (superseded) return false;
  final state = subSessionChildState(child);
  switch (state) {
    case SubSessionChildState.notLoaded:
    case SubSessionChildState.starting:
    case SubSessionChildState.working:
      return true;
    case SubSessionChildState.archived:
    case SubSessionChildState.stopped:
      return false;
    case SubSessionChildState.idle:
    case SubSessionChildState.offline:
      final createdAt = call['createdAt'];
      if (createdAt is! num) return true;
      return nowMs - createdAt < subSessionIdleGrace.inMilliseconds;
  }
}

/// Agent-row state for the agents sheet and banner counters:
/// `running`, `completed` or `error`. Failed and unknown outcomes count as
/// `error` so they draw attention; a turn that settled without a result
/// (see [isSubSessionTurnOpen]) counts as `completed`.
String subSessionAgentRowState(
  Map<String, dynamic> call, {
  required Session? child,
  required bool superseded,
  required int nowMs,
}) {
  switch (subSessionTurnStatus(call)) {
    case SubSessionTurnStatus.completed:
      return 'completed';
    case SubSessionTurnStatus.failed:
    case SubSessionTurnStatus.unknown:
      return 'error';
    case SubSessionTurnStatus.running:
      return isSubSessionTurnOpen(
            call,
            child: child,
            superseded: superseded,
            nowMs: nowMs,
          )
          ? 'running'
          : 'completed';
  }
}
