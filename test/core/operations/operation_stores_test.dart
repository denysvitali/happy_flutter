import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/sessions_api.dart';
import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/mcp_server.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';
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

Machine _machine(String id) => Machine(
  id: id,
  seq: 1,
  createdAt: 1,
  updatedAt: 1,
  active: true,
  activeAt: 1,
  metadataVersion: 1,
  daemonStateVersion: 1,
);

class _StubMachines extends MachinesNotifier {
  @override
  Map<String, Machine> build() => {'m1': _machine('m1'), 'm2': _machine('m2')};

  @override
  void loadFromSync() {}
}

class _StubPermissions extends PermissionsNotifier {
  final replies = <Completer<PermissionResponse>>[];

  Future<PermissionResponse> _next() {
    final reply = Completer<PermissionResponse>();
    replies.add(reply);
    return reply.future;
  }

  @override
  Future<PermissionResponse> allow(
    String sessionId,
    String permissionId, {
    String? mode,
    List<String>? allowTools,
    String? decision,
    Map<String, dynamic>? updatedInput,
  }) => _next();

  @override
  Future<PermissionResponse> deny(
    String sessionId,
    String permissionId, {
    String? decision,
  }) => _next();
}

const _search = McpServer(
  name: 'search',
  scope: McpServerScope.user,
  transport: McpTransport.stdio,
);

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

  group('MachineOperationsNotifier', () {
    test(
      'a deleting machine leaves the list until the server answers',
      () async {
        final reply = Completer<int?>();
        final container = ProviderContainer(
          overrides: [
            machinesNotifierProvider.overrideWith(_StubMachines.new),
            machineDeleteRunnerProvider.overrideWithValue((_) => reply.future),
          ],
        );
        addTearDown(container.dispose);
        List<String> listed() =>
            container.read(machinesListProvider).map((m) => m.id).toList();

        container.read(machineOperationsNotifierProvider.notifier).delete('m1');
        expect(listed(), ['m2']);

        reply.complete(503);
        await pumpEventQueue();
        // Refused: the machine is back and the failure keeps its status.
        expect(listed(), unorderedEquals(['m1', 'm2']));
        final failed = container.read(machineOperationsNotifierProvider)['m1']!;
        expect(failed.isFailed, isTrue);
        expect(failed.error, '503');
      },
    );

    test('a confirmed delete removes the machine for good', () async {
      final container = ProviderContainer(
        overrides: [
          machinesNotifierProvider.overrideWith(_StubMachines.new),
          machineDeleteRunnerProvider.overrideWithValue((_) async => null),
        ],
      );
      addTearDown(container.dispose);
      container.read(machineOperationsNotifierProvider.notifier).delete('m1');
      await pumpEventQueue();
      expect(container.read(machinesNotifierProvider).keys, ['m2']);
      expect(container.read(machineOperationsNotifierProvider), isEmpty);
    });
  });

  group('PermissionOperationsNotifier', () {
    test('a decision counts as answered while it syncs', () async {
      final permissions = _StubPermissions();
      final container = ProviderContainer(
        overrides: [
          permissionsNotifierProvider.overrideWith(() => permissions),
        ],
      );
      addTearDown(container.dispose);
      bool? decided(String id) => decidedPermission(
        container.read(permissionOperationsNotifierProvider),
        's1',
        id,
      );
      final store = container.read(
        permissionOperationsNotifierProvider.notifier,
      );

      store.submit(
        const PermissionDecision(
          sessionId: 's1',
          permissionId: 'p1',
          allow: true,
        ),
      );
      store.submit(
        const PermissionDecision(
          sessionId: 's1',
          permissionId: 'p2',
          allow: false,
        ),
      );
      expect(decided('p1'), isTrue);
      expect(decided('p2'), isFalse);
      expect(decided('p3'), isNull);

      permissions.replies[0].complete(
        const PermissionResponse(success: true, scope: 'once'),
      );
      permissions.replies[1].complete(
        const PermissionResponse(success: false, error: 'expired'),
      );
      await pumpEventQueue();
      // Applied stays answered; a refusal returns the request to pending.
      expect(decided('p1'), isTrue);
      expect(
        container.read(permissionOperationsNotifierProvider)['s1/p1']!.receipt,
        isNotNull,
      );
      expect(decided('p2'), isNull);
      expect(
        container.read(permissionOperationsNotifierProvider)['s1/p2']!.error,
        'expired',
      );
    });
  });

  group('McpOperationsNotifier', () {
    test(
      'lists show the change at once; a refusal keeps the response',
      () async {
        final reply = Completer<McpConfigResponse>();
        final container = ProviderContainer(
          overrides: [
            mcpChangeRunnerProvider.overrideWithValue((_) => reply.future),
          ],
        );
        addTearDown(container.dispose);
        final store = container.read(mcpOperationsNotifierProvider.notifier);
        store.submit(
          const McpRequest(
            machineId: 'm1',
            server: _search,
            action: McpOperationAction.disable,
          ),
        );
        final ops = container.read(mcpOperationsNotifierProvider);
        expect(
          applyMcpOperations('m1', const [_search], ops).single.enabled,
          isFalse,
        );
        // Another machine's identical server is untouched.
        expect(
          applyMcpOperations('m2', const [_search], ops).single.enabled,
          isTrue,
        );

        reply.complete(const McpConfigResponse(success: false));
        final settled = await store.whenSettled(mcpOperationKey('m1', _search));
        expect(settled!.isFailed, isTrue);
        expect(settled.cause, isA<McpOperationFailed>());
        expect(
          applyMcpOperations('m1', const [
            _search,
          ], container.read(mcpOperationsNotifierProvider)).single.enabled,
          isTrue,
        );
      },
    );
  });
}
