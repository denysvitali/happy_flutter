import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';

void main() {
  group('SpawnSessionRequest.toJson', () {
    test('includes sessionId when provided', () {
      final request = SpawnSessionRequest(
        type: 'spawn-in-directory',
        directory: '/tmp/project',
        sessionId: 'c1af40f2f18914fb43a9d19b4',
        agent: 'claude',
        spawnBackend: 'kubernetes',
        repoUrl: 'https://example.com/repo.git',
        repoRef: 'main',
      );

      expect(
        request.toJson(),
        containsPair('sessionId', 'c1af40f2f18914fb43a9d19b4'),
      );
      expect(request.toJson(), containsPair('spawnBackend', 'kubernetes'));
      expect(
        request.toJson(),
        containsPair('repoUrl', 'https://example.com/repo.git'),
      );
      expect(request.toJson(), containsPair('repoRef', 'main'));
      expect(request.toJson(), isNot(contains('isRestore')));
    });

    test('includes explicit restore intent', () {
      final request = SpawnSessionRequest(
        type: 'spawn-in-directory',
        directory: '/tmp/project',
        sessionId: 'session-1',
        isRestore: true,
      );

      expect(request.toJson(), containsPair('isRestore', true));
    });
  });

  group('SpawnSessionResponse.fromJson', () {
    test('parses camelCase fields', () {
      final response = SpawnSessionResponse.fromJson({
        'type': 'success',
        'sessionId': 'session-123',
        'errorMessage': null,
        'directory': '/tmp/project',
        'dataEncryptionKey': 'dek-abc',
        'sandboxRequested': true,
        'sandboxRequired': true,
        'sandboxEnforced': false,
        'sandboxBackend': 'none',
        'sandboxReason': 'boxy is unavailable',
        'runtimeType': 'kubernetes',
        'podName': 'happy-session-123',
        'namespace': 'happy-sessions',
        'phase': 'Running',
      });

      expect(response.type, 'success');
      expect(response.sessionId, 'session-123');
      expect(response.directory, '/tmp/project');
      expect(response.dataEncryptionKey, 'dek-abc');
      expect(response.sandboxRequested, isTrue);
      expect(response.sandboxRequired, isTrue);
      expect(response.sandboxEnforced, isFalse);
      expect(response.sandboxBackend, 'none');
      expect(response.sandboxReason, 'boxy is unavailable');
      expect(response.runtimeKind, 'kubernetes');
      expect(response.podName, 'happy-session-123');
      expect(response.namespace, 'happy-sessions');
      expect(response.phase, 'Running');
    });

    test('parses snake_case compatibility fields', () {
      final response = SpawnSessionResponse.fromJson({
        'type': 'success',
        'session_id': 'session-456',
        'error_message': 'none',
        'directory': '/tmp/project',
        'data_encryption_key': 'dek-def',
      });

      expect(response.type, 'success');
      expect(response.sessionId, 'session-456');
      expect(response.errorMessage, 'none');
      expect(response.dataEncryptionKey, 'dek-def');
    });
  });

  group('Kubernetes pod RPC responses', () {
    test('parses pod state and bounded logs', () {
      final pods = SessionPodsResponse.fromJson({
        'pods': [
          {
            'sessionId': 'session-1',
            'podName': 'happy-session-1',
            'namespace': 'happy',
            'status': 'ready',
            'phase': 'Running',
            'reason': '',
            'message': '',
            'ready': true,
            'paused': false,
            'archived': false,
            'repoUrl': 'https://github.com/happy/repo.git',
            'repoRef': 'main',
          },
        ],
      });
      final logs = SessionPodLogsResponse.fromJson({
        'podName': 'happy-session-1',
        'content': 'agent started',
        'truncated': true,
      });

      expect(pods.pods.single.ready, isTrue);
      expect(pods.pods.single.repoRef, 'main');
      expect(logs.content, 'agent started');
      expect(logs.truncated, isTrue);
    });

    test('parses shared Claude auth flow responses', () {
      final begin = ClaudeAuthBeginResponse.fromJson({
        'flowId': 'flow-1',
        'authorizationUrl': 'https://claude.ai/oauth/authorize',
        'expiresAt': '1234',
        'status': 'waiting_for_response',
      });
      final status = ClaudeAuthStatusResponse.fromJson({
        'flowId': 'flow-1',
        'status': 'authenticated',
        'success': true,
        'authenticated': true,
        'error': '',
      });

      expect(begin.expiresAt, 1234);
      expect(status.success, isTrue);
      expect(status.authenticated, isTrue);
    });
  });
}
