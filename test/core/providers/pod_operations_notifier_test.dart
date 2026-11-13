import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/pod_operations_notifier.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';
import 'package:riverpod/riverpod.dart';

const _ok = SessionPodActionResponse(success: true, message: '');

void main() {
  late List<Completer<SessionPodActionResponse>> replies;
  late List<String> sent;
  late ProviderContainer container;

  PodOperationsNotifier notifier() =>
      container.read(podOperationsNotifierProvider.notifier);
  Map<String, PodOperation> ops() =>
      container.read(podOperationsNotifierProvider);

  setUp(() {
    replies = [];
    sent = [];
    container = ProviderContainer(
      overrides: [
        podActionRunnerProvider.overrideWithValue((machineId, sessionId, a) {
          sent.add('$machineId/$sessionId/${a.name}');
          final reply = Completer<SessionPodActionResponse>();
          replies.add(reply);
          return reply.future;
        }),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('PodOperationsNotifier', () {
    test('submit records pending immediately and settles succeeded', () async {
      expect(
        notifier().submitAction(
          machineId: 'm',
          sessionId: 's',
          action: KubernetesPodAction.kill,
        ),
        isTrue,
      );
      expect(ops()['m/s']!.phase, OperationPhase.pending);
      expect(sent, ['m/s/kill']);

      replies.single.complete(_ok);
      await pumpEventQueue();
      expect(ops()['m/s']!.phase, OperationPhase.succeeded);
    });

    test('submit ignores a second action while one is pending', () async {
      notifier().submitAction(
        machineId: 'm',
        sessionId: 's',
        action: KubernetesPodAction.pause,
      );
      expect(
        notifier().submitAction(
          machineId: 'm',
          sessionId: 's',
          action: KubernetesPodAction.kill,
        ),
        isFalse,
      );
      expect(sent, ['m/s/pause']);
      expect(ops()['m/s']!.action, KubernetesPodAction.pause);
    });

    test(
      'a rejected or thrown action settles failed with its message',
      () async {
        notifier().submitAction(
          machineId: 'm',
          sessionId: 's',
          action: KubernetesPodAction.kill,
        );
        replies.single.complete(
          const SessionPodActionResponse(success: false, message: 'denied'),
        );
        await pumpEventQueue();
        expect(ops()['m/s']!.phase, OperationPhase.failed);
        expect(ops()['m/s']!.error, 'denied');

        expect(notifier().retry('m/s'), isTrue);
        expect(ops()['m/s']!.phase, OperationPhase.pending);
        replies.last.completeError(StateError('offline'));
        await pumpEventQueue();
        expect(ops()['m/s']!.phase, OperationPhase.failed);
        expect(ops()['m/s']!.error, contains('offline'));
        expect(sent, ['m/s/kill', 'm/s/kill']);
      },
    );

    test('dismiss forgets settled operations but not pending ones', () async {
      notifier().submitAction(
        machineId: 'm',
        sessionId: 's',
        action: KubernetesPodAction.kill,
      );
      notifier().dismiss('m/s');
      expect(ops(), contains('m/s'));
      replies.single.completeError(StateError('x'));
      await pumpEventQueue();
      notifier().dismiss('m/s');
      expect(ops(), isEmpty);
    });

    test('reconcile drops succeeded operations a report confirms', () async {
      for (final (session, action) in [
        ('kill', KubernetesPodAction.kill),
        ('pause', KubernetesPodAction.pause),
        ('resume', KubernetesPodAction.resume),
        ('away', KubernetesPodAction.kill),
      ]) {
        notifier().submitAction(
          machineId: 'm',
          sessionId: session,
          action: action,
        );
      }
      for (final reply in replies) {
        reply.complete(_ok);
      }
      await pumpEventQueue();

      // A stale report (taken before the daemon applied the actions)
      // confirms nothing.
      notifier().reconcile({
        'm/kill': SessionPodDisplayState.ready,
        'm/pause': SessionPodDisplayState.ready,
        'm/resume': SessionPodDisplayState.paused,
      });
      expect(
        ops().keys,
        unorderedEquals(['m/kill', 'm/pause', 'm/resume', 'm/away']),
      );

      notifier().reconcile({
        'm/kill': null,
        'm/pause': SessionPodDisplayState.paused,
        'm/resume': SessionPodDisplayState.scheduling,
      });
      // The unreachable daemon's operation keeps overlaying.
      expect(ops().keys, ['m/away']);
    });

    test('an unconfirmed success expires after the timeout', () {
      fakeAsync((async) {
        notifier().submitAction(
          machineId: 'm',
          sessionId: 's',
          action: KubernetesPodAction.pause,
        );
        replies.single.complete(_ok);
        async.flushMicrotasks();
        expect(ops()['m/s']!.isSucceeded, isTrue);
        async.elapse(notifier().confirmationTimeout);
        expect(ops(), isEmpty);
      });
    });

    test(
      'a superseded completion does not overwrite the newer record',
      () async {
        notifier().submitAction(
          machineId: 'm',
          sessionId: 's',
          action: KubernetesPodAction.pause,
        );
        replies.first.completeError(StateError('x'));
        await pumpEventQueue();
        notifier().submitAction(
          machineId: 'm',
          sessionId: 's',
          action: KubernetesPodAction.kill,
        );
        expect(ops()['m/s']!.action, KubernetesPodAction.kill);
        expect(ops()['m/s']!.isPending, isTrue);
      },
    );
  });

  group('PodOperation.isConfirmedBy', () {
    PodOperation op(KubernetesPodAction action) => PodOperation(
      id: 1,
      key: 'm/s',
      request: PodRequest(machineId: 'm', sessionId: 's', action: action),
      phase: OperationPhase.succeeded,
      submittedAtMs: 0,
    );

    test('matches each action to its target state', () {
      expect(op(KubernetesPodAction.kill).isConfirmedBy(null), isTrue);
      expect(
        op(
          KubernetesPodAction.kill,
        ).isConfirmedBy(SessionPodDisplayState.archived),
        isTrue,
      );
      expect(
        op(
          KubernetesPodAction.kill,
        ).isConfirmedBy(SessionPodDisplayState.ready),
        isFalse,
      );
      expect(
        op(
          KubernetesPodAction.pause,
        ).isConfirmedBy(SessionPodDisplayState.paused),
        isTrue,
      );
      expect(op(KubernetesPodAction.resume).isConfirmedBy(null), isFalse);
      expect(
        op(
          KubernetesPodAction.resume,
        ).isConfirmedBy(SessionPodDisplayState.ready),
        isTrue,
      );
    });
  });
}
