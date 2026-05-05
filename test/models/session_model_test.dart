import 'package:happy_flutter/core/models/session.dart';
import 'package:test/test.dart';

void main() {
  group('Session metadata', () {
    test('preserves lifecycle error details from json', () {
      final session = Session.fromJson({
        'id': 'session-1',
        'seq': 1,
        'createdAt': 1,
        'updatedAt': 1,
        'active': true,
        'activeAt': 1,
        'metadataVersion': 1,
        'agentStateVersion': 1,
        'thinking': false,
        'presence': 'offline',
        'metadata': {
          'host': 'workspace',
          'lifecycleState': 'errored',
          'lifecycleStateError': 'daemon started without a live process',
          'lifecycleStateSince': 1777996729148,
        },
      });

      expect(session.hasLifecycleError, isTrue);
      expect(session.metadata?.lifecycleState, 'errored');
      expect(
        session.metadata?.lifecycleStateError,
        'daemon started without a live process',
      );
    });
  });
}
