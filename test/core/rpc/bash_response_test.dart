import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';

void main() {
  group('BashResponse', () {
    test('parses bounded-output metadata', () {
      final response = BashResponse.fromJson(<String, dynamic>{
        'success': true,
        'stdout': 'tail',
        'stderr': 'warning',
        'exitCode': 0,
        'stdoutTruncated': true,
        'stderrTruncated': false,
        'stdoutBytes': 2097152,
        'stderrBytes': '7',
      });

      expect(response.stdoutTruncated, isTrue);
      expect(response.stderrTruncated, isFalse);
      expect(response.stdoutBytes, 2097152);
      expect(response.stderrBytes, 7);
    });

    test('defaults absent or malformed metadata safely', () {
      final response = BashResponse.fromJson(<String, dynamic>{
        'success': true,
        'stdoutBytes': 'unknown',
        'stderrBytes': 4.5,
      });

      expect(response.stdoutTruncated, isFalse);
      expect(response.stderrTruncated, isFalse);
      expect(response.stdoutBytes, isNull);
      expect(response.stderrBytes, isNull);
    });
  });
}
