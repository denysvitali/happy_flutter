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
      final ids = <String>{};
      for (var i = 0; i < taps; i++) {
        final id = sync.createLocalMessageId();
        expect(id, isNotEmpty);
        ids.add(id);
      }
      expect(
        ids.length,
        taps,
        reason:
            'each inline-reply tap must produce a distinct localId — '
            'identical "continue"-style replies must not collapse '
            'to one logical message',
      );
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
}
