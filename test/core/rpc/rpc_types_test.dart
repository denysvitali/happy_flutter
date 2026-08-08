import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';

void main() {
  test('SpawnSessionResponse parses flat sandbox enforcement metadata', () {
    final response = SpawnSessionResponse.fromJson(const <String, dynamic>{
      'type': 'success',
      'sessionId': 'session-1',
      'sandboxRequested': true,
      'sandboxRequired': false,
      'sandboxEnforced': true,
      'sandboxBackend': 'kubernetes',
      'sandboxReason': 'policy fallback',
    });

    expect(response.sandboxRequested, isTrue);
    expect(response.sandboxRequired, isFalse);
    expect(response.sandboxEnforced, isTrue);
    expect(response.sandboxBackend, 'kubernetes');
    expect(response.sandboxReason, 'policy fallback');
  });

  test('StopSessionResponse accepts the canonical daemon payload', () {
    final response = StopSessionResponse.fromJson(const <String, dynamic>{
      'message': 'Session stopped',
    });

    expect(response.message, 'Session stopped');
  });

  test('PermissionResponse preserves the daemon-applied decision scope', () {
    final response = PermissionResponse.fromJson(const <String, dynamic>{
      'success': true,
      'requestId': 'permission-1',
      'decision': 'approved_for_session',
      'scope': 'session',
      'allowTools': <String>['Bash(git status)'],
      'mode': 'acceptEdits',
    });

    expect(response.requestId, 'permission-1');
    expect(response.decision, 'approved_for_session');
    expect(response.scope, 'session');
    expect(response.allowTools, ['Bash(git status)']);
    expect(response.mode, 'acceptEdits');
  });
}
