import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/session_failure_reason.dart';

void main() {
  test('classifies the daemon sentences seen in production', () {
    const cases = <String, SessionFailureKind?>{
      'kubernetes pod p failed to start: Error happy-session: exit code 1 '
              'failed to recover pending messages for sid=x: message outbox '
              'is already in use: resource temporarily unavailable':
          SessionFailureKind.duplicatePod,
      "kubernetes pod p failed to start: Error checkout: exit code 1 fatal: "
              "couldn't find remote ref main":
          SessionFailureKind.branchNotFound,
      'branch "main" does not exist in acme/widgets; its default branch is '
              '"master"':
          SessionFailureKind.branchNotFound,
      'kubernetes pod p failed to start: Error checkout: exit code 128 '
              'fatal: Authentication failed for https://github.com/a/b':
          SessionFailureKind.repositoryAccess,
      'kubernetes pod p failed to start: Error checkout: exit code 1':
          SessionFailureKind.checkoutFailed,
      'kubernetes pod p failed to start: ImagePullBackOff happy-session: '
              'Back-off pulling image':
          SessionFailureKind.imagePull,
      "agent-cli-preflight: exit code 127 required executable 'claude' is "
              'missing from Kubernetes session image':
          SessionFailureKind.imageMissingAgent,
      'kubernetes pod p failed to start: OOMKilled happy-session: exit code '
              '137':
          SessionFailureKind.outOfMemory,
      'kubernetes pod p made no startup progress for 5m0s: Unschedulable '
              '0/3 nodes are available':
          SessionFailureKind.unschedulable,
      'kubernetes pod p made no startup progress for 5m0s: ':
          SessionFailureKind.startTimeout,
      'kubernetes pod p failed to start: NotFound kubernetes pod no longer '
              'exists':
          SessionFailureKind.podGone,
      'kubernetes pod p failed to start: pod was deleted while starting '
              '[phase Pending; init: agent-cli-preflight running 1m29s]':
          SessionFailureKind.podGone,
      'stop previous Kubernetes runtime before switching provider/model: '
              'confirm pod agents/p stopped: context deadline exceeded (pod '
              'still present: phase Pending)':
          SessionFailureKind.stopTimeout,
      'process exited: signal: killed': SessionFailureKind.agentExited,
      'daemon started without a live local process for this running session':
          null,
      '': null,
    };
    cases.forEach((raw, kind) {
      expect(classifySessionFailure(raw), kind, reason: raw);
    });
    expect(classifySessionFailure(null), isNull);
  });

  test('detail drops only the "failed to start" lead-in', () {
    expect(
      sessionFailureDetail(
        'kubernetes pod happy-session-abc failed to start: Error '
        'happy-session: exit code 1 boom',
      ),
      'Error happy-session: exit code 1 boom',
    );
    expect(
      sessionFailureDetail(
        'kubernetes pod p made no startup progress for 5m0s: Pending',
      ),
      'kubernetes pod p made no startup progress for 5m0s: Pending',
    );
    expect(sessionFailureDetail('  '), isNull);
    expect(sessionFailureDetail(null), isNull);
  });

  test('splits the daemon diagnosis off a start failure', () {
    final parts = splitSessionFailureDiagnosis(
      'pod was deleted while starting [phase Pending, terminating for 36s; '
      'node talos-a; init: agent-cli-preflight running 1m29s, checkout '
      'waiting (PodInitializing); Initialized=False (ContainersNotInitialized)'
      ': containers with incomplete status: [agent-cli-preflight]]',
    );
    expect(parts.summary, 'pod was deleted while starting');
    expect(parts.facts, [
      'phase Pending, terminating for 36s',
      'node talos-a',
      'init: agent-cli-preflight running 1m29s, checkout waiting '
          '(PodInitializing)',
      'Initialized=False (ContainersNotInitialized): containers with '
          'incomplete status: [agent-cli-preflight]',
    ]);
    final plain = splitSessionFailureDiagnosis('Error: exit code 1');
    expect(plain.summary, 'Error: exit code 1');
    expect(plain.facts, isEmpty);
  });
}
