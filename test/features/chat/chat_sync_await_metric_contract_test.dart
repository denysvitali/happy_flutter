import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat sync await exports a bounded Prometheus histogram', () {
    final source = File(
      'lib/features/chat/_chat_screen_actions.dart',
    ).readAsStringSync();

    expect(source, contains("'app.chat.sync.await'"));
    for (final label in <String>[
      "'mode'",
      "'outcome'",
      "'has_cached_messages'",
      "'queue_present'",
    ]) {
      expect(source, contains(label));
    }
    expect(
      source,
      isNot(contains("'app.chat.sync.await',\n          sessionId")),
      reason: 'session ids must not become histogram labels',
    );
  });
}
