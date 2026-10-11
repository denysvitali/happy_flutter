import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

void main() {
  late Sync sync;
  const sessionId = 'runtime-ingest';

  Map<String, dynamic> row(String id, int seq, {String? localId}) => {
    'id': id,
    'seq': seq,
    'localId': localId,
    'createdAt': seq * 1000,
    'role': 'user',
    'kind': 'text',
    'content': 'continue',
  };

  setUp(() {
    sync = createTestSync();
    resetTestSync(sync);
    sync.testIsInitialized = true;
    sync.testSessions[sessionId] = Session(
      id: sessionId,
      seq: 1,
      createdAt: 0,
      updatedAt: 0,
      active: true,
      activeAt: 0,
      metadataVersion: 1,
      agentStateVersion: 1,
      thinking: false,
      lastSeq: 200,
    );
    sync.encryption = _Encryption(_Decryptor());
    sync.testFetchMessagesOverride = (_, _, _) async => {
      'messages': [row('old', 200)],
      'hasMore': false,
    };
  });

  tearDown(() {
    sync.testPostDecryptMutationYieldOverride = null;
    sync.testFetchMessagesOverride = null;
    sync.testSetVisibleSessionId(null);
    resetTestSync(sync);
    sync.testResetDataChangeDebounce();
    sync.testIsInitialized = false;
  });

  void replaceRuntime() {
    sync.testAdvanceRuntimeGeneration();
    sync.testClearAllSessionMessageState();
    sync.testClearSpawnGuardState();
    sync.testClearInlineDedupState();
    sync.testSetSessionMessages(sessionId, [row('new', 7)]);
    sync.testSetSessionLastSeq(sessionId, 7);
  }

  void expectReplacementUntouched() {
    expect(sync.messagesForSession(sessionId).map((m) => m['id']), ['new']);
    expect(sync.testGetSessionLastSeq(sessionId), 7);
    expect(sync.testHasPendingSaveTimer(sessionId), isFalse);
  }

  test('forward HTTP completion cannot publish across reset', () async {
    final started = Completer<void>();
    final release = Completer<Map<String, dynamic>>();
    sync.testFetchMessagesOverride = (_, _, _) {
      started.complete();
      return release.future;
    };
    final work = sync.fetchMessages(sessionId);
    await started.future;
    replaceRuntime();
    release.complete({
      'messages': [row('old', 200)],
      'hasMore': false,
    });
    await work;
    expectReplacementUntouched();
  });

  test('forward decrypt completion cannot publish across reset', () async {
    final decryptor = _Decryptor(block: true);
    sync.encryption = _Encryption(decryptor);
    final work = sync.fetchMessages(sessionId);
    await decryptor.started.future;
    replaceRuntime();
    decryptor.release.complete();
    await work;
    expectReplacementUntouched();
  });

  for (final phase in [1, 2]) {
    test('forward merge yield $phase cannot publish across reset', () async {
      final started = Completer<void>();
      final release = Completer<void>();
      var yields = 0;
      sync.testPostDecryptMutationYieldOverride = () async {
        if (++yields == phase) {
          started.complete();
          await release.future;
        }
      };
      final work = sync.fetchMessages(sessionId);
      await started.future;
      replaceRuntime();
      release.complete();
      await work;
      expectReplacementUntouched();
    });

    test('socket mutation yield $phase cannot publish across reset', () async {
      final started = Completer<void>();
      final release = Completer<void>();
      var yields = 0;
      sync.encryption = _Encryption(_Decryptor(large: true));
      sync.testPostDecryptMutationYieldOverride = () async {
        if (++yields == phase) {
          started.complete();
          await release.future;
        }
      };
      final work = sync.ingestFromSocket(
        MessageIngressEvent(
          source: MessagePipelineSource.socket,
          sessionId: sessionId,
          rawPayload: row('old', 200),
        ),
      );
      await started.future;
      replaceRuntime();
      release.complete();
      await work;
      expectReplacementUntouched();
    });
  }

  test('socket decrypt completion cannot publish across reset', () async {
    final decryptor = _Decryptor(block: true);
    sync.encryption = _Encryption(decryptor);
    final work = sync.ingestFromSocket(
      MessageIngressEvent(
        source: MessagePipelineSource.socket,
        sessionId: sessionId,
        rawPayload: row('old', 200),
      ),
    );
    await decryptor.started.future;
    replaceRuntime();
    decryptor.release.complete();
    await work;
    expectReplacementUntouched();
  });

  test(
    'socket decrypt failure after reset does not invalidate new sync',
    () async {
      final decryptor = _Decryptor(block: true);
      sync.encryption = _Encryption(decryptor);
      final work = sync.ingestFromSocket(
        MessageIngressEvent(
          source: MessagePipelineSource.socket,
          sessionId: sessionId,
          rawPayload: row('old', 200),
        ),
      );
      await decryptor.started.future;
      replaceRuntime();
      decryptor.release.completeError(StateError('old decrypt failed'));
      await work;
      expectReplacementUntouched();
    },
  );

  test('queued socket events reject their captured old generation', () async {
    final event = MessageIngressEvent(
      source: MessagePipelineSource.socket,
      sessionId: sessionId,
      rawPayload: row('old', 200),
      metadata: const {'runtimeGeneration': -1},
    );
    replaceRuntime();
    await sync.ingestFromSocketBatch([event]);
    expectReplacementUntouched();
  });

  test('reset between visibility groups drops remaining old events', () async {
    final decryptor = _Decryptor(block: true);
    sync.encryption = _Encryption(decryptor);
    final work = sync.ingestFromSocketBatch([
      MessageIngressEvent(
        source: MessagePipelineSource.socket,
        sessionId: sessionId,
        rawPayload: row('old', 200),
        isVisibleSession: true,
      ),
      MessageIngressEvent(
        source: MessagePipelineSource.socket,
        sessionId: sessionId,
        rawPayload: row('old-next-group', 201),
        isVisibleSession: false,
      ),
    ]);
    await decryptor.started.future;
    replaceRuntime();
    decryptor.release.complete();
    await work;
    expectReplacementUntouched();
    expect(decryptor.calls, 1);
  });

  test(
    'old message queue cleanup cannot clear new runtime busy marker',
    () async {
      final started = Completer<void>();
      final release = Completer<Map<String, dynamic>>();
      sync.testFetchMessagesOverride = (_, _, _) {
        started.complete();
        return release.future;
      };
      sync.prepareSessionVisibility(sessionId);
      final oldQueue = sync.messagesSync[sessionId]!;
      oldQueue.invalidate();
      await started.future;
      sync.testAdvanceRuntimeGeneration();
      sync.testResetSyncState();
      sync.testOnSyncRunningChanged('replacement', true);
      oldQueue.dispose();
      expect(sync.isSyncing, isTrue);
      release.complete({'messages': <dynamic>[], 'hasMore': false});
      await Future<void>.delayed(Duration.zero);
      expect(sync.isSyncing, isTrue);
      sync.testOnSyncRunningChanged('replacement', false);
    },
  );

  test(
    'old older-fetch cleanup cannot clear new runtime busy marker',
    () async {
      final firstStarted = Completer<void>();
      final secondStarted = Completer<void>();
      final firstResponse = Completer<Map<String, dynamic>>();
      final secondResponse = Completer<Map<String, dynamic>>();
      var calls = 0;
      sync.testSetSessionFirstLoadedSeq(sessionId, 1001);
      sync.testFetchOlderMessagesOverride = (_, _, _) {
        if (++calls == 1) {
          firstStarted.complete();
          return firstResponse.future;
        }
        secondStarted.complete();
        return secondResponse.future;
      };
      addTearDown(() => sync.testFetchOlderMessagesOverride = null);
      final oldWork = sync.fetchOlderMessages(sessionId);
      await firstStarted.future;
      replaceRuntime();
      sync.testSetSessionFirstLoadedSeq(sessionId, 1001);
      final newWork = sync.fetchOlderMessages(sessionId);
      await secondStarted.future;
      firstResponse.complete({
        'messages': [row('old', 600)],
        'hasMore': false,
      });
      await oldWork;
      expect(sync.isLoadingOlderMessages(sessionId), isTrue);
      expectReplacementUntouched();
      secondResponse.complete({'messages': <dynamic>[], 'hasMore': false});
      await newWork;
      expect(sync.isLoadingOlderMessages(sessionId), isFalse);
    },
  );

  test(
    'repeated text and overlapping acknowledgments preserve localIds',
    () async {
      sync.testSetSessionMessages(sessionId, [
        row('first', 0, localId: 'first'),
        row('retry', 0, localId: 'retry'),
      ]);
      final persisted = [
        row('ack-retry', 2, localId: 'retry'),
        row('ack-first', 1, localId: 'first'),
      ];
      for (final message in persisted) {
        await sync.ingestFromSocket(
          MessageIngressEvent(
            source: MessagePipelineSource.socket,
            sessionId: sessionId,
            rawPayload: message,
          ),
        );
      }
      await sync.ingestFromHttp(
        FetchResponseBatch(
          sessionId: sessionId,
          rawMessages: persisted,
          traceId: 'overlap',
          isVisibleSession: true,
        ),
        applyMutations: true,
      );
      final messages = sync.messagesForSession(sessionId);
      expect(messages.map((m) => m['id']), ['ack-first', 'ack-retry']);
      expect(messages.map((m) => m['localId']), ['first', 'retry']);
    },
  );
}

class _Encryption implements Encryption {
  _Encryption(this.decryptor);
  final SessionEncryption decryptor;

  @override
  SessionEncryption? getSessionEncryption(String sessionId) => decryptor;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Decryptor implements SessionEncryption {
  _Decryptor({this.block = false, this.large = false});
  final bool block;
  final bool large;
  final started = Completer<void>();
  final release = Completer<void>();
  int calls = 0;

  @override
  bool get canDecryptAes => true;

  @override
  Future<ProcessedMessages> decryptAndProcessMessages(
    List<Map<String, dynamic>> messages,
    String sessionId,
  ) async {
    calls++;
    if (block && calls == 1) {
      started.complete();
      await release.future;
    }
    return ProcessedMessages(
      messages: large
          ? List.generate(
              180,
              (i) => {...messages.first, 'id': 'old-$i', 'seq': i + 1},
            )
          : messages,
      toolResults: const [],
      usageUpdates: const [],
      maxSeq: large
          ? 180
          : messages.fold<int>(
              0,
              (seq, m) => (m['seq'] as int) > seq ? m['seq'] as int : seq,
            ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
