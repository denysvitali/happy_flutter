import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';

// Prometheus showed 13 connects against 12 disconnects on a single device —
// every socket died — but `websocket.disconnect` spans carried no reason, so a
// server eviction and a backgrounded radio were indistinguishable. The reason
// is now normalized onto the span; keep the facet set bounded, because an
// unbounded label space is how a useful attribute becomes an unusable one.
void main() {
  group('DisconnectReason.normalize', () {
    test('maps every Socket.IO reason to a stable facet', () {
      expect(
        DisconnectReason.normalize('io server disconnect'),
        DisconnectReason.ioServerDisconnect,
      );
      expect(
        DisconnectReason.normalize('io client disconnect'),
        DisconnectReason.ioClientDisconnect,
      );
      expect(
        DisconnectReason.normalize('ping timeout'),
        DisconnectReason.pingTimeout,
      );
      expect(
        DisconnectReason.normalize('transport close'),
        DisconnectReason.transportClose,
      );
      expect(
        DisconnectReason.normalize('transport error'),
        DisconnectReason.transportError,
      );
      expect(
        DisconnectReason.normalize('parse error'),
        DisconnectReason.parseError,
      );
    });

    test('is case and whitespace insensitive', () {
      expect(
        DisconnectReason.normalize('  Ping Timeout '),
        DisconnectReason.pingTimeout,
      );
    });

    test('collapses unrecognised payloads instead of leaking cardinality', () {
      expect(
        DisconnectReason.normalize('session c0ed2896d2e0 evicted'),
        DisconnectReason.other,
      );
      expect(DisconnectReason.normalize(42), DisconnectReason.other);
    });

    test('distinguishes "no payload" from "unrecognised payload"', () {
      expect(DisconnectReason.normalize(null), DisconnectReason.unknown);
      expect(DisconnectReason.normalize(''), DisconnectReason.unknown);
      expect(DisconnectReason.normalize('null'), DisconnectReason.unknown);
    });
  });
}
