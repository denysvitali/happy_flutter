import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/types/identity_types.dart';
import 'package:happy_flutter/core/types/message_state.dart';

void main() {
  group('LocalId / ServerMessageId / SessionId', () {
    test('wrap a string with zero runtime cost', () {
      const id = LocalId('abc');
      expect(id.value, 'abc');
      expect(id.isNotEmpty, true);
      expect(id.isEmpty, false);
    });

    test('empty sentinel is detectable', () {
      const id = LocalId('');
      expect(id.isEmpty, true);
      expect(id.isNotEmpty, false);
    });

    test('extension types compare structurally', () {
      const a = LocalId('x');
      const b = LocalId('x');
      const c = LocalId('y');
      expect(a, b);
      expect(a == c, false);
    });

    test('different id kinds are distinct types', () {
      // This test doesn't assert — its purpose is to ensure the
      // assignments compile. If LocalId were an alias for String the
      // compiler would silently allow mixing them.
      LocalId fromLocal(LocalId id) => id;
      ServerMessageId fromServer(ServerMessageId id) => id;
      SessionId fromSession(SessionId id) => id;

      const local = LocalId('l');
      const server = ServerMessageId('s');
      const session = SessionId('sess');

      expect(fromLocal(local).value, 'l');
      expect(fromServer(server).value, 's');
      expect(fromSession(session).value, 'sess');
    });
  });

  group('MessageMapIdentity helpers', () {
    test('reads localId and id from a loose map', () {
      final map = <String, dynamic>{
        'id': 'srv-1',
        'localId': 'lcl-1',
        'role': 'user',
      };
      expect(map.localIdOrNull, const LocalId('lcl-1'));
      expect(map.serverIdOrNull, const ServerMessageId('srv-1'));
    });

    test('returns null for absent fields', () {
      final map = <String, dynamic>{'role': 'agent'};
      expect(map.localIdOrNull, isNull);
      expect(map.serverIdOrNull, isNull);
    });
  });

  group('MessageSendState', () {
    test('round-trips through wire string', () {
      for (final raw in ['sending', 'pending', 'failed', 'sent']) {
        final state = MessageSendState.fromWireString(raw);
        expect(state.wireString, raw);
      }
    });

    test('null and unknown map to MessageSent', () {
      expect(MessageSendState.fromWireString(null), isA<MessageSent>());
      expect(MessageSendState.fromWireString('garbage'), isA<MessageSent>());
    });

    test('exhaustive switch compiles', () {
      // The whole point of a sealed hierarchy is that this switch is
      // exhaustive. If a new variant is added without updating this
      // test, the compiler will complain about a missing case.
      String describe(MessageSendState state) {
        return switch (state) {
          MessageSending() => 'sending',
          MessagePending() => 'pending',
          MessageFailed() => 'failed',
          MessageSent() => 'sent',
        };
      }

      expect(describe(const MessageSending()), 'sending');
      expect(describe(const MessagePending()), 'pending');
      expect(describe(const MessageFailed()), 'failed');
      expect(describe(const MessageSent()), 'sent');
    });
  });

  group('MessageIdentity', () {
    test('extracts both ids from a map', () {
      final identity = MessageIdentity.fromMap({
        'id': 'srv-1',
        'localId': 'lcl-1',
      });
      expect(identity.serverId, const ServerMessageId('srv-1'));
      expect(identity.localId, const LocalId('lcl-1'));
      expect(identity.hasLocalId, true);
    });

    test('hasLocalId is false for empty/null localId', () {
      final empty = MessageIdentity.fromMap({'id': 'srv', 'localId': ''});
      expect(empty.hasLocalId, false);

      final missing = MessageIdentity.fromMap({'id': 'srv'});
      expect(missing.hasLocalId, false);
    });
  });
}
