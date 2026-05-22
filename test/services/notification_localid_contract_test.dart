import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

/// Contract: an inline-reply received from a notification must produce
/// exactly one canonical `localId` for the resulting message — no extra
/// id is invented at the notification layer, and no id is reused between
/// two distinct notification taps.
///
/// The notification layer routes inline replies through
/// [Sync.sendMessage] without supplying a `clientLocalId`, which means
/// the canonical id is whatever [Sync.createLocalMessageId] returns for
/// that single call. This test pins that invariant by checking the
/// id-creation surface directly.
void main() {
  late Sync sync;

  setUp(() {
    sync = createTestSync();
  });

  test(
    'createLocalMessageId returns a unique id per notification reply tap',
    () {
      // Each "tap" of the inline-reply action triggers exactly one
      // call into Sync.sendMessage, which calls createLocalMessageId
      // exactly once. So we should never see two equal ids in a row.
      const taps = 25;
      final orderedIds = <String>[];
      for (var i = 0; i < taps; i++) {
        final id = sync.createLocalMessageId();
        // Strengthen: every id must be a non-empty string.
        expect(id, isA<String>());
        expect(id, isNotEmpty);
        orderedIds.add(id);
      }
      // Original assertion: 25 taps → 25 entries observed.
      expect(orderedIds.length, taps);
      // Stronger identity invariant: distinct across all 25 taps.
      // Set length must equal tap count — no localId may collide.
      expect(
        orderedIds.toSet().length,
        taps,
        reason:
            'each inline-reply tap must produce a distinct localId — '
            'identical "continue"-style replies must not collapse '
            'to one logical message',
      );
    },
  );

  test(
    'createLocalMessageId matches the canonical fallback or UUID format',
    () {
      // The canonical generator (see `_sync_messaging_send.dart`) returns
      //  - `encryption.generateId()` → uuid v4 when encryption is wired
      //  - else `'${microsecondsSinceEpoch}-${randomInt32}'` (fallback)
      //
      // `createTestSync()` does not wire encryption, so the fallback path
      // is exercised here. Pin its shape so the canonical id-generator
      // contract cannot drift silently.
      final fallbackPattern = RegExp(r'^\d+-\d+$');
      final uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      for (var i = 0; i < 10; i++) {
        final id = sync.createLocalMessageId();
        final matchesFallback = fallbackPattern.hasMatch(id);
        final matchesUuid = uuidPattern.hasMatch(id);
        expect(
          matchesFallback || matchesUuid,
          isTrue,
          reason:
              'localId "$id" must match either the UUID v4 format or the '
              'fallback "<microseconds>-<random>" format — the canonical '
              'generator contract',
        );
      }
    },
  );

  test(
    'repeated identical inline replies (e.g. "ok") produce distinct ids',
    () {
      // Tighter version of the above for the specific case the
      // ROADMAP P0 invariant calls out: repeated text like
      // "continue"/"ok" is never an identity.
      final a = sync.createLocalMessageId();
      final b = sync.createLocalMessageId();
      expect(a, isNot(equals(b)));
    },
  );

  test(
    'each localId survives intact through optimistic insert and merge',
    () {
      // Simulates the canonical pipeline for a single notification tap:
      //   1. createLocalMessageId() mints a canonical id
      //   2. optimistic placeholder is inserted with that id
      //   3. server ack arrives carrying the same localId and the
      //      authoritative server id
      //   4. merge replaces the placeholder, never the localId
      //
      // The contract: each user tap's localId must be observable in the
      // final post-merge state (on the server record's `localId` field).
      const sessionId = 'notif-pipeline-1';
      const taps = 5;

      sync.testSetSessionMessages(sessionId, []);

      final mintedIds = <String>[];
      for (var i = 0; i < taps; i++) {
        final localId = sync.createLocalMessageId();
        mintedIds.add(localId);

        // Optimistic insert (mirrors `_sync_messaging_send.dart`).
        sync.testUpsertSessionMessages(sessionId, [
          {
            'id': localId,
            'localId': localId,
            'seq': 0,
            'role': 'user',
            'kind': 'text',
            'content': 'continue',
            'createdAt': 1700000000000 + i,
            'sendStatus': 'sending',
          },
        ]);

        // Server ack — same localId, new authoritative server id.
        sync.testUpsertSessionMessages(sessionId, [
          {
            'id': 'srv-$i',
            'localId': localId,
            'seq': 100 + i,
            'role': 'user',
            'kind': 'text',
            'content': 'continue',
            'createdAt': 1700000000000 + i,
            'sendStatus': 'sent',
          },
        ]);
      }

      // Distinct localIds — no collapse.
      expect(
        mintedIds.toSet().length,
        taps,
        reason: '$taps taps must mint $taps distinct localIds',
      );

      final msgs = sync.testSessionMessages(sessionId);
      expect(msgs, isNotNull);
      final observedLocalIds = msgs!
          .map((m) => m['localId'] as String?)
          .whereType<String>()
          .toSet();
      // Every minted id must be visible post-merge — none was lost,
      // none was rewritten by the merge layer.
      for (final id in mintedIds) {
        expect(
          observedLocalIds.contains(id),
          isTrue,
          reason:
              'localId "$id" minted at notification tap must survive '
              'through optimistic insert and server-ack merge',
        );
      }
      // And no orphan optimistic rows should remain.
      final stillSending = msgs
          .where((m) => m['sendStatus'] == 'sending')
          .toList();
      expect(
        stillSending,
        isEmpty,
        reason: 'All optimistic placeholders must be replaced by acks',
      );
    },
  );
}
