import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/session_ui_state_notifier.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';
import 'package:happy_flutter/features/kubernetes/kubernetes_pod_state.dart';
import 'package:happy_flutter/features/kubernetes/kubernetes_pods_model.dart';
import 'package:happy_flutter/features/kubernetes/kubernetes_sessions_screen.dart';
import 'package:happy_flutter/features/kubernetes/kubernetes_sessions_strip.dart';
import 'package:happy_flutter/features/sessions/widgets/session_board_view.dart';
import 'package:happy_flutter/features/sessions/widgets/sessions_view_style.dart';

Session _session(
  String id, {
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
  createdAt: 1,
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
      expect(entries.map((e) => e.key), ['m1/orphan', 'm1/a', 'm2/remote']);
      final orphan = entries.first;
      expect(orphan.session, isNull);
      expect(orphan.sessionTitle, isNull);
      expect(orphan.state, SessionPodDisplayState.scheduling);
      final tracked = entries[1];
      expect(tracked.session?.id, 'a');
      expect(tracked.live, isTrue);
      expect(tracked.repoRef, 'main');
      // m2 did not answer: metadata fallback, marked not live.
      final remote = entries.last;
      expect(remote.live, isFalse);
      expect(remote.pod, isNull);
      expect(remote.podName, 'happy-remote');
      expect(remote.state, SessionPodDisplayState.ready);
    });

    test('failed pods sort first and carry their reason', () {
      final entries = mergeKubernetesPods(
        sessions: const {},
        podsByMachine: {
          'm1': [
            _pod('ok'),
            _pod('bad', reason: 'ImagePullBackOff', ready: false),
          ],
        },
      );
      expect(entries.first.key, 'm1/bad');
      expect(entries.first.state, SessionPodDisplayState.failed);
      expect(entries.first.detail, 'ImagePullBackOff');
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
      expect(find.text('No matching session'), findsOneWidget);
      expect(find.text('Session s'), findsOneWidget);
      expect(find.text('happy-s · happy'), findsOneWidget);
      expect(find.text('Last known'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });

    testWidgets('pods screen merges live pods and flags unreachable daemons', (
      tester,
    ) async {
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
      expect(find.byKey(const Key('kubernetes-section-failed')), findsOne);
      expect(find.byKey(const Key('kubernetes-section-ready')), findsOne);
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
