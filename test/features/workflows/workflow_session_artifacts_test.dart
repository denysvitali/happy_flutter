import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/artifact.dart';
import 'package:happy_flutter/core/providers/artifacts_notifier.dart';
import 'package:happy_flutter/features/workflows/workflow_session_artifacts.dart';

void main() {
  testWidgets('filters session links and drafts, then opens artifact detail', (
    tester,
  ) async {
    final notifier = _Artifacts([
      _artifact('older', sessions: ['session'], updatedAt: 1),
      _artifact('newer', sessions: ['other', 'session'], updatedAt: 2),
      _artifact('other-session', sessions: ['other']),
      _artifact('unlinked'),
      _artifact('draft', sessions: ['session'], draft: true),
    ]);
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_harness(notifier, router));
    await tester.pumpAndSettle();

    expect(find.text('Session artifacts'), findsOneWidget);
    expect(
      find.text(
        'Artifacts linked to this session may come from any workflow run',
      ),
      findsOneWidget,
    );
    expect(find.text('newer'), findsOneWidget);
    expect(find.text('older'), findsOneWidget);
    expect(find.text('other-session'), findsNothing);
    expect(find.text('unlinked'), findsNothing);
    expect(find.text('draft'), findsNothing);
    expect(
      tester.getTopLeft(find.text('newer')).dy,
      lessThan(tester.getTopLeft(find.text('older')).dy),
    );

    await tester.tap(find.text('newer'));
    await tester.pumpAndSettle();
    expect(find.text('Detail: newer'), findsOneWidget);
  });

  testWidgets(
    'empty session and provider updates stay readable at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final notifier = _Artifacts([]);
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        _harness(notifier, router, textScaler: TextScaler.linear(2)),
      );
      await tester.pumpAndSettle();
      expect(find.text('No artifacts yet'), findsOneWidget);
      expect(tester.takeException(), isNull);

      notifier.addArtifact(_artifact('arrived', sessions: ['session']));
      await tester.pump();
      expect(find.text('No artifacts yet'), findsNothing);
      expect(find.text('arrived'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

GoRouter _router() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(
        body: CustomScrollView(
          slivers: [WorkflowSessionArtifacts(sessionId: 'session')],
        ),
      ),
    ),
    GoRoute(
      path: '/artifacts/:artifactId',
      name: 'artifact-detail',
      builder: (context, state) =>
          Scaffold(body: Text('Detail: ${state.pathParameters['artifactId']}')),
    ),
  ],
);

Widget _harness(
  _Artifacts notifier,
  GoRouter router, {
  TextScaler textScaler = TextScaler.noScaling,
}) => ProviderScope(
  overrides: [artifactsNotifierProvider.overrideWith(() => notifier)],
  child: MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
  ),
);

DecryptedArtifact _artifact(
  String id, {
  List<String>? sessions,
  bool? draft,
  int updatedAt = 0,
}) => DecryptedArtifact(
  id: id,
  title: id,
  sessions: sessions,
  draft: draft,
  headerVersion: 0,
  seq: 0,
  createdAt: 0,
  updatedAt: updatedAt,
);

class _Artifacts extends ArtifactsNotifier {
  _Artifacts(this.artifacts);

  final List<DecryptedArtifact> artifacts;

  @override
  Map<String, DecryptedArtifact> build() => {
    for (final artifact in artifacts) artifact.id: artifact,
  };

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync() async {}
}
