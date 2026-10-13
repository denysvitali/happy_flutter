import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/models/built_in_profiles.dart';
import 'package:happy_flutter/core/services/sidechain_grouper.dart';
import 'package:happy_flutter/core/services/tool_result_processor.dart';

import '../fixtures/prime_agent_captured_envelopes.dart';

void main() {
  group('happy-cli-go cross-repo contract', () {
    test('Flutter and Go agree on session message protocol', () {
      final cliRoot = _cliRoot();
      if (cliRoot == null) {
        _skipOrFail(_missingCliMessage);
        return;
      }
      final goFiles = _requireGoFiles(cliRoot, [
        'proto/server/v1/sessions.proto',
        'internal/server/db/migrations/000001_initial_schema.up.sql',
        'internal/server/ws/session_handlers.go',
        'internal/server/compat_handlers_sessions.go',
        'internal/server/ws/server.go',
        'internal/server/service/session_message_store.go',
        'internal/server/server.go',
      ]);
      if (goFiles == null) return; // already skipped

      final messagesApi = _read('lib/core/api/messages_api.dart');
      final sessionsApi = _read('lib/core/api/sessions_api.dart');
      final sendSync = _read('lib/core/services/_sync_messaging_send.dart');
      final goSessionsProto = goFiles[0];
      final goSchema = goFiles[1];
      final goSessionHandlers = goFiles[2];
      final goCompatHandlers = goFiles[3];
      final goMessageIngest = goFiles[4];
      final goMessageStore = goFiles[5];
      final goServer = goFiles[6];

      expect(messagesApi, contains(r'/v3/sessions/$sessionId/messages'));
      expect(messagesApi, contains("'localId': ?localId"));
      expect(messagesApi, contains("localId: serverMsg['localId'] as String?"));

      final sendPath = _read('lib/core/services/_sync_messaging_send.dart');
      expect(sendPath, contains('sendTimeout: Sync._messageSendTimeout'));
      expect(sendPath, contains('receiveTimeout: Sync._messageSendTimeout'));
      expect(
        goSessionsProto,
        contains('post: "/v3/sessions/{session_id}/messages"'),
      );
      expect(
        goSessionsProto,
        contains('get: "/v3/sessions/{session_id}/messages"'),
      );
      expect(goSessionsProto, contains('string local_id = 3;'));
      expect(goSchema, contains('UNIQUE(session_id, local_id)'));
      expect(goSessionHandlers, contains('localIDRaw := data["localId"]'));
      expect(
        goMessageIngest,
        contains('msg, created, err = s.sessionMessageStore('),
      );
      expect(goMessageIngest, contains('ctx, sid, localID, msgContent'));
      expect(goMessageIngest, contains('if !created {'));
      expect(goMessageIngest, contains('"localId":   msg.LocalID'));
      expect(
        goServer,
        contains(
          's.socketSrv.SetSessionMessageStore('
          'sessionSvc.StoreWebSocketMessage)',
        ),
      );
      expect(goMessageStore, contains('LocalID: *localID'));
      expect(
        goMessageStore,
        contains('ON CONFLICT (session_id, local_id) DO UPDATE'),
      );
      expect(goMessageStore, contains('id = candidate_id AS created'));
      expect(
        sendSync,
        contains('localId'),
        reason: 'sendMessage must preserve the canonical localId end to end',
      );
      expect(
        sendSync,
        isNot(contains('localId: null')),
        reason: 'sendMessage should not intentionally drop localId identity',
      );

      expect(sessionsApi, contains('/v2/sessions'));
      expect(sessionsApi, contains(r'/v1/sessions/$sessionId'));
      expect(goSessionsProto, contains('get: "/v2/sessions"'));
      expect(goCompatHandlers, contains('GET /v1/sessions/:id'));
      expect(goCompatHandlers, contains('svc.GetSessionByID'));
    });

    test('Flutter and Go agree on machine spawn and socket surfaces', () {
      final cliRoot = _cliRoot();
      if (cliRoot == null) {
        _skipOrFail(_missingCliMessage);
        return;
      }
      final goFiles = _requireGoFiles(cliRoot, [
        'proto/server/v1/machines.proto',
        'internal/api/machine_sync.go',
        'internal/api/session_sync.go',
        'internal/wsapi/events.go',
      ]);
      if (goFiles == null) return; // already skipped

      final syncOperations = _read(
        'lib/core/services/_sync_operations_session.dart',
      );
      final syncRpc = _read('lib/core/services/_sync_messaging_rpc.dart');
      final socketClient = _read('lib/core/api/socket_io_client.dart');
      final goMachinesProto = goFiles[0];
      final goMachineSync = goFiles[1];
      final goSessionSync = goFiles[2];
      final goWsEvents = goFiles[3];

      expect(syncOperations, contains('spawn-happy-session'));
      expect(syncRpc, contains('spawn-happy-session'));
      expect(
        goMachinesProto,
        contains('post: "/v1/machines/{machine_id}/spawn"'),
      );
      expect(goMachineSync, contains('spawn-happy-session'));

      expect(socketClient, contains('/v1/updates'));
      expect(socketClient, contains(".setTransports(['websocket'])"));
      expect(goSessionSync, contains('/v1/updates'));
      expect(goWsEvents, contains('EventMessage'));
      expect(goWsEvents, contains('EventUpdate'));
    });

    test('daemon cannot hijack provider choice via its own shell env', () {
      final cliRoot = _cliRoot();
      if (cliRoot == null) {
        _skipOrFail(_missingCliMessage);
        return;
      }
      final goFiles = _requireGoFiles(cliRoot, [
        'internal/daemon/daemon_runtime.go',
        'internal/daemon/spawn_env_validation_test.go',
      ]);
      if (goFiles == null) return;

      // App side of the contract: "Anthropic (Default)" intentionally sends
      // NO provider env vars — their absence on the wire means "use the
      // machine's plain Anthropic login", not "daemon may fill the gap".
      final anthropic = getBuiltInProfile('anthropic');
      expect(anthropic, isNotNull);
      expect(
        anthropic!.environmentVariables,
        isEmpty,
        reason:
            'The built-in Anthropic profile must stay env-var-free; the '
            'daemon interprets absence as "plain Anthropic"',
      );
      expect(
        anthropic.anthropicConfig,
        isNull,
        reason: 'No base-URL/auth-token/model overrides for plain Anthropic',
      );

      // Daemon side: buildSpawnEnvMap must strip provider-routing vars
      // inherited from the daemon's own process environment. Without this, a
      // daemon started from a shell with a third-party provider exported
      // (e.g. MiniMax) silently overrides the user's explicit provider
      // choice — incident: a fable:high Anthropic session was answered by
      // MiniMax-M3 (session cf84f290ef71e368788c4ac66).
      final goRuntime = goFiles[0];
      expect(goRuntime, contains('stripInheritedProviderEnv(envMap)'));
      expect(goRuntime, contains('"ANTHROPIC_BASE_URL"'));
      expect(goRuntime, contains('"ANTHROPIC_AUTH_TOKEN"'));
      expect(goRuntime, contains('"ANTHROPIC_MODEL"'));
      expect(goRuntime, contains('ANTHROPIC_DEFAULT_'));
      expect(goRuntime, contains('HAPPY_INHERIT_PROVIDER_ENV'));

      // And the Go regression test pinning the incident must stay in place.
      final goSpawnTests = goFiles[1];
      expect(
        goSpawnTests,
        contains(
          'TestSpawnEnv_DaemonShellProviderConfigCannotHijackAnthropicSpawn',
        ),
      );
      expect(
        goSpawnTests,
        contains('TestSpawnEnv_AnthropicBaseURLNotInheritedFromDaemonEnv'),
      );
    });
    test('native Prime daemon child fixture reaches sibling conversations', () {
      final cliRoot = _cliRoot();
      if (cliRoot == null) {
        _skipOrFail(_missingCliMessage);
        return;
      }
      final goFiles = _requireGoFiles(cliRoot, [
        'internal/remote/primeagent/testdata/subagents-native-happy.jsonl',
      ]);
      if (goFiles == null) return;
      final envelopes = const LineSplitter()
          .convert(goFiles.single)
          .where((line) => line.trim().isNotEmpty)
          .map((line) => jsonDecode(line) as Map<String, dynamic>)
          .toList();
      expect(
        envelopes,
        nativePrimeAgentEnvelopes(),
        reason: 'Browser-safe native replay must match Go producer evidence',
      );
      final parsed = processDecryptedMessages(
        decryptedJsonList: envelopes,
        wireMessages: [
          for (var i = 0; i < envelopes.length; i++)
            {'id': 'native-prime-$i', 'seq': i + 1, 'createdAt': 1000 + i},
        ],
        sessionId: 'native-prime-session',
      );
      expect(parsed.droppedReasons, isEmpty);
      final grouped = SidechainGrouper().groupMessages(parsed.messages)!;
      expect(grouped.hasOrphans, isFalse);
      final updated = ToolResultProcessor().applyToolResults(
        grouped.messages,
        parsed.toolResults,
      );
      final anchors = updated.messages.where((row) => row['name'] == 'Agent');
      expect(
        anchors.map((row) => row['agentId']),
        unorderedEquals(['sub-alpha', 'sub-beta']),
      );
      expect(updated.messages, hasLength(3));
      expect(updated.messages.last['content'], 'ALPHA=17 and BETA=29');
      expect(
        updated.messages.any((row) => row['isSidechain'] == true),
        isFalse,
      );
      for (final anchor in anchors) {
        final children = (anchor['children'] as List)
            .cast<Map<String, dynamic>>();
        expect(anchor['state'], 'completed');
        expect(children, hasLength(3));
        for (final child in children) {
          expect(child['isSidechain'], isTrue);
          expect(child['parentToolUseId'], anchor['toolUseId']);
          expect(child['agentId'], anchor['agentId']);
        }
      }
      final children = anchors
          .expand(
            (anchor) =>
                (anchor['children'] as List).cast<Map<String, dynamic>>(),
          )
          .toList();
      expect(children.any((row) => row['isThinking'] == true), isTrue);
      for (final thinking in children.where(
        (row) => row['isThinking'] == true,
      )) {
        expect(thinking['content'], contains('Read the requested file.'));
      }
      final tools = children.where((row) => row['kind'] == 'tool-call');
      expect(tools, isNotEmpty);
      for (final tool in tools) {
        expect(tool['state'], 'completed');
        expect(tool['result'], isNotNull);
        expect(updated.matchedIds, contains(tool['toolUseId']));
        final raw = tool['raw'] as Map<String, dynamic>;
        final originalInput = raw['content']['data']['input'];
        expect((originalInput as Map).keys, unorderedEquals(['code']));
        final output = tool['agentId'] == 'sub-alpha' ? 'ALPHA=17' : 'BETA=29';
        expect(originalInput, {'code': "print('$output')"});
        expect(raw['content']['data']['wireInput'], originalInput);
        expect(tool['wireInput'] ?? tool['input'], originalInput);
        expect(tool['result'], output);
      }
    });

    test('canonical message fixtures round-trip through Flutter processor', () {
      final cliRoot = _cliRoot();
      if (cliRoot == null) {
        _skipOrFail(_missingCliMessage);
        return;
      }

      final fixturesDir = Directory('${cliRoot.path}/test/fixtures/messages');
      if (!fixturesDir.existsSync()) {
        _skipOrFail(
          'Fixture directory not found: ${fixturesDir.path}. '
          'Run UPDATE_FIXTURES=1 in happy-cli-go to generate.',
        );
        return;
      }

      if (_requireCliGo) {
        for (final name in _requiredFixtures) {
          expect(
            File('${fixturesDir.path}/$name').existsSync(),
            isTrue,
            reason: 'Required happy-cli-go fixture missing: $name',
          );
        }
      }

      final fixtures = fixturesDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      expect(fixtures, isNotEmpty, reason: 'expected at least one fixture');

      for (final fixture in fixtures) {
        final raw =
            jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>;
        expect(
          raw['v'],
          1,
          reason: '${fixture.path} must declare envelope version v:1',
        );

        final wireId = 'fixture-${fixture.uri.pathSegments.last}';
        final processed = processDecryptedMessages(
          decryptedJsonList: [raw],
          wireMessages: [
            {
              'id': wireId,
              'seq': 1,
              'createdAt': DateTime.now().millisecondsSinceEpoch,
            },
          ],
          sessionId: 'fixture-session',
        );

        // Some canonical events (ready, thinking, usage_report) are
        // intentionally silent in the Flutter UI. Treat those drops as
        // successful contract fulfillment, but fail on any other drop.
        final allowedDrops = processed.droppedReasons
            .where(
              (r) =>
                  !r.startsWith('event data type ') && r != 'redacted thinking',
            )
            .toList();
        expect(
          allowedDrops,
          isEmpty,
          reason:
              '${fixture.path} should not be dropped '
              'for an unknown reason',
        );

        // Every fixture must produce at least one display message or tool
        // result, unless it is an intentionally silent event.
        final isSilentEvent = processed.droppedReasons.any(
          (r) => r.startsWith('event data type '),
        );
        expect(
          processed.messages.isNotEmpty ||
              processed.toolResults.isNotEmpty ||
              isSilentEvent,
          isTrue,
          reason:
              '${fixture.path} produced no messages, tool results, or known silent drop',
        );
      }
    });
  });
}

