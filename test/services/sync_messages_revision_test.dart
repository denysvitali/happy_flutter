// Contract tests for the per-session message revision counter.
//
// Disappearing-message bug: ChatScreen decided whether to rebuild using a
// tail-of-5 fingerprint plus identical() on a cached unmodifiable view.
// In-place edits to messages OUTSIDE that tail (e.g. a tool-call gaining a
// result mid-thread) produced an identical fingerprint, so the UI silently
// early-returned and the change never rendered — the message appeared to
// go stale / disappear.
//
// Fix: Sync bumps a monotonic per-session revision on every real
// message-list change, funnelled through the single
// _notifySessionMessagesChanged call. The chat UI rebuilds whenever the
// revision moves, independent of the fingerprint heuristic.
//
// See: lib/core/services/sync_service.dart (messagesRevision),
//      lib/core/services/_sync_socket.dart (_notifySessionMessagesChanged),
//      lib/features/chat/chat_screen.dart (_refreshFromSync).

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('Sync messagesRevision contract', () {
    late Sync instance;

    setUp(() {
      instance = createTestSync();
    });

    test('unknown session starts at revision 0', () {
      expect(instance.messagesRevision('never-seen'), 0);
    });

    test('every message-change notification bumps the revision', () {
      const id = 'sess-rev-bump';
      expect(instance.messagesRevision(id), 0);

      instance.testNotifySessionMessagesChanged(id);
      expect(instance.messagesRevision(id), 1);

      instance.testNotifySessionMessagesChanged(id);
      expect(instance.messagesRevision(id), 2);
    });

    test('revision is tracked independently per session', () {
      instance.testNotifySessionMessagesChanged('sess-rev-a');
      instance.testNotifySessionMessagesChanged('sess-rev-a');
      instance.testNotifySessionMessagesChanged('sess-rev-b');

      expect(instance.messagesRevision('sess-rev-a'), 2);
      expect(instance.messagesRevision('sess-rev-b'), 1);
      expect(instance.messagesRevision('sess-rev-c'), 0);
    });

    test(
      'revision has already advanced when onSessionMessagesChanged fires '
      '— a UI refresh can never observe a stale revision',
      () async {
        const id = 'sess-rev-emit';
        final revisionsAtEmit = <int>[];
        final sub = instance.onSessionMessagesChanged
            .where((s) => s == id)
            .listen(
              (_) => revisionsAtEmit.add(instance.messagesRevision(id)),
            );

        instance.testNotifySessionMessagesChanged(id);
        // Broadcast streams deliver on microtasks; let the queue drain.
        await Future<void>.delayed(const Duration(milliseconds: 5));

        expect(
          revisionsAtEmit,
          isNotEmpty,
          reason: 'a real change must wake onSessionMessagesChanged',
        );
        expect(
          revisionsAtEmit.first,
          greaterThanOrEqualTo(1),
          reason: 'the revision must move before/with the emit, otherwise '
              '_refreshFromSync early-returns and the change disappears',
        );

        await sub.cancel();
      },
    );
  });
}
