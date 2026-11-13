import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/sessions_api.dart';
import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:riverpod/riverpod.dart';

import '../../features/loops/loop_notifier_test_helpers.dart';

Session _session(String id) => Session(
  id: id,
  seq: 1,
  createdAt: 1,
  updatedAt: 1,
  active: false,
  activeAt: 1,
  metadataVersion: 1,
  agentStateVersion: 0,
  thinking: false,
  metadata: Metadata(path: '/repo/$id', host: 'mac'),
);

class _StubSessions extends SessionsNotifier {
  _StubSessions(this.calls);

  final List<String> calls;
  Completer<bool>? deleteReply;
  Object? archiveError;

  @override
  Map<String, Session> build() => SessionCollectionSnapshot(const {});

  @override
  void loadFromSync() => calls.add('load');

  @override
  void hideArchived(String id) => calls.add('hide:$id');

  @override
  void unhideArchived(String id) => calls.add('unhide:$id');

  @override
  Future<void> markSessionArchived(String id, bool archived) async {
    calls.add('archive-local:$id');
    if (archiveError case final error?) throw error;
  }

  @override
  Future<bool> optimisticDelete(String id) {
    calls.add('delete:$id');
    return (deleteReply ??= Completer<bool>()).future;
  }
}

class _StubApi extends SessionsApi {
  _StubApi(this.calls);
  final List<String> calls;

  @override
  Future<void> setSessionArchived(String sessionId, bool archived) async {
    calls.add('archive-server:$sessionId');
  }
}

class _PublishingLoops extends StubLoopsNotifier {
  _PublishingLoops({super.initial, super.actionCalls, super.deleteCalls});

  void publish(Map<String, List<Loop>> loops) => state = loops;
}

void main() {
  group('SessionOperationsNotifier', () {
    late List<String> calls;
    late _StubSessions sessions;
    late ProviderContainer container;

    SessionOperationsNotifier store() =>
        container.read(sessionOperationsNotifierProvider.notifier);
    Map<String, SessionOperation> ops() =>
        container.read(sessionOperationsNotifierProvider);

    setUp(() {
      calls = [];
      sessions = _StubSessions(calls);
      container = ProviderContainer(
        overrides: [
          sessionsNotifierProvider.overrideWith(() => sessions),
          sessionsApiProvider.overrideWithValue(_StubApi(calls)),
        ],
      );
    });
    tearDown(() => container.dispose());

    test('archive hides at once, then archives and drops the record', () async {
      expect(store().archive(_session('a')), isTrue);
      // Hidden synchronously, before anything reached the server.
      expect(calls.first, 'hide:a');
      expect(ops()['a']!.isPending, isTrue);

      await pumpEventQueue();
      expect(calls, ['hide:a', 'archive-local:a', 'archive-server:a', 'load']);
      expect(ops(), isEmpty);
    });

    test('a failed archive restores the row and keeps the failure', () async {
      sessions.archiveError = StateError('pod pause failed');
      store().archive(_session('a'));
      await pumpEventQueue();

      expect(calls, ['hide:a', 'archive-local:a', 'unhide:a']);
      expect(ops()['a']!.isFailed, isTrue);
      expect(ops()['a']!.error, contains('pod pause failed'));

      sessions.archiveError = null;
      expect(store().retry('a'), isTrue);
      await pumpEventQueue();
      expect(ops(), isEmpty);
    });

    test('delete does not block and reports a server rejection', () async {
      expect(store().delete('a'), isTrue);
      expect(calls, ['delete:a']);
      expect(ops()['a']!.isPending, isTrue);
      // A second delete of the same row is ignored while one is in flight.
      expect(store().delete('a'), isFalse);

      sessions.deleteReply!.complete(false);
      await pumpEventQueue();
      expect(ops()['a']!.isFailed, isTrue);

      store().dismiss('a');
      expect(ops(), isEmpty);
    });
  });

  group('LoopOperationsNotifier', () {
    late List<String> actionCalls;
    late List<String> deleteCalls;
    late _PublishingLoops loops;
    late ProviderContainer container;

    LoopOperationsNotifier store() =>
        container.read(loopOperationsNotifierProvider.notifier);

    setUp(() {
      actionCalls = [];
      deleteCalls = [];
      loops = _PublishingLoops(
        initial: {
          's1': [testLoop(id: 'l1'), testLoop(id: 'l2')],
        },
        actionCalls: actionCalls,
        deleteCalls: deleteCalls,
      );
      container = ProviderContainer(
        overrides: [loopsNotifierProvider.overrideWith(() => loops)],
      );
      // Instantiate the store so it listens to loop updates.
      container.listen(loopOperationsNotifierProvider, (_, _) {});
    });
    tearDown(() => container.dispose());

    List<Loop> visible() => applyLoopOperations(
      container.read(loopsNotifierProvider)['s1']!,
      container.read(loopOperationsNotifierProvider),
    );

    test('lists show the requested state before the daemon answers', () {
      store().submit(
        const LoopRequest(
          sessionId: 's1',
          loopId: 'l1',
          action: LoopOperationAction.delete,
        ),
      );
      store().submit(
        const LoopRequest(
          sessionId: 's1',
          loopId: 'l2',
          action: LoopOperationAction.pause,
        ),
      );
      final shown = visible();
      expect(shown.map((loop) => loop.id), ['l2']);
      expect(shown.single.paused, isTrue);
    });

    test('a daemon update confirms the operation and clears it', () async {
      store().submit(
        const LoopRequest(
          sessionId: 's1',
          loopId: 'l1',
          action: LoopOperationAction.delete,
        ),
      );
      final settled = await store().whenSettled('s1/l1');
      expect(settled!.isSucceeded, isTrue);
      expect(deleteCalls, ['s1:l1']);
      // Still hidden until the daemon's loop list drops it.
      expect(container.read(loopOperationsNotifierProvider), contains('s1/l1'));

      loops.publish({
        's1': [testLoop(id: 'l2')],
      });
      expect(container.read(loopOperationsNotifierProvider), isEmpty);
    });

    test('a failed operation stops overlaying and keeps its cause', () async {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          loopsNotifierProvider.overrideWith(
            () => StubLoopsNotifier(
              initial: {
                's1': [testLoop(id: 'l1')],
              },
              pauseError: ArgumentError('daemon down'),
            ),
          ),
        ],
      );
      store().submit(
        const LoopRequest(
          sessionId: 's1',
          loopId: 'l1',
          action: LoopOperationAction.pause,
        ),
      );
      final settled = await store().whenSettled('s1/l1');
      expect(settled!.isFailed, isTrue);
      expect(settled.cause, isA<ArgumentError>());
      expect(visible().single.paused, isFalse);
    });
  });
}
