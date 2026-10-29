import 'dart:async';

// Artifact detail / create / edit flows, including the optimistic delete
// path and its rollback, plus the "source session row opens that session"
// routing contract.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/artifact.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/repositories/artifacts_repository.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/features/artifacts/artifact_detail_screen.dart';
import 'package:happy_flutter/features/artifacts/edit_artifact_screen.dart';
import 'package:happy_flutter/features/artifacts/new_artifact_screen.dart';

import '../../helpers/session_open_harness.dart';
import '../../helpers/test_helpers.dart';

const detailArtifactId = 'a1ffee0001';

DecryptedArtifact detailArtifact({
  String id = detailArtifactId,
  String? title = 'Release notes alpha',
  String? body = 'alpha body',
  bool? draft,
  List<String>? sessions,
}) {
  return DecryptedArtifact(
    id: id,
    title: title,
    body: body,
    draft: draft,
    sessions: sessions,
    headerVersion: 1,
    seq: 7,
    createdAt: 1700000000000,
    updatedAt: 1700000600000,
  );
}

/// In-memory stand-in for the artifacts repository.
class FakeArtifactsRepository implements ArtifactsRepository {
  FakeArtifactsRepository({this.createdId = 'new-artifact-1'});

  final String createdId;

  final deleted = <String>[];
  final created = <(String?, String?)>[];
  final updated = <(String, String?, String?)>[];

  Object? deleteError;
  Object? createError;
  Object? updateError;

  @override
  List<DecryptedArtifact> get artifacts => const [];

  @override
  Future<void> fetchArtifactsList() async {}

  @override
  Future<DecryptedArtifact?> fetchArtifactWithBody(String id) async => null;

  @override
  Future<String> createArtifact(String? title, String? body) async {
    created.add((title, body));
    if (createError != null) throw createError!;
    return createdId;
  }

  @override
  Future<void> updateArtifact(String id, {String? title, String? body}) async {
    updated.add((id, title, body));
    if (updateError != null) throw updateError!;
  }

  @override
  Future<void> deleteArtifact(String id) async {
    deleted.add(id);
    if (deleteError != null) throw deleteError!;
  }
}

/// Real [ArtifactsNotifier] behaviour (optimistic delete included) over a
/// seeded, Sync-free state.
class SeededArtifactsNotifier extends ArtifactsNotifier {
  SeededArtifactsNotifier(this._initial);

  final Map<String, DecryptedArtifact> _initial;

  @override
  Map<String, DecryptedArtifact> build() => _initial;

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync() async {}
}

