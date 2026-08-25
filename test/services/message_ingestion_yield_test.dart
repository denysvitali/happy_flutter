import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

/// The post-decrypt ingest tail used to run as one long synchronous span.
/// These contract tests pin the observable behavior that any yield-based
/// split must preserve: FIFO mutation order, one canonical localId, no
/// duplicate rows, and exactly one UI notification per batch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> text(String id, int seq) => {
    'id': id,
    'seq': seq,
    'createdAt': seq * 1000,
    'role': 'assistant',
    'kind': 'text',
    'content': 'row $id',
  };

  Map<String, dynamic> toolCall(String id, String toolUseId, int seq) => {
    'id': id,
    'seq': seq,
    'createdAt': seq * 1000,
    'role': 'assistant',
    'kind': 'tool-call',
    'toolUseId': toolUseId,
    'state': 'running',
  };

  test('a large socket batch yields between mutation phases', () async {
    final sync = createTestSync();
    addTearDown(sync.testClearAllSessionMessageState);
    const sessionId = 'sess-ingest-yield';
    sync.testClearSessionMessageState(sessionId);
    sync.encryption = _FakeEncryption(_YieldingSessionEncryption());
    sync.testPostDecryptMutationYieldOverride = () async {
      _YieldingSessionEncryption.yieldCount++;
    };
    addTearDown(() => sync.testPostDecryptMutationYieldOverride = null);

    await sync.ingestFromSocket(
      MessageIngressEvent(
        source: MessagePipelineSource.socket,
        sessionId: sessionId,
        rawPayload: text('only-row', 1),
      ),
    );

    expect(
      _YieldingSessionEncryption.yieldCount,
      greaterThanOrEqualTo(2),
      reason:
          'the synchronous post-decrypt tail must expose frame boundaries '
          'between the message, auxiliary-state, and grouping phases',
    );
    expect(
      sync.messagesForSession(sessionId),
      hasLength(180),
      reason: 'the yield must not split or duplicate the logical batch',
    );
  });

  test('mutation phases stay ordered across the yield boundary', () async {
    final sync = createTestSync();
    addTearDown(sync.testClearAllSessionMessageState);
    const sessionId = 'sess-ingest-order';
    const localId = 'canonical-local-id';
    sync.testClearSessionMessageState(sessionId);
    sync.encryption = _FakeEncryption(_OrderedSessionEncryption());

    final first = ingestFromHttp(sync, sessionId, [
      text('message-1', 1),
      toolCall('call-1', localId, 2),
    ]);
    final second = ingestFromHttp(sync, sessionId, [
      {
        'id': 'result-1',
        'seq': 3,
        'createdAt': 3000,
        'role': 'assistant',
        'kind': 'tool-result',
        'toolUseId': localId,
        'state': 'completed',
        'result': 'done',
      },
    ]);
    await Future.wait([first, second]);

    final messages = sync.messagesForSession(sessionId);
    expect(messages.map((m) => m['id']), ['message-1', 'call-1']);
    expect(messages.where((m) => m['id'] == 'call-1'), hasLength(1));
    expect(
      messages.singleWhere((m) => m['id'] == 'call-1')['state'],
      'completed',
    );
    expect(sync.messagesRevision(sessionId), greaterThan(0));
  });
}

Future<ProcessedMessageBundle> ingestFromHttp(
  Sync sync,
  String sessionId,
  List<Map<String, dynamic>> messages,
) {
  return sync.ingestFromHttp(
    FetchResponseBatch(
      sessionId: sessionId,
      rawMessages: messages,
      traceId: 'trace-$sessionId',
      isVisibleSession: true,
    ),
    applyMutations: true,
    emitSessionNotification: true,
  );
}

class _FakeEncryption implements Encryption {
  _FakeEncryption(this.sessionEncryption);

  final SessionEncryption sessionEncryption;

  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      sessionEncryption;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _YieldingSessionEncryption implements SessionEncryption {
  static int yieldCount = 0;

  _YieldingSessionEncryption() {
    yieldCount = 0;
  }

  @override
  bool get canDecryptAes => false;

  @override
  Future<ProcessedMessages> decryptAndProcessMessages(
    List<Map<String, dynamic>> messages,
    String sessionId,
  ) async {
    return ProcessedMessages(
      messages: List.generate(
        180,
        (index) => {
          'id': 'row-$index',
          'seq': index + 1,
          'createdAt': (index + 1) * 1000,
          'role': 'assistant',
          'kind': 'text',
          'content': 'row $index',
        },
      ),
      toolResults: const [],
      usageUpdates: const [],
      maxSeq: 180,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OrderedSessionEncryption implements SessionEncryption {
  @override
  bool get canDecryptAes => false;

  @override
  Future<ProcessedMessages> decryptAndProcessMessages(
    List<Map<String, dynamic>> messages,
    String sessionId,
  ) async {
    if (messages.any((m) => m['kind'] == 'tool-result')) {
      return ProcessedMessages(
        messages: const [],
        toolResults: List<Map<String, dynamic>>.from(messages),
        usageUpdates: const [],
        maxSeq: 3,
      );
    }
    return ProcessedMessages(
      messages: messages,
      toolResults: const [],
      usageUpdates: const [],
      maxSeq: 2,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
