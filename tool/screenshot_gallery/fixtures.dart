// Fixture data for the screenshot gallery.
//
// Everything here is plain in-memory model data in the same shape the real
// `Sync` service produces after decrypting server payloads: `Session` /
// `Machine` models plus processed message maps (`kind: text | tool-call`,
// `role: user | agent`). Timestamps are relative to "now" so relative-time
// labels ("2m ago") stay realistic on every run.
//
// ignore_for_file: lines_longer_than_80_chars

import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';

/// Wall clock captured once so every fixture agrees on "now".
final int fixtureNow = DateTime.now().millisecondsSinceEpoch;

int _ago(Duration d) => fixtureNow - d.inMilliseconds;

const laptopMachineId = 'm-laptop';
const clusterMachineId = 'm-k2';

// Session ids referenced by scenes.
const workingSessionId = 's-claude-composer';
const permissionSessionId = 's-claude-deploy';
const signinSessionId = 's-claude-otel';
const codexPermissionSessionId = 's-codex-spawn';

/// Two machines: a laptop running the local daemon and a Kubernetes cluster.
Map<String, Machine> fixtureMachines() {
  final machines = [
    Machine(
      id: laptopMachineId,
      seq: 1,
      createdAt: _ago(const Duration(days: 90)),
      updatedAt: _ago(const Duration(seconds: 20)),
      active: true,
      activeAt: _ago(const Duration(seconds: 20)),
      metadataVersion: 1,
      daemonStateVersion: 1,
      metadata: const MachineMetadata(
        host: 'denys-mbp',
        displayName: 'denys-mbp',
        platform: 'darwin',
        arch: 'arm64',
        username: 'denys',
        homeDir: '/Users/denys',
        happyCliVersion: '1.0.0-512',
        spawnBackends: ['local'],
        defaultSpawnBackend: 'local',
        sandboxBackend: 'boxy',
        sandboxAvailable: true,
        sandboxEnabled: true,
      ),
      daemonState: const {'status': 'running'},
    ),
    Machine(
      id: clusterMachineId,
      seq: 1,
      createdAt: _ago(const Duration(days: 40)),
      updatedAt: _ago(const Duration(seconds: 35)),
      active: true,
      activeAt: _ago(const Duration(seconds: 35)),
      metadataVersion: 1,
      daemonStateVersion: 1,
      metadata: const MachineMetadata(
        host: 'happy-daemon-0',
        displayName: 'k2 cluster',
        platform: 'linux',
        arch: 'amd64',
        username: 'happy',
        homeDir: '/home/happy',
        happyCliVersion: '1.0.0-512',
        spawnBackends: ['kubernetes', 'local'],
        defaultSpawnBackend: 'kubernetes',
        kubernetesCheckoutBaseDir: '/workspace',
      ),
      daemonState: const {'status': 'running'},
    ),
  ];
  return {for (final m in machines) m.id: m};
}

Metadata _meta({
  required String flavor,
  required String title,
  required String path,
  required Duration age,
  String machineId = laptopMachineId,
  String? model,
  String? lifecycleState,
  String? lifecycleStateError,
  String? branch,
}) {
  final onCluster = machineId == clusterMachineId;
  return Metadata(
    path: path,
    host: onCluster ? 'happy-daemon-0' : 'denys-mbp',
    machineId: machineId,
    homeDir: onCluster ? '/home/happy' : '/Users/denys',
    flavor: flavor,
    model: model,
    name: title,
    summary: Summary(text: title, updatedAt: _ago(age)),
    os: onCluster ? 'linux' : 'darwin',
    version: '1.0.0-512',
    lifecycleState: lifecycleState,
    lifecycleStateError: lifecycleStateError,
    lifecycleStateSince: lifecycleState == null ? null : _ago(age),
    gitBranch: branch,
    runtimeKind: onCluster ? 'kubernetes' : null,
    podName: onCluster
        ? 'happy-session-${title.hashCode.toUnsigned(20)}'
        : null,
    namespace: onCluster ? 'happy-sessions' : null,
    podPhase: onCluster ? 'Running' : null,
    podReady: onCluster ? true : null,
  );
}