const _requireCliGo = bool.fromEnvironment('HAPPY_REQUIRE_CLI_GO');
const _requiredFixtures = [
  'event_v1.json',
  'sidechain_v1.json',
  'text_v1.json',
  'tool_call_v1.json',
  'tool_result_v1.json',
  'user_text_v1.json',
];

void _skipOrFail(String reason) {
  if (_requireCliGo) fail(reason);
  markTestSkipped(reason);
}

const _missingCliMessage =
    'Set HAPPY_CLI_GO_PATH to a happy-cli-go checkout to run this '
    'cross-repo contract.';

Directory? _cliRoot() {
  final path = Platform.environment['HAPPY_CLI_GO_PATH'] ?? '../happy-cli-go';
  final root = Directory(path);
  if (!root.existsSync()) {
    return null;
  }
  return root;
}

/// Missing Go files fail required CI contracts, but skip optional checkouts.
List<String>? _requireGoFiles(Directory root, List<String> paths) {
  final contents = <String>[];
  for (final path in paths) {
    final file = File('${root.path}/$path');
    if (!file.existsSync()) {
      _skipOrFail(
        'Cross-repo file not found: $path. '
        'Update your happy-cli-go checkout.',
      );
      return null;
    }
    contents.add(file.readAsStringSync());
  }
  return contents;
}

String _read(String path) => File(path).readAsStringSync();
