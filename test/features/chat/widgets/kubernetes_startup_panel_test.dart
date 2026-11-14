import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';
import 'package:happy_flutter/core/theme/app_scroll_behavior.dart';
import 'package:happy_flutter/features/chat/widgets/kubernetes_startup_panel.dart';

Session _session({
  String? runtimeKind = 'kubernetes',
  String? lifecycle,
  String? podPhase,
  bool? podPaused,
  bool archived = false,
  String? lifecycleError,
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
    lifecycleStateError: lifecycleError,
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

    test('hides when the agent works past a stale errored lifecycle', () {
      // A failed replacement pod errored the session while the original
      // pod kept serving it; the send that is "waiting" is being answered.
      final working = _session(
        lifecycle: 'errored',
      ).copyWith(thinking: true, presence: 'online', thinkingAt: 200000);
      final session = working.copyWith(
        metadata: working.metadata!.copyWith(lifecycleStateSince: 100000),
      );

      expect(
        shouldShowKubernetesStartup(
          session: session,
          isReady: false,
          hasPendingRequest: true,
        ),
        isFalse,
      );
      expect(
        shouldShowKubernetesStartup(
          session: session.copyWith(thinking: false),
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

  testWidgets(
    'log tail scrolls under app scroll physics and keeps a reader in place',
    (tester) async {
      var logs = List.generate(80, (i) => 'line $i').join('\n');
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const AppScrollBehavior(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: KubernetesStartupPanel(
                session: _session(lifecycle: 'starting'),
                pollInterval: const Duration(seconds: 1),
                loadPod: () async => _pod(phase: 'Running'),
                loadLogs: () async => SessionPodLogsResponse(
                  podName: 'happy-s1',
                  content: logs,
                  truncated: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      ScrollPosition logPosition() => tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const Key('kubernetes-startup-logs')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;

      final end = logPosition().maxScrollExtent;
      expect(end, greaterThan(0));
      expect(logPosition().pixels, end);

      // Dragging over the selectable text scrolls the log box; the text's
      // own phantom scrollable must not swallow the drag and spring back.
      await tester.drag(
        find.byKey(const Key('kubernetes-startup-logs')),
        const Offset(0, 120),
      );
      await tester.pumpAndSettle();
      final reading = logPosition().pixels;
      expect(reading, lessThan(end - 60));

      // New output while reading earlier lines does not yank the view.
      logs = '$logs\nline 80';
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(logPosition().pixels, reading);

      await tester.pumpWidget(_wrap(const SizedBox()));
    },
  );

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

  // The reported screenshot: the daemon started two pods for one session,
  // failed and deleted the second, and errored the session. The panel then
  // polled the first pod, so under "failed to start" it said "Pod running ·
  // waiting for the agent to connect" above three bare init headers.
  testWidgets('a failed session shows why, not the surviving pod', (
    tester,
  ) async {
    const daemonError =
        'kubernetes pod happy-session-s1-07b03fca failed to start: Error '
        'happy-session: exit code 1 failed to recover pending messages for '
        'sid=s1: message outbox is already in use: resource temporarily '
        'unavailable';
    await tester.pumpWidget(
      _wrap(
        KubernetesStartupPanel(
          session: _session(lifecycle: 'errored', lifecycleError: daemonError),
          loadPod: () async => _pod(phase: 'Running', ready: true),
          loadLogs: () async => const SessionPodLogsResponse(
            podName: 'happy-s1',
            content:
                '==> init: agent-cli-preflight <==\n\n'
                '==> init: claude-auth <==\n\n'
                '==> init: happy-runtime <==\n',
            truncated: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Kubernetes pod failed to start'), findsOneWidget);
    expect(
      find.textContaining('Two pods started for this conversation at once'),
      findsOneWidget,
    );
    expect(find.textContaining('waiting for the agent'), findsNothing);
    final detail = tester.widget<SelectableText>(
      find.byKey(const Key('kubernetes-startup-message')),
    );
    expect(detail.data, startsWith('Error happy-session: exit code 1'));
    expect(detail.data, contains('message outbox is already in use'));
    expect(find.textContaining('==> init'), findsNothing);
    expect(
      find.text('The pod printed nothing before it stopped.'),
      findsOneWidget,
    );
  });

  test('log sections holding only escape sequences are dropped', () {
    const content = '==> init <==\n\x1b[0m\x1b[K\n==> agent <==\nready\n';
    expect(kubernetesLogsWithoutEmptySections(content), '==> agent <==\nready');
  });

  testWidgets('renders ANSI colours in the log tail, not raw escapes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        KubernetesStartupPanel(
          session: _session(lifecycle: 'starting'),
          loadPod: () async => _pod(),
          loadLogs: () async => const SessionPodLogsResponse(
            podName: 'happy-s1',
            content: 'cloning \x1b[32mdone\x1b[0m\x1b[K\n',
            truncated: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('cloning done'), findsOneWidget);
    final text = tester.widget<SelectableText>(
      find.descendant(
        of: find.byKey(const Key('kubernetes-startup-logs')),
        matching: find.byType(SelectableText),
      ),
    );
    final spans = text.textSpan!.children!.cast<TextSpan>();
    final done = spans.firstWhere((span) => span.text == 'done');
    expect(done.style?.color, const Color(0xFF00CC00));
    await tester.pumpWidget(_wrap(const SizedBox()));
  });

  test('log sections without output are dropped', () {
    expect(
      kubernetesLogsWithoutEmptySections(
        '==> init: preflight <==\n\n'
        '==> init: checkout <==\nfatal: bad ref\n\n'
        '==> init: mise <==\n',
      ),
      '==> init: checkout <==\nfatal: bad ref',
    );
    expect(kubernetesLogTail('plain line\nsecond\n'), 'plain line\nsecond');
    expect(kubernetesLogTail('==> init: a <==\n\n==> b <==\n'), isEmpty);
  });

  group('startup steps and diagnostics', () {
    testWidgets('lists each container with its state and duration', (
      tester,
    ) async {
      final pod = SessionPod.fromJson({
        'sessionId': 's1',
        'podName': 'happy-s1',
        'phase': 'Pending',
        'deleting': true,
        'containers': [
          {
            'name': 'agent-cli-preflight',
            'init': true,
            'state': 'running',
            'startedAtMs': '1000',
          },
          {'name': 'checkout', 'init': true, 'state': 'waiting'},
          {
            'name': 'runtime-bundle',
            'init': true,
            'state': 'terminated',
            'hasExitCode': true,
            'exitCode': 0,
            'startedAtMs': '1000',
            'finishedAtMs': '4000',
          },
          {
            'name': 'broken',
            'state': 'terminated',
            'reason': 'Error',
            'hasExitCode': true,
            'exitCode': 2,
            'message': 'boom',
          },
        ],
      });
      expect(pod.containers, hasLength(4));
      expect(pod.deleting, isTrue);
      await tester.pumpWidget(
        _wrap(KubernetesPodSteps(pod: pod, nowMs: 90000)),
      );
      expect(find.text('agent-cli-preflight'), findsOneWidget);
      expect(find.textContaining('Running · 1m 29s'), findsOneWidget);
      expect(find.textContaining('Waiting'), findsOneWidget);
      expect(find.textContaining('Done · 3s'), findsOneWidget);
      expect(find.textContaining('Failed · Error · exit 2'), findsOneWidget);
      expect(find.text('boom'), findsOneWidget);
    });

    testWidgets('shows the daemon diagnosis of a pod that no longer exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          KubernetesStartupPanel(
            session: _session(
              lifecycle: 'errored',
              lifecycleError:
                  'kubernetes pod happy-s1 failed to start: pod was deleted '
                  'while starting [phase Pending; init: agent-cli-preflight '
                  'running 1m29s]',
            ),
            loadPod: () async => null,
            loadLogs: () async => const SessionPodLogsResponse(
              podName: '',
              content: '',
              truncated: false,
            ),
            fillHeight: true,
          ),
        ),
      );
      await tester.pump();
      expect(
        find.textContaining('pod was deleted while starting'),
        findsWidgets,
      );
      expect(
        find.textContaining('init: agent-cli-preflight running 1m29s'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('kubernetes-startup-diagnostics')),
        findsOneWidget,
      );
    });

    test('an older daemon without containers reports none', () {
      final pod = SessionPod.fromJson({'sessionId': 's1', 'phase': 'Pending'});
      expect(pod.containers, isEmpty);
      expect(pod.events, isEmpty);
      expect(pod.diagnosis, isEmpty);
    });
  });
}
