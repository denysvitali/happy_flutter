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

  group('Session lifecycleStateCleartext precedence', () {
    Session sessionWith({
      String? cleartext,
      String? metadataState,
      Map<String, dynamic> extraMetadata = const {},
    }) {
      return Session.fromJson({
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
        if (cleartext != null) 'lifecycleStateCleartext': cleartext,
        'metadata': {
          'host': 'workspace',
          if (metadataState != null) 'lifecycleState': metadataState,
          ...extraMetadata,
        },
      });
    }

    test('cleartext running clears stale encrypted errored', () {
      final session = sessionWith(
        cleartext: 'running',
        metadataState: 'errored',
      );

      expect(session.hasLifecycleError, isFalse);
      expect(session.effectiveLifecycleState, 'running');
      expect(session.canAttemptLifecycleRestore, isFalse);
    });

    test('cleartext errored wins over encrypted running', () {
      final session = sessionWith(
        cleartext: 'errored',
        metadataState: 'running',
      );

      expect(session.hasLifecycleError, isTrue);
      expect(session.effectiveLifecycleState, 'errored');
    });

    test('absent cleartext falls back to encrypted metadata', () {
      final session = sessionWith(metadataState: 'errored');

      expect(session.lifecycleStateCleartext, '');
      expect(session.hasLifecycleError, isTrue);
      expect(session.effectiveLifecycleState, 'errored');
    });

    test('absent cleartext and clean metadata reports no error', () {
      final session = sessionWith(metadataState: 'running');

      expect(session.hasLifecycleError, isFalse);
      expect(session.effectiveLifecycleState, 'running');
    });

    test('restore requires error plus machineId and path', () {
      final session = sessionWith(
        cleartext: 'errored',
        metadataState: 'errored',
        extraMetadata: {'machineId': 'm-1', 'path': '/work/repo'},
      );

      expect(session.canAttemptLifecycleRestore, isTrue);
    });
  });
}
