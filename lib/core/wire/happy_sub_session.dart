import 'wire_parsers.dart';

/// `subagent_type` happy-cli-go stamps on Agent calls that spawn (or follow
/// up with) a separate child Happy session.
const String happySubSessionAgentType = 'happy-session';

/// Whether [message] is an Agent/Task tool call that drives a child Happy
/// session rather than an in-process subagent.
///
/// The child is a separate session with its own transcript: the parent
/// chat never receives sidechain rows for it, so these calls must not be
/// treated as sidechain containers.
bool isHappySubSessionSpawn(Map<String, dynamic> message) {
  if (message['kind'] != 'tool-call') return false;
  final name = message['name'];
  if (name != 'Agent' && name != 'Task') return false;
  final input = WireParsers.asMap(message['input']);
  return input?['subagent_type'] == happySubSessionAgentType;
}

/// Child session id of a happy-session spawn: `input.sessionId`, then
/// `input.agentId`, then the call's top-level `agentId`.
String? happySubSessionChildId(Map<String, dynamic> message) {
  final input = WireParsers.asMap(message['input']);
  for (final value in [
    input?['sessionId'],
    input?['agentId'],
    message['agentId'],
  ]) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}