Session _session({
  required String id,
  required Metadata metadata,
  required Duration age,
  bool online = false,
  bool thinking = false,
  bool archived = false,
  AgentState? agentState,
  String lifecycleCleartext = '',
}) {
  final at = _ago(age);
  return Session(
    id: id,
    seq: 20,
    createdAt: at - const Duration(hours: 2).inMilliseconds,
    updatedAt: at,
    active: !archived,
    activeAt: at,
    archived: archived,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    thinkingAt: thinking ? at : null,
    presence: online && !archived ? 'online' : '${at - 1000}',
    agentState: agentState,
    lifecycleStateCleartext: lifecycleCleartext,
    lastMessageAt: at,
    metadata: metadata,
  );
}

/// The full sessions catalog: mixed agents, states and machines.
Map<String, Session> fixtureSessions() {
  final sessions = <Session>[
    _session(
      id: workingSessionId,
      age: const Duration(seconds: 12),
      online: true,
      thinking: true,
      metadata: _meta(
        flavor: 'claude',
        model: 'claude-opus-4-6',
        title: 'Refactor composer attachment tray',
        path: '/Users/denys/git/happy_flutter',
        age: const Duration(seconds: 12),
        branch: 'main',
      ),
    ),
    _session(
      id: permissionSessionId,
      age: const Duration(minutes: 1),
      online: true,
      agentState: AgentState(
        requests: {
          'toolu_perm_rollout': RequestInfo(
            tool: 'Bash',
            arguments: const {
              'command': 'kubectl -n happy rollout restart deploy/happy-server',
              'description': 'Restart happy-server to pick up the new config',
            },
            createdAt: _ago(const Duration(seconds: 50)),
          ),
        },
      ),
      metadata: _meta(
        flavor: 'claude',
        model: 'claude-sonnet-4-6',
        title: 'Roll out server config change',
        path: '/workspace/k2-gitops',
        machineId: clusterMachineId,
        age: const Duration(minutes: 1),
      ),
    ),
    _session(
      id: codexPermissionSessionId,
      age: const Duration(minutes: 3),
      online: true,
      agentState: AgentState(
        requests: {
          'call_codex_rm': RequestInfo(
            tool: 'Bash',
            arguments: const {
              'command': 'go test -p 1 -race ./internal/daemon/...',
            },
            createdAt: _ago(const Duration(minutes: 3)),
          ),
        },
      ),
      metadata: _meta(
        flavor: 'codex',
        model: 'gpt-5.3-codex',
        title: 'Fix flaky daemon spawn test',
        path: '/Users/denys/git/happy-cli-go',
        age: const Duration(minutes: 3),
        branch: 'master',
      ),
    ),
    _session(
      id: signinSessionId,
      age: const Duration(minutes: 6),
      online: true,
      metadata: _meta(
        flavor: 'claude',
        title: 'Investigate dropped OTel spans',
        path: '/workspace/happy-cli-go',
        machineId: clusterMachineId,
        age: const Duration(minutes: 6),
      ),
    ),
    _session(
      id: 's-grok-notes',
      age: const Duration(minutes: 14),
      online: true,
      metadata: _meta(
        flavor: 'grok',
        model: 'grok-code-fast-2',
        title: 'Draft release notes for 1.0.0-512',
        path: '/Users/denys/git/happy_flutter',
        age: const Duration(minutes: 14),
      ),
    ),
    _session(
      id: 's-opencode-alerts',
      age: const Duration(minutes: 42),
      metadata: _meta(
        flavor: 'opencode',
        model: 'opencode/big-pickle',
        title: 'Add Prometheus alert for 5xx rate',
        path: '/workspace/k2-gitops',
        machineId: clusterMachineId,
        age: const Duration(minutes: 42),
      ),
    ),
    _session(
      id: 's-claude-migration',
      age: const Duration(hours: 2),
      lifecycleCleartext: 'errored',
      metadata: _meta(
        flavor: 'claude',
        title: 'Migrate sessions table index',
        path: '/Users/denys/git/happy-cli-go',
        age: const Duration(hours: 2),
        lifecycleState: 'errored',
        lifecycleStateError: 'claude exited with code 1',
      ),
    ),
    _session(
      id: 's-codex-boxy',
      age: const Duration(hours: 5),
      metadata: _meta(
        flavor: 'codex',
        title: 'Tighten boxy network allowlist',
        path: '/Users/denys/git/boxy',
        age: const Duration(hours: 5),
      ),
    ),
    _session(
      id: 's-claude-flutter-bump',
      age: const Duration(days: 2),
      archived: true,
      metadata: _meta(
        flavor: 'claude',
        title: 'Bump Flutter to 3.41',
        path: '/Users/denys/git/happy_flutter',
        age: const Duration(days: 2),
      ),
    ),
    _session(
      id: 's-grok-sqlc',
      age: const Duration(days: 9),
      archived: true,
      metadata: _meta(
        flavor: 'grok',
        title: 'Benchmark sqlc prepared statements',
        path: '/workspace/happy-cli-go',
        machineId: clusterMachineId,
        age: const Duration(days: 9),
      ),
    ),
  ];
  return {for (final s in sessions) s.id: s};
}

