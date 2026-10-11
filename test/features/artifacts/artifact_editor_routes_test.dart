import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/artifact.dart';
import 'package:happy_flutter/core/providers/artifacts_notifier.dart';
import 'package:happy_flutter/features/artifacts/artifacts_list_screen.dart';
import 'package:happy_flutter/features/artifacts/edit_artifact_screen.dart';
import 'package:happy_flutter/features/artifacts/new_artifact_screen.dart';

class _Artifacts extends ArtifactsNotifier {
  Completer<void>? saving;
  bool failSave = false;
  int saves = 0;

  @override
  Future<String> createArtifact(String? title, String? body) async {
    if (saving != null) await saving!.future;
    if (failSave) throw StateError('Rejected create');
    return 'new-artifact';
  }

  @override
  Map<String, DecryptedArtifact> build() => {
    for (final id in ['a1', 'a2'])
      id: DecryptedArtifact(
        id: id,
        title: id == 'a1' ? 'First' : 'Second',
        body: 'Original body',
        headerVersion: 1,
        bodyVersion: 1,
        seq: 1,
        createdAt: 1,
        updatedAt: 2,
      ),
  };

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync() async {}

  @override
  Future<void> saveArtifact(String id, {String? title, String? body}) async {
    saves++;
    if (saving != null) await saving!.future;
    if (failSave) throw StateError('Rejected save');
  }
}

Future<void> _openRoute(
  WidgetTester tester,
  _Artifacts notifier, {
  bool list = false,
  bool create = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [artifactsNotifierProvider.overrideWith(() => notifier)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => list
                      ? const ArtifactsListScreen()
                      : create
                      ? const NewArtifactScreen()
                      : const EditArtifactScreen(artifactId: 'a1'),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _dirty(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).first, 'Unsaved title');
  await tester.pump();
}

Future<void> _editInline(WidgetTester tester) async {
  await tester.tap(find.text('First'));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  await _dirty(tester);
}

void main() {
  testWidgets('system back reacts to edits, Stay retains and Leave exits', (
    tester,
  ) async {
    await _openRoute(tester, _Artifacts());
    await _dirty(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved title'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.byType(EditArtifactScreen), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('toolbar back guards content edits and reverts become clean', (
    tester,
  ) async {
    await _openRoute(tester, _Artifacts());
    await tester.enterText(find.byType(TextFormField).last, 'Changed body');
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Original body');
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(EditArtifactScreen), findsNothing);
  });

  testWidgets('successful dirty save exits without discard confirmation', (
    tester,
  ) async {
    final notifier = _Artifacts();
    await _openRoute(tester, notifier);
    await _dirty(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    expect(notifier.saves, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(EditArtifactScreen), findsNothing);
  });

  testWidgets('failed save retains edits and busy save blocks back', (
    tester,
  ) async {
    final notifier = _Artifacts()
      ..saving = Completer<void>()
      ..failSave = true;
    await _openRoute(tester, notifier);
    await _dirty(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(EditArtifactScreen), findsOneWidget);
    notifier.saving!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Unsaved title'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('tablet switching and New require discard approval', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _openRoute(tester, _Artifacts(), list: true);
    await _editInline(tester);
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved title'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved title'), findsOneWidget);
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.byType(EditArtifactScreen), findsNothing);
    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await _dirty(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.byType(NewArtifactScreen), findsOneWidget);
  });

  testWidgets('tablet resize preserves mounted editor and dirty route guard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _openRoute(tester, _Artifacts(), list: true);
    await _editInline(tester);
    final state = tester.state(find.byType(EditArtifactScreen));
    tester.view.physicalSize = const Size(500, 900);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(EditArtifactScreen)), same(state));
    expect(find.text('Unsaved title'), findsOneWidget);
    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(EditArtifactScreen)), same(state));
    expect(find.text('Unsaved title'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('create route back reacts to edits and approved Leave exits', (
    tester,
  ) async {
    await _openRoute(tester, _Artifacts(), create: true);
    await _dirty(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved title'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.byType(NewArtifactScreen), findsNothing);
  });

  testWidgets(
    'tablet create guards switching, New and close, survives resize',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _openRoute(tester, _Artifacts(), list: true);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await _dirty(tester);
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved title'), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(NewArtifactScreen));
      tester.view.physicalSize = const Size(500, 900);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(NewArtifactScreen)), same(state));
      expect(find.text('Unsaved title'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.byType(NewArtifactScreen), findsNothing);
    },
  );

  testWidgets('tablet New discards approved create input into fresh form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _openRoute(tester, _Artifacts(), list: true);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await _dirty(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.byType(NewArtifactScreen), findsOneWidget);
    expect(find.text('Unsaved title'), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      isEmpty,
    );
    await _dirty(tester);
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.byType(NewArtifactScreen), findsNothing);
  });

  testWidgets('failed create keeps dirty input and blocks busy dismissal', (
    tester,
  ) async {
    final notifier = _Artifacts()
      ..saving = Completer<void>()
      ..failSave = true;
    await _openRoute(tester, notifier, create: true);
    await _dirty(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Create'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(NewArtifactScreen), findsOneWidget);
    notifier.saving!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Unsaved title'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('successful embedded create exits without discard dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _openRoute(tester, _Artifacts(), list: true);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await _dirty(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Create'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(NewArtifactScreen), findsNothing);
  });
}
