import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/loop.dart';

void main() {
  group('Loop', () {
    test('serializes and deserializes all fields', () {
      final original = Loop(
        id: 'abc12345',
        sessionId: 's1',
        expression: '*/5 * * * *',
        prompt: 'check the deploy',
        recurring: true,
        createdAt: 1700000000000,
        expiresAt: 1700604800000,
        lastFiredAt: 1700000060000,
        fireCount: 7,
        paused: false,
      );

      final json = original.toJson();
      final restored = Loop.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.sessionId, original.sessionId);
      expect(restored.expression, original.expression);
      expect(restored.prompt, original.prompt);
      expect(restored.recurring, original.recurring);
      expect(restored.createdAt, original.createdAt);
      expect(restored.expiresAt, original.expiresAt);
      expect(restored.lastFiredAt, original.lastFiredAt);
      expect(restored.fireCount, original.fireCount);
      expect(restored.paused, original.paused);
    });

    test('fromJson defaults recurring, fireCount, and paused when omitted', () {
      final loop = Loop.fromJson(<String, dynamic>{
        'id': 'id1234ab',
        'sessionId': 's1',
        'expression': '0 9 * * *',
        'prompt': 'daily standup',
        'createdAt': 1,
        'expiresAt': 2,
      });
      expect(loop.recurring, isTrue);
      expect(loop.fireCount, 0);
      expect(loop.paused, isFalse);
      expect(loop.lastFiredAt, isNull);
    });

    test('lastFiredAt omitted from toJson when null', () {
      final loop = Loop(
        id: 'id1234ab',
        sessionId: 's1',
        expression: '* * * * *',
        prompt: 'p',
        recurring: false,
        createdAt: 1,
        expiresAt: 2,
      );
      final json = loop.toJson();
      expect(json.containsKey('lastFiredAt'), isFalse);
    });

    test('copyWith updates individual fields without mutating others', () {
      final loop = Loop(
        id: 'id1234ab',
        sessionId: 's1',
        expression: '* * * * *',
        prompt: 'p',
        recurring: true,
        createdAt: 100,
        expiresAt: 200,
        lastFiredAt: 150,
      );
      final updated = loop.copyWith(paused: true, fireCount: 3);
      expect(updated.id, loop.id);
      expect(updated.paused, isTrue);
      expect(updated.fireCount, 3);
      expect(updated.lastFiredAt, loop.lastFiredAt);
      expect(updated.expression, loop.expression);
    });

    test('copyWith clearLastFiredAt removes the field', () {
      final loop = Loop(
        id: 'id1234ab',
        sessionId: 's1',
        expression: '* * * * *',
        prompt: 'p',
        recurring: true,
        createdAt: 100,
        expiresAt: 200,
        lastFiredAt: 150,
      );
      final cleared = loop.copyWith(clearLastFiredAt: true);
      expect(cleared.lastFiredAt, isNull);
      expect(cleared.toJson().containsKey('lastFiredAt'), isFalse);
    });

    test('isExpired returns true when nowMs >= expiresAt', () {
      final loop = Loop(
        id: 'id1234ab',
        sessionId: 's1',
        expression: '* * * * *',
        prompt: 'p',
        recurring: true,
        createdAt: 100,
        expiresAt: 200,
      );
      expect(loop.isExpired(nowMs: 200), isTrue);
      expect(loop.isExpired(nowMs: 199), isFalse);
    });

    test('round-trip through JSON stays byte-stable for default fields', () {
      final loop = Loop(
        id: '12345678',
        sessionId: 's1',
        expression: '*/5 * * * *',
        prompt: 'check the deploy',
        recurring: true,
        createdAt: 1700000000000,
        expiresAt: 1700604800000,
        fireCount: 3,
      );
      final json = loop.toJson();
      // Recurring true / paused false / fireCount 3 — all defaults except
      // the explicit values we set above.
      expect(json['recurring'], isTrue);
      expect(json['paused'], isFalse);
      expect(json['fireCount'], 3);
      expect(json['id'], '12345678');
      // Re-decode and ensure the cycle is stable.
      final restored = Loop.fromJson(json).toJson();
      expect(restored, equals(json));
    });
  });
}