// ── Message builders ────────────────────────────────────────────────────

int _seq = 0;

Map<String, dynamic> _user(String id, String text, Duration age) => {
  'id': id,
  'localId': id,
  'seq': ++_seq,
  'createdAt': _ago(age),
  'role': 'user',
  'kind': 'text',
  'content': text,
  'sendStatus': 'sent',
};

Map<String, dynamic> _agent(
  String id,
  String text,
  Duration age, {
  bool thinking = false,
}) => {
  'id': id,
  'seq': ++_seq,
  'createdAt': _ago(age),
  'role': 'agent',
  'kind': 'text',
  'content': text,
  if (thinking) 'isThinking': true,
};

Map<String, dynamic> _tool(
  String id,
  String name,
  Map<String, dynamic> input,
  Duration age, {
  Object? result,
  String state = 'completed',
  Map<String, dynamic>? permission,
}) => {
  'id': id,
  'seq': ++_seq,
  'createdAt': _ago(age),
  'role': 'agent',
  'kind': 'tool-call',
  'name': name,
  'input': input,
  'toolUseId': id,
  'state': state,
  'result': ?result,
  'permission': ?permission,
};

/// Messages per session id. Every session gets at least a short exchange so
/// list previews have real "last message" text.
Map<String, List<Map<String, dynamic>>> fixtureMessages() {
  _seq = 0;
  return {
    workingSessionId: _workingChat(),
    permissionSessionId: _permissionChat(),
    signinSessionId: _signinChat(),
    codexPermissionSessionId: [
      _user(
        'cx-u1',
        'TestDaemon_SpawnLocal flakes about 1 in 20 runs on CI. Find out why and fix it.',
        const Duration(minutes: 9),
      ),
      _agent(
        'cx-a1',
        'The spawn test races the session-started webhook against the exit watcher. I added a barrier so the watcher only arms after `markSessionStarted`. Running the daemon package under `-race` to confirm.',
        const Duration(minutes: 4),
      ),
      _tool(
        'call_codex_rm',
        'Bash',
        {'command': 'go test -p 1 -race ./internal/daemon/...'},
        const Duration(minutes: 3),
        state: 'running',
        permission: {'id': 'call_codex_rm', 'status': 'pending'},
      ),
    ],
    's-grok-notes': [
      _user(
        'gk-u1',
        'Draft release notes from the commits since 1.0.0-498. Group by feature, keep it short.',
        const Duration(minutes: 20),
      ),
      _agent(
        'gk-a1',
        'Draft is ready in `docs/release-notes/1.0.0-512.md`: 3 features (Kubernetes runtime bundle, Claude sign-in from chat, faster session list), 7 fixes, no breaking changes.',
        const Duration(minutes: 14),
      ),
    ],
    's-opencode-alerts': [
      _user(
        'oc-u1',
        'Add an alert when happy-server 5xx rate is above 2% for 10 minutes.',
        const Duration(minutes: 50),
      ),
      _agent(
        'oc-a1',
        'Added `HappyServerHigh5xxRate` to `monitoring/rules/happy.yaml` and validated it with `promtool check rules`. It pages after 10m above 2%.',
        const Duration(minutes: 42),
      ),
    ],
    's-claude-migration': [
      _user(
        'mg-u1',
        'Make migration 000015 stop blocking writes on the sessions table.',
        const Duration(hours: 2, minutes: 10),
      ),
      _agent(
        'mg-a1',
        'The migrate driver wraps every file in a transaction, so `CREATE INDEX CONCURRENTLY` cannot run there. I will move the index to a separate startup step.',
        const Duration(hours: 2, minutes: 2),
      ),
      {
        'id': 'mg-err',
        'seq': ++_seq,
        'createdAt': _ago(const Duration(hours: 2)),
        'role': 'agent',
        'kind': 'error',
        'content': 'Session process stopped: claude exited with code 1',
      },
    ],
    's-codex-boxy': [
      _user(
        'bx-u1',
        'Only allow api.anthropic.com and github.com from sandboxed sessions by default.',
        const Duration(hours: 5, minutes: 20),
      ),
      _agent(
        'bx-a1',
        'Done. The default profile now uses `network: allowlist` with those two hosts; `boxy doctor` passes and the e2e sandbox test is green.',
        const Duration(hours: 5),
      ),
    ],
    's-claude-flutter-bump': [
      _user(
        'fb-u1',
        'Bump Flutter to 3.41 and fix analyzer fallout.',
        const Duration(days: 2, minutes: 30),
      ),
      _agent(
        'fb-a1',
        'Bumped to 3.41.9 in `mise.toml`; fixed 14 deprecations. `flutter analyze` is clean.',
        const Duration(days: 2),
      ),
    ],
    's-grok-sqlc': [
      _user(
        'sq-u1',
        'Benchmark prepared vs unprepared sqlc statements.',
        const Duration(days: 9, minutes: 40),
      ),
      _agent(
        'sq-a1',
        'No measurable win: p50 differs by 0.04ms. Not worth the pgbouncer complexity.',
        const Duration(days: 9),
      ),
    ],
  };
}

