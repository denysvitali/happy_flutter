import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/utils/session_utils.dart';
import 'package:happy_flutter/features/sessions/widgets/session_list_helpers.dart';
import 'package:happy_flutter/features/sessions/widgets/sessions_view_style.dart';

const _httpsRemote = 'https://github.com/denysvitali/k2-gitops.git';
const _sshRemote = 'git@github.com:denysvitali/k2-gitops.git';
const _repoKey = 'repo:github.com/denysvitali/k2-gitops';

/// Repository-centric grouping: one group per git repository across
/// machines and Kubernetes pods, folders outside a repository kept apart.
void main() {
  Session buildSession(
    String id, {
    String machineId = 'm1',
    String path = '/home/dev/k2-gitops',
    String? repoUrl,
    String? gitRemoteUrl,
    bool active = false,
    int updatedAt = 1000,
  }) {
    return Session(
      id: id,
      seq: 1,
      createdAt: updatedAt,
      updatedAt: updatedAt,
      active: active,
      activeAt: updatedAt,
      metadataVersion: 1,
      agentStateVersion: 1,
      thinking: false,
      presence: active ? 'online' : 'offline',
      metadata: Metadata(
        host: '$machineId-host',
        path: path,
        machineId: machineId,
        repoUrl: repoUrl,
        gitRemoteUrl: gitRemoteUrl,
      ),
    );
  }

  group('parseRepositoryUrl', () {
    test('https, ssh, scp and trailing variants share one key', () {
      for (final remote in [
        _httpsRemote,
        _sshRemote,
        'ssh://git@github.com/denysvitali/k2-gitops',
        'https://GitHub.com/denysvitali/K2-GitOps/',
        'https://token@github.com/denysvitali/k2-gitops.git',
        '  $_httpsRemote\n',
      ]) {
        expect(
          parseRepositoryUrl(remote)?.key,
          'github.com/denysvitali/k2-gitops',
          reason: remote,
        );
      }
    });

    test('keeps the original path case for display', () {
      final repo = parseRepositoryUrl('https://github.com/Owner/Repo.git')!;
      expect(repo.path, 'Owner/Repo');
      expect(repo.namespace, 'github.com/Owner');
    });

    test('rejects local paths and incomplete remotes', () {
      for (final raw in [
        null,
        '',
        '/home/dev/k2-gitops',
        './a:b',
        'https://github.com/',
        'git@github.com:',
      ]) {
        expect(parseRepositoryUrl(raw), isNull, reason: '$raw');
      }
    });
  });

  group('sessionGroupKey', () {
    test('spawn repoUrl wins over the observed remote', () {
      final session = buildSession(
        'a',
        repoUrl: _httpsRemote,
        gitRemoteUrl: 'https://github.com/other/repo.git',
      );
      expect(sessionGroupKey(session, SessionGrouping.repository), _repoKey);
    });

    test('falls back to the folder key outside a repository', () {
      final session = buildSession('a');
      expect(
        sessionGroupKey(session, SessionGrouping.repository),
        sessionFolderKey(session),
      );
      expect(sessionRepositoryKey(session), isNull);
    });

    test('folder grouping ignores repositories', () {
      final session = buildSession('a', gitRemoteUrl: _httpsRemote);
      expect(
        sessionGroupKey(session, SessionGrouping.folder),
        sessionFolderKey(session),
      );
    });
  });

  group('groupAllSessionsByFolder(repository)', () {
    test('merges a local checkout and a pod session of one repository', () {
      final local = buildSession(
        'local',
        gitRemoteUrl: _sshRemote,
        active: true,
        updatedAt: 2000,
      );
      final pod = buildSession(
        'pod',
        machineId: 'k8s',
        path: '/workspace/k2-gitops-abc',
        repoUrl: _httpsRemote,
      );
      final loose = buildSession('loose', path: '/tmp/scratch');

      final groups = groupAllSessionsByFolder(
        [local],
        [pod, loose],
        const {},
        grouping: SessionGrouping.repository,
      );

      expect(groups, hasLength(2));
      final repo = groups.firstWhere((g) => g.header.isRepository);
      expect(repo.header.folderKey, _repoKey);
      expect(repo.header.grouping, SessionGrouping.repository);
      expect(repo.header.displayPath, 'denysvitali/k2-gitops');
      expect(repo.header.machineName, 'github.com/denysvitali');
      expect(repo.activeSessions.map((s) => s.id), ['local']);
      expect(repo.inactiveSessions.map((s) => s.id), ['pod']);

      final unlinked = groups.firstWhere((g) => !g.header.isRepository);
      expect(unlinked.header.folderKey, sessionFolderKey(loose));
      expect(unlinked.header.displayPath, '/tmp/scratch');
    });

    test('default grouping keeps folder behaviour', () {
      final groups = groupAllSessionsByFolder(const [], [
        buildSession('a', gitRemoteUrl: _httpsRemote),
        buildSession('b', machineId: 'm2', gitRemoteUrl: _httpsRemote),
      ], const {});
      expect(groups, hasLength(2));
      expect(groups.every((g) => !g.header.isRepository), isTrue);
    });

    test('selection scope matches the open repository group', () {
      final sessions = [
        buildSession('a', gitRemoteUrl: _httpsRemote),
        buildSession('b', machineId: 'k8s', path: '/w', repoUrl: _sshRemote),
        buildSession('c', path: '/elsewhere'),
      ];
      final groups = groupAllSessionsByFolder(
        const [],
        sessions,
        const {},
        grouping: SessionGrouping.repository,
      );
      final repo = groups.firstWhere((g) => g.header.isRepository);
      expect(
        selectableSessionIds(
          sessions: sessions,
          hideInactive: false,
          folder: repo.header,
        ),
        {'a', 'b'},
      );
    });
  });

  group('SessionsViewStyle', () {
    test('repository round-trips and groups by repository', () {
      final style = SessionsViewStyle.fromWire(
        SessionsViewStyle.repository.wire,
      );
      expect(style, SessionsViewStyle.repository);
      expect(style.workspaceGrouping, SessionGrouping.repository);
      expect(
        SessionsViewStyle.folder.workspaceGrouping,
        SessionGrouping.folder,
      );
      expect(SessionsViewStyle.missionControl.workspaceGrouping, isNull);
    });
  });
}
