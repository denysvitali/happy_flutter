import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';
import 'package:happy_flutter/features/chat/widgets/kubernetes_startup_panel.dart';

Session _session({
  String? runtimeKind = 'kubernetes',
  String? lifecycle,
  String? podPhase,
  bool? podPaused,
  bool archived = false,
}) => Session(
  id: 's1',
  seq: 0,
  createdAt: 0,
  updatedAt: 0,
  active: true,
  activeAt: 0,
  metadataVersion: 1,
  agentStateVersion: 0,
  thinking: false,
  archived: archived,
  metadata: Metadata(
    path: '/workspace',
    host: 'pod',
    machineId: 'm1',
    runtimeKind: runtimeKind,
    podName: runtimeKind == null ? null : 'happy-s1',
    lifecycleState: lifecycle,
    podPhase: podPhase,
    podPaused: podPaused,
  ),
);

SessionPod _pod({
  String phase = 'Pending',
  String reason = '',
  String message = '',
  bool ready = false,
}) => SessionPod(
  sessionId: 's1',
  podName: 'happy-s1',
  namespace: 'happy',
  status: 'running',
  phase: phase,
  reason: reason,
  message: message,
  ready: ready,
  paused: false,
  archived: false,
  repoUrl: '',
  repoRef: '',
);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  group('shouldShowKubernetesStartup', () {
    test('shows for a starting Kubernetes session that is not ready', () {
      expect(
        shouldShowKubernetesStartup(
          session: _session(lifecycle: 'starting'),
          isReady: false,
          hasPendingRequest: false,
        ),
        isTrue,
      );
    });

    test('shows while a send waits on a stopped pod', () {
      expect(
        shouldShowKubernetesStartup(
          session: _session(lifecycle: 'stopped'),
          isReady: false,
          hasPendingRequest: true,
        ),
        isTrue,
      );
    });

    test('hides once the session is reachable', () {
      expect(
        shouldShowKubernetesStartup(
          session: _session(lifecycle: 'starting'),
          isReady: true,
          hasPendingRequest: true,
        ),
        isFalse,
      );
    });

    test('stays quiet for idle stopped, paused, archived and local', () {
      for (final session in [
        _session(lifecycle: 'stopped'),
        _session(lifecycle: 'starting', podPaused: true),
        _session(lifecycle: 'starting', archived: true),
        _session(runtimeKind: null, lifecycle: 'starting'),
      ]) {
        expect(
          shouldShowKubernetesStartup(
            session: session,
            isReady: false,
            hasPendingRequest: false,
          ),
          isFalse,
        );
      }
    });

    test('shows for a pending pod phase', () {
      expect(
        shouldShowKubernetesStartup(
          session: _session(podPhase: 'Pending'),
          isReady: false,
          hasPendingRequest: false,
        ),
        isTrue,
      );
    });
  });

  test('kubernetesPodStartFailed flags unrecoverable reasons', () {
    expect(kubernetesPodStartFailed(_pod(reason: 'ContainerCreating')), false);
    expect(kubernetesPodStartFailed(_pod(reason: 'ImagePullBackOff')), true);
    expect(kubernetesPodStartFailed(_pod(phase: 'Failed')), true);
    expect(kubernetesPodStartFailed(null), false);
  });

  test('kubernetesLogTail keeps only the newest lines', () {
    final content = List.generate(5, (i) => 'line $i').join('\n');
    expect(kubernetesLogTail('$content\n', maxLines: 2), 'line 3\nline 4');
  });

  testWidgets('renders the real pod status and log tail, then polls', (
    tester,
  ) async {
    var podCalls = 0;
    var pod = _pod(
      reason: 'ContainerCreating',
      message: 'pulling image ghcr.io/happy/agent',
    );
    await tester.pumpWidget(
      _wrap(
        KubernetesStartupPanel(
          session: _session(lifecycle: 'starting'),
          pollInterval: const Duration(seconds: 1),
          loadPod: () async {
            podCalls++;
            return pod;
          },
          loadLogs: () async => const SessionPodLogsResponse(
            podName: 'happy-s1',
            content: 'cloning repo\nstarting claude\n',
            truncated: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Starting Kubernetes pod'), findsOneWidget);
    expect(find.text('Pending · ContainerCreating · happy-s1'), findsOneWidget);
    expect(find.text('pulling image ghcr.io/happy/agent'), findsOneWidget);
    expect(find.text('cloning repo\nstarting claude'), findsOneWidget);
    expect(podCalls, 1);

    pod = _pod(reason: 'ImagePullBackOff', message: 'Back-off pulling image');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump();

    expect(podCalls, 2);
    expect(find.text('Kubernetes pod failed to start'), findsOneWidget);
    expect(find.text('Back-off pulling image'), findsOneWidget);

    // Removing the panel stops polling.
    await tester.pumpWidget(_wrap(const SizedBox()));
    await tester.pump(const Duration(seconds: 5));
    expect(podCalls, 2);
  });

  testWidgets('shows a waiting hint while the container has no logs', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        KubernetesStartupPanel(
          session: _session(lifecycle: 'starting'),
          loadPod: () async => _pod(),
          loadLogs: () async => throw StateError('container waiting'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Logs appear once the container starts.'), findsOneWidget);
    await tester.pumpWidget(_wrap(const SizedBox()));
  });

  testWidgets('fills the chat body with status and logs when fillHeight', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          height: 600,
          child: KubernetesStartupPanel(
            session: _session(lifecycle: 'starting'),
            fillHeight: true,
            loadPod: () async => _pod(reason: 'PodInitializing'),
            loadLogs: () async => const SessionPodLogsResponse(
              podName: 'happy-s1',
              content: '[checkout] cloning repo\n',
              truncated: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('kubernetes-startup-body')), findsOneWidget);
    expect(find.text('Starting Kubernetes pod'), findsOneWidget);
    expect(find.text('[checkout] cloning repo'), findsOneWidget);
    // The log pane takes the remaining height instead of a 180px strip.
    final logs = tester.getSize(
      find.byKey(const Key('kubernetes-startup-logs')),
    );
    expect(logs.height, greaterThan(300));
    // Body mode has no collapse affordance.
    expect(find.byIcon(Icons.expand_less_rounded), findsNothing);
    await tester.pumpWidget(_wrap(const SizedBox()));
  });
}
