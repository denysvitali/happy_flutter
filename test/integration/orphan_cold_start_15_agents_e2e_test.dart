import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';

/// Cold-start contract test for the user's worst-case session:
/// 1000 messages including 15 background `Agent` tool_uses, where the
/// MMKV cache (200 msg window) covers only the trailing sidechain
/// children whose `parent_tool_use_id` resolves to Agent tool_uses that
/// live earlier than the cached window.
///
/// Reproduces session `c3758ad7b964191fd6b96c6dc` shape.
///
/// This test encodes the contract that the absorber+restore fixes are
/// supposed to enforce.  On `main` today it FAILS — that's intentional.
/// Inline comments call out which expectation breaks on main vs which
/// already holds.
void main() {
  group('orphan cold start: 15 agents @ session ~1000 msgs', () {
    // Agent seqs taken verbatim from the user's session.
    const agentSeqs = <int>[
      5, 27, 57, 84, 118, 166, 222, 274, 313, 373,
      417, 453, 494, 545, 612,
    ];
    const sessionId = 'sess-15-agents-worst-case';
    const lastSeq = 1000;

    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      _stubAllSyncs(sync);
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: lastSeq);
      sync.testVisibleSessionId = sessionId;
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchOlderMessagesOverride = null;
      sync.testClearSessionMessageState(sessionId);
      sync.testVisibleSessionId = null;
    });

    test(
      'cold-start with 200-msg cache full of sidechain orphans never '
      'creates a synthetic _orphanRecovery tile, fetches older pages '
      'aggressively, and ends with 15 real Agent tool_calls each with '
      'non-empty children',
      () async {
        // ------------------------------------------------------------
        // Build the 1000-message synthetic session.
        //
        // Layout:
        //   - 15 Agent tool_use messages at the spec'd seqs.
        //   - The remaining seqs are sidechain children stamped with
        //     parentToolUseId = the *most recent* Agent's toolUseId
        //     up to that point. This produces "runs" of ~60-70 sidechain
        //     messages per Agent.
        //   - For each Agent, one of its children is a `task_started`
        //     marker (kind: 'text', isSidechain: true) at agent.seq + 1.
        //
        // Each message carries:
        //   parentToolUseId = 'toolu_<n>' (Claude `parent_tool_use_id`)
        //   agentId         = 'agent-task-<n>'
        //
        // The cache window covers ONLY the trailing 200 seqs
        // (seq 801-1000) — none of those 200 are real Agent tool_uses;
        // all are sidechain children whose parent_tool_use_id points to
        // a real Agent at seq <= 612 which lives OUTSIDE the cache.
        // ------------------------------------------------------------
        final fullSession = _buildSyntheticSession(
          agentSeqs: agentSeqs,
          lastSeq: lastSeq,
        );
        expect(
          fullSession.length,
          lastSeq,
          reason: 'synthetic session must produce exactly $lastSeq msgs',
        );

        // Sanity-check: 15 Agent tool_uses, all at the spec'd seqs,
        // all at seq <= 612 (outside the cache window).
        final agentRows = fullSession
            .where((m) => m['kind'] == 'tool-call' && m['name'] == 'Agent')
            .toList();
        expect(agentRows, hasLength(15));
        expect(
          agentRows.every((m) => (m['seq'] as int) <= 612),
          isTrue,
          reason: 'all real Agents must live below the cache window',
        );

        // Trailing 200 = cache window contents.
        final cachedWindow = fullSession.sublist(fullSession.length - 200);
        expect(cachedWindow, hasLength(200));
        expect(
          cachedWindow.every(
            (m) =>
                m['isSidechain'] == true &&
                (m['parentToolUseId'] as String?)?.isNotEmpty == true,
          ),
          isTrue,
          reason:
              'every cached msg must be a sidechain child with a '
              'non-empty parent_tool_use_id',
        );
        expect(
          cachedWindow.any((m) => m['name'] == 'Agent'),
          isFalse,
          reason: 'no real Agent tool_use should appear in the cache',
        );

        // ------------------------------------------------------------
        // Simulate MMKV cold-restore: only the cache window is loaded
        // in-memory at app start.  firstLoadedSeq points at the first
        // cached seq so hasOlderMessages() == true.
        // ------------------------------------------------------------
        sync.testSetSessionMessages(sessionId, cachedWindow);
        // First cached seq is fullSession[fullSession.length - 200]['seq'].
        final firstCachedSeq = cachedWindow.first['seq'] as int;
        sync.testSetSessionFirstLoadedSeq(sessionId, firstCachedSeq);
        sync.testSetSessionLastSeq(sessionId, lastSeq);

        expect(sync.hasOlderMessages(sessionId), isTrue);

        // ------------------------------------------------------------
        // Wire fetchOlderMessages so each invocation injects the slice
        // of pre-built session messages it should be returning.
        //
        // We bypass the wire/decrypt pipeline by upserting the slice
        // directly into _sessionMessages, then returning an empty
        // response (the override's only required job for this test).
        // ------------------------------------------------------------
        final fetchInvocations = <_FetchInvocation>[];
        final clock = Stopwatch()..start();
        sync.testFetchOlderMessagesOverride =
            (sid, afterSeq, limit) async {
          fetchInvocations.add(
            _FetchInvocation(
              afterSeq: afterSeq,
              limit: limit,
              elapsedMs: clock.elapsedMilliseconds,
            ),
          );
          // Slice the pre-built session from afterSeq+1 to afterSeq+limit.
          final slice = fullSession
              .where(
                (m) =>
                    (m['seq'] as int) > afterSeq &&
                    (m['seq'] as int) <= afterSeq + limit,
              )
              .toList();
          sync.testUpsertSessionMessages(sessionId, slice);
          // Return empty so the merge phase in fetchOlderMessages is a
          // no-op — we already mutated state in-place.
          return <String, dynamic>{
            'messages': <Map<String, dynamic>>[],
            'hasMore': false,
          };
        };

        // ------------------------------------------------------------
        // ASSERTION 1 (the cache window itself): trigger the first
        // grouper sweep against the cache-only state.
        //
        // On main: every cached msg is a sidechain orphan (its
        // parent_tool_use_id resolves nowhere in the loaded window).
        // The deferred sweep will eventually absorb them into one or
        // more synthetic `_orphanRecovery: true` Task tiles.  This is
        // the bug.  The contract says: as long as hasOlderMessages is
        // true AND every orphan has parent_tool_use_id, NO synthetic
        // should ever be created.
        // ------------------------------------------------------------
        sync.testGroupSidechainMessages(sessionId);
        // Two sweeps without progress is the threshold for absorb.
        sync.testRunDeferredRegroupSweep(sessionId);
        // The first sweep should kick off ONE fetchOlder. Give that
        // microtask a chance to run, then run sweep #2.
        await _drain();
        sync.testRunDeferredRegroupSweep(sessionId);
        await _drain();
        sync.testRunDeferredRegroupSweep(sessionId);
        await _drain();

        final afterFirstSweep = sync.testGetSessionMessages(sessionId);
        final syntheticAfterFirstSweep = afterFirstSweep
            .where((m) => m['_orphanRecovery'] == true)
            .toList();
        // CONTRACT ASSERTION (fails on main today):
        // The absorber currently creates a synthetic placeholder for
        // every chain root after 2 no-progress sweeps even though
        // hasOlderMessages == true AND parent_tool_use_id is present.
        expect(
          syntheticAfterFirstSweep,
          isEmpty,
          reason:
              'CONTRACT (broken on main): with hasOlderMessages=true '
              'and every orphan carrying parent_tool_use_id, the '
              'absorber must defer to fetchOlder instead of inserting '
              '_orphanRecovery synthetic Task tiles.',
        );

        // ------------------------------------------------------------
        // ASSERTION 2 (aggressive fetch cadence): at least 3 fetchOlder
        // calls within the first 30s of simulated wall time, reaching
        // seqs < 500.
        //
        // On main: _runDeferredRegroupSweep gates fetchOlder behind a
        // 60s `_orphanFetchOlderAttemptedMs` cooldown — so the second
        // call cannot fire within 30s.  This is the bug the absorber
        // restore work is supposed to remove.
        // ------------------------------------------------------------
        // Trigger more sweeps to demonstrate the cadence cap.
        for (var i = 0; i < 5; i++) {
          sync.testRunDeferredRegroupSweep(sessionId);
          await _drain();
        }
        final within30s = fetchInvocations
            .where((f) => f.elapsedMs <= 30000)
            .toList();
        expect(
          within30s.length,
          greaterThanOrEqualTo(3),
          reason:
              'CONTRACT (broken on main): at least 3 fetchOlder rounds '
              'must fire within 30 simulated seconds of a cold-start '
              'with 200 sidechain orphans; main caps it at 1 per 60s.',
        );
        expect(
          within30s.any((f) => f.afterSeq < 500),
          isTrue,
          reason:
              'CONTRACT (broken on main): fetch cadence must reach '
              'seq < 500 within 30s to surface the early Agents.',
        );

        // ------------------------------------------------------------
        // ASSERTION 3 (eventual convergence): after enough fetchOlder
        // rounds to cover seq <= 5 (the earliest Agent), the flat
        // message list must contain all 15 real Agent tool_calls, each
        // with non-empty `children`, and ZERO `_orphanRecovery` entries.
        //
        // This part exercises the grouper end state.  It passes once
        // the absorber correctly defers and the grouper attaches every
        // sidechain to its real Agent via parent_tool_use_id.
        // ------------------------------------------------------------
        // Drive fetchOlderMessages directly (e.g. ChatScreen's
        // scroll-to-top behaviour) until firstLoadedSeq reaches 0 so
        // every Agent (lowest at seq=5) is paged in.  This bypasses
        // the sweep-internal cooldown, isolating assertion 3 to the
        // grouper's ability to attach children — independent of the
        // absorber regressions exercised in assertions 1 and 2.
        var safetyCounter = 0;
        while (sync.hasOlderMessages(sessionId) && safetyCounter < 20) {
          await sync.fetchOlderMessages(sessionId);
          await _drain();
          safetyCounter++;
        }
        // One final grouper pass after the last fetchOlder.
        sync.testGroupSidechainMessages(sessionId);

        final finalMessages = sync.testGetSessionMessages(sessionId);
        final realAgents = finalMessages
            .where(
              (m) =>
                  m['kind'] == 'tool-call' &&
                  m['name'] == 'Agent' &&
                  m['_orphanRecovery'] != true,
            )
            .toList();
        expect(
          realAgents,
          hasLength(15),
          reason: 'all 15 real Agent tool_uses must appear after restore',
        );
        for (final agent in realAgents) {
          final children = agent['children'] as List<dynamic>?;
          expect(
            children,
            isNotNull,
            reason:
                'Agent toolUseId=${agent['toolUseId']} must have grouped '
                'sidechain children attached',
          );
          expect(
            children,
            isNotEmpty,
            reason:
                'Agent toolUseId=${agent['toolUseId']} must have at '
                'least one sidechain child after grouping',
          );
        }
        final syntheticFinal = finalMessages
            .where((m) => m['_orphanRecovery'] == true)
            .toList();
        expect(
          syntheticFinal,
          isEmpty,
          reason:
              'CONTRACT: no _orphanRecovery synthetic Task tiles may '
              'survive once the real Agents have been paged in.',
        );
      },
      // Keep wall-clock budget tight.
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });
}

