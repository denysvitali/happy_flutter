import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/wire/message_envelope.dart';

void main() {
  group('MessageEnvelope (proto3-compatible wire format)', () {
    test('encode -> decode roundtrips', () {
      const e = MessageEnvelope(
        serverId: 'srv-1',
        localId: 'local-2',
        seq: 42,
        role: 'user',
        content: 'continue',
        createdAt: 1730000000000,
      );
      final back = MessageEnvelope.decode(e.encode());
      expect(back.serverId, e.serverId);
      expect(back.localId, e.localId);
      expect(back.seq, e.seq);
      expect(back.role, e.role);
      expect(back.content, e.content);
      expect(back.createdAt, e.createdAt);
    });

    test('default values omit fields on the wire', () {
      const e = MessageEnvelope();
      expect(e.encode(), isEmpty);
      final back = MessageEnvelope.decode(e.encode());
      expect(back.serverId, '');
      expect(back.seq, 0);
    });

    test('encodeJsonShim mirrors legacy JSON wire shape', () {
      const e = MessageEnvelope(
        localId: 'L1',
        role: 'user',
        content: 'hi',
      );
      final json = e.encodeJsonShim();
      expect(json['localId'], 'L1');
      expect(json['role'], 'user');
      expect((json['content']! as Map)['c'], 'hi');
    });

    test('large seq + content survive varint encoding', () {
      final e = MessageEnvelope(
        seq: 123456789,
        content: 'a' * 300,
      );
      final back = MessageEnvelope.decode(e.encode());
      expect(back.seq, 123456789);
      expect(back.content.length, 300);
    });
  });
}
