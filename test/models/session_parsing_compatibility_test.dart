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

    test('keeps valid summary fields', () {
      final metadata = Metadata.fromJson(<String, dynamic>{
        'host': 'devbox',
        'summary': <String, dynamic>{
          'text': 'All good',
          'updatedAt': 1700000000000,
        },
      });

      expect(metadata.host, 'devbox');
      expect(metadata.summary, isNotNull);
      expect(metadata.summary?.text, 'All good');
      expect(metadata.summary?.updatedAt, 1700000000000);
    });
  });

  group('AgentState.fromJson compatibility', () {
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
