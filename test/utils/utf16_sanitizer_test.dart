import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/utf16_sanitizer.dart';

void main() {
  test('preserves valid surrogate pairs', () {
    expect(sanitizeUtf16('hello \u{1F600}'), 'hello \u{1F600}');
  });

  test('replaces unpaired high and low surrogates', () {
    expect(sanitizeUtf16('a\uD800b\uDC00c'), 'a\uFFFDb\uFFFDc');
  });

  test('sanitizes nested JSON values and keys', () {
    final result =
        sanitizeJsonUtf16(<String, dynamic>{
              'bad\uD800': <dynamic>['ok', 'bad\uDC00'],
            })
            as Map<String, dynamic>;

    expect(result, <String, dynamic>{
      'bad\uFFFD': <dynamic>['ok', 'bad\uFFFD'],
    });
  });
}
