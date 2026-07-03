// Regression tests for the `[pipeline]` breadcrumb contract in
// `message_ingestion_orchestrator.dart`. Loki greps for
// `outcome=(error|dropped)` are the canonical signal for pipeline
// failures; if any of these tests regress the breadcrumb format or
// stop emitting on a real failure, those greps go blind again.
//
// Covered scenarios:
//   - missing session encryption -> `stage=normalized outcome=no-encryption`
//     at `logger.warning`, plus `stage=notified outcome=error` from
//     `ingestFromSocket`.
//   - `decryptAndProcessMessages` throws -> outer catch emits
//     `stage=processed outcome=error` with `{errorMessage}` payload.

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/services/logger_service.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';

class _ThrowingSessionEncryption implements SessionEncryption {
  const _ThrowingSessionEncryption(this._error);

  final Object _error;

  // The orchestrator probes `canDecryptAes` to decide whether to refresh
  // the DEK before decrypting. Returning `false` skips the refresh so the
  // decrypt path runs and `decryptAndProcessMessages` always throws.
  @override
  bool get canDecryptAes => false;

  @override
  Future<ProcessedMessages> decryptAndProcessMessages(
    List<Map<String, dynamic>> messages,
    String sessionId,
  ) async {
    throw _error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OkSessionEncryption implements SessionEncryption {
  const _OkSessionEncryption();

  @override
  bool get canDecryptAes => true;

  @override
  Future<ProcessedMessages> decryptAndProcessMessages(
    List<Map<String, dynamic>> messages,
    String sessionId,
  ) async {
    return ProcessedMessages(
      messages: messages,
      toolResults: const [],
      usageUpdates: const [],
      maxSeq: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEncryption implements Encryption {
  _FakeEncryption(this._sessionEncryption);

  final SessionEncryption? _sessionEncryption;

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
  instance.sessionGitStatusSync = InvalidateSync(() async {});
  instance.messagesSync.clear();
}

/// Returns every `[pipeline]` breadcrumb emitted during the test, in
/// order. Filters by message prefix so unrelated logger entries don't
/// pollute the result.
List<LogEntry> _pipelineBreadcrumbs() {
  return LoggerService()
      .getLogs()
      .where((entry) => entry.message.startsWith('[pipeline]'))
      .toList(growable: false);
}

/// Returns the breadcrumb whose `stage=` and `outcome=` match the
/// given pair. Returns `null` if no such breadcrumb exists.
LogEntry? _findBreadcrumb({
  required String stage,
  required String outcome,
}) {
  for (final entry in _pipelineBreadcrumbs()) {
    final msg = entry.message;
    if (msg.contains('stage=$stage ') && msg.contains('outcome=$outcome')) {
      return entry;
    }
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('message ingestion pipeline breadcrumbs', () {
    late Sync instance;

    setUp(() {
      instance = Sync();
      _stubAllSyncs(instance);
      instance.testIsInitialized = true;
      LoggerService().clear();
    });

    tearDown(LoggerService().clear);

    test(
      'missing session encryption logs `no-encryption` at warning and emits '
      '`notified=error` from ingestFromSocket',
      () async {
        const sessionId = 'sess-no-encryption';
        instance.encryption = _FakeEncryption(null);
        instance.testClearSessionMessageState(sessionId);

        await instance.ingestFromSocket(
          MessageIngressEvent(
            source: MessagePipelineSource.socket,
            sessionId: sessionId,
            rawPayload: <String, dynamic>{
              'id': 'msg-no-enc',
              'seq': 1,
              'createdAt': 1700000000000,
            },
            isVisibleSession: true,
            notifySessionsDomain: true,
          ),
        );

        // The inner `no-encryption` breadcrumb must be emitted from
        // `_processMessageBatch`.
        final noEnc = _findBreadcrumb(
          stage: 'normalized',
          outcome: 'no-encryption',
        );
        expect(
          noEnc,
          isNotNull,
          reason: 'expected `stage=normalized outcome=no-encryption`',
        );
        expect(
          noEnc!.level,
          LogLevel.warning,
          reason: 'no-encryption breadcrumb must be at warning so Loki '
              'captures it in production (debug logs are not forwarded)',
        );

        // `ingestFromSocket` must surface the inner errorMessage as a
        // `notified=error` breadcrumb so Loki greps for
        // `outcome=(error|dropped)` no longer miss this failure.
        final notifiedError = _findBreadcrumb(
          stage: 'notified',
          outcome: 'error',
        );
        expect(
          notifiedError,
          isNotNull,
          reason: 'expected `[pipeline] stage=notified outcome=error` when '
              'inner work set errorMessage',
        );
        expect(
          notifiedError!.message,
          contains('errorMessage'),
          reason: 'notified=error payload must include the errorMessage key',
        );

        // The plaintext `notified=ok` line must NOT be emitted on
        // failure — that's the lie we're fixing.
        expect(
          _findBreadcrumb(stage: 'notified', outcome: 'ok'),
          isNull,
          reason: 'notified=ok must not appear when errorMessage is set',
        );
      },
    );

    test(
      'decryptAndProcessMessages throw is captured as `processed=error` '
      'breadcrumb under the pipeline namespace',
      () async {
        const sessionId = 'sess-throw';
        const thrown = 'crypto-secret-box-mac-failed';
        instance.encryption = _FakeEncryption(
          const _ThrowingSessionEncryption(thrown),
        );
        instance.testClearSessionMessageState(sessionId);

        await instance.ingestFromSocket(
          MessageIngressEvent(
            source: MessagePipelineSource.socket,
            sessionId: sessionId,
            rawPayload: <String, dynamic>{
              'id': 'msg-throw',
              'seq': 1,
              'createdAt': 1700000000000,
            },
            isVisibleSession: true,
            notifySessionsDomain: true,
          ),
        );

        final processedError = _findBreadcrumb(
          stage: 'processed',
          outcome: 'error',
        );
        expect(
          processedError,
          isNotNull,
          reason: 'outer catch must emit '
              '`[pipeline] stage=processed outcome=error` so Loki greps '
              'for `outcome=(error|dropped)` see the failure',
        );
        expect(
          processedError!.message,
          contains('errorMessage'),
          reason: 'processed=error payload must include errorMessage key',
        );
        expect(
          processedError.message,
          contains(thrown),
          reason: 'processed=error payload must include the thrown error '
              'message so we can correlate with Sentry',
        );

        // `notified=error` still fires (inner bundle carried the error).
        expect(
          _findBreadcrumb(stage: 'notified', outcome: 'error'),
          isNotNull,
          reason: 'ingestFromSocket must forward outer catch failures as '
              'notified=error',
        );
        expect(
          _findBreadcrumb(stage: 'notified', outcome: 'ok'),
          isNull,
        );
      },
    );

    test(
      'happy path still emits `notified=ok` without errorMessage',
      () async {
        const sessionId = 'sess-happy';
        instance.encryption = _FakeEncryption(const _OkSessionEncryption());
        instance.testClearSessionMessageState(sessionId);

        await instance.ingestFromSocket(
          MessageIngressEvent(
            source: MessagePipelineSource.socket,
            sessionId: sessionId,
            rawPayload: <String, dynamic>{
              'id': 'msg-ok',
              'seq': 1,
              'createdAt': 1700000000000,
            },
            isVisibleSession: true,
            notifySessionsDomain: true,
          ),
        );

        expect(
          _findBreadcrumb(stage: 'notified', outcome: 'ok'),
          isNotNull,
          reason: 'successful ingest still reports notified=ok',
        );
        expect(
          _findBreadcrumb(stage: 'notified', outcome: 'error'),
          isNull,
          reason: 'no errorMessage means no notified=error breadcrumb',
        );
      },
    );
  });

  group('HTTP batch sidechain eligibility (applyMutations=false)', () {
    late Sync instance;

    setUp(() {
      instance = Sync();
      _stubAllSyncs(instance);
      instance.testIsInitialized = true;
      instance.encryption = _FakeEncryption(const _OkSessionEncryption());
    });

    test(
      'taskEvent-only message sets hasSidechain=true on the returned bundle',
      () async {
        const sessionId = 'sess-http-task-event';
        instance.testClearSessionMessageState(sessionId);

        final processed = await instance.ingestFromHttp(
          FetchResponseBatch(
            sessionId: sessionId,
            rawMessages: <Map<String, dynamic>>[
              {
                'id': 'task-1',
                'kind': 'tool-call',
                'name': 'Agent',
                'uuid': 'task-uuid',
              },
              {
                'id': 'event-1',
                'kind': 'agent-event',
                'taskEvent': true,
                'parentUuid': 'task-uuid',
              },
            ],
            traceId: 'trace-http-task-event',
            isVisibleSession: true,
          ),
          applyMutations: false,
          emitSessionNotification: false,
        );

        expect(processed.hasSidechain, isTrue);
      },
    );

    test(
      'parentToolUseId-only message sets hasSidechain=true on the returned '
      'bundle',
      () async {
        const sessionId = 'sess-http-parent-tool-use-id';
        instance.testClearSessionMessageState(sessionId);

        final processed = await instance.ingestFromHttp(
          FetchResponseBatch(
            sessionId: sessionId,
            rawMessages: <Map<String, dynamic>>[
              {
                'id': 'task-1',
                'kind': 'tool-call',
                'name': 'Agent',
                'uuid': 'task-uuid',
                'toolUseId': 'toolu_01Parent',
              },
              {
                'id': 'child-1',
                'kind': 'text',
                'parentUuid': 'broken-chain',
                'parentToolUseId': 'toolu_01Parent',
              },
            ],
            traceId: 'trace-http-parent-tool-use-id',
            isVisibleSession: true,
          ),
          applyMutations: false,
          emitSessionNotification: false,
        );

        expect(processed.hasSidechain, isTrue);
      },
    );

    test(
      'sidechain-link bridge message sets hasSidechain=true on the returned '
      'bundle',
      () async {
        const sessionId = 'sess-http-sidechain-link';
        instance.testClearSessionMessageState(sessionId);

        final processed = await instance.ingestFromHttp(
          FetchResponseBatch(
            sessionId: sessionId,
            rawMessages: <Map<String, dynamic>>[
              {
                'id': 'task-1',
                'kind': 'tool-call',
                'name': 'Agent',
                'uuid': 'task-uuid',
              },
              {
                'id': 'link-1',
                'kind': 'sidechain-link',
                'uuid': 'link-uuid',
                'parentUuid': 'task-uuid',
              },
            ],
            traceId: 'trace-http-sidechain-link',
            isVisibleSession: true,
          ),
          applyMutations: false,
          emitSessionNotification: false,
        );

        expect(processed.hasSidechain, isTrue);
      },
    );
  });

}