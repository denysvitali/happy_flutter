import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/parse_token.dart';

String _buildJwt(Map<String, dynamic> claims) {
  final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
  final payload = base64Url.encode(utf8.encode(jsonEncode(claims)));
  final signature = base64Url.encode(utf8.encode('sig'));
  return '$header.$payload.$signature';
}

void main() {
  group('parseToken', () {
    test('extracts user ID from sub claim', () {
      final token = _buildJwt({'sub': 'user-123'});
      expect(parseToken(token), 'user-123');
    });

    test('extracts user ID from user_id claim', () {
      final token = _buildJwt({'user_id': 'user-456'});
      expect(parseToken(token), 'user-456');
    });

    test('extracts user ID from userId claim', () {
      final token = _buildJwt({'userId': 'user-789'});
      expect(parseToken(token), 'user-789');
    });

    test('prefers sub over user_id and userId', () {
      final token = _buildJwt({
        'sub': 'preferred',
        'user_id': 'fallback1',
        'userId': 'fallback2',
      });
      expect(parseToken(token), 'preferred');
    });

    test('prefers user_id over userId when sub missing', () {
      final token = _buildJwt({
        'user_id': 'preferred',
        'userId': 'fallback',
      });
      expect(parseToken(token), 'preferred');
    });

    test('returns unknown when no recognized claim present', () {
      final token = _buildJwt({'name': 'test'});
      expect(parseToken(token), 'unknown');
    });

    test('returns unknown for empty claims', () {
      final token = _buildJwt({});
      expect(parseToken(token), 'unknown');
    });

    test('returns first 8 chars for malformed JWT (wrong parts)', () {
      expect(parseToken('only-one-part'), 'only-one');
      expect(parseToken('two.parts'), 'two.part');
    });

    test('throws for empty token (substring out of range)', () {
      expect(() => parseToken(''), throwsRangeError);
    });

    test('throws for token shorter than 8 (substring out of range)', () {
      expect(() => parseToken('abc'), throwsRangeError);
    });

    test('returns first 8 chars for non-JWT string', () {
      expect(parseToken('not-a-jwt-token-at-all'), 'not-a-jw');
    });

    test('handles JWT with invalid base64 payload', () {
      const token = 'header.not-base64!@#.signature';
      expect(parseToken(token), 'header.n');
    });

    test('handles JWT with non-JSON payload', () {
      final header = base64Url.encode(utf8.encode('{}'));
      final payload = base64Url.encode(utf8.encode('not json'));
      final token = '$header.$payload.sig';
      expect(parseToken(token), isNotNull);
      // Falls back to first 8 chars on decode error
      expect(parseToken(token).length, lessThanOrEqualTo(8));
    });

    test('handles JWT with non-string claim values', () {
      final token = _buildJwt({'sub': 123});
      // sub is int, not String, so cast fails via TypeError,
      // falls back to first 8 chars of token
      final result = parseToken(token);
      expect(result.length, 8);
    });

    test('handles JWT with null claim values', () {
      final token = _buildJwt({'sub': null, 'user_id': null});
      expect(parseToken(token), 'unknown');
    });

    test('handles JWT with extra claims', () {
      final token = _buildJwt({
        'sub': 'user-1',
        'exp': 9999999999,
        'iat': 1234567890,
        'aud': 'test',
      });
      expect(parseToken(token), 'user-1');
    });
  });
}
