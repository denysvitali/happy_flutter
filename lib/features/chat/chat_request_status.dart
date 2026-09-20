import 'send/chat_send_coordinator.dart';

enum ChatRequestPhase { none, sending, waiting, reasoning }

/// Presentation only: never changes delivery state or message identity.
typedef ChatRequestStatus = ({ChatRequestPhase phase, String? localId});

/// Reads the resident tail before display filtering removes empty reasoning
/// signals. Verified prompt echoes are removed by Sync before this scan;
/// a sub-agent response cannot answer a user send.
ChatRequestStatus resolveChatRequestStatus(
  List<Map<String, dynamic>> messages,
) {
  const idle = (phase: ChatRequestPhase.none, localId: null);
  var reasoning = false;
  final start = (messages.length - 1000).clamp(0, messages.length);
  for (var i = messages.length - 1; i >= start; i--) {
    final message = messages[i];
    if (message['isSidechain'] == true) continue;
    if (message['role'] == 'user') {
      final status = message['sendStatus'];
      if (status == 'failed' || status == 'pending') {
        return (
          phase: ChatRequestPhase.none,
          localId: canonicalMessageIdentityKey(message),
        );
      }
      return (
        phase: reasoning
            ? ChatRequestPhase.reasoning
            : status == 'sending'
            ? ChatRequestPhase.sending
            : ChatRequestPhase.waiting,
        localId: canonicalMessageIdentityKey(message),
      );
    }
    if (message['role'] != 'agent' && message['role'] != 'assistant') {
      continue;
    }
    if (message['isThinking'] == true) {
      reasoning = true;
      continue;
    }
    final event = message['event'];
    if (event is Map &&
        const {
          'ready',
          'turn-end',
          'stop',
          'aborted',
        }.contains(event['type'])) {
      return idle;
    }
    final kind = message['kind'];
    if (kind == 'error' || kind == 'tool-call') return idle;
    final content = message['content'];
    if ((kind == null || kind == 'text') &&
        content is String &&
        content.trim().isNotEmpty) {
      return idle;
    }
  }
  return idle;
}
