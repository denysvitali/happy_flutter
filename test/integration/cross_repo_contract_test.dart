import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
