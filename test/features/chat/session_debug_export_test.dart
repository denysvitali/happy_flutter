import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/features/chat/session_debug_export.dart';

void main() {
  test(
    'metadata-only export hashes identifiers and omits private metadata',
    () {
      const rawSessionId = 'c948d14cf2c6fc0573379cbb1';
      const rawPath = '/home/alice/private-project';
      final session = Session(
        id: rawSessionId,
        seq: 1,
        createdAt: 1,
        updatedAt: 2,
        active: true,
        activeAt: 2,
        metadataVersion: 1,
        agentStateVersion: 1,
        thinking: false,
        metadata: const Metadata(
          host: 'alice-laptop',
          path: rawPath,
          machineId: 'private-machine-id',
        ),
      );

      final encoded = buildSessionDebugExportText(session);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(encoded, isNot(contains(rawSessionId)));
      expect(encoded, isNot(contains(rawPath)));
      expect(encoded, isNot(contains('alice-laptop')));
      expect(encoded, isNot(contains('private-machine-id')));
      expect(decoded['sessionFingerprint'], isA<String>());
      expect(decoded['sessionFingerprint'] as String, hasLength(16));
      expect(decoded.containsKey('sessionId'), isFalse);
    },
  );
}
