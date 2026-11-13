import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/session_operations_notifier.dart';
import 'package:happy_flutter/core/providers/session_ui_state_notifier.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';
import 'package:happy_flutter/features/kubernetes/kubernetes_pod_format.dart';
import 'package:happy_flutter/features/kubernetes/kubernetes_pod_state.dart';
import 'package:happy_flutter/features/kubernetes/kubernetes_pods_model.dart';
import 'package:happy_flutter/features/kubernetes/kubernetes_sessions_screen.dart';
import 'package:happy_flutter/features/kubernetes/kubernetes_sessions_strip.dart';
import 'package:happy_flutter/features/sessions/widgets/session_board_view.dart';
import 'package:happy_flutter/features/sessions/widgets/sessions_view_style.dart';

Session _session(
  String id, {
  int createdAt = 1,
  bool kubernetes = true,
  bool active = true,
  bool archived = false,
  String machineId = 'm1',
  String? lifecycle = 'running',
  String? podPhase,
  bool? podReady,
  bool? podPaused,
}) => Session(
  id: id,
  seq: 1,
  createdAt: createdAt,
  updatedAt: 1,
  active: active,
  activeAt: 1,
  metadataVersion: 1,
  agentStateVersion: 0,
  thinking: false,
  archived: archived,
  metadata: Metadata(
    path: '/workspace/$id',
    host: kubernetes ? 'happy-$id-7f9c' : 'devbox',
    machineId: machineId,
    runtimeKind: kubernetes ? 'kubernetes' : null,
    podName: kubernetes ? 'happy-$id' : null,
    namespace: kubernetes ? 'happy' : null,
    lifecycleState: lifecycle,
    podPhase: podPhase,
    podReady: podReady,
    podPaused: podPaused,
    summary: Summary(text: 'Session $id', updatedAt: 1),
  ),
);

SessionPod _pod(
  String sessionId, {
  String phase = 'Running',
  String reason = '',
  bool ready = true,
  bool paused = false,
  bool archived = false,
  bool metrics = false,
  int startedAtMs = 0,
  int restarts = 0,
}) => SessionPod(
  sessionId: sessionId,
  podName: 'happy-$sessionId',
  namespace: 'happy',
  status: '',
  phase: phase,
  reason: reason,
  message: '',
  ready: ready,
  paused: paused,
  archived: archived,
  repoUrl: 'https://github.com/acme/app',
  repoRef: 'main',
  startedAtMs: startedAtMs,
  nodeName: 'worker-1',
  restartCount: restarts,
  cpuLimitMillicores: 2000,
  memoryLimitBytes: 4 << 30,
  metricsAvailable: metrics,
  cpuUsageMillicores: metrics ? 250 : 0,
  memoryUsageBytes: metrics ? 512 << 20 : 0,
);

Machine _machine(
  String id, {
  bool kubernetes = true,
  bool online = true,
  int activeAt = 1000000,
}) => Machine(
  id: id,
  seq: 1,
  createdAt: 1,
  updatedAt: 1,
  active: online,
  activeAt: online ? activeAt : 0,
  metadataVersion: 1,
  daemonStateVersion: 1,
  metadata: MachineMetadata(
    host: id,
    spawnBackends: kubernetes ? const ['local', 'kubernetes'] : null,
  ),
);

class _StubSessions extends SessionsNotifier {
  _StubSessions(this.initial);

  final Map<String, Session> initial;

  @override
  Map<String, Session> build() => initial;
}

class _RecordingSessionOperations extends SessionOperationsNotifier {
  final archived = <String>[];

  @override
  bool archive(Session session) {
    archived.add(session.id);
    return true;
  }
}

class _StubMachines extends MachinesNotifier {
  _StubMachines(this.initial);

  final Map<String, Machine> initial;

  @override
  Map<String, Machine> build() => initial;
}

