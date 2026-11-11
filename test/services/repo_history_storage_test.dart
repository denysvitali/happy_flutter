import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/repo_history_storage.dart';

class _FakeStorage extends MMKVStorage {
  _FakeStorage() : super.testConstructor();

  final Map<String, String> data = {};

  @override
  String? getString(String key) => data[key];

  @override
  void setString(String key, String value) => data[key] = value;
}

void main() {
  late _FakeStorage storage;

  ProviderContainer open() {
    final container = ProviderContainer(
      overrides: [
        repoHistoryProvider.overrideWith(
          () => RepoHistoryNotifier(storage: storage),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => storage = _FakeStorage());

  test('every GitHub spelling of a repository shares one history key', () {
    for (final spelling in [
      'https://github.com/Acme/Widgets.git',
      'https://github.com/acme/widgets/',
      'git@github.com:acme/widgets.git',
      'ssh://git@github.com/acme/widgets',
      'acme/widgets',
    ]) {
      expect(repoHistoryKey(spelling), 'acme/widgets', reason: spelling);
    }
    expect(repoHistoryKey('  '), isEmpty);
    expect(
      repoDisplayName('https://github.com/Acme/Widgets.git'),
      'Acme/Widgets',
    );
    expect(repoDisplayName('not a repo'), 'not a repo');
  });

  test('remembers the branch per repository and survives a restart', () {
    final first = open();
    final notifier = first.read(repoHistoryProvider.notifier);
    notifier.recordUse(
      repoUrl: 'https://github.com/acme/legacy',
      repoRef: 'master',
    );
    notifier.recordUse(repoUrl: 'https://github.com/acme/app', repoRef: 'main');
    notifier.recordUse(
      repoUrl: 'git@github.com:acme/legacy.git',
      repoRef: 'release/1.x',
      additionalRepos: ['acme/docs'],
    );

    final restarted = open().read(repoHistoryProvider);
    // The wrong-branch report: "main" was assumed for a "master" repository.
    expect(restarted.branchesFor('acme/legacy'), ['release/1.x', 'master']);
    expect(restarted.lastBranchFor('https://github.com/acme/app.git'), 'main');
    expect(restarted.lastBranchFor('acme/unknown'), isNull);
    // One entry per repository, newest first, in its latest spelling.
    expect(restarted.recentRepos, [
      'git@github.com:acme/legacy.git',
      'acme/docs',
      'https://github.com/acme/app',
    ]);
  });

  test('history is bounded and forgets branches of evicted repositories', () {
    final notifier = open().read(repoHistoryProvider.notifier);
    for (var i = 0; i < RepoHistoryNotifier.maxRepos + 5; i++) {
      notifier.recordUse(repoUrl: 'acme/repo$i', repoRef: 'b$i');
    }
    for (var i = 0; i < RepoHistoryNotifier.maxBranchesPerRepo + 3; i++) {
      notifier.recordUse(repoUrl: 'acme/busy', repoRef: 'branch-$i');
    }
    final state = open().read(repoHistoryProvider);
    expect(state.recentRepos, hasLength(RepoHistoryNotifier.maxRepos));
    expect(state.branchesByRepo.keys, hasLength(RepoHistoryNotifier.maxRepos));
    expect(state.lastBranchFor('acme/repo0'), isNull);
    expect(
      state.branchesFor('acme/busy'),
      hasLength(RepoHistoryNotifier.maxBranchesPerRepo),
    );
    expect(state.branchesFor('acme/busy').first, 'branch-10');
  });

  test('sets persist, replace by name, and delete', () {
    final notifier = open().read(repoHistoryProvider.notifier);
    const set = RepoSet(
      id: '1',
      name: 'Platform',
      repoUrl: 'https://github.com/acme/api',
      repoRef: 'master',
      additionalRepos: ['acme/web', 'acme/infra'],
    );
    notifier.saveSet(set);
    notifier.saveSet(
      const RepoSet(
        id: '2',
        name: 'platform',
        repoUrl: 'acme/api2',
        repoRef: '',
      ),
    );
    notifier.saveSet(
      const RepoSet(
        id: '3',
        name: 'Docs',
        repoUrl: 'acme/docs',
        repoRef: 'main',
      ),
    );
    var sets = open().read(repoHistoryProvider).sets;
    expect(sets.map((s) => s.id), ['3', '2']);
    notifier.saveSet(set);
    sets = open().read(repoHistoryProvider).sets;
    expect(sets.first, set);
    expect(sets.first.additionalRepos, ['acme/web', 'acme/infra']);
    notifier.deleteSet('1');
    expect(open().read(repoHistoryProvider).sets.map((s) => s.id), ['3']);
  });

  test('a corrupt or foreign payload is an empty history', () {
    for (final raw in [
      '{not json',
      '[]',
      '{"s":[{"id":"x"}],"b":{"a":1},"r":[3]}',
    ]) {
      storage.data[RepoHistoryNotifier.storageKey] = raw;
      final state = open().read(repoHistoryProvider);
      expect(state.sets, isEmpty, reason: raw);
      expect(state.recentRepos, isEmpty, reason: raw);
      expect(state.branchesByRepo, isEmpty, reason: raw);
    }
  });
}
