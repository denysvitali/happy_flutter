// Flutter's test clock uses fake_async supplied by flutter_test.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/logger_service.dart';
import 'package:happy_flutter/core/services/opentelemetry_service.dart';
import 'package:happy_flutter/core/services/sidechain_diagnostics.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUp(SidechainDiagnostics.resetRuntime);
  tearDown(SidechainDiagnostics.resetRuntime);
  test('bounded sidechain INFO reaches release telemetry without dev mode', () {
    final forwarded = <LogEntry>[];
    logger
      ..clear()
      ..setMinLevel(LogLevel.debug)
      ..setDeveloperMode(false)
      ..installOtelSink(forwarded.add)
      ..debugReleaseModeOverride = true;
    addTearDown(() {
      logger
        ..removeOtelSink()
        ..debugReleaseModeOverride = null
        ..clear();
    });
    final sentryBefore = logger.debugSentryEmitCount;
    SidechainDiagnostics().recordGrouping(
      sessionId: 'session' * 1000,
      runtimeGeneration: 1,
      source: 'http',
      incoming: const [],
      resident: const [],
      metadata: const Metadata(flavor: 'prime-agent'),
    );
    logger.info('routine INFO');
    expect(forwarded, hasLength(1));
    expect(forwarded.single.level, LogLevel.info);
    expect(forwarded.single.message, startsWith('[sidechain]'));
    expect(forwarded.single.message.length, lessThanOrEqualTo(4096));
    expect(logger.count, 0);
    expect(logger.debugSentryEmitCount, sentryBefore);
  });
  test('counts nested children and flat links without retaining content', () {
    final child = <String, dynamic>{
      'id': 'child',
      'parentToolUseId': 'anchor',
      'text': 'private prose',
      'input': {'secret': 'private input'},
    };
    final snapshot = SidechainSnapshot.inspect([
      {
        'id': 'selected',
        'kind': 'tool-call',
        'name': 'Agent',
        'toolUseId': 'anchor',
        'children': [child],
      },
      {'id': 'orphan', 'parentToolUseId': 'missing'},
      {'id': 'flat-matched', 'parentToolUseId': 'anchor'},
    ], selectedId: 'selected');
    expect(snapshot.counts, {
      'resident_top_level_rows': 3,
      'visited_rows': 4,
      'linked_rows': 3,
      'grouped_children': 1,
      'flat_linked_rows': 2,
      'flat_unmatched_links': 1,
      'agent_anchors': 1,
      'matched_agent_anchors': 1,
      'truncated': false,
    });
    expect(snapshot.selectedFound, isTrue);
    expect(snapshot.selectedToolUseId, 'anchor');
    expect(snapshot.selectedChildren, 1);
    expect(snapshot.counts.toString(), isNot(contains('private')));
    // Inspection must not alter canonical messages.
    expect(child['input'], {'secret': 'private input'});
  });

  test('identity cycles and shared rows are visited once', () {
    final row = <String, dynamic>{'id': 'loop'};
    row['children'] = [row];
    final snapshot = SidechainSnapshot.inspect([row, row]);
    expect(snapshot.counts['visited_rows'], 1);
    expect(snapshot.counts['truncated'], false);
  });

  test('malformed and oversize trees report a bounded partial observation', () {
    final rows = List<Map<String, dynamic>>.generate(
      SidechainSnapshot.maxRows + 1,
      (i) => {'parentToolUseId': i.isEven ? 'anchor' : 7},
    );
    final snapshot = SidechainSnapshot.inspect(rows);
    expect(snapshot.counts['resident_top_level_rows'], rows.length);
    expect(snapshot.counts['visited_rows'], SidechainSnapshot.maxRows);
    expect(snapshot.counts['linked_rows'], SidechainSnapshot.maxRows ~/ 2);
    expect(snapshot.counts['truncated'], true);
  });

  test('rate gate bounds sessions and resets on account/runtime changes', () {
    final gate = SidechainDiagnosticGate();
    final now = DateTime.utc(2026);
    expect(gate.shouldEmit('session', 1, now), isTrue);
    expect(gate.shouldEmit('session', 1, now), isFalse);
    expect(
      gate.shouldEmit('session', 1, now.add(const Duration(seconds: 29))),
      isFalse,
    );
    expect(
      gate.shouldEmit('session', 1, now.add(const Duration(seconds: 30))),
      isTrue,
    );
    expect(gate.shouldEmit('session', 2, now), isTrue);
    var emitted = 1;
    for (var i = 0; i < 100; i++) {
      if (gate.shouldEmit('session-$i', 2, now)) emitted++;
    }
    expect(emitted, SidechainDiagnosticGate.maxSessions);
    expect(gate.trackedSessions, SidechainDiagnosticGate.maxSessions);
    expect(gate.shouldEmit('new-account', 3, now), isTrue);
    expect(gate.trackedSessions, 1);
  });

  test('incoming counters remain exact while logs are throttled', () {
    final observations = <(String, int, Map<String, Object?>)>[];
    OpenTelemetryService.debugCountSink = (name, value, attributes) {
      observations.add((name, value, attributes));
    };
    addTearDown(() => OpenTelemetryService.debugCountSink = null);
    final diagnostics = SidechainDiagnostics();
    for (var i = 0; i < 2; i++) {
      diagnostics
        ..recordIngress(
          source: 'socket',
          incoming: [
            {'parentToolUseId': 'private-anchor', 'text': 'private text'},
          ],
          metadata: const Metadata(flavor: 'prime-agent'),
        )
        ..recordGrouping(
          sessionId: 'private-session',
          runtimeGeneration: 1,
          source: 'socket',
          incoming: [
            {'parentToolUseId': 'private-anchor', 'text': 'private text'},
          ],
          resident: const [],
          metadata: const Metadata(flavor: 'prime-agent'),
        );
    }
    expect(
      observations
          .where((o) => o.$1 == 'app.sidechain.incoming_linked_rows')
          .fold<int>(0, (total, o) => total + o.$2),
      2,
    );
    expect(
      observations.where((o) => o.$1 == 'app.sidechain.grouping_reports'),
      hasLength(1),
    );
    for (final observation in observations) {
      expect(observation.$3.keys, everyElement(isIn(['source', 'capability'])));
      expect(observation.$3.toString(), isNot(contains('private')));
    }
  });

  test(
    'HTTP preview and socket ingress both count decoded linked rows',
    () async {
      final instance = createTestSync();
      resetTestSync(instance);
      instance.testIsInitialized = true;
      const sessionId = 'diagnostic-ingress';
      instance.testSessions[sessionId] = const Session(
        id: sessionId,
        seq: 1,
        createdAt: 0,
        updatedAt: 0,
        active: true,
        activeAt: 0,
        metadataVersion: 1,
        agentStateVersion: 1,
        thinking: false,
        metadata: Metadata(flavor: 'prime-agent'),
      );
      instance.encryption = _DiagnosticEncryption();
      final sources = <String>[];
      OpenTelemetryService.debugCountSink = (name, value, attributes) {
        if (name == 'app.sidechain.incoming_linked_rows') {
          expect(value, 1);
          sources.add(attributes['source']! as String);
        }
      };
      addTearDown(() {
        OpenTelemetryService.debugCountSink = null;
        resetTestSync(instance);
        instance
          ..testResetDataChangeDebounce()
          ..testIsInitialized = false;
      });
      final row = <String, dynamic>{
        'id': 'linked',
        'seq': 1,
        'kind': 'sidechain-link',
        'parentToolUseId': 'anchor',
        'localId': 'canonical',
      };
      final preview = await instance.ingestFromHttp(
        FetchResponseBatch(
          sessionId: sessionId,
          rawMessages: [row],
          traceId: 'diagnostic-http',
          isVisibleSession: false,
        ),
      );
      expect(preview.messages.single['localId'], 'canonical');
      expect(instance.messagesForSession(sessionId), isEmpty);
      await instance.ingestFromSocket(
        MessageIngressEvent(
          source: MessagePipelineSource.socket,
          sessionId: sessionId,
          rawPayload: row,
        ),
      );
      expect(sources, ['http', 'socket']);
      expect(row['localId'], 'canonical');
    },
  );

  test('nullable CLI child capability survives serialization and copy', () {
    final metadata = Metadata.fromJson({
      'primeAgentChildStepsVersion': 1,
      'primeAgentChildStepsRevision': 'child-diag-v1',
    });
    final copied = metadata.copyWith(machineId: 'machine');
    final restored = Metadata.fromJson(copied.toJson());
    expect(restored.primeAgentChildStepsVersion, 1);
    expect(restored.primeAgentChildStepsRevision, 'child-diag-v1');
    expect(Metadata.fromJson({}).primeAgentChildStepsVersion, isNull);
    expect(
      Metadata.fromJson({
        'primeAgentChildStepsVersion': 'invalid',
        'primeAgentChildStepsRevision': {},
      }).primeAgentChildStepsVersion,
      isNull,
    );
  });

  test(
    'screen changes report their latest counts and dispose cancels work',
    () {
      fakeAsync((async) {
        final events = <Map<String, Object?>>[];
        OpenTelemetryService.debugCountSink = (name, _, attributes) {
          if (name == 'app.sidechain.child_screen_reports') {
            events.add(attributes);
          }
        };
        addTearDown(() => OpenTelemetryService.debugCountSink = null);
        final diagnostics = SidechainDiagnostics();
        void report(int children) => diagnostics.recordScreen(
          sessionId: 'session',
          selectedMessageId: 'selected',
          resident: const [],
          renderedChildren: children,
        );
        report(0);
        report(1);
        report(2);
        expect(events, [
          {'event': 'open', 'empty': true},
        ]);
        async.elapse(const Duration(seconds: 30));
        expect(events.last, {'event': 'changed', 'empty': false});
        expect(events, hasLength(2));
        report(0);
        SidechainDiagnostics.resetRuntime();
        async.elapse(const Duration(seconds: 30));
        expect(events, hasLength(2));
        report(0);
        expect(events.last, {'event': 'open', 'empty': true});
        report(1);
        diagnostics.dispose();
        async.elapse(const Duration(seconds: 30));
        expect(events, hasLength(3));
      });
    },
  );
}

class _DiagnosticEncryption implements Encryption {
  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      _DiagnosticSessionEncryption();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DiagnosticSessionEncryption implements SessionEncryption {
  @override
  bool get canDecryptAes => true;

  @override
  Future<ProcessedMessages> decryptAndProcessMessages(
    List<Map<String, dynamic>> messages,
    String sessionId,
  ) async => ProcessedMessages(
    messages: messages,
    toolResults: const [],
    usageUpdates: const [],
    maxSeq: 1,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
