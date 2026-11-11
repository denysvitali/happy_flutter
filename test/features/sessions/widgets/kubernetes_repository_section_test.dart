import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/repo_history_storage.dart';
import 'package:happy_flutter/features/sessions/widgets/kubernetes_repository_section.dart';

class _FakeStorage extends MMKVStorage {
  _FakeStorage() : super.testConstructor();

  final Map<String, String> data = {};

  @override
  String? getString(String key) => data[key];

  @override
  void setString(String key, String value) => data[key] = value;
}

/// GitHub as the daemon reports it: acme/legacy defaults to master.
Future<RepoBranchesResponse> _github(String repoUrl, String ref) async {
  if (repoHistoryKey(repoUrl) != 'acme/legacy') {
    return const RepoBranchesResponse(success: false, notFound: true);
  }
  const branches = ['master', 'develop'];
  return RepoBranchesResponse(
    success: true,
    repo: 'acme/legacy',
    defaultBranch: 'master',
    branches: branches,
    refExists: branches.contains(ref) || ref == 'v1.0',
  );
}

void main() {
  late _FakeStorage storage;
  late KubernetesRepositorySelection selection;
  late List<String> lookups;

  setUp(() {
    storage = _FakeStorage();
    selection = const KubernetesRepositorySelection();
    lookups = [];
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    String? url,
    String? ref,
    RepoBranchLookup? lookup = _github,
    RejectedRepoRef? rejected,
  }) async {
    final container = ProviderContainer(
      overrides: [
        repoHistoryProvider.overrideWith(
          () => RepoHistoryNotifier(storage: storage),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: KubernetesRepositorySection(
                initialRepoUrl: url,
                initialRepoRef: ref,
                rejectedRef: rejected,
                lookupDebounce: const Duration(milliseconds: 10),
                lookupBranches: lookup == null
                    ? null
                    : (repoUrl, ref) {
                        lookups.add('$repoUrl@$ref');
                        return lookup(repoUrl, ref);
                      },
                onChanged: (value) => selection = value,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 20));
    return container;
  }

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

  // The reported mistake: "main" for a repository whose branch is "master".
  testWidgets('a typed branch that does not exist is fixed in one tap', (
    tester,
  ) async {
    await pump(tester, url: 'https://github.com/acme/legacy', ref: 'main');

    expect(
      find.text('Branch “main” doesn\'t exist in acme/legacy.'),
      findsOneWidget,
    );
    expect(selection.refMissing, isTrue);
    expect(selection.repoRef, 'main');

    await tester.tap(find.text('Use master'));
    await tester.pumpAndSettle(const Duration(milliseconds: 20));

    expect(fieldText(tester, 'k8s-repo-ref'), 'master');
    expect(selection.repoRef, 'master');
    expect(selection.refMissing, isFalse);
    expect(find.textContaining('doesn\'t exist'), findsNothing);
    // The other real branch stays one tap away.
    expect(find.text('develop'), findsOneWidget);
  });

  testWidgets('an untouched branch follows the repository default', (
    tester,
  ) async {
    await pump(tester);
    expect(fieldText(tester, 'k8s-repo-ref'), 'main');

    await tester.enterText(
      find.byKey(const Key('k8s-repo-url')),
      'https://github.com/acme/legacy',
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 20));

    expect(fieldText(tester, 'k8s-repo-ref'), 'master');
    expect(selection.repoRef, 'master');
    expect(selection.refMissing, isFalse);
    expect(find.textContaining('doesn\'t exist'), findsNothing);
  });

  testWidgets('a tag outside the branch list is accepted', (tester) async {
    await pump(tester, url: 'acme/legacy', ref: 'v1.0');
    expect(selection.refMissing, isFalse);
    expect(find.textContaining('doesn\'t exist'), findsNothing);
  });

  testWidgets('the branch used last time is preselected and offered', (
    tester,
  ) async {
    final seed = ProviderContainer(
      overrides: [
        repoHistoryProvider.overrideWith(
          () => RepoHistoryNotifier(storage: storage),
        ),
      ],
    );
    seed.read(repoHistoryProvider.notifier)
      ..recordUse(repoUrl: 'https://github.com/acme/legacy', repoRef: 'develop')
      ..recordUse(repoUrl: 'acme/other', repoRef: 'trunk');
    seed.dispose();

    await pump(tester, lookup: null);
    // Recent repositories are one tap away, newest first.
    expect(find.text('acme/other'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('repo-suggestion-acme/legacy')));
    await tester.pumpAndSettle();

    expect(fieldText(tester, 'k8s-repo-url'), 'https://github.com/acme/legacy');
    expect(fieldText(tester, 'k8s-repo-ref'), 'develop');
    expect(selection.repoRef, 'develop');
    expect(lookups, isEmpty);
  });

  testWidgets('additional repositories are added, deduplicated and removed', (
    tester,
  ) async {
    await pump(tester, url: 'https://github.com/acme/legacy', ref: 'master');
    final field = find.byKey(const Key('k8s-additional-repo'));

    await tester.enterText(field, 'acme/docs');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.enterText(field, 'https://github.com/acme/docs.git');
    await tester.tap(find.byTooltip('Add repository'));
    await tester.pump();
    // The primary repository is never an additional one.
    await tester.enterText(field, 'acme/legacy');
    await tester.tap(find.byTooltip('Add repository'));
    await tester.pump();
    await tester.enterText(field, 'acme/infra');
    await tester.tap(find.byTooltip('Add repository'));
    await tester.pump();

    expect(selection.additionalRepos, ['acme/docs', 'acme/infra']);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('additional-repo-acme/docs')),
        matching: find.byTooltip('Remove'),
      ),
    );
    await tester.pump();
    expect(selection.additionalRepos, ['acme/infra']);
  });

  testWidgets('a saved repository set restores every field', (tester) async {
    final container = await pump(
      tester,
      url: 'https://github.com/acme/legacy',
      ref: 'master',
    );
    await tester.enterText(
      find.byKey(const Key('k8s-additional-repo')),
      'acme/docs',
    );
    await tester.tap(find.byTooltip('Add repository'));
    await tester.pump();

    await tester.tap(find.byKey(const Key('k8s-save-repo-set')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('k8s-repo-set-name')),
      'Platform',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final saved = container.read(repoHistoryProvider).sets.single;
    expect(saved.name, 'Platform');
    expect(saved.repoUrl, 'https://github.com/acme/legacy');
    expect(saved.repoRef, 'master');
    expect(saved.additionalRepos, ['acme/docs']);

    // A later dialog: empty fields, one tap on the set.
    await tester.pumpWidget(const SizedBox());
    await pump(tester);
    expect(fieldText(tester, 'k8s-repo-url'), isEmpty);
    await tester.tap(find.text('Platform'));
    await tester.pumpAndSettle(const Duration(milliseconds: 20));

    expect(selection.repoUrl, 'https://github.com/acme/legacy');
    expect(selection.repoRef, 'master');
    expect(selection.additionalRepos, ['acme/docs']);
    expect(selection.refMissing, isFalse);
  });

  testWidgets('a spawn refusal offers the daemon-suggested branch', (
    tester,
  ) async {
    // No lookup (older daemon without a token): only the refusal is known.
    await pump(
      tester,
      url: 'https://github.com/acme/legacy',
      ref: 'main',
      lookup: null,
      rejected: (ref: 'main', defaultBranch: 'master'),
    );
    expect(selection.refMissing, isTrue);
    await tester.tap(find.text('Use master'));
    await tester.pumpAndSettle();
    expect(selection.repoRef, 'master');
    expect(selection.refMissing, isFalse);
  });

  test('parses the daemon refusal and ignores other errors', () {
    expect(
      parseRejectedRepoRef(
        'branch "main" does not exist in acme/legacy; its default branch is '
        '"master"',
      ),
      (ref: 'main', defaultBranch: 'master'),
    );
    expect(parseRejectedRepoRef('branch "x/y" does not exist in acme/legacy'), (
      ref: 'x/y',
      defaultBranch: '',
    ));
    expect(parseRejectedRepoRef('Machine is offline'), isNull);
  });

  test('only complete GitHub repositories are looked up', () {
    for (final ok in [
      'https://github.com/acme/widgets.git',
      'git@github.com:acme/widgets.git',
      'acme/widgets',
    ]) {
      expect(isGitHubRepository(ok), isTrue, reason: ok);
    }
    for (final no in [
      '',
      'acme',
      'https://github.com/acme',
      'https://example.com/repo.git',
      'https://gitlab.com/acme/widgets',
    ]) {
      expect(isGitHubRepository(no), isFalse, reason: no);
    }
  });
}
