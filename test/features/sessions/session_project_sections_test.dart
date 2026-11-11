import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/session_ui_state_notifier.dart';
import 'package:happy_flutter/core/utils/session_projects.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_control_view.dart';
import 'package:happy_flutter/features/sessions/widgets/session_board_view.dart';
import 'package:happy_flutter/features/sessions/widgets/sessions_view_style.dart';

const _remote = 'https://github.com/denysvitali/k2-gitops.git';

Session _session(
  String id, {
  required String path,
  String machine = 'workspace-denys',
  String? repoUrl,
  String? gitRemoteUrl,
  bool pod = false,
  bool active = true,
  int ageMin = 5,
}) {
  final at = DateTime.now().millisecondsSinceEpoch - ageMin * 60000;
  return Session(
    id: id,
    seq: 1,
    createdAt: at,
    updatedAt: at,
    active: active,
    activeAt: at,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    presence: active ? 'online' : 'offline',
    metadata: Metadata(
      host: machine,
      path: path,
      machineId: machine,
      repoUrl: repoUrl,
      gitRemoteUrl: gitRemoteUrl,
      runtimeKind: pod ? 'kubernetes' : null,
      podName: pod ? 'happy-session-$id' : null,
      summary: Summary(text: id, updatedAt: at),
    ),
  );
}

Machine _machine(String id) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Machine(
    id: id,
    seq: 1,
    createdAt: now,
    updatedAt: now,
    active: true,
    activeAt: now,
    metadataVersion: 1,
    daemonStateVersion: 1,
    metadata: MachineMetadata(
      host: id,
      platform: 'linux',
      happyCliVersion: '1',
      happyHomeDir: '/h',
      homeDir: '/h',
    ),
  );
}

Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeHelper.buildDarkTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    ),
  );
  return captured;
}

