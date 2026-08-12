import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

const goldenChatSessionId = 'golden-chat-session';

/// Seed timestamp that renders the same string on every calendar day.
///
/// Session cards and the chat header print "last seen" relative to
/// `DateTime.now()`, so a fixed epoch rots the baselines: a Nov-2023
/// timestamp rendered "1000d ago" the day the goldens were generated and
/// "1001d ago" the next, failing CI on an unchanged tree. Anchoring under
/// two minutes before the run pins every label at "1m ago" and keeps the
/// seeded rows on today's date header outside the first minutes after
/// midnight.
///
/// [ageSeconds] must stay inside 61-119 so the label does not change; give
/// each seeded session a distinct value, because the session list sorts by
/// timestamp and equal values leave the row order — and therefore the
/// screenshot — undefined.
int goldenSeededTimestamp({int ageSeconds = 90}) => DateTime.now()
    .subtract(Duration(seconds: ageSeconds))
    .millisecondsSinceEpoch;

Session goldenChatSession() => Session(
  id: goldenChatSessionId,
  seq: 4,
  createdAt: goldenSeededTimestamp(),
  updatedAt: goldenSeededTimestamp(),
  active: true,
  activeAt: goldenSeededTimestamp(),
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