// ===========================================================================
// Synthetic session generator
// ===========================================================================

/// Builds the 1000-message worst-case session shape.
///
/// Returns the *display-ready* (already-processed) message maps that would
/// normally come out of `decryptAndProcessMessages`.  Inserting them via
/// [Sync.testUpsertSessionMessages] is equivalent to having them arrive
/// from a server fetch.
List<Map<String, dynamic>> _buildSyntheticSession({
  required List<int> agentSeqs,
  required int lastSeq,
}) {
  final result = <Map<String, dynamic>>[];
  final agentToolUseIds = <int, String>{
    for (var i = 0; i < agentSeqs.length; i++)
      agentSeqs[i]: 'toolu_${i.toString().padLeft(2, '0')}',
  };
  final agentTaskIds = <int, String>{
    for (var i = 0; i < agentSeqs.length; i++)
      agentSeqs[i]: 'agent-task-${i.toString().padLeft(2, '0')}',
  };

  // The "currently active" Agent for each seq is the most recently
  // emitted Agent at seq <= current.
  String? currentAgentToolUseId;
  String? currentAgentTaskId;
  int? currentAgentSeq;

  for (var seq = 1; seq <= lastSeq; seq++) {
    final isAgentSeq = agentToolUseIds.containsKey(seq);
    if (isAgentSeq) {
      currentAgentToolUseId = agentToolUseIds[seq];
      currentAgentTaskId = agentTaskIds[seq];
      currentAgentSeq = seq;
      // Emit the parent Agent tool_use (top-level, NOT a sidechain).
      result.add(<String, dynamic>{
        'id': 'msg-agent-$seq',
        'seq': seq,
        'createdAt': 1700000000000 + seq * 1000,
        'role': 'agent',
        'kind': 'tool-call',
        'name': 'Agent',
        'toolUseId': currentAgentToolUseId,
        'uuid': currentAgentToolUseId,
        'state': 'running',
        'input': <String, dynamic>{
          'description': 'background agent #${agentSeqs.indexOf(seq) + 1}',
          'prompt': 'agent prompt $seq',
        },
      });
      continue;
    }

    // No active Agent yet (e.g. seqs 1-4 before first Agent at 5).
    // Emit a benign user/agent text row to fill the slot.
    if (currentAgentToolUseId == null) {
      result.add(<String, dynamic>{
        'id': 'msg-pre-$seq',
        'seq': seq,
        'createdAt': 1700000000000 + seq * 1000,
        'role': 'user',
        'kind': 'text',
        'content': 'pre-agent filler $seq',
      });
      continue;
    }

    // Sidechain child of the current Agent.
    // The first child after an Agent is a `task_started` sidechain
    // text marker; subsequent children are assistant text/tool-calls.
    final isTaskStarted = seq == (currentAgentSeq! + 1);
    result.add(<String, dynamic>{
      'id': 'msg-side-$seq',
      'uuid': 'sc-uuid-$seq',
      'seq': seq,
      'createdAt': 1700000000000 + seq * 1000,
      'role': 'agent',
      'kind': 'text',
      'content': isTaskStarted
          ? 'task_started for ${currentAgentTaskId!}'
          : 'sidechain output line @seq=$seq',
      'isSidechain': true,
      // CRITICAL: parent_tool_use_id is the Claude-stamped link to the
      // spawning Agent.  It survives independently of parentUuid (which
      // chains through prior sidechain message uuids and would be
      // broken once the cache window slices off the chain head).
      'parentToolUseId': currentAgentToolUseId,
      'parentUuid': seq == currentAgentSeq + 1
          // First sidechain child: chain root, points at the Agent itself.
          ? currentAgentToolUseId
          // Subsequent: chain through prior sidechain message.
          : 'sc-uuid-${seq - 1}',
      'agentId': currentAgentTaskId,
      if (isTaskStarted)
        'task_id': currentAgentTaskId,
    });
  }

  return result;
}

