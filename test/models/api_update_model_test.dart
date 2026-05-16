import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/api_update.dart';

void main() {
  group('ApiUpdateNewMessage', () {
    group('fromJson', () {
      test('parses all fields', () {
        final json = {
          't': 'new-message',
          'sid': 'sess-1',
          'message': {'id': 'msg-1', 'content': 'hello'},
        };

        final update = ApiUpdateNewMessage.fromJson(json);

        expect(update.t, 'new-message');
        expect(update.sid, 'sess-1');
        expect(update.message, {'id': 'msg-1', 'content': 'hello'});
      });

      test('handles missing fields with defaults', () {
        final json = <String, dynamic>{};

        final update = ApiUpdateNewMessage.fromJson(json);

        expect(update.t, '');
        expect(update.sid, '');
        expect(update.message, isEmpty);
      });
    });
  });

  group('ApiUpdateNewSession', () {
    group('fromJson', () {
      test('parses all fields', () {
        final json = {
          't': 'new-session',
          'id': 'sess-new',
          'createdAt': 1700000000,
          'updatedAt': 1700000100,
        };

        final update = ApiUpdateNewSession.fromJson(json);

        expect(update.t, 'new-session');
        expect(update.id, 'sess-new');
        expect(update.createdAt, 1700000000);
        expect(update.updatedAt, 1700000100);
      });

      test('handles double timestamps via _asInt', () {
        final json = {
          't': 'new-session',
          'id': 'sess-1',
          'createdAt': 1700000000.0,
          'updatedAt': 1700000100.0,
        };

        final update = ApiUpdateNewSession.fromJson(json);

        expect(update.createdAt, 1700000000);
        expect(update.updatedAt, 1700000100);
      });

      test('defaults missing fields', () {
        final json = <String, dynamic>{};

        final update = ApiUpdateNewSession.fromJson(json);

        expect(update.t, '');
        expect(update.id, '');
        expect(update.createdAt, 0);
        expect(update.updatedAt, 0);
      });
    });
  });

  group('ApiDeleteSession', () {
    group('fromJson', () {
      test('parses fields', () {
        final json = {'t': 'delete-session', 'sid': 'sess-1'};

        final update = ApiDeleteSession.fromJson(json);

        expect(update.t, 'delete-session');
        expect(update.sid, 'sess-1');
      });

      test('defaults missing fields', () {
        final json = <String, dynamic>{};

        final update = ApiDeleteSession.fromJson(json);

        expect(update.t, '');
        expect(update.sid, '');
      });
    });
  });

  group('ApiUpdateSessionState', () {
    group('fromJson', () {
      test('parses with agentState and metadata', () {
        final json = {
          't': 'update-session-state',
          'id': 'sess-1',
          'agentState': {'version': 1, 'value': 'idle'},
          'metadata': {'version': 2, 'value': '{}'},
        };

        final update = ApiUpdateSessionState.fromJson(json);

        expect(update.t, 'update-session-state');
        expect(update.id, 'sess-1');
        expect(update.agentState, isNotNull);
        expect(update.agentState!.version, 1);
        expect(update.agentState!.value, 'idle');
        expect(update.metadata, isNotNull);
        expect(update.metadata!.version, 2);
      });

      test('handles null agentState and metadata', () {
        final json = {'t': 'update-session-state', 'id': 'sess-1'};

        final update = ApiUpdateSessionState.fromJson(json);

        expect(update.agentState, isNull);
        expect(update.metadata, isNull);
      });

      test('handles non-map agentState as null', () {
        final json = {
          't': 'update-session-state',
          'id': 'sess-1',
          'agentState': 'invalid',
          'metadata': 123,
        };

        final update = ApiUpdateSessionState.fromJson(json);

        expect(update.agentState, isNull);
        expect(update.metadata, isNull);
      });

      test('accepts sid when id is absent', () {
        final json = {'t': 'update-session-state', 'sid': 'sess-1'};

        final update = ApiUpdateSessionState.fromJson(json);

        expect(update.id, 'sess-1');
      });
    });
  });

  group('VersionedValue', () {
    group('fromJson', () {
      test('parses version and value', () {
        final json = {'version': 5, 'value': 'running'};

        final vv = VersionedValue.fromJson(json);

        expect(vv.version, 5);
        expect(vv.value, 'running');
      });

      test('handles null value', () {
        final json = {'version': 3, 'value': null};

        final vv = VersionedValue.fromJson(json);

        expect(vv.version, 3);
        expect(vv.value, '');
      });

      test('handles missing value', () {
        final json = {'version': 1};

        final vv = VersionedValue.fromJson(json);

        expect(vv.version, 1);
        expect(vv.value, '');
      });

      test('handles double version', () {
        final json = {'version': 4.0, 'value': 'test'};

        final vv = VersionedValue.fromJson(json);

        expect(vv.version, 4);
      });

      test('defaults version to zero', () {
        final json = <String, dynamic>{};

        final vv = VersionedValue.fromJson(json);

        expect(vv.version, 0);
      });
    });
  });

  group('ApiUpdate', () {
    group('fromJson', () {
      test('parses wrapped format (body key)', () {
        final json = {
          'body': {'t': 'new-message', 'sid': 'sess-1'},
        };

        final update = ApiUpdate.fromJson(json);

        expect(update.type, 'new-message');
        expect(update.data, isA<Map>());
      });

      test('parses flat format (direct t key)', () {
        final json = {
          't': 'update-account',
          'data': {'name': 'test'},
        };

        final update = ApiUpdate.fromJson(json);

        expect(update.type, 'update-account');
        expect(update.data, json);
      });

      test('defaults type to empty string', () {
        final json = {'body': <String, dynamic>{}};

        final update = ApiUpdate.fromJson(json);

        expect(update.type, '');
      });

      test('wrapped format takes precedence over flat', () {
        final json = {
          't': 'flat-type',
          'body': {'t': 'wrapped-type'},
        };

        final update = ApiUpdate.fromJson(json);

        expect(update.type, 'wrapped-type');
      });
    });
  });

  group('ApiUpdateAccount', () {
    test('stores data', () {
      const update = ApiUpdateAccount(data: {'name': 'Alice'});
      expect(update.data, {'name': 'Alice'});
    });
  });

  group('ApiUpdateMachine', () {
    test('stores id and data', () {
      const update = ApiUpdateMachine(
        id: 'machine-1',
        data: {'status': 'online'},
      );
      expect(update.id, 'machine-1');
      expect(update.data, {'status': 'online'});
    });
  });

  group('ApiNewArtifact', () {
    test('stores data', () {
      const update = ApiNewArtifact(data: {'id': 'art-1'});
      expect(update.data, {'id': 'art-1'});
    });
  });

  group('ApiUpdateArtifact', () {
    test('stores data', () {
      const update = ApiUpdateArtifact(data: {'id': 'art-1'});
      expect(update.data, {'id': 'art-1'});
    });
  });

  group('ApiDeleteArtifact', () {
    test('stores id', () {
      const update = ApiDeleteArtifact(id: 'art-1');
      expect(update.id, 'art-1');
    });
  });

}
