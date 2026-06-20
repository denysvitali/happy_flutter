import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/loop.dart';

Map<String, dynamic> _validJson({String id = 'aaaaaaaa'}) => <String, dynamic>{
      'id': id,
      'sessionId': 's1',
      'expression': '*/5 * * * *',
      'prompt': 'check the deploy',
      'recurring': true,
      'createdAt': 1700000000000,
      'expiresAt': 1700604800000,
      'fireCount': 0,
      'paused': false,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Loop.tryFromJson', () {
    test('parses a fully-typed payload', () {
      final loop = Loop.tryFromJson(_validJson(id: 'cafef00d'));
      expect(loop, isNotNull);
      expect(loop!.id, 'cafef00d');
      expect(loop.recurring, isTrue);
      expect(loop.fireCount, 0);
      expect(loop.paused, isFalse);
      expect(loop.lastFiredAt, isNull);
    });

    test('tolerates string-typed numeric fields (legacy backend shape)', () {
      // Regression: prior to the WireParsers migration,
      // `(json['createdAt'] as num).toInt()` threw on
      // `String '1700000000000'`. Different server variants (and
      // legacy daemons) emit numeric fields as strings; the lenient
      // parser must accept either.
      final json = <String, dynamic>{
        'id': 'aaaaaaaa',
        'sessionId': 's1',
        'expression': '*/5 * * * *',
        'prompt': 'check',
        'recurring': 'true', // also string-typed
        'createdAt': '1700000000000',
        'expiresAt': '1700604800000',
        'lastFiredAt': '1700000060000',
        'fireCount': '3',
        'paused': 'false',
      };
      final loop = Loop.tryFromJson(json);
      expect(loop, isNotNull);
      expect(loop!.createdAt, 1700000000000);
      expect(loop.expiresAt, 1700604800000);
      expect(loop.lastFiredAt, 1700000060000);
      expect(loop.fireCount, 3);
      expect(loop.recurring, isTrue);
      expect(loop.paused, isFalse);
    });

    test('returns null when a required field is missing', () {
      final required = ['id', 'sessionId', 'expression', 'prompt', 'createdAt', 'expiresAt'];
      for (final key in required) {
        final json = _validJson()..remove(key);
        expect(
          Loop.tryFromJson(json),
          isNull,
          reason: 'must return null when $key is missing',
        );
      }
    });

    test('returns null when a required numeric field is unparseable', () {
      final json = _validJson()
        ..['createdAt'] = 'not-a-number';
      expect(Loop.tryFromJson(json), isNull);
    });

    test('returns null on a completely empty payload', () {
      expect(Loop.tryFromJson(<String, dynamic>{}), isNull);
    });

    test('defaults recurring to true, paused to false, fireCount to 0', () {
      final json = _validJson()..remove('recurring')..remove('paused')..remove('fireCount');
      final loop = Loop.tryFromJson(json);
      expect(loop, isNotNull);
      expect(loop!.recurring, isTrue);
      expect(loop.paused, isFalse);
      expect(loop.fireCount, 0);
    });

    test('a single bad entry never throws to the caller', () {
      // The contract is "never throw" — listLoops / _applyLoopsUpdate
      // rely on this so a malformed payload can't poison the rest of
      // the batch.
      expect(
        () => Loop.tryFromJson(<String, dynamic>{'id': null}),
        returnsNormally,
      );
      expect(Loop.tryFromJson(<String, dynamic>{'id': null}), isNull);
    });
  });
}