// ===========================================================================
// Helpers
// ===========================================================================

class _FetchInvocation {
  _FetchInvocation({
    required this.afterSeq,
    required this.limit,
    required this.elapsedMs,
  });
  final int afterSeq;
  final int limit;
  final int elapsedMs;
}

Future<void> _drain() async {
  // Let microtasks settle (fetchOlderMessages is async even with the
  // override) and small timers fire.
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void _stubAllSyncs(Sync sync) {
  sync.sessionsSync = InvalidateSync(() async {});
  sync.settingsSync = InvalidateSync(() async {});
  sync.profileSync = InvalidateSync(() async {});
  sync.purchasesSync = InvalidateSync(() async {});
  sync.machinesSync = InvalidateSync(() async {});
  sync.pushTokenSync = InvalidateSync(() async {});
  sync.nativeUpdateSync = InvalidateSync(() async {});
  sync.artifactsSync = InvalidateSync(() async {});
  sync.sessionGitStatusSync = InvalidateSync(() async {});
  sync.messagesSync.clear();
}

Session _makeSession(String id, {required int lastSeq}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 1700000000000,
    updatedAt: 1700000000000,
    active: true,
    activeAt: 1700000000000,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    presence: 'offline',
    lastSeq: lastSeq,
  );
}

class _FakeEncryption implements Encryption {
  final Map<String, _FakeSessionEncryption> _sessions = {};

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return _sessions.putIfAbsent(
      sessionId,
      () => _FakeSessionEncryption(sessionId: sessionId),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeSessionEncryption extends SessionEncryption {
  _FakeSessionEncryption({required String sessionId})
      : super(
          sessionId: sessionId,
          encryptor: _FakeEncryptor(),
          decryptor: _FakeEncryptor(),
          cache: EncryptionCache(),
        );
}

class _FakeEncryptor implements Encryptor {
  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    return data.map((item) {
      final json = jsonEncode(item);
      final bytes = utf8.encode(json);
      final output = Uint8List(bytes.length + 1);
      output[0] = 0x01;
      output.setRange(1, output.length, bytes);
      return output;
    }).toList();
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    return data.map((item) {
      if (item.isEmpty) return null;
      try {
        return item[0] == 0x01
            ? jsonDecode(utf8.decode(item.sublist(1)))
            : utf8.decode(item);
      } catch (_) {
        return null;
      }
    }).toList();
  }
}