void main() {
  const ui = SessionUiState(bySessionId: {});
  final machines = {
    'workspace-denys': _machine('workspace-denys'),
    'happy-daemon': _machine('happy-daemon'),
    'laptop': _machine('laptop'),
  };

  group('SessionProjectIndex', () {
    test('catalog index resolves project keys until the catalog changes', () {
      final a = _session('a', path: '/home/workspace/git/har');
      final b = _session('b', path: '/home/workspace/git/har');
      final c = _session('c', path: '/home/workspace/git/pmos');
      final catalog = {'a': a, 'b': b, 'c': c};
      final index = SessionProjectIndex.forCatalog(catalog);

      expect(SessionProjectIndex.forCatalog(catalog), same(index));
      expect(
        SessionProjectIndex.catalogProjectKeyOf('a'),
        SessionProjectIndex.catalogProjectKeyOf('b'),
      );
      expect(
        SessionProjectIndex.catalogProjectKeyOf('a'),
        isNot(SessionProjectIndex.catalogProjectKeyOf('c')),
      );
      expect(SessionProjectIndex.catalogProjectKeyOf('missing'), isNull);

      expect(SessionProjectIndex.forCatalog({...catalog}), isNot(same(index)));
    });

    test('a pod and a local checkout of one repository share a project', () {
      final pod = _session(
        'pod',
        path: '/workspace/k2-gitops',
        machine: 'happy-daemon',
        repoUrl: _remote,
        pod: true,
      );
      final local = _session(
        'local',
        path: '/home/workspace/git/k2-gitops',
        gitRemoteUrl: 'git@github.com:denysvitali/k2-gitops',
      );
      final index = SessionProjectIndex.build([pod, local]);

      expect(index.projectOf(pod).key, index.projectOf(local).key);
      expect(index.projectOf(pod).name, 'k2-gitops');
      expect(index.projectOf(pod).repository, isNotNull);
    });

    test('sessions without a remote inherit their folder repository', () {
      final reported = _session(
        'new',
        path: '/home/workspace/git/k2-gitops',
        gitRemoteUrl: _remote,
      );
      final legacy = _session(
        'old',
        path: '/home/workspace/git/k2-gitops',
        active: false,
      );
      final index = SessionProjectIndex.build([legacy, reported]);

      expect(index.projectOf(legacy).key, index.projectOf(reported).key);
    });

    test('a folder name used by exactly one repository joins it', () {
      final pod = _session(
        'pod',
        path: '/workspace/k2-gitops',
        machine: 'happy-daemon',
        repoUrl: _remote,
        pod: true,
      );
      final bare = _session('bare', path: '/home/workspace/git/K2-GitOps');
      final index = SessionProjectIndex.build([pod, bare]);

      expect(index.projectOf(bare).key, index.projectOf(pod).key);
    });

    test('a name shared by two repositories never guesses', () {
      final mine = _session('mine', path: '/w/api', repoUrl: _remote);
      final fork = _session(
        'fork',
        path: '/w/api',
        machine: 'laptop',
        repoUrl: 'https://github.com/acme/api',
      );
      final theirs = _session(
        'theirs',
        path: '/x/api',
        machine: 'laptop',
        repoUrl: 'https://github.com/other/api',
      );
      final bare = _session('bare', path: '/srv/api', machine: 'happy-daemon');
      final index = SessionProjectIndex.build([mine, fork, theirs, bare]);

      expect(index.projectOf(fork).key, isNot(index.projectOf(theirs).key));
      expect(index.projectOf(bare).key, isNot(index.projectOf(fork).key));
      expect(index.projectOf(bare).key, isNot(index.projectOf(theirs).key));
      // Same-named repositories are told apart by owner.
      expect(index.projectOf(fork).name, 'acme/api');
      expect(index.projectOf(theirs).name, 'other/api');
    });

    test('same-named folders without git merge across machines', () {
      final a = _session('a', path: '/home/workspace/notes');
      final b = _session('b', path: '/home/d/notes', machine: 'laptop');
      final c = _session('c', path: '/home/d/other', machine: 'laptop');
      final index = SessionProjectIndex.build([a, b, c]);

      expect(index.projectOf(a).key, index.projectOf(b).key);
      expect(index.projectOf(c).key, isNot(index.projectOf(a).key));
    });

    test('cached index is reused until a catalog list changes', () {
      final active = [_session('a', path: '/w/a')];
      final inactive = <Session>[];
      final first = SessionProjectIndex.cached(active, inactive);

      expect(SessionProjectIndex.cached(active, inactive), same(first));
      expect(
        SessionProjectIndex.cached([...active], inactive),
        isNot(same(first)),
      );
    });
  });

  test('projects replaces the repository overview as a board', () {
    expect(
      SessionsViewStyle.fromWire('repository'),
      SessionsViewStyle.projects,
    );
    expect(SessionsViewStyle.projects.isBoard, isTrue);
    expect(SessionsViewStyle.projects.workspaceGrouping, isNull);
    expect(SessionsViewStyle.folder.workspaceGrouping, isNotNull);
  });

  group('buildProjectSections', () {
    testWidgets('one section per project, naming where it runs', (
      tester,
    ) async {
      final context = await _context(tester);
      final sessions = [
        _session(
          'pod1',
          path: '/workspace/k2-gitops',
          machine: 'happy-daemon',
          repoUrl: _remote,
          pod: true,
          ageMin: 20,
        ),
        _session(
          'pod2',
          path: '/workspace/k2-gitops',
          machine: 'happy-daemon',
          repoUrl: _remote,
          pod: true,
          ageMin: 30,
        ),
        _session(
          'local',
          path: '/home/workspace/git/k2-gitops',
          gitRemoteUrl: _remote,
          ageMin: 1,
        ),
        _session('solo', path: '/home/workspace/git/hive', ageMin: 47),
      ];
      final sections = buildProjectSections(
        context,
        sessions,
        machines,
        ui,
        index: SessionProjectIndex.build(sessions),
      );

      expect(sections.map((s) => s.title), ['k2-gitops', 'hive']);
      final k2 = sections.first;
      expect(k2.rows.map((r) => r.session.id), ['local', 'pod1', 'pod2']);
      expect(k2.subtitle, '2 pods · workspace-denys');
      // Mixed project: every row says where it runs.
      expect(k2.rows.every((r) => r.runtime?.icon != null), isTrue);
      expect(k2.rows.first.runtime!.label, 'Runs on workspace-denys');
      expect(k2.rows.last.runtime!.label, 'Runs in a Kubernetes pod');
      // Single-machine project names the machine once, in the header.
      expect(sections.last.subtitle, 'workspace-denys');
      expect(sections.last.rows.single.runtime!.icon, isNull);
      // Quiet rows name the agent, never the project or machine again.
      expect(sections.last.rows.single.runtime!.detail, 'Claude');
    });

    testWidgets('projects waiting on the user come first', (tester) async {
      final context = await _context(tester);
      final sessions = [
        _session('fresh', path: '/w/fresh', ageMin: 1),
        _session('waiting', path: '/w/waiting', ageMin: 300),
      ];
      final sections = buildProjectSections(
        context,
        sessions,
        machines,
        const SessionUiState(
          bySessionId: {
            'waiting': SessionUiEntry(lastMessageRole: 'agent', unreadCount: 2),
          },
        ),
        index: SessionProjectIndex.build(sessions),
      );

      expect(sections.map((s) => s.title), ['waiting', 'fresh']);
      expect(sections.first.subtitle, startsWith('1 '));
    });

    testWidgets('busy projects fold; archived projects preview three', (
      tester,
    ) async {
      final context = await _context(tester);
      final active = [
        for (var i = 0; i < projectBoardFoldThreshold + 1; i++)
          _session('a$i', path: '/w/busy', ageMin: i),
      ];
      final archived = [
        for (var i = 0; i < 5; i++)
          _session('z$i', path: '/w/busy', active: false, ageMin: 100 + i),
      ];
      final index = SessionProjectIndex.build([...active, ...archived]);

      final live = buildProjectSections(
        context,
        active,
        machines,
        ui,
        index: index,
      ).single;
      expect(live.collapseAfter, projectBoardPreview);

      final past = buildProjectSections(
        context,
        archived,
        machines,
        ui,
        index: index,
        archived: true,
      ).single;
      expect(past.collapseAfter, projectBoardArchivedPreview);
      expect(past.subtitle, isNull);
      expect(past.rows.first.session.id, 'z0');
      expect(past.rows.every((r) => r.lane == MissionLane.quiet), isTrue);
    });
  });
}
