import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/models/built_in_profiles.dart';

void main() {
  group('happy-cli-go cross-repo contract', () {
    test('Flutter and Go agree on session message protocol', () {
      final cliRoot = _cliRoot();
      if (cliRoot == null) {
        markTestSkipped(_missingCliMessage);
        return;
      }
      final goFiles = _requireGoFiles(cliRoot, [
        'proto/server/v1/sessions.proto',
        'internal/server/db/migrations/000001_initial_schema.up.sql',
        'internal/server/ws/session_handlers.go',
        'internal/server/compat_handlers.go',
      ]);
      if (goFiles == null) return; // already skipped

      final messagesApi = _read('lib/core/api/messages_api.dart');
      final sessionsApi = _read('lib/core/api/sessions_api.dart');
      final sendSync = _read('lib/core/services/_sync_messaging_send.dart');
      final goSessionsProto = goFiles[0];
      final goSchema = goFiles[1];
      final goSessionHandlers = goFiles[2];
      final goCompatHandlers = goFiles[3];

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
      expect(goSessionHandlers, contains('GetMessageByLocalID'));
      expect(goSessionHandlers, contains('"localId":   msg.LocalID'));
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
        markTestSkipped(_missingCliMessage);
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
        markTestSkipped(_missingCliMessage);
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
    test('canonical message fixtures round-trip through Flutter processor', () {
      final cliRoot = _cliRoot();
      if (cliRoot == null) {
        markTestSkipped(_missingCliMessage);
        return;
      }

      final fixturesDir = Directory(
        '${cliRoot.path}/test/fixtures/messages',
      );
      if (!fixturesDir.existsSync()) {
        markTestSkipped(
          'Fixture directory not found: ${fixturesDir.path}. '
          'Run UPDATE_FIXTURES=1 in happy-cli-go to generate.',
        );
        return;
      }

      final fixtures = fixturesDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      expect(fixtures, isNotEmpty, reason: 'expected at least one fixture');

      for (final fixture in fixtures) {
        final raw = jsonDecode(fixture.readAsStringSync())
            as Map<String, dynamic>;
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
                  !r.startsWith('event data type ') &&
                  r != 'redacted thinking',
            )
            .toList();
        expect(
          allowedDrops,
          isEmpty,
          reason: '${fixture.path} should not be dropped '
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

/// Reads multiple Go files, skipping the test if any are missing.
List<String>? _requireGoFiles(Directory root, List<String> paths) {
  final contents = <String>[];
  for (final path in paths) {
    final file = File('${root.path}/$path');
    if (!file.existsSync()) {
      markTestSkipped(
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
