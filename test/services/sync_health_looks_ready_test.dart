// Pins send-path auto-restore gates. A live Codex process older than
// 2 minutes must still look ready, otherwise follow-up sends spawn a
// replacement and the conversation loses its thread history.

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

void main() {
  group('SyncHealth.looksReady', () {
    Session session({
      required String presence,
      required String lifecycle,
      int? lifecycleSince,
    }) {
      return Session(
        id: 'codex-live',
        seq: 1,
        createdAt: 0,
        updatedAt: 0,
        active: true,
        activeAt: 0,
        metadataVersion: 0,
        agentStateVersion: 0,
        thinking: false,
        presence: presence,
        lifecycleStateCleartext: lifecycle,
        metadata: Metadata(
          lifecycleState: lifecycle,
          lifecycleStateSince: lifecycleSince,
        ),
      );
    }

    test('running + online + stale lifecycle still looks ready', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final health = SyncHealth(
        session: session(
          presence: 'online',
          lifecycle: 'running',
          // Spawned 10 minutes ago — past the 2 minute lcRecent window.
          lifecycleSince: now - 10 * 60 * 1000,
        ),
        sessionSpawnedAt: const {},
        // Missed keep-alives: ephemeral older than 2 minutes.
        lastEphemeralAt: {'codex-live': now - 10 * 60 * 1000},
      );

      expect(
        health.looksReady,
        isTrue,
        reason:
            'A live running session must not auto-restore just because '
            'lifecycleStateSince and ephemeral keep-alives are stale. '
            'Replacement spawn starts a new Codex thread and drops history.',
      );
    });

    test('running + offline + stale lifecycle does not look ready', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final health = SyncHealth(
        session: session(
          presence: 'offline',
          lifecycle: 'running',
          lifecycleSince: now - 10 * 60 * 1000,
        ),
        sessionSpawnedAt: const {},
        lastEphemeralAt: const {},
      );

      expect(
        health.looksReady,
        isFalse,
        reason:
            'A crashed agent that never flipped lifecycle still needs '
            'auto-restore once presence has gone offline.',
      );
    });

    test('archived sessions never look ready', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final health = SyncHealth(
        session: session(
          presence: 'online',
          lifecycle: 'archived',
          lifecycleSince: now,
        ),
        sessionSpawnedAt: const {},
        lastEphemeralAt: {'codex-live': now},
      );

      expect(health.looksReady, isFalse);
    });
  });
}
