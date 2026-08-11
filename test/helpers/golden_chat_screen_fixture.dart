import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

const goldenChatSessionId = 'golden-chat-session';

Session goldenChatSession() => const Session(
  id: goldenChatSessionId,
  seq: 4,
  createdAt: 1700000000000,
  updatedAt: 1700050000000,
  active: true,
  activeAt: 1700050000000,
  metadataVersion: 1,
  agentStateVersion: 1,
  thinking: false,
  presence: 'online',
  metadata: Metadata(
    host: 'mbp-work.local',
    path: '/Users/alex/work/backend-api',
    name: 'Backend API',
  ),
);

/// Seeds the real [ChatScreen] data source without a server or encryption.
void seedGoldenChatScreen() {
  sync.isInitialized = true;
  sync.messagesSync[goldenChatSessionId] = InvalidateSync(() async {});
  sync.testSessions[goldenChatSessionId] = goldenChatSession();
  sync.testSetSessionMessages(goldenChatSessionId, const [
    {
      'id': 'golden-user-1',
      'localId': 'golden-local-1',
      'role': 'user',
      'content': 'Please inspect the API client and make retries safer.',
      'sendStatus': 'sent',
    },
    {
      'id': 'golden-assistant-1',
      'role': 'assistant',
      'content':
          'I found two retry paths that could race. I will unify them behind '
          'one request policy and preserve the original request identity.',
    },
    {
      'id': 'golden-tool-1',
      'role': 'assistant',
      'kind': 'tool-call',
      'name': 'Read',
      'toolUseId': 'golden-read-1',
      'state': 'completed',
      'input': {
        'file_path': '/Users/alex/work/backend-api/lib/api_client.dart',
      },
      'result': 'class ApiClient { /* existing retry policy */ }',
    },
    {
      'id': 'golden-assistant-2',
      'role': 'assistant',
      'content': 'The retry policy is now centralized and bounded.',
    },
  ]);
}

void clearGoldenChatScreen() {
  sync.testClearSessionMessageState(goldenChatSessionId);
  sync.testSessions.remove(goldenChatSessionId);
  sync.isInitialized = false;
}