List<Map<String, dynamic>> _workingChat() => [
  _user(
    'w-u1',
    'The attachment tray in the composer jumps when you add a second image. Can you fix the layout and add a test?',
    const Duration(minutes: 6),
  ),
  _agent(
    'w-th1',
    'Start by finding where the tray computes its height; the jump suggests the tray switches from intrinsic sizing to a fixed row height once there are 2+ items.',
    const Duration(minutes: 6),
    thinking: true,
  ),
  _tool(
    'w-t1',
    'Grep',
    {'pattern': 'AttachmentTray', 'path': 'lib/features/chat'},
    const Duration(minutes: 5, seconds: 50),
    result:
        'lib/features/chat/chat_input_attachments.dart\nlib/features/chat/chat_input.dart',
  ),
  _tool(
    'w-t2',
    'Read',
    {
      'file_path':
          '/Users/denys/git/happy_flutter/lib/features/chat/chat_input_attachments.dart',
    },
    const Duration(minutes: 5, seconds: 40),
    result:
        '  Widget build(BuildContext context) {\n    final height = items.length > 1 ? 72.0 : null;\n    return SizedBox(height: height, child: _row());\n  }',
  ),
  _agent(
    'w-a1',
    'Found it. The tray only pins its height **after** the second attachment, so the composer grows by 8px at exactly that moment:\n\n```dart\nfinal height = items.length > 1 ? 72.0 : null;\nreturn SizedBox(height: height, child: _row());\n```\n\nI will give the tray a fixed thumbnail extent from the first item so adding more never changes its height.',
    const Duration(minutes: 5),
  ),
  _tool(
    'w-t3',
    'Edit',
    {
      'file_path':
          '/Users/denys/git/happy_flutter/lib/features/chat/chat_input_attachments.dart',
      'old_string': '    final height = items.length > 1 ? 72.0 : null;',
      'new_string': '    const height = AppSize.attachmentThumb;',
    },
    const Duration(minutes: 4),
    result: 'The file has been updated.',
  ),
  _tool(
    'w-t4',
    'Bash',
    {
      'command': 'flutter analyze lib/features/chat',
      'description': 'Analyze the chat feature',
    },
    const Duration(minutes: 2),
    result: 'Analyzing chat...\nNo issues found! (ran in 4.1s)',
  ),
  _tool(
    'w-t5',
    'Write',
    {
      'file_path':
          '/Users/denys/git/happy_flutter/test/features/chat/attachment_tray_height_test.dart',
      'content': "testWidgets('tray height is stable', (tester) async {});",
    },
    const Duration(seconds: 15),
    state: 'running',
  ),
];

