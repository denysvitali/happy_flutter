import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/notification_service.dart';

void main() {
  test('parseStuckAction accepts only a valid stuck-session payload', () {
    expect(
      parseStuckAction(
        payload: jsonEncode({'type': 'stuck', 'sessionId': 'session-1'}),
      ),
      'session-1',
    );
    expect(
      parseStuckAction(
        payload: jsonEncode({'type': 'activity', 'sessionId': 'session-1'}),
      ),
      isNull,
    );
    expect(parseStuckAction(payload: '{bad json'), isNull);
    expect(parseStuckAction(payload: null), isNull);
  });
}
