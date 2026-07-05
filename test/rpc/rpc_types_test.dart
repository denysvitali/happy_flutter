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
      });

      expect(response.type, 'success');
      expect(response.sessionId, 'session-123');
      expect(response.directory, '/tmp/project');
      expect(response.dataEncryptionKey, 'dek-abc');
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
}