/// Lets a shown SnackBar time out so its performance-mode request is
/// released before the test ends.
Future<void> drainSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late FakeArtifactsRepository repo;
  late SessionOpenRecorder recorder;
  late List<String> routes;

  List<Override> overridesFor(Map<String, DecryptedArtifact> artifacts) => [
    artifactsNotifierProvider.overrideWith(
      () => SeededArtifactsNotifier(artifacts),
    ),
    artifactsRepositoryProvider.overrideWithValue(repo),
    ...contractListOverrides(settings: Settings.new),
  ];

  setUp(() {
    repo = FakeArtifactsRepository();
    recorder = SessionOpenRecorder();
    routes = <String>[];
    createTestSync();
    sync.isInitialized = true;
  });

  tearDown(() {
    sync.isInitialized = false;
    cancelContractChatSwitchMetrics();
    container.dispose();
  });

  Future<void> pumpDetail(
    WidgetTester tester, {
    required Map<String, DecryptedArtifact> artifacts,
    String artifactId = detailArtifactId,
  }) async {
    container = ProviderContainer(overrides: overridesFor(artifacts));
    final router = buildSessionOpenRouter(
      recorder: recorder,
      home: (_) => ArtifactDetailScreen(artifactId: artifactId),
      extraRoutes: [
        recordingRoute('/artifacts', routes, name: 'artifacts'),
        recordingRoute('/artifacts/$artifactId/edit', routes),
      ],
    );
    await tester.pumpWidget(
      buildSessionOpenApp(container: container, router: router),
    );
    await tester.pumpAndSettle();
  }

  group('detail rendering', () {
    testWidgets('shows title, id, sequence and body', (tester) async {
      final a = detailArtifact();
      await pumpDetail(tester, artifacts: {a.id: a});

      expect(find.text('Release notes alpha'), findsOneWidget);
      expect(find.text(detailArtifactId), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('alpha body'), findsOneWidget);
    });

    testWidgets('draft status row only appears for drafts', (tester) async {
      final plain = detailArtifact();
      await pumpDetail(tester, artifacts: {plain.id: plain});
      expect(find.text('Status'), findsNothing);

      container.dispose();
      final draft = detailArtifact(draft: true);
      await pumpDetail(tester, artifacts: {draft.id: draft});
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
    });

    testWidgets('missing artifact renders the not-found state', (tester) async {
      await pumpDetail(tester, artifacts: const {});

      expect(find.text('Not found'), findsOneWidget);
    });

    testWidgets('empty body renders the encrypted placeholder without a '
        'copy action', (tester) async {
      final a = detailArtifact(body: null);
      await pumpDetail(tester, artifacts: {a.id: a});

      expect(find.textContaining('Encrypted content'), findsOneWidget);
      expect(find.text('Copy'), findsNothing);
    });

    testWidgets('failed clipboard write reports failure and permits retry', (
      tester,
    ) async {
      var fail = true;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData' && fail) {
          throw PlatformException(code: 'clipboard-unavailable');
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });
      final a = detailArtifact();
      await pumpDetail(tester, artifacts: {a.id: a});
      final copy = find.widgetWithText(TextButton, 'Copy');
      expect(tester.getSize(copy).height, greaterThanOrEqualTo(44));
      await tester.tap(copy);
      await tester.pump();
      expect(find.text('Done'), findsNothing);
      expect(find.text('Failed to copy text to clipboard'), findsOneWidget);
      fail = false;
      await tester.tap(copy);
      await tester.pump();
      expect(find.widgetWithText(TextButton, 'Done'), findsOneWidget);
      await drainSnackBar(tester);
    });

    testWidgets('late clipboard completion cannot mark newer content copied', (
      tester,
    ) async {
      final pending = Completer<void>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') await pending.future;
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });
      final a = detailArtifact();
      await pumpDetail(tester, artifacts: {a.id: a});
      await tester.tap(find.widgetWithText(TextButton, 'Copy'));
      await tester.pump();
      container
          .read(artifactsNotifierProvider.notifier)
          .addArtifact(detailArtifact(body: 'New body'));
      await tester.pump();
      pending.complete();
      await tester.pump();
      expect(find.text('New body'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Copy'), findsOneWidget);
      expect(find.text('Done'), findsNothing);
    });

    testWidgets('each successful copy renews the feedback duration', (
      tester,
    ) async {
      final a = detailArtifact();
      await pumpDetail(tester, artifacts: {a.id: a});
      await tester.tap(find.widgetWithText(TextButton, 'Copy'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.widgetWithText(TextButton, 'Done'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.widgetWithText(TextButton, 'Done'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.widgetWithText(TextButton, 'Copy'), findsOneWidget);
    });

    testWidgets('edit action pushes the edit route for this artifact', (
      tester,
    ) async {
      final a = detailArtifact();
      await pumpDetail(tester, artifacts: {a.id: a});

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(routes, ['/artifacts/$detailArtifactId/edit']);
    });
  });

  group('source session rows', () {
    testWidgets('each row opens the session it names', (tester) async {
      final a = detailArtifact(
        sessions: [contractAlphaId, contractBravoId, contractCharlieId],
      );
      await pumpDetail(tester, artifacts: {a.id: a});

      expect(find.text(contractCharlieLabel), findsOneWidget);
      await tester.tap(find.text(contractCharlieLabel));
      await tester.pumpAndSettle();

      expect(recorder.opened, [contractCharlieId]);
    });

    testWidgets('unknown session falls back to a short id label and still '
        'routes to the full id', (tester) async {
      const unknownId = 'deadbeefcafe0001';
      final a = detailArtifact(sessions: const [unknownId]);
      await pumpDetail(tester, artifacts: {a.id: a});

      expect(find.text('Session deadbeef'), findsOneWidget);
      await tester.tap(find.text('Session deadbeef'));
      await tester.pumpAndSettle();

      expect(recorder.opened, [unknownId]);
    });

    testWidgets('no sessions means no source-sessions section', (tester) async {
      final a = detailArtifact();
      await pumpDetail(tester, artifacts: {a.id: a});

      expect(find.text('Source sessions'), findsNothing);
    });
  });

  group('optimistic delete', () {
    testWidgets('confirmed delete removes the artifact and leaves the '
        'screen', (tester) async {
      final a = detailArtifact();
      await pumpDetail(tester, artifacts: {a.id: a});

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repo.deleted, [detailArtifactId]);
      expect(container.read(artifactsNotifierProvider), isEmpty);
      expect(routes, ['/artifacts']);
    });

    testWidgets('cancelling keeps the artifact and stays put', (tester) async {
      final a = detailArtifact();
      await pumpDetail(tester, artifacts: {a.id: a});

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(repo.deleted, isEmpty);
      expect(container.read(artifactsNotifierProvider), hasLength(1));
      expect(routes, isEmpty);
      expect(find.text('Release notes alpha'), findsOneWidget);
    });

    testWidgets('a failed delete rolls the artifact back into state', (
      tester,
    ) async {
      repo.deleteError = StateError('server said no');
      final a = detailArtifact();
      await pumpDetail(tester, artifacts: {a.id: a});

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      final state = container.read(artifactsNotifierProvider);
      expect(state.keys, [detailArtifactId]);
      expect(state[detailArtifactId]?.title, 'Release notes alpha');
    });
  });

  group('create', () {
    Future<void> pumpNew(WidgetTester tester) async {
      container = ProviderContainer(overrides: overridesFor(const {}));
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const NewArtifactScreen()),
          GoRoute(
            path: '/artifacts/:artifactId',
            builder: (_, state) {
              routes.add(state.pathParameters['artifactId']!);
              return const Scaffold(body: Text('detail'));
            },
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('creates with trimmed title/content and opens the new id', (
      tester,
    ) async {
      await pumpNew(tester);

      await tester.enterText(find.byType(TextFormField).first, '  Title  ');
      await tester.enterText(find.byType(TextFormField).last, ' Body ');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(repo.created, [('Title', 'Body')]);
      expect(routes, ['new-artifact-1']);
    });

    testWidgets('empty form is rejected before any request', (tester) async {
      await pumpNew(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(repo.created, isEmpty);
      expect(routes, isEmpty);
      expect(find.text('Please enter a title or content.'), findsOneWidget);
      await drainSnackBar(tester);
    });

    testWidgets('a failed create keeps the form and reports the failure', (
      tester,
    ) async {
      repo.createError = StateError('boom');
      await pumpNew(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Title');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(routes, isEmpty);
      expect(find.text('Failed to create artifact'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Create'), findsOneWidget);
      await drainSnackBar(tester);
    });
  });

  group('edit', () {
    Future<void> pumpEdit(
      WidgetTester tester, {
      required Map<String, DecryptedArtifact> artifacts,
    }) async {
      container = ProviderContainer(overrides: overridesFor(artifacts));
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('list')),
          ),
          GoRoute(
            path: '/edit',
            builder: (_, _) =>
                const EditArtifactScreen(artifactId: detailArtifactId),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      // Push instead of deep-linking so a successful save has a page to
      // pop back to, as it does in the app.
      router.push('/edit');
      await tester.pumpAndSettle();
    }

    testWidgets('fields are prefilled from the artifact', (tester) async {
      final a = detailArtifact();
      await pumpEdit(tester, artifacts: {a.id: a});

      expect(
        find.widgetWithText(TextFormField, 'Release notes alpha'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'alpha body'), findsOneWidget);
    });

    testWidgets('saving sends the edited values for this artifact id', (
      tester,
    ) async {
      final a = detailArtifact();
      await pumpEdit(tester, artifacts: {a.id: a});

      await tester.enterText(find.byType(TextFormField).first, 'Renamed alpha');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repo.updated, [(detailArtifactId, 'Renamed alpha', 'alpha body')]);
    });

    testWidgets('a failed save keeps the editor open and reports it', (
      tester,
    ) async {
      repo.updateError = StateError('nope');
      final a = detailArtifact();
      await pumpEdit(tester, artifacts: {a.id: a});

      await tester.enterText(find.byType(TextFormField).first, 'Renamed');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to save artifact'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
      await drainSnackBar(tester);
    });

    testWidgets('missing artifact renders the not-found state', (tester) async {
      await pumpEdit(tester, artifacts: const {});

      expect(find.text('Not found'), findsOneWidget);
    });
  });
}