Widget _routerApp(Widget home) => MaterialApp.router(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  routerConfig: GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(
        path: '/chat/:sessionId',
        name: 'chat',
        builder: (_, state) =>
            Text('chat ${state.pathParameters['sessionId']}'),
      ),
      GoRoute(
        path: '/chat/:sessionId/info',
        name: 'session-info',
        builder: (_, state) =>
            Text('info ${state.pathParameters['sessionId']}'),
      ),
    ],
  ),
);

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  group('pod display state', () {
    test('a crash-looping pod reads as failed even when ready', () {
      expect(
        _pod('a', reason: 'CrashLoopBackOff').displayState,
        SessionPodDisplayState.failed,
      );
      expect(_pod('a').displayState, SessionPodDisplayState.ready);
      expect(
        _pod('a', phase: 'Pending', ready: false).displayState,
        SessionPodDisplayState.scheduling,
      );
      expect(
        _pod('a', paused: true).displayState,
        SessionPodDisplayState.paused,
      );
      expect(
        _pod('a', archived: true).displayState,
        SessionPodDisplayState.archived,
      );
    });
  });

  group('isLiveKubernetesSession', () {
    test('counts active pods, paused and failed pods only', () {
      expect(isLiveKubernetesSession(_session('a')), isTrue);
      expect(isLiveKubernetesSession(_session('a', kubernetes: false)), false);
      expect(isLiveKubernetesSession(_session('a', archived: true)), isFalse);
      // A disconnected "running" row is a leftover, not a container.
      expect(isLiveKubernetesSession(_session('a', active: false)), isFalse);
      expect(
        isLiveKubernetesSession(
          _session('a', active: false, lifecycle: null, podPaused: true),
        ),
        isTrue,
      );
      expect(
        isLiveKubernetesSession(
          _session('a', active: false, lifecycle: 'errored'),
        ),
        isTrue,
      );
    });
  });

  group('KubernetesSessionCounts', () {
    test('counts live sessions by pod state with value equality', () {
      final sessions = {
        'a': _session('a'),
        'b': _session('b', lifecycle: 'starting'),
        'c': _session('c', podPaused: true),
        'd': _session('d', lifecycle: 'errored'),
        'e': _session('e', kubernetes: false),
        'f': _session('f', archived: true),
      };
      final counts = KubernetesSessionCounts.fromSessions(sessions);
      expect(counts.ready, 1);
      expect(counts.scheduling, 1);
      expect(counts.paused, 1);
      expect(counts.failed, 1);
      expect(counts.total, 4);
      expect(counts, KubernetesSessionCounts.fromSessions({...sessions}));
      expect(KubernetesSessionCounts.fromSessions({}).total, 0);
    });
  });

  group('kubernetesPodMachineIds', () {
    test('asks online Kubernetes daemons and owners of live pods', () {
      final ids = kubernetesPodMachineIds(
        machines: {
          'k8s': _machine('k8s'),
          'local': _machine('local', kubernetes: false),
          'owner': _machine('owner', kubernetes: false),
          'offline': _machine('offline', online: false),
        },
        sessions: {
          'a': _session('a', machineId: 'owner'),
          'b': _session('b', machineId: 'offline'),
        },
        nowMs: 1000000,
      );
      expect(ids, ['k8s', 'owner']);
    });
  });

  group('mergeKubernetesPods', () {
    test('a reachable daemon is authoritative for its machine', () {
      final entries = mergeKubernetesPods(
        sessions: {
          'a': _session('a'),
          // Reported nowhere by m1, so its pod is gone.
          'gone': _session('gone'),
          'remote': _session('remote', machineId: 'm2'),
        },
        podsByMachine: {
          'm1': [
            _pod('a'),
            _pod('orphan', phase: 'Pending', ready: false),
            _pod('old', archived: true),
          ],
        },
      );
      // Newest first; the orphan has no known creation time.
      expect(entries.map((e) => e.key), ['m1/a', 'm2/remote', 'm1/orphan']);
      final orphan = entries.last;
      expect(orphan.session, isNull);
      expect(orphan.sessionTitle, isNull);
      expect(orphan.canArchive, isFalse);
      expect(orphan.state, SessionPodDisplayState.scheduling);
      final tracked = entries.first;
      expect(tracked.canArchive, isTrue);
      expect(tracked.session?.id, 'a');
      expect(tracked.live, isTrue);
      expect(tracked.repoRef, 'main');
      // m2 did not answer: metadata fallback, marked not live.
      final remote = entries[1];
      expect(remote.live, isFalse);
      expect(remote.pod, isNull);
      expect(remote.podName, 'happy-remote');
      expect(remote.state, SessionPodDisplayState.ready);
    });

    test('sorts newest pods first and failed pods carry their reason', () {
      final entries = mergeKubernetesPods(
        sessions: {
          // Paused: no pod start time, so the session's creation counts.
          'paused': _session('paused', createdAt: 2500, podPaused: true),
        },
        podsByMachine: {
          'm1': [
            _pod('old', startedAtMs: 1000),
            _pod(
              'bad',
              reason: 'ImagePullBackOff',
              ready: false,
              startedAtMs: 3000,
            ),
            _pod('mid', startedAtMs: 2000),
            _pod('paused', paused: true),
          ],
        },
      );
      expect(entries.map((e) => e.key), [
        'm1/bad',
        'm1/paused',
        'm1/mid',
        'm1/old',
      ]);
      expect(entries.first.state, SessionPodDisplayState.failed);
      expect(entries.first.detail, 'ImagePullBackOff');
      // A succeeded pause keeps the creation-time order.
      final paused = applyPodOperations(entries, {
        'm1/mid': PodOperation(
          id: 1,
          key: 'm1/mid',
          request: const PodRequest(
            machineId: 'm1',
            sessionId: 'mid',
            action: KubernetesPodAction.pause,
          ),
          phase: OperationPhase.succeeded,
          submittedAtMs: 0,
        ),
      });
      expect(paused.map((e) => e.key), [
        'm1/bad',
        'm1/paused',
        'm1/mid',
        'm1/old',
      ]);
      expect(paused[2].state, SessionPodDisplayState.paused);
    });
  });

  group('widgets', () {
    testWidgets('strip shows non-zero counts and opens on tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          KubernetesSessionsStripView(
            counts: const KubernetesSessionCounts(ready: 3, failed: 1),
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.text('Kubernetes'), findsOneWidget);
      expect(find.text('3 running'), findsOneWidget);
      expect(find.text('1 failed'), findsOneWidget);
      expect(find.textContaining('paused'), findsNothing);
      await tester.tap(find.byKey(const Key('kubernetes-sessions-strip')));
      expect(taps, 1);
    });

    testWidgets('pill leads with the state that needs attention', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          KubernetesSessionsPill(
            counts: const KubernetesSessionCounts(
              ready: 3,
              scheduling: 2,
              failed: 1,
            ),
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.text('1 failed'), findsOneWidget);
      expect(find.textContaining('running'), findsNothing);
      expect(find.textContaining('starting'), findsNothing);
      await tester.tap(find.byKey(const Key('kubernetes-sessions-pill')));
      expect(taps, 1);

      await tester.pumpWidget(
        _app(
          KubernetesSessionsPill(
            counts: const KubernetesSessionCounts(ready: 3, scheduling: 2),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('2 starting'), findsOneWidget);
    });

    testWidgets('tight pill keeps the count and the spoken summary', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          KubernetesSessionsPill(
            counts: const KubernetesSessionCounts(ready: 3),
            tight: true,
            onTap: () {},
          ),
        ),
      );
      expect(find.text('3'), findsOneWidget);
      expect(find.text('3 running'), findsNothing);
      expect(
        tester
            .getSemantics(find.byKey(const Key('kubernetes-sessions-pill')))
            .label,
        contains('3 session pods'),
      );
    });

    testWidgets('pod tile names untracked pods and stale state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              KubernetesPodTile(
                entry: KubernetesPodEntry(machineId: 'm1', pod: _pod('orphan')),
              ),
              KubernetesPodTile(
                entry: KubernetesPodEntry(
                  machineId: 'm2',
                  session: _session('s'),
                  live: false,
                ),
                onTap: () {},
                onInfo: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.text('happy-orphan'), findsOneWidget);
      expect(find.textContaining('No matching session'), findsOneWidget);
      expect(find.text('Session s'), findsOneWidget);
      expect(find.textContaining('Last known'), findsOneWidget);
      // Only the tracked pod has somewhere to go, so only it has a menu.
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    });

    testWidgets('pod tile shows uptime, restarts and usage against limits', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 11, 11, 10);
      await tester.pumpWidget(
        _app(
          KubernetesPodTile(
            entry: KubernetesPodEntry(
              machineId: 'm1',
              session: _session('a'),
              pod: _pod(
                'a',
                metrics: true,
                restarts: 2,
                startedAtMs: now
                    .subtract(const Duration(hours: 2, minutes: 14))
                    .millisecondsSinceEpoch,
              ),
            ),
            now: now,
          ),
        ),
      );
      expect(find.text('Ready · acme/app @ main · 2 restarts'), findsOneWidget);
      expect(find.text('2h 14m'), findsOneWidget);
      expect(find.byTooltip('Up 2h 14m'), findsOneWidget);
      expect(
        find.text('CPU 0.25 / 2 · Memory 512 MiB / 4 GiB'),
        findsOneWidget,
      );
    });

    testWidgets('a ready pod without metrics shows no usage line', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          KubernetesPodTile(
            entry: KubernetesPodEntry(
              machineId: 'm1',
              session: _session('a'),
              pod: _pod('a'),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('kubernetes-pod-usage')), findsNothing);
      expect(find.textContaining('Usage'), findsNothing);
    });

    testWidgets('pods screen merges live pods and flags unreachable daemons', (
      tester,
    ) async {
      // Every card must be built: ListView is lazy below the viewport.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final now = DateTime.now().millisecondsSinceEpoch;
      final asked = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsNotifierProvider.overrideWith(
              () => _StubSessions({
                'a': _session('a', machineId: 'k8s'),
                'b': _session('b', machineId: 'down'),
              }),
            ),
            machinesNotifierProvider.overrideWith(
              () => _StubMachines({
                'k8s': _machine('k8s', activeAt: now),
                'down': _machine('down', activeAt: now),
              }),
            ),
          ],
          child: _routerApp(
            KubernetesSessionsScreen(
              loadPods: (machineId) async {
                asked.add(machineId);
                if (machineId == 'down') throw StateError('offline');
                return [
                  _pod('a'),
                  _pod('orphan', reason: 'CrashLoopBackOff', ready: false),
                ];
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(asked..sort(), ['down', 'k8s']);
      expect(find.byKey(const Key('kubernetes-unreachable')), findsOneWidget);
      expect(find.byKey(const Key('kubernetes-pod-list')), findsOne);
      expect(find.text('3 pods · 1 failed · 2 running'), findsOne);
      expect(find.text('happy-orphan'), findsOneWidget);
      expect(find.text('Session a'), findsOneWidget);
      // b's daemon did not answer: last known metadata state.
      expect(find.text('Session b'), findsOneWidget);
      expect(find.text('Last known'), findsOneWidget);

      await tester.tap(find.text('Session a'));
      await tester.pumpAndSettle();
      expect(find.text('chat a'), findsOneWidget);

      // Dispose the screen so its poll timer is cancelled.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('summary totals usage and kill confirms before sending', (
      tester,
    ) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final sent = <String>[];
      var killed = false;
      final reply = Completer<SessionPodActionResponse>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsNotifierProvider.overrideWith(
              () => _StubSessions({'a': _session('a', machineId: 'k8s')}),
            ),
            machinesNotifierProvider.overrideWith(
              () => _StubMachines({'k8s': _machine('k8s', activeAt: now)}),
            ),
            podActionRunnerProvider.overrideWithValue((
              machineId,
              sessionId,
              action,
            ) {
              sent.add('$machineId/$sessionId/${action.name}');
              return reply.future;
            }),
          ],
          child: _routerApp(
            KubernetesSessionsScreen(
              loadPods: (_) async => [
                if (!killed) _pod('a', metrics: true),
                _pod('b', metrics: true),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final summary = find.byKey(const Key('kubernetes-summary'));
      expect(
        find.descendant(of: summary, matching: find.text('2 pods · 2 running')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: summary,
          matching: find.text('CPU 0.5 · Memory 1 GiB'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('kubernetes-pod-menu-k8s/a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('kubernetes-pod-kill')));
      await tester.pumpAndSettle();
      // The confirmation names the session and what is lost.
      expect(find.textContaining('workspace volume is deleted'), findsOne);
      expect(sent, isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Kill pod'));
      await tester.pump();
      expect(sent, ['k8s/a/kill']);
      // The daemon has not answered yet: the screen is not blocked and the
      // card shows the deletion in progress.
      expect(find.text('Session a'), findsOneWidget);
      expect(find.text('Deleting…'), findsOneWidget);

      killed = true;
      reply.complete(
        const SessionPodActionResponse(success: true, message: ''),
      );
      await tester.pumpAndSettle();
      expect(find.text('Session a'), findsNothing);
      expect(find.text('Deleting…'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('failed kill restores the card with an error and retry', (
      tester,
    ) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      var attempts = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsNotifierProvider.overrideWith(
              () => _StubSessions({'a': _session('a', machineId: 'k8s')}),
            ),
            machinesNotifierProvider.overrideWith(
              () => _StubMachines({'k8s': _machine('k8s', activeAt: now)}),
            ),
            podActionRunnerProvider.overrideWithValue((_, _, _) async {
              attempts++;
              if (attempts == 1) throw StateError('forbidden');
              return const SessionPodActionResponse(
                success: false,
                message: 'pod is locked',
              );
            }),
          ],
          child: _routerApp(
            KubernetesSessionsScreen(loadPods: (_) async => [_pod('a')]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('kubernetes-pod-menu-k8s/a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('kubernetes-pod-kill')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Kill pod'));
      await tester.pumpAndSettle();

      expect(find.text('Session a'), findsOneWidget);
      expect(find.text('Deleting…'), findsNothing);
      expect(
        find.byKey(const Key('pod-operation-failed-k8s/a')),
        findsOneWidget,
      );
      expect(find.textContaining('forbidden'), findsWidgets);

      await tester.tap(find.byKey(const Key('pod-operation-retry')));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.textContaining('pod is locked'), findsWidgets);

      await tester.tap(find.byKey(const Key('pod-operation-dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pod-operation-failed-k8s/a')), findsNothing);
      expect(find.text('Session a'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('selects several pods and archives their sessions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final now = DateTime.now().millisecondsSinceEpoch;
      final recorder = _RecordingSessionOperations();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsNotifierProvider.overrideWith(
              () => _StubSessions({
                'a': _session('a', machineId: 'k8s'),
                'b': _session('b', machineId: 'k8s'),
                'c': _session('c', machineId: 'k8s'),
              }),
            ),
            machinesNotifierProvider.overrideWith(
              () => _StubMachines({'k8s': _machine('k8s', activeAt: now)}),
            ),
            sessionOperationsNotifierProvider.overrideWith(() => recorder),
          ],
          child: _routerApp(
            KubernetesSessionsScreen(
              loadPods: (_) async => [
                _pod('a', startedAtMs: now - 3000),
                _pod('b', startedAtMs: now - 2000),
                _pod('c', startedAtMs: now - 1000),
                _pod('orphan', startedAtMs: now),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long-press enters selection mode with that row selected; taps then
      // toggle rows instead of opening the chat.
      await tester.longPress(find.text('Session a'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.text('Session b'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.text('chat b'), findsNothing);
      // An untracked pod has no session to archive.
      await tester.tap(find.text('happy-orphan'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.byKey(const Key('kubernetes-archive-selected')));
      await tester.pumpAndSettle();
      expect(find.text('Archive 2 sessions?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await tester.pumpAndSettle();

      expect(recorder.archived, unorderedEquals(['a', 'b']));
      // The rows leave at once and selection mode ends.
      expect(find.text('Session a'), findsNothing);
      expect(find.text('Session b'), findsNothing);
      expect(find.text('Session c'), findsOneWidget);
      expect(find.text('Kubernetes'), findsOneWidget);

      // Select all picks every archivable row; close leaves selection.
      await tester.tap(find.byKey(const Key('kubernetes-select')));
      await tester.pumpAndSettle();
      expect(find.text('0 selected'), findsOneWidget);
      await tester.tap(find.byKey(const Key('kubernetes-select-all')));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.byKey(const Key('kubernetes-selection-close')));
      await tester.pumpAndSettle();
      expect(find.text('Kubernetes'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('sorts by creation time and flips to oldest first', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final now = DateTime.now().millisecondsSinceEpoch;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsNotifierProvider.overrideWith(
              () => _StubSessions({
                'old': _session('old', machineId: 'k8s'),
                'new': _session('new', machineId: 'k8s'),
              }),
            ),
            machinesNotifierProvider.overrideWith(
              () => _StubMachines({'k8s': _machine('k8s', activeAt: now)}),
            ),
          ],
          child: _routerApp(
            KubernetesSessionsScreen(
              loadPods: (_) async => [
                _pod('old', startedAtMs: now - 60000),
                _pod('new', startedAtMs: now - 1000),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(top('Session new'), lessThan(top('Session old')));

      await tester.tap(find.byKey(const Key('kubernetes-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oldest first'));
      await tester.pumpAndSettle();
      expect(top('Session old'), lessThan(top('Session new')));

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('pod formatting', () {
    test('formats cores, bytes, uptime and repositories', () {
      expect(formatCpuCores(250), '0.25');
      expect(formatCpuCores(1500), '1.5');
      expect(formatCpuCores(2000), '2');
      expect(formatCpuCores(12345), '12');
      expect(formatCpuCores(0), '0');
      expect(formatBinaryBytes(512 << 20), '512 MiB');
      expect(formatBinaryBytes(1536 << 20), '1.5 GiB');
      expect(formatBinaryBytes(4 << 30), '4 GiB');
      expect(formatBinaryBytes(0), '0 B');
      expect(formatPodUptime(const Duration(seconds: 45)), '45s');
      expect(formatPodUptime(const Duration(minutes: 12)), '12m');
      expect(formatPodUptime(const Duration(hours: 2, minutes: 14)), '2h 14m');
      expect(formatPodUptime(const Duration(hours: 3)), '3h');
      expect(formatPodUptime(const Duration(days: 3, hours: 4)), '3d 4h');
      expect(
        formatPodRepo('https://github.com/acme/app.git', 'main'),
        'acme/app @ main',
      );
      expect(formatPodRepo('git@github.com:acme/app.git', ''), 'acme/app');
      expect(formatPodRepo('', 'main'), '');
      expect(podUsageFraction(usage: 500, limit: 2000, request: 100), 0.25);
      expect(podUsageFraction(usage: 50, limit: 0, request: 100), 0.5);
      expect(podUsageFraction(usage: 50, limit: 0, request: 0), isNull);
      expect(podUsageFraction(usage: 900, limit: 100, request: 0), 1.0);
    });

    test('SessionPod parses protojson int64 strings', () {
      final pod = SessionPod.fromJson({
        'sessionId': 'a',
        'startedAtMs': '1762844400000',
        'restartCount': 3,
        'cpuUsageMillicores': '250',
        'memoryLimitBytes': '4294967296',
        'metricsAvailable': true,
      });
      expect(pod.startedAtMs, 1762844400000);
      expect(pod.restartCount, 3);
      expect(pod.cpuUsageMillicores, 250);
      expect(pod.memoryLimitBytes, 4 << 30);
      expect(pod.metricsAvailable, isTrue);
      expect(SessionPod.fromJson({}).cpuUsageMillicores, 0);
    });
  });

  group('Kubernetes board layout', () {
    test('is a board style with a stable wire', () {
      expect(
        SessionsViewStyle.fromWire('kubernetes'),
        SessionsViewStyle.kubernetes,
      );
      expect(SessionsViewStyle.kubernetes.isBoard, isTrue);
    });

    testWidgets('groups pods by state, then sessions on machines', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final sections = buildKubernetesSections(context, [
        _session('ready'),
        _session('local', kubernetes: false),
        _session('failed', lifecycle: 'errored'),
        _session('paused', podPaused: true),
        _session('archived', archived: true),
      ], const SessionUiState(bySessionId: {}));
      expect(sections.map((s) => s.key), [
        'kubernetes-failed',
        'kubernetes-ready',
        'kubernetes-paused',
        'kubernetes-local',
      ]);
      expect(sections.last.rows.single.session.id, 'local');
      final ids = sections.expand((s) => s.rows).map((r) => r.session.id);
      expect(ids.toSet().length, ids.length);
      expect(ids, isNot(contains('archived')));
    });
  });
}
