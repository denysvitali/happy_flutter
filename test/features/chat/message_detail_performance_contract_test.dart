import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('message detail bounds work performed by its first route frame', () {
    final detail = File(
      'lib/features/chat/message_detail_screen.dart',
    ).readAsStringSync();
    final jsonViewer = File(
      'lib/features/chat/tools/json_viewer.dart',
    ).readAsStringSync();

    expect(detail, contains('_largePayloadThreshold'));
    expect(detail, contains('_DeferredToolResultSection'));
    expect(detail, contains('_PagedSelectableText'));
    expect(
      detail,
      isNot(contains('return value.values.any(_hasMeaningfulPayload);')),
      reason: 'route build must not recursively walk a tool payload',
    );
    expect(
      jsonViewer,
      isNot(contains('value: _decodeNestedJsonStrings(value)')),
      reason:
          'JSON trees must decode children lazily, not clone the whole '
          'payload during navigation',
    );
  });
}
