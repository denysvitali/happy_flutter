// Artifacts list: loading → content/empty, search + count, and the
// "tap row N opens artifact N" routing contract.
//
// Fixture artifacts share a title prefix and differ only by id/suffix so a
// row/id misalignment cannot pass by coincidence.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/artifact.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/features/artifacts/artifacts_list_screen.dart';

import '../../helpers/test_helpers.dart';

const artifactAlphaId = 'a1ffee0001';
const artifactBravoId = 'a1ffee0002';
const artifactCharlieId = 'a1ffee0003';

DecryptedArtifact artifact({
  required String id,
  String? title,
  String? body,
  bool? draft,
  List<String>? sessions,
  int updatedAtOffsetMs = 0,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return DecryptedArtifact(
    id: id,
    title: title,
    body: body,
    draft: draft,
    sessions: sessions,
    headerVersion: 1,
    seq: 1,
    createdAt: now - 120000,
    updatedAt: now - updatedAtOffsetMs,
  );
}

/// Sync-free artifacts notifier seeded from memory.
class StubArtifactsNotifier extends ArtifactsNotifier {
  StubArtifactsNotifier(this._initial, {this.refreshGate});

  final Map<String, DecryptedArtifact> _initial;

  /// When set, `refreshFromSync` blocks on it so the loading state is
  /// observable.
  final Future<void>? refreshGate;

  var refreshCount = 0;

  @override
  Map<String, DecryptedArtifact> build() => _initial;

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync() async {
    refreshCount++;
    if (refreshGate != null) await refreshGate;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late List<String> pushedRoutes;

  /// The default 800x600 test surface is wider than the tablet
  /// breakpoint, which puts the screen in master-detail mode. Most cases
  /// want the phone layout, where a row tap is a route push.
  void useWidth(WidgetTester tester, double logicalWidth) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(logicalWidth, 900);
    addTearDown(tester.view.reset);
  }

  Widget buildApp({
    required Map<String, DecryptedArtifact> artifacts,
    Future<void>? refreshGate,
  }) {
    container = ProviderContainer(
      overrides: [
        artifactsNotifierProvider.overrideWith(
          () => StubArtifactsNotifier(artifacts, refreshGate: refreshGate),
        ),
      ],
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ArtifactsListScreen()),
        GoRoute(
          path: '/artifacts/new',
          builder: (_, _) {
            pushedRoutes.add('new');
            return const Scaffold(body: Text('create'));
          },
        ),
        GoRoute(
          path: '/artifacts/:artifactId',
          builder: (_, state) {
            final id = state.pathParameters['artifactId']!;
            pushedRoutes.add(id);
            return Scaffold(body: Text('detail:$id'));
          },
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  Map<String, DecryptedArtifact> threeArtifacts() {
    final list = [
      artifact(
        id: artifactAlphaId,
        title: 'Release notes alpha',
        body: 'alpha body',
        updatedAtOffsetMs: 1000,
      ),
      artifact(
        id: artifactBravoId,
        title: 'Release notes bravo',
        body: 'bravo body',
        updatedAtOffsetMs: 3000,
        draft: true,
      ),
      artifact(
        id: artifactCharlieId,
        title: 'Release notes charlie',
        body: 'charlie body',
        updatedAtOffsetMs: 2000,
      ),
    ];
    return {for (final a in list) a.id: a};
  }

  setUp(() {
    pushedRoutes = <String>[];
    // Sync is a singleton; wire its InvalidateSync fields to no-ops so the
    // screen's domain subscription cannot reach the network.
    createTestSync();
  });

  tearDown(() {
    container.dispose();
  });

  group('loading and empty states', () {
    testWidgets('shows the shimmer until the first refresh resolves', (
      tester,
    ) async {
      final gate = Completer<void>();
      useWidth(tester, 390);
      await tester.pumpWidget(
        buildApp(artifacts: threeArtifacts(), refreshGate: gate.future),
      );
      await tester.pump();

      expect(find.text('Release notes alpha'), findsNothing);
      expect(find.byType(ListView), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Release notes alpha'), findsOneWidget);
    });

    testWidgets('empty catalog renders the empty state, not a no-results '
        'search state', (tester) async {
      useWidth(tester, 390);
      await tester.pumpWidget(buildApp(artifacts: const {}));
      await tester.pumpAndSettle();

      expect(find.text('No artifacts yet'), findsOneWidget);
      expect(find.text('No matching artifacts'), findsNothing);
    });

    testWidgets('refresh is requested exactly once on mount', (tester) async {
      useWidth(tester, 390);
      await tester.pumpWidget(buildApp(artifacts: threeArtifacts()));
      await tester.pumpAndSettle();

      final notifier =
          container.read(artifactsNotifierProvider.notifier)
              as StubArtifactsNotifier;
      expect(notifier.refreshCount, 1);
    });
  });

  group('list rendering', () {
    testWidgets('renders every artifact newest-first with its body preview', (
      tester,
    ) async {
      useWidth(tester, 390);
      await tester.pumpWidget(buildApp(artifacts: threeArtifacts()));
      await tester.pumpAndSettle();

      expect(find.text('alpha body'), findsOneWidget);
      expect(find.text('bravo body'), findsOneWidget);
      final alphaY = tester.getTopLeft(find.text('Release notes alpha')).dy;
      final charlieY = tester
          .getTopLeft(find.text('Release notes charlie'))
          .dy;
      final bravoY = tester.getTopLeft(find.text('Release notes bravo')).dy;
      expect(alphaY, lessThan(charlieY));
      expect(charlieY, lessThan(bravoY));
    });

    testWidgets('untitled artifact falls back to a short id', (tester) async {
      final untitled = artifact(id: 'abcdefghijklmnop');
      useWidth(tester, 390);
      await tester.pumpWidget(buildApp(artifacts: {untitled.id: untitled}));
      await tester.pumpAndSettle();

      expect(find.text('abcdefghijkl...'), findsOneWidget);
    });

    testWidgets('draft artifacts are badged', (tester) async {
      useWidth(tester, 390);
      await tester.pumpWidget(buildApp(artifacts: threeArtifacts()));
      await tester.pumpAndSettle();

      expect(find.text('Draft'), findsOneWidget);
    });

    testWidgets('the count label reports the whole catalog', (tester) async {
      useWidth(tester, 390);
      await tester.pumpWidget(buildApp(artifacts: threeArtifacts()));
      await tester.pumpAndSettle();

      expect(find.text('3 artifacts'), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('filters by title and updates the count', (tester) async {
      useWidth(tester, 390);
      await tester.pumpWidget(buildApp(artifacts: threeArtifacts()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'charlie');
      await tester.pumpAndSettle();

      expect(find.text('Release notes charlie'), findsOneWidget);
      expect(find.text('Release notes alpha'), findsNothing);
      expect(find.text('1 artifact'), findsOneWidget);
    });

    testWidgets('matches on id and is case-insensitive', (tester) async {
      useWidth(tester, 390);
      await tester.pumpWidget(buildApp(artifacts: threeArtifacts()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), artifactBravoId
          .toUpperCase());
      await tester.pumpAndSettle();

      expect(find.text('Release notes bravo'), findsOneWidget);
      expect(find.text('Release notes alpha'), findsNothing);
    });

    testWidgets('no match shows the no-results state', (tester) async {
      useWidth(tester, 390);
      await tester.pumpWidget(buildApp(artifacts: threeArtifacts()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'nothing-here');
      await tester.pumpAndSettle();

      expect(find.text('No matching artifacts'), findsOneWidget);
      expect(find.text('0 artifacts'), findsOneWidget);
    });

    testWidgets('clearing the query restores every row', (tester) async {
      useWidth(tester, 390);
      await tester.pumpWidget(buildApp(artifacts: threeArtifacts()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'charlie');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(find.text('Release notes alpha'), findsOneWidget);
      expect(find.text('3 artifacts'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('tapping a row opens that artifact id', (tester) async {
      useWidth(tester, 390);
      await tester.pumpWidget(buildApp(artifacts: threeArtifacts()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Release notes charlie'));
      await tester.pumpAndSettle();

      expect(pushedRoutes, [artifactCharlieId]);
    });

    testWidgets('tapping a filtered row still opens its own id', (
      tester,
    ) async {
      useWidth(tester, 390);
      await tester.pumpWidget(buildApp(artifacts: threeArtifacts()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'bravo');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Release notes bravo'));
      await tester.pumpAndSettle();

      expect(pushedRoutes, [artifactBravoId]);
    });

    testWidgets('the FAB opens the create route', (tester) async {
      useWidth(tester, 390);
      await tester.pumpWidget(buildApp(artifacts: threeArtifacts()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(pushedRoutes, ['new']);
    });
  });

  group('tablet master-detail', () {
    testWidgets('a row tap selects that artifact in the side pane instead '
        'of pushing a route', (tester) async {
      useWidth(tester, 1000);
      await tester.pumpWidget(buildApp(artifacts: threeArtifacts()));
      await tester.pumpAndSettle();

      expect(find.text('Select an artifact'), findsOneWidget);

      await tester.tap(find.text('Release notes charlie'));
      await tester.pumpAndSettle();

      expect(pushedRoutes, isEmpty);
      // The pane renders the tapped artifact's own id, not the newest one.
      expect(find.text(artifactCharlieId), findsOneWidget);
      expect(find.text('charlie body'), findsWidgets);
    });

    testWidgets('the FAB opens the inline create pane', (tester) async {
      useWidth(tester, 1000);
      await tester.pumpWidget(buildApp(artifacts: threeArtifacts()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(pushedRoutes, isEmpty);
      expect(find.text('New Artifact'), findsOneWidget);
    });
  });
}
