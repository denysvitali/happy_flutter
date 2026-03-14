import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/kv.dart';

void main() {
  group('KvItem', () {
    group('fromJson', () {
      test('parses all fields', () {
        final json = {
          'key': 'pref.theme',
          'value': 'dark',
          'version': 5,
        };

        final item = KvItem.fromJson(json);

        expect(item.key, 'pref.theme');
        expect(item.value, 'dark');
        expect(item.version, 5);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final item = KvItem(
          key: 'pref.lang',
          value: 'en',
          version: 3,
        );

        final json = item.toJson();

        expect(json['key'], 'pref.lang');
        expect(json['value'], 'en');
        expect(json['version'], 3);
      });

      test('round-trip preserves data', () {
        final original = {
          'key': 'test.key',
          'value': 'test-value',
          'version': 10,
        };

        final item = KvItem.fromJson(original);
        final restored = item.toJson();

        expect(restored, original);
      });
    });
  });

  group('KvListResponse', () {
    group('fromJson', () {
      test('parses list of items', () {
        final json = {
          'items': [
            {'key': 'a', 'value': '1', 'version': 1},
            {'key': 'b', 'value': '2', 'version': 2},
          ],
        };

        final response = KvListResponse.fromJson(json);

        expect(response.items.length, 2);
        expect(response.items.first.key, 'a');
        expect(response.items.last.key, 'b');
      });

      test('handles empty list', () {
        final json = {'items': <dynamic>[]};

        final response = KvListResponse.fromJson(json);
        expect(response.items, isEmpty);
      });
    });

    group('toJson', () {
      test('serializes items list', () {
        final response = KvListResponse(
          items: [
            KvItem(key: 'x', value: 'y', version: 1),
          ],
        );

        final json = response.toJson();

        expect(json['items'], isA<List>());
        expect((json['items'] as List).length, 1);
      });
    });
  });

  group('KvBulkGetRequest', () {
    group('toJson', () {
      test('serializes keys list', () {
        final request = KvBulkGetRequest(keys: ['a', 'b', 'c']);
        final json = request.toJson();

        expect(json['keys'], ['a', 'b', 'c']);
      });

      test('handles empty keys', () {
        final request = KvBulkGetRequest(keys: []);
        final json = request.toJson();

        expect(json['keys'], isEmpty);
      });
    });
  });

  group('KvBulkGetResponse', () {
    group('fromJson', () {
      test('parses values list', () {
        final json = {
          'values': [
            {'key': 'k1', 'value': 'v1', 'version': 1},
          ],
        };

        final response = KvBulkGetResponse.fromJson(json);

        expect(response.values.length, 1);
        expect(response.values.first.key, 'k1');
      });
    });

    group('toJson', () {
      test('serializes values', () {
        final response = KvBulkGetResponse(
          values: [
            KvItem(key: 'k', value: 'v', version: 1),
          ],
        );

        final json = response.toJson();
        expect(json['values'], isA<List>());
      });
    });
  });

  group('KvMutation', () {
    group('toJson', () {
      test('serializes with value', () {
        final mutation = KvMutation(
          key: 'key-1',
          value: 'new-val',
          version: 2,
        );

        final json = mutation.toJson();

        expect(json['key'], 'key-1');
        expect(json['value'], 'new-val');
        expect(json['version'], 2);
      });

      test('serializes with null value (delete)', () {
        final mutation = KvMutation(
          key: 'key-1',
          value: null,
          version: 3,
        );

        final json = mutation.toJson();

        expect(json['key'], 'key-1');
        expect(json['value'], isNull);
        expect(json['version'], 3);
      });

      test('serializes new key with version -1', () {
        final mutation = KvMutation(
          key: 'new-key',
          value: 'val',
          version: -1,
        );

        final json = mutation.toJson();
        expect(json['version'], -1);
      });
    });
  });

  group('KvMutateRequest', () {
    group('toJson', () {
      test('serializes mutations list', () {
        final request = KvMutateRequest(
          mutations: [
            KvMutation(key: 'a', value: '1', version: 1),
            KvMutation(key: 'b', value: null, version: 2),
          ],
        );

        final json = request.toJson();

        expect(json['mutations'], isA<List>());
        expect((json['mutations'] as List).length, 2);
      });
    });
  });

  group('KvMutateResult', () {
    group('fromJson', () {
      test('parses key and version', () {
        final json = {'key': 'result-key', 'version': 7};

        final result = KvMutateResult.fromJson(json);

        expect(result.key, 'result-key');
        expect(result.version, 7);
      });
    });

    group('toJson', () {
      test('serializes key and version', () {
        final result = KvMutateResult(key: 'k', version: 5);
        final json = result.toJson();

        expect(json['key'], 'k');
        expect(json['version'], 5);
      });
    });
  });

  group('KvMutateError', () {
    group('fromJson', () {
      test('parses all fields', () {
        final json = {
          'key': 'err-key',
          'error': 'version-mismatch',
          'version': 3,
          'value': 'current-val',
        };

        final error = KvMutateError.fromJson(json);

        expect(error.key, 'err-key');
        expect(error.error, 'version-mismatch');
        expect(error.version, 3);
        expect(error.value, 'current-val');
      });

      test('handles missing optional value', () {
        final json = {
          'key': 'err-key',
          'error': 'version-mismatch',
          'version': 3,
        };

        final error = KvMutateError.fromJson(json);
        expect(error.value, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final error = KvMutateError(
          key: 'k',
          error: 'version-mismatch',
          version: 1,
          value: 'v',
        );

        final json = error.toJson();

        expect(json['key'], 'k');
        expect(json['error'], 'version-mismatch');
        expect(json['version'], 1);
        expect(json['value'], 'v');
      });
    });
  });

  group('KvMutateResponse', () {
    group('fromJson', () {
      test('parses success response', () {
        final json = {
          'success': true,
          'results': [
            {'key': 'a', 'version': 2},
          ],
        };

        final response = KvMutateResponse.fromJson(json);

        expect(response.isSuccess, isTrue);
        expect(response.isError, isFalse);
        expect(response.results.length, 1);
        expect(response.results.first.key, 'a');
      });

      test('parses error response', () {
        final json = {
          'success': false,
          'errors': [
            {
              'key': 'a',
              'error': 'version-mismatch',
              'version': 1,
            },
          ],
        };

        final response = KvMutateResponse.fromJson(json);

        expect(response.isError, isTrue);
        expect(response.isSuccess, isFalse);
        expect(response.errors.length, 1);
        expect(response.errors.first.error, 'version-mismatch');
      });
    });

    group('KvMutateSuccessResponse', () {
      test('toJson serializes with success true', () {
        final response = KvMutateSuccessResponse([
          KvMutateResult(key: 'a', version: 1),
        ]);

        final json = response.toJson();

        expect(json['success'], isTrue);
        expect(json['results'], isA<List>());
      });
    });

    group('KvMutateErrorResponse', () {
      test('toJson serializes with success false', () {
        final response = KvMutateErrorResponse([
          KvMutateError(
            key: 'a',
            error: 'version-mismatch',
            version: 1,
          ),
        ]);

        final json = response.toJson();

        expect(json['success'], isFalse);
        expect(json['errors'], isA<List>());
      });
    });
  });
}
