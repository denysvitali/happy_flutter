import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/kv.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KvItem', () {
    test('fromJson creates correct instance', () {
      final json = {
        'key': 'my-key',
        'value': 'my-value',
        'version': 5,
      };

      final item = KvItem.fromJson(json);

      expect(item.key, equals('my-key'));
      expect(item.value, equals('my-value'));
      expect(item.version, equals(5));
    });

    test('toJson produces correct map', () {
      final item = KvItem(
        key: 'test-key',
        value: 'test-value',
        version: 3,
      );

      final json = item.toJson();

      expect(json['key'], equals('test-key'));
      expect(json['value'], equals('test-value'));
      expect(json['version'], equals(3));
    });

    test('fromJson and toJson are symmetric', () {
      final original = {
        'key': 'symmetric',
        'value': 'data',
        'version': 42,
      };

      final item = KvItem.fromJson(original);
      final roundTrip = item.toJson();

      expect(roundTrip, equals(original));
    });
  });

  group('KvListResponse', () {
    test('fromJson parses list of items', () {
      final json = {
        'items': [
          {'key': 'k1', 'value': 'v1', 'version': 1},
          {'key': 'k2', 'value': 'v2', 'version': 2},
        ],
      };

      final response = KvListResponse.fromJson(json);

      expect(response.items, hasLength(2));
      expect(response.items[0].key, equals('k1'));
      expect(response.items[1].key, equals('k2'));
    });

    test('fromJson handles empty list', () {
      final json = {'items': <dynamic>[]};

      final response = KvListResponse.fromJson(json);

      expect(response.items, isEmpty);
    });

    test('toJson produces correct structure', () {
      final response = KvListResponse(items: [
        KvItem(key: 'a', value: '1', version: 0),
      ]);

      final json = response.toJson();

      expect(json['items'], hasLength(1));
      expect(json['items'][0]['key'], equals('a'));
    });
  });

  group('KvBulkGetResponse', () {
    test('fromJson parses values list', () {
      final json = {
        'values': [
          {'key': 'x', 'value': '10', 'version': 1},
          {'key': 'y', 'value': '20', 'version': 2},
        ],
      };

      final response = KvBulkGetResponse.fromJson(json);

      expect(response.values, hasLength(2));
      expect(response.values[0].key, equals('x'));
      expect(response.values[1].value, equals('20'));
    });

    test('const constructor works', () {
      const response = KvBulkGetResponse(values: []);

      expect(response.values, isEmpty);
    });

    test('toJson produces correct structure', () {
      final response = KvBulkGetResponse(values: [
        KvItem(key: 'k', value: 'v', version: 1),
      ]);

      final json = response.toJson();

      expect(json['values'], hasLength(1));
    });
  });

  group('KvMutation', () {
    test('toJson includes key, value, and version', () {
      final mutation = KvMutation(
        key: 'test',
        value: 'data',
        version: -1,
      );

      final json = mutation.toJson();

      expect(json['key'], equals('test'));
      expect(json['value'], equals('data'));
      expect(json['version'], equals(-1));
    });

    test('toJson handles null value for delete', () {
      final mutation = KvMutation(
        key: 'to-delete',
        value: null,
        version: 5,
      );

      final json = mutation.toJson();

      expect(json['key'], equals('to-delete'));
      expect(json['value'], isNull);
      expect(json['version'], equals(5));
    });
  });

  group('KvMutateResult', () {
    test('fromJson creates correct instance', () {
      final json = {'key': 'result-key', 'version': 10};

      final result = KvMutateResult.fromJson(json);

      expect(result.key, equals('result-key'));
      expect(result.version, equals(10));
    });

    test('toJson produces correct map', () {
      final result = KvMutateResult(key: 'k', version: 3);

      final json = result.toJson();

      expect(json['key'], equals('k'));
      expect(json['version'], equals(3));
    });
  });

  group('KvMutateError', () {
    test('fromJson creates correct instance', () {
      final json = {
        'key': 'bad-key',
        'error': 'version-mismatch',
        'version': 7,
        'value': 'server-value',
      };

      final error = KvMutateError.fromJson(json);

      expect(error.key, equals('bad-key'));
      expect(error.error, equals('version-mismatch'));
      expect(error.version, equals(7));
      expect(error.value, equals('server-value'));
    });

    test('fromJson handles missing optional value', () {
      final json = {
        'key': 'k',
        'error': 'conflict',
        'version': 1,
      };

      final error = KvMutateError.fromJson(json);

      expect(error.value, isNull);
    });

    test('toJson includes all fields', () {
      final error = KvMutateError(
        key: 'k',
        error: 'version-mismatch',
        version: 5,
        value: 'v',
      );

      final json = error.toJson();

      expect(json['key'], equals('k'));
      expect(json['error'], equals('version-mismatch'));
      expect(json['version'], equals(5));
      expect(json['value'], equals('v'));
    });
  });

  group('KvMutateResponse', () {
    test('fromJson parses success response', () {
      final json = {
        'success': true,
        'results': [
          {'key': 'k1', 'version': 1},
        ],
      };

      final response = KvMutateResponse.fromJson(json);

      expect(response, isA<KvMutateSuccessResponse>());
      expect(response.isSuccess, isTrue);
      expect(response.isError, isFalse);
      expect(response.results, hasLength(1));
    });

    test('fromJson parses error response', () {
      final json = {
        'success': false,
        'errors': [
          {
            'key': 'k1',
            'error': 'version-mismatch',
            'version': 5,
          },
        ],
      };

      final response = KvMutateResponse.fromJson(json);

      expect(response, isA<KvMutateErrorResponse>());
      expect(response.isSuccess, isFalse);
      expect(response.isError, isTrue);
      expect(response.errors, hasLength(1));
      expect(response.errors.first.error, equals('version-mismatch'));
    });

    test('KvMutateSuccessResponse toJson includes success flag', () {
      final response = KvMutateSuccessResponse([
        KvMutateResult(key: 'k', version: 1),
      ]);

      final json = response.toJson();

      expect(json['success'], isTrue);
      expect(json['results'], hasLength(1));
    });

    test('KvMutateErrorResponse toJson includes success false', () {
      final response = KvMutateErrorResponse([
        KvMutateError(
          key: 'k',
          error: 'version-mismatch',
          version: 1,
        ),
      ]);

      final json = response.toJson();

      expect(json['success'], isFalse);
      expect(json['errors'], hasLength(1));
    });
  });
}
