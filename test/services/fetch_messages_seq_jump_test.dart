// Contract tests for the seq-jump placeholder behaviour in fetchMessages.
//
// When a page of raw messages decrypts to nothing visible, fetchMessages
// must distinguish between:
//   - expected invisible content (empty acks, control events) -> stay silent
//   - genuine parser drift (unknown dataType, malformed envelope) -> placeholder
//
// A common false positive is silently-dropped messages: the processor skips
// blocks without adding a droppedReason. In that case there is no evidence of
// drift, so the chat must not show an "Unsupported messages" placeholder.

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';

class _ConfigurableSessionEncryption implements SessionEncryption {
  _ConfigurableSessionEncryption({
    required this.maxSeq,
    this.droppedReasons = const [],
  });

  final int maxSeq;
  final List<String> droppedReasons;

  @override
  Future<ProcessedMessages> decryptAndProcessMessages(
    List<Map<String, dynamic>> messages,
    String sessionId,
  ) async {
    return ProcessedMessages(
      messages: const [],
      toolResults: const [],
      usageUpdates: const [],
      maxSeq: maxSeq,
      droppedReasons: droppedReasons,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEncryption implements Encryption {
  _FakeEncryption(this._sessionEncryption);

  final SessionEncryption _sessionEncryption;

  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      _sessionEncryption;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _stubAllSyncs(Sync instance) {
  instance.sessionsSync = InvalidateSync(() async {});
  instance.settingsSync = InvalidateSync(() async {});
  instance.profileSync = InvalidateSync(() async {});
  instance.purchasesSync = InvalidateSync(() async {});
  instance.machinesSync = InvalidateSync(() async {});
  instance.pushTokenSync = InvalidateSync(() async {});
  instance.nativeUpdateSync = InvalidateSync(() async {});
  instance.artifactsSync = InvalidateSync(() async {});
  instance.messagesSync.clear();
}

void main() {
  group('fetchMessages seq-jump placeholder contract', () {
    late Sync instance;
    const sessionId = 'sess-silent-drop';

    setUp(() {
      instance = Sync();
      _stubAllSyncs(instance);
      instance.testIsInitialized = true;
      instance.testVisibleSessionId = sessionId;
      instance.testClearSessionMessageState(sessionId);
      instance.testSessions[sessionId] = Session(
        id: sessionId,
        seq: 10,
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
        active: true,
        activeAt: 1700000000000,
        metadataVersion: 1,
        agentStateVersion: 1,
        thinking: false,
        presence: 'online',
      );
      instance.messagesSync[sessionId] = InvalidateSync(() async {});
    });

    test('silently dropped messages do not create an unsupported-messages '
        'placeholder', () async {
      instance.encryption = _FakeEncryption(
        _ConfigurableSessionEncryption(maxSeq: 10, droppedReasons: const []),
      );
      instance.testFetchMessagesOverride = (_, __, ___) async {
        return <String, dynamic>{
          'messages': <Map<String, dynamic>>[
            {'id': 'm1', 'seq': 8},
            {'id': 'm2', 'seq': 9},
            {'id': 'm3', 'seq': 10},
          ],
          'pagination': <String, dynamic>{'hasMore': false},
        };
      };

      await instance.fetchMessages(sessionId);

      final messages = instance.testSessionMessages(sessionId) ?? [];
      final hasPlaceholder = messages.any(
        (m) =>
            m['kind'] == 'agent-event' &&
            (m['event']?['type'] as String?) == 'unrendered',
      );
      expect(
        hasPlaceholder,
        isFalse,
        reason: 'silent drops (no drift reasons) must not alarm the user',
      );
    });

    test('seq-jump placeholder preserves original dropped reasons, not a '
        'generic seq-advanced label', () async {
      instance.encryption = _FakeEncryption(
        _ConfigurableSessionEncryption(
          maxSeq: 10,
          droppedReasons: const [
            'assistant content list is empty',
            'output data type not handled',
          ],
        ),
      );
      instance.testFetchMessagesOverride = (_, __, ___) async {
        return <String, dynamic>{
          'messages': <Map<String, dynamic>>[
            {'id': 'm1', 'seq': 8},
          ],
          'pagination': <String, dynamic>{'hasMore': false},
        };
      };

      await instance.fetchMessages(sessionId);

      final messages = instance.testSessionMessages(sessionId) ?? [];
      final placeholder = messages.firstWhere(
        (m) =>
            m['kind'] == 'agent-event' &&
            (m['event']?['type'] as String?) == 'unrendered',
        orElse: () => const <String, dynamic>{},
      );
      final reasons =
          (placeholder['debugData']?['droppedReasons'] as List<dynamic>?)
              ?.cast<String>();
      expect(
        reasons,
        isNotNull,
        reason: 'placeholder must carry debug reasons',
      );
      expect(
        reasons,
        contains('output data type not handled'),
        reason: 'unknown drift reason must be preserved for diagnosis',
      );
      expect(
        reasons,
        isNot(contains('seq advanced without UI mutation')),
        reason: 'generic seq-advanced label must not replace real reasons',
      );
    });

    test(
      'handled seq-advanced drops do not create unsupported placeholder',
      () async {
        instance.encryption = _FakeEncryption(
          _ConfigurableSessionEncryption(
            maxSeq: 10,
            droppedReasons: const ['seq advanced without UI mutation'],
          ),
        );
        instance.testFetchMessagesOverride = (_, __, ___) async {
          return <String, dynamic>{
            'messages': <Map<String, dynamic>>[
              {'id': 'm1', 'seq': 8},
            ],
            'pagination': <String, dynamic>{'hasMore': false},
          };
        };

        await instance.fetchMessages(sessionId);

        final messages = instance.testSessionMessages(sessionId) ?? [];
        final hasPlaceholder = messages.any(
          (m) =>
              m['kind'] == 'agent-event' &&
              (m['event']?['type'] as String?) == 'unrendered',
        );
        expect(hasPlaceholder, isFalse);
      },
    );

    test(
      'genuine parser drift still creates an unsupported-messages placeholder',
      () async {
        instance.encryption = _FakeEncryption(
          _ConfigurableSessionEncryption(
            maxSeq: 10,
            droppedReasons: const ['output data type not handled'],
          ),
        );
        instance.testFetchMessagesOverride = (_, __, ___) async {
          return <String, dynamic>{
            'messages': <Map<String, dynamic>>[
              {'id': 'm1', 'seq': 8},
            ],
            'pagination': <String, dynamic>{'hasMore': false},
          };
        };

        await instance.fetchMessages(sessionId);

        final messages = instance.testSessionMessages(sessionId) ?? [];
        final hasPlaceholder = messages.any(
          (m) =>
              m['kind'] == 'agent-event' &&
              (m['event']?['type'] as String?) == 'unrendered',
        );
        expect(
          hasPlaceholder,
          isTrue,
          reason: 'unknown drift must still surface a placeholder',
        );
      },
    );
  });
}
