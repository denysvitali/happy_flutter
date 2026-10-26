import 'package:happy_flutter/core/models/session.dart';
import 'package:test/test.dart';

void main() {
  group('Session metadata', () {
    test('ACP plan entries retain statuses and tolerate malformed values', () {
      final metadata = Metadata.fromJson({
        'flavor': 'opencode',
        'plan': [
          {'content': 'Read file', 'status': 'in_progress', 'priority': 'high'},
          {'content': 'Reply', 'status': 'pending'},
          null,
        ],
      });
      expect(metadata.plan, hasLength(2));
      expect(metadata.acpPlanItems.first.content, 'Read file');
      expect(metadata.acpPlanItems.first.status.value, 'inProgress');
      expect(metadata.acpPlanItems.last.priority, 'medium');
      expect(Metadata.fromJson(metadata.toJson()).plan, metadata.plan);
      expect(Metadata.fromJson({'plan': false}).acpPlanItems, isEmpty);
    });

    test('OpenCode catalog roundtrips and ignores malformed entries', () {
      final metadata = Metadata.fromJson({
        'flavor': 'opencode',
        'model': 'opencode/big-pickle',
        'opencodeModels': [
          {'id': 'opencode/big-pickle', 'name': 'OpenCode/Big Pickle'},
          {'id': 'provider/free'},
          {'id': ''},
          {'id': 123},
          null,
        ],
      });
      expect(metadata.opencodeModels!.map((m) => m.id), [
        'opencode/big-pickle',
        'provider/free',
      ]);
      expect(metadata.opencodeModels!.last.name, 'provider/free');
      expect(
        metadata.copyWith(model: 'provider/free').opencodeModels,
        metadata.opencodeModels,
      );
      expect(Metadata.fromJson(metadata.toJson()), metadata);
      expect(
        Metadata.fromJson({'opencodeModels': 'bad'}).opencodeModels,
        isNull,
      );
    });

    test('Har catalog roundtrips and ignores malformed entries', () {
      final metadata = Metadata.fromJson({
        'flavor': 'har',
        'model': 'codex/gpt-6.1-terra',
        'harModels': [
          {'id': 'codex/gpt-6.1-terra', 'name': 'GPT-6.1 Terra'},
          {'id': ' provider/model:variant '},
          {'id': ''},
          {'id': 123},
          null,
        ],
      });
      expect(metadata.harModels!.map((m) => m.id), [
        'codex/gpt-6.1-terra',
        ' provider/model:variant ',
      ]);
      expect(metadata.harModels!.last.name, ' provider/model:variant ');
      expect(metadata.copyWith(model: 'other').harModels, metadata.harModels);
      expect(Metadata.fromJson(metadata.toJson()), metadata);
      expect(Metadata.fromJson({'harModels': false}).harModels, isNull);
    });

    test('roundtrips the Prime Agent saved transcript field', () {
      final metadata = Metadata.fromJson({
        'host': 'workspace',
        'primeAgentSessionFile': 'conversation.jsonl',
      });

      expect(metadata.primeAgentSessionFile, 'conversation.jsonl');
      expect(metadata.hasPrimeAgentSessionFile, isTrue);
      expect(metadata.toJson()['primeAgentSessionFile'], 'conversation.jsonl');
      expect(
        metadata.copyWith(model: 'new-model').primeAgentSessionFile,
        'conversation.jsonl',
      );
    });

    test('only accepts a saved transcript basename with a nonempty stem', () {
      for (final file in <String?>[
        null,
        '',
        '.jsonl',
        'conversation',
        'conversation.JSONL',
        '/tmp/conversation.jsonl',
        '../conversation.jsonl',
        r'folder\conversation.jsonl',
        'conversation\u0000.jsonl',
      ]) {
        expect(
          Metadata(
            host: '',
            primeAgentSessionFile: file,
          ).hasPrimeAgentSessionFile,
          isFalse,
          reason: 'Invalid saved transcript: $file',
        );
      }
    });

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

    for (final flavor in ['har', 'prime-agent']) {
      test('$flavor cannot restore even with a machine and path', () {
        final session = sessionWith(
          cleartext: 'errored',
          extraMetadata: {
            'flavor': flavor,
            'machineId': 'm-1',
            'path': '/work/repo',
          },
        );
        expect(session.hasLifecycleError, isTrue);
        expect(session.canAttemptLifecycleRestore, isFalse);
      });
    }

    test('Har restore requires the qualified private resume protocol', () {
      final metadata = <String, dynamic>{
        'flavor': 'har',
        'machineId': 'm-1',
        'path': '/work/repo',
        'harSessionId': 'har-saved',
        'harDurableResumeSupported': true,
        'harResumeProtocol': 'happy-private-v1',
      };
      final session = sessionWith(
        cleartext: 'errored',
        extraMetadata: metadata,
      );
      expect(session.canRestoreHar, isTrue);
      expect(session.canAttemptLifecycleRestore, isTrue);
      for (final key in metadata.keys) {
        final incomplete = Map<String, dynamic>.from(metadata)..remove(key);
        expect(
          sessionWith(
            cleartext: 'errored',
            extraMetadata: incomplete,
          ).canRestoreHar,
          isFalse,
          reason: key,
        );
      }
    });

    test('Prime restore requires a saved transcript plus machine and path', () {
      final session = sessionWith(
        cleartext: 'errored',
        extraMetadata: {
          'flavor': 'prime-agent',
          'machineId': 'm-1',
          'path': '/work/repo',
          'primeAgentSessionFile': 'conversation.jsonl',
        },
      );

      expect(session.canRestorePrimeAgent, isTrue);
      expect(session.canAttemptLifecycleRestore, isTrue);
      for (final state in ['running', 'stopped', 'exited', 'archived']) {
        final changed = session.copyWith(lifecycleStateCleartext: state);
        expect(changed.canRestorePrimeAgent, isTrue);
        expect(changed.canAttemptLifecycleRestore, isFalse);
      }
      for (final metadata in [
        session.metadata!.copyWith(machineId: null),
        session.metadata!.copyWith(path: ''),
        session.metadata!.copyWith(primeAgentSessionFile: '../bad.jsonl'),
        session.metadata!.copyWith(flavor: 'har'),
      ]) {
        final changed = session.copyWith(metadata: metadata);
        expect(changed.canRestorePrimeAgent, isFalse);
        expect(changed.canAttemptLifecycleRestore, isFalse);
      }
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
