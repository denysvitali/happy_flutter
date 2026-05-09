import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/notification_service.dart';

void main() {
  group('parseReplyAction', () {
    test('returns null when payload is missing', () {
      expect(parseReplyAction(payload: null, input: 'hi'), isNull);
    });

    test('returns null when input is empty after trim', () {
      final payload = json.encode({'sessionId': 's1'});
      expect(parseReplyAction(payload: payload, input: ''), isNull);
      expect(parseReplyAction(payload: payload, input: '   '), isNull);
      expect(parseReplyAction(payload: payload, input: null), isNull);
    });

    test('returns null when payload has no sessionId', () {
      final payload = json.encode({'type': 'permission'});
      expect(parseReplyAction(payload: payload, input: 'hi'), isNull);
    });

    test('returns null on invalid JSON payload', () {
      expect(
        parseReplyAction(payload: '{not-json', input: 'hi'),
        isNull,
      );
    });

    test('returns parsed data with trimmed text on a valid payload', () {
      final payload = json.encode({
        'type': 'activity',
        'sessionId': 'session-42',
      });
      final result = parseReplyAction(
        payload: payload,
        input: '  hello agent  ',
      );
      expect(result, isNotNull);
      expect(result!.sessionId, 'session-42');
      expect(result.text, 'hello agent');
      expect(result.permissionId, isNull);
    });

    test('captures permissionId for permission notifications', () {
      final payload = json.encode({
        'type': 'permission',
        'sessionId': 's1',
        'permissionId': 'perm-99',
      });
      final result = parseReplyAction(payload: payload, input: 'no');
      expect(result, isNotNull);
      expect(result!.permissionId, 'perm-99');
    });

    test(
      'each invocation produces an independent InlineReplyData '
      '— the only id created downstream comes from sync, not the parser',
      () {
        // The parser must NOT invent an id of its own; the canonical
        // localId is created exactly once by Sync.sendMessage. This test
        // pins that invariant: parseReplyAction never carries a localId
        // field, even when called many times for the same payload.
        final payload = json.encode({'sessionId': 's1'});
        final a = parseReplyAction(payload: payload, input: 'hello');
        final b = parseReplyAction(payload: payload, input: 'hello');
        expect(a, isNotNull);
        expect(b, isNotNull);
        // Same content but distinct instances — neither owns an id.
        expect(identical(a, b), isFalse);
        expect(a!.sessionId, b!.sessionId);
        expect(a.text, b.text);
        // Sanity: the type has no public "localId" surface to leak.
        expect(
          a.toString().contains('localId'),
          isFalse,
          reason: 'parser must not invent an id',
        );
      },
    );
  });
}