List<Map<String, dynamic>> _permissionChat() => [
  _user(
    'p-u1',
    'The new rate-limit config is merged. Roll it out to happy-server.',
    const Duration(minutes: 4),
  ),
  _tool(
    'p-t1',
    'Bash',
    {
      'command': 'kubectl -n happy get deploy happy-server -o wide',
      'description': 'Check the current deployment',
    },
    const Duration(minutes: 3),
    result:
        'NAME           READY   UP-TO-DATE   AVAILABLE   AGE\nhappy-server   3/3     3            3           12d',
  ),
  _agent(
    'p-a1',
    'All 3 replicas are healthy and still on the old ConfigMap hash. A rolling restart picks up the new config with no downtime (maxUnavailable is 0).',
    const Duration(minutes: 2),
  ),
  _tool(
    'toolu_perm_rollout',
    'Bash',
    {
      'command': 'kubectl -n happy rollout restart deploy/happy-server',
      'description': 'Restart happy-server to pick up the new config',
    },
    const Duration(seconds: 50),
    state: 'running',
    permission: {'id': 'toolu_perm_rollout', 'status': 'pending'},
  ),
];

/// Mirrors the message happy-cli-go's Claude auth gate posts
/// (`internal/cli/claude_auth_gate.go`).
const _signinLink =
    'https://claude.com/cai/oauth/authorize?code=true&client_id=9d1c250a-e61b-44d9-88ed-5944d1962f5e&response_type=code&redirect_uri=https%3A%2F%2Fconsole.anthropic.com%2Foauth%2Fcode%2Fcallback&scope=user%3Ainference&code_challenge=Xq3n0dV7&code_challenge_method=S256&state=f2b9c1';

List<Map<String, dynamic>> _signinChat() => [
  _user(
    's-u1',
    'Why are we dropping spans from the session child? Check the OTel exporter config.',
    const Duration(minutes: 9),
  ),
  _agent(
    's-a1',
    'Claude Code is not signed in for this session.\n'
        '1. Open this link and approve access: $_signinLink\n'
        '2. Paste the code it shows as your next message.\n\n'
        'Your pending message is held and runs once you are signed in. Other sessions on this machine reuse the sign-in.',
    const Duration(minutes: 9),
  ),
  _user(
    's-u2',
    'gH7kQ2mZ9vXw4LpR1sT8yB3nC6dF0aJ5eU#f2b9c1',
    const Duration(minutes: 7),
  ),
  _agent(
    's-a2',
    'Signed in to Claude Code. Other sessions on this machine will use this sign-in.',
    const Duration(minutes: 6),
  ),
];
