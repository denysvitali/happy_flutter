import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';

void main() {
  group('Metadata.fromJson compatibility', () {
    test('tolerates null host and mixed-type tool arrays', () {
      final metadata = Metadata.fromJson(<String, dynamic>{
        'path': '/repo',
        'host': null,
        'summary': <String, dynamic>{
          'text': 'Summary',
          'updatedAt': 'invalid-int',
        },
        'tools': <dynamic>['bash', 42, null],
        'slashCommands': <dynamic>[
          '/help',
          <String, dynamic>{'x': 1},
        ],
      });

      expect(metadata.path, '/repo');
      expect(metadata.host, '');
      expect(metadata.summary, isNull);
      expect(metadata.tools, <String>['bash']);
      expect(metadata.slashCommands, <String>['/help']);
    });

    test('accepts snake_case slash_commands from agent init metadata', () {
      final metadata = Metadata.fromJson(<String, dynamic>{
        'host': 'devbox',
        'slash_commands': <dynamic>['goal', '/review', 42],
      });

      expect(metadata.slashCommands, <String>['goal', '/review']);
    });

    test('keeps valid summary fields', () {
      final metadata = Metadata.fromJson(<String, dynamic>{
        'host': 'devbox',
        'summary': <String, dynamic>{
          'text': 'All good',
          'updatedAt': 1700000000000,
        },
        'sandbox': <String, dynamic>{'enabled': true},
      });

      expect(metadata.host, 'devbox');
      expect(metadata.summary, isNotNull);
      expect(metadata.summary?.text, 'All good');
      expect(metadata.summary?.updatedAt, 1700000000000);
      expect(metadata.sandboxEnabled, isTrue);
    });

    test('parses explicit sandbox enforcement metadata', () {
      final metadata = Metadata.fromJson(<String, dynamic>{
        'host': 'devbox',
        'sandboxRequested': true,
        'sandboxRequired': false,
        'sandboxEnforced': false,
        'sandboxBackend': 'none',
        'sandboxReason': 'boxy doctor failed',
      });

      expect(metadata.sandboxRequested, isTrue);
      expect(metadata.sandboxRequired, isFalse);
      expect(metadata.sandboxEnforced, isFalse);
      expect(metadata.sandboxBackend, 'none');
      expect(metadata.sandboxReason, 'boxy doctor failed');
    });

    test('preserves authoritative runtime identity for restore', () {
      final metadata = Metadata.fromJson(<String, dynamic>{
        'host': 'worker',
        'runtimeType': 'kubernetes',
        'podName': 'happy-session-123',
        'namespace': 'agents',
      });

      expect(metadata.runtimeKind, 'kubernetes');
      expect(metadata.podName, 'happy-session-123');
      expect(metadata.namespace, 'agents');
    });

    test('accepts legacy string summary from restored Claude sessions', () {
      final metadata = Metadata.fromJson(<String, dynamic>{
        'host': 'devbox',
        'summary': 'The existing loops differ by agent, but they all',
      });

      expect(
        metadata.summary?.text,
        'The existing loops differ by agent, but they all',
      );
      expect(metadata.summary?.updatedAt, 0);
    });
  });

  group('AgentState.fromJson compatibility', () {
    test('parses Codex goal state without dropping permission requests', () {
      final state = AgentState.fromJson(<String, dynamic>{
        'controlledByUser': false,
        'goal': <String, dynamic>{
          'objective': 'Keep Codex aware of the current goal',
          'status': 'active',
          'updatedAt': 1700000000000,
        },
        'requests': <String, dynamic>{
          'ok': <String, dynamic>{
            'tool': 'bash',
            'arguments': <String, dynamic>{'command': 'ls'},
          },
        },
      });

      expect(state.goal, isNotNull);
      expect(state.goal?.objective, 'Keep Codex aware of the current goal');
      expect(state.goal?.status, 'active');
      expect(state.goal?.updatedAt, 1700000000000);
      expect(state.requests?.containsKey('ok'), isTrue);
      expect(state.toJson()['goal'], isA<Map<String, dynamic>>());
    });

    test('accepts legacy goal text field', () {
      final state = AgentState.fromJson(<String, dynamic>{
        'goal': <String, dynamic>{'text': 'Legacy goal text'},
      });

      expect(state.goal?.objective, 'Legacy goal text');
      expect(state.goal?.isVisible, isTrue);
    });

    test('drops malformed request entries instead of throwing', () {
      final state = AgentState.fromJson(<String, dynamic>{
        'controlledByUser': 'invalid-bool',
        'requests': <String, dynamic>{
          'ok': <String, dynamic>{
            'tool': 'bash',
            'arguments': <String, dynamic>{'command': 'ls'},
            'createdAt': 1700000000000,
          },
          'bad_type': 'not-a-map',
          'bad_shape': <String, dynamic>{'arguments': 123},
        },
        'completedRequests': <String, dynamic>{
          'ok': <String, dynamic>{
            'tool': 'read_file',
            'status': 'approved',
            'allowedTools': <dynamic>['read_file', 99],
          },
          'bad': <String, dynamic>{'tool': 123, 'status': true},
        },
      });

      expect(state.controlledByUser, isNull);
      expect(state.requests, isNotNull);
      expect(state.requests?.containsKey('ok'), isTrue);
      expect(state.requests?.containsKey('bad_type'), isFalse);
      expect(state.requests?.containsKey('bad_shape'), isFalse);

      expect(state.completedRequests, isNotNull);
      expect(state.completedRequests?.containsKey('ok'), isTrue);
      expect(state.completedRequests?['ok']?.allowedTools, <String>[
        'read_file',
      ]);
      expect(state.completedRequests?.containsKey('bad'), isFalse);
    });
  });
}
