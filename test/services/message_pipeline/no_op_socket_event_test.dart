// Contract test for the no-op socket event path in the message pipeline.
//
// Server keepalives and control events can advance the seq cursor without
// producing a visible chat row. The pipeline must still advance
// _sessionLastSeq so gap detection stays correct, but it must not emit
// onSessionMessagesChanged / onDataChanged for a truly invisible event,
// otherwise every streaming token triggers a pointless UI rebuild.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

class _NoOpSessionEncryption implements SessionEncryption {
  final int maxSeq;

  const _NoOpSessionEncryption({required this.maxSeq});

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
    );
  }

  @override
  bool get canDecryptAes => false;

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
  group('no-op socket event pipeline contract', () {
    late Sync instance;

    setUp(() {
      instance = Sync();
      _stubAllSyncs(instance);
      instance.testIsInitialized = true;
      instance.encryption = _FakeEncryption(
        const _NoOpSessionEncryption(maxSeq: 42),
      );
      instance.testClearSessionMessageState('sess-noop');
    });

    test(
      'socket event with no visible mutation advances cursor but does not '
      'notify session/domain streams',
      () {
        fakeAsync((async) {
          const sessionId = 'sess-noop';
          final sessionEmits = <String>[];
          final domainEmits = <void>[];

          final sessionSub = instance.onSessionMessagesChanged
              .listen((id) => sessionEmits.add(id));
          final domainSub = instance.onDataChanged
              .listen((_) => domainEmits.add(null));

          instance.ingestFromSocket(
            MessageIngressEvent(
              source: MessagePipelineSource.socket,
              sessionId: sessionId,
              rawPayload: <String, dynamic>{
                'id': 'msg-noop',
                'seq': 42,
                'createdAt': 1700000000000,
              },
              isVisibleSession: true,
              notifySessionsDomain: true,
            ),
          );

          async.elapse(const Duration(seconds: 1));

          expect(
            instance.testGetSessionLastSeq(sessionId),
            42,
            reason: 'cursor must advance even for no-op events',
          );
          expect(
            sessionEmits,
            isEmpty,
            reason: 'no-op events must not wake onSessionMessagesChanged',
          );
          expect(
            domainEmits,
            isEmpty,
            reason: 'no-op events must not wake onDataChanged',
          );

          sessionSub.cancel();
          domainSub.cancel();
        });
      },
    );
  });
}
