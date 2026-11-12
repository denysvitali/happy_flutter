import '../../../core/models/session.dart';
import 'sub_session_projection.dart';

/// Agent-row field: child session id of a happy-session thread row.
const String subSessionChildIdField = '_subSessionChildId';

/// Agent-row field: [SubSessionChildState.name] of the child.
const String subSessionChildStateField = '_subSessionChildState';

/// Agent-row field: number of turns sent to the child.
const String subSessionTurnCountField = '_subSessionTurnCount';

/// Agent-row field: the child's title, when the session is known.
const String subSessionTitleField = '_subSessionTitle';

/// Child session id when [agent] is a happy-session thread row or call.
String? subSessionAgentChildId(Map<String, dynamic> agent) {
  final stamped = agent[subSessionChildIdField];
  if (stamped is String && stamped.isNotEmpty) return stamped;
  return isHappySubSessionSpawn(agent) ? happySubSessionChildId(agent) : null;
}

/// Counter contribution of the sub-session rows.
class SubSessionRowCounts {
  const SubSessionRowCounts({
    required this.running,
    required this.completed,
    required this.error,
  });

  final int running;
  final int completed;
  final int error;

  int get total => running + completed + error;
}

/// Agent rows for happy-session spawns: one row per child session, built
/// from that child's latest turn, with a live `state` that settles turns
/// whose result never arrived (see [isSubSessionTurnOpen]).
///
/// [calls] are the resident spawn calls in transcript order; [lookup]
/// reads the child from the session store and [titleOf] names it.
({List<Map<String, dynamic>> rows, SubSessionRowCounts counts, int signature})
buildSubSessionAgentRows(
  List<Map<String, dynamic>> calls, {
  required Session? Function(String sessionId) lookup,
  required String Function(Session session) titleOf,
  required int nowMs,
}) {
  final threads = SubSessionThreads.fromMessages(calls);
  final latestByChild = <String, Map<String, dynamic>>{};
  final countByChild = <String, int>{};
  for (final call in calls) {
    final childId = happySubSessionChildId(call);
    if (childId == null) continue;
    final position = threads.positionOf(call);
    if (position == null) continue;
    countByChild[childId] = position.count;
    if (position.isLatest) latestByChild[childId] = call;
  }

  final rows = <Map<String, dynamic>>[];
  var running = 0;
  var completed = 0;
  var error = 0;
  var signature = 0;
  for (final MapEntry(key: childId, value: call) in latestByChild.entries) {
    final child = lookup(childId);
    final state = subSessionAgentRowState(
      call,
      child: child,
      superseded: false,
      nowMs: nowMs,
    );
    final childState = subSessionChildState(child);
    switch (state) {
      case 'running':
        running++;
      case 'error':
        error++;
      default:
        completed++;
    }
    final title = child == null ? null : titleOf(child);
    signature = Object.hash(
      signature,
      call,
      state,
      childState,
      title,
      countByChild[childId],
    );
    rows.add(<String, dynamic>{
      ...call,
      'state': state,
      subSessionChildIdField: childId,
      subSessionChildStateField: childState.name,
      subSessionTurnCountField: countByChild[childId] ?? 1,
      subSessionTitleField: ?title,
    });
  }
  return (
    rows: rows,
    counts: SubSessionRowCounts(
      running: running,
      completed: completed,
      error: error,
    ),
    signature: signature,
  );
}
