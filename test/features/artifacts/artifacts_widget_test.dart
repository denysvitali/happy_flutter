import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/artifact.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/artifacts_notifier.dart';

/// Widget tests for artifact screens.
///
/// These tests verify UI rendering based on provider state without
/// requiring the sync singleton or network calls.

// ── Helpers ────────────────────────────────────────────────────

DecryptedArtifact _makeArtifact({
  required String id,
  String? title,
  String? body,
  bool? draft,
  List<String>? sessions,
  bool isDecrypted = true,
  int headerVersion = 1,
  int seq = 1,
  int? createdAt,
  int? updatedAt,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return DecryptedArtifact(
    id: id,
    title: title,
    body: body,
    draft: draft,
    sessions: sessions,
    isDecrypted: isDecrypted,
    headerVersion: headerVersion,
    seq: seq,
    createdAt: createdAt ?? now - 60000,
    updatedAt: updatedAt ?? now,
  );
}

/// A simple test wrapper that provides a [ProviderScope] with
/// pre-seeded artifact state.
Widget _wrapWithProvider({
  required Map<String, DecryptedArtifact> artifacts,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      artifactsNotifierProvider.overrideWith(() {
        final notifier = ArtifactsNotifier();
        // Build the notifier then set state.
        notifier.build();
        notifier.setArtifacts(artifacts.values.toList());
        return notifier;
      }),
    ],
    child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
        home: child),
  );
}

// ── ArtifactsListScreen logic tests ────────────────────────────

// We test the filter/sort logic indirectly through the provider state.
// Since the screen depends on sync singleton for initState, we test
// the provider behavior that the screen relies on.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArtifactsNotifier - provider state for UI', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('empty state: provider returns empty map', () {
      final artifacts = container.read(artifactsNotifierProvider);
      expect(artifacts, isEmpty);
    });

    test('with artifacts: provider returns map keyed by id', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);
      final items = [
        _makeArtifact(id: 'a1', title: 'First'),
        _makeArtifact(id: 'a2', title: 'Second'),
      ];
      notifier.setArtifacts(items);

      final state = container.read(artifactsNotifierProvider);
      expect(state, hasLength(2));
      expect(state['a1']?.title, 'First');
      expect(state['a2']?.title, 'Second');
    });

    test('artifacts can be filtered by title', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);
      notifier.setArtifacts([
        _makeArtifact(id: 'a1', title: 'Meeting Notes'),
        _makeArtifact(id: 'a2', title: 'Project Plan'),
        _makeArtifact(id: 'a3', title: 'Meeting Agenda'),
      ]);

      final state = container.read(artifactsNotifierProvider);
      final meetingArtifacts = state.values
          .where((a) => (a.title ?? '').toLowerCase().contains('meeting'))
          .toList();

      expect(meetingArtifacts, hasLength(2));
    });

    test('artifacts can be sorted by updatedAt descending', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);
      notifier.setArtifacts([
        _makeArtifact(id: 'old', updatedAt: 1000),
        _makeArtifact(id: 'new', updatedAt: 3000),
        _makeArtifact(id: 'mid', updatedAt: 2000),
      ]);

      final state = container.read(artifactsNotifierProvider);
      final sorted = state.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      expect(sorted.map((a) => a.id), ['new', 'mid', 'old']);
    });

    test('draft artifacts are flagged correctly', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);
      notifier.setArtifacts([
        _makeArtifact(id: 'd1', title: 'Draft', draft: true),
        _makeArtifact(id: 'p1', title: 'Published', draft: false),
        _makeArtifact(id: 'n1', title: 'No flag'),
      ]);

      final state = container.read(artifactsNotifierProvider);

      expect(state['d1']?.draft, isTrue);
      expect(state['p1']?.draft, isFalse);
      expect(state['n1']?.draft, isNull);
    });

    test('artifacts with sessions show linked sessions', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);
      notifier.setArtifacts([
        _makeArtifact(id: 'linked', sessions: ['s1', 's2', 's3']),
        _makeArtifact(id: 'unlinked'),
      ]);

      final state = container.read(artifactsNotifierProvider);

      expect(state['linked']?.sessions, hasLength(3));
      expect(state['unlinked']?.sessions, isNull);
    });

    test('undecrypted artifacts are flagged', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);
      notifier.setArtifacts([
        _makeArtifact(id: 'ok', isDecrypted: true),
        _makeArtifact(id: 'fail', isDecrypted: false),
      ]);

      final state = container.read(artifactsNotifierProvider);

      expect(state['ok']?.isDecrypted, isTrue);
      expect(state['fail']?.isDecrypted, isFalse);
    });

    test('artifact detail lookup by id', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);
      notifier.setArtifacts([
        _makeArtifact(
          id: 'detail-1',
          title: 'Detail Test',
          body: 'Body content here',
          createdAt: 1700000000000,
          updatedAt: 1700001000000,
        ),
      ]);

      final state = container.read(artifactsNotifierProvider);
      final artifact = state['detail-1'];

      expect(artifact, isNotNull);
      expect(artifact?.title, 'Detail Test');
      expect(artifact?.body, 'Body content here');
    });

    test('artifact lookup for non-existent id returns null', () {
      final state = container.read(artifactsNotifierProvider);
      expect(state['does-not-exist'], isNull);
    });

    test('adding artifact updates state for UI', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      expect(container.read(artifactsNotifierProvider), isEmpty);

      notifier.addArtifact(_makeArtifact(id: 'new-1', title: 'Created'));

      final state = container.read(artifactsNotifierProvider);
      expect(state, hasLength(1));
      expect(state['new-1']?.title, 'Created');
    });

    test('removing artifact updates state for UI', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);
      notifier.setArtifacts([
        _makeArtifact(id: 'a'),
        _makeArtifact(id: 'b'),
      ]);

      notifier.removeArtifact('a');

      final state = container.read(artifactsNotifierProvider);
      expect(state, hasLength(1));
      expect(state.containsKey('a'), isFalse);
      expect(state['b'], isNotNull);
    });

    test('updating artifact reflects in state', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);
      notifier.addArtifact(
        _makeArtifact(id: 'upd', title: 'Original', body: 'Old body'),
      );

      notifier.updateArtifactInState(
        'upd',
        (a) => a.copyWith(title: 'Modified', body: 'New body'),
      );

      final state = container.read(artifactsNotifierProvider);
      expect(state['upd']?.title, 'Modified');
      expect(state['upd']?.body, 'New body');
    });

    test('search by id matches', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);
      notifier.setArtifacts([
        _makeArtifact(id: 'abc123', title: 'No match in title'),
      ]);

      final state = container.read(artifactsNotifierProvider);
      final query = 'abc';
      final results = state.values.where((a) {
        final title = (a.title ?? '').toLowerCase();
        final id = a.id.toLowerCase();
        return title.contains(query) || id.contains(query);
      }).toList();

      expect(results, hasLength(1));
    });
  });

  group('ArtifactDetailScreen - state scenarios', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('looking up artifact after deletion returns null', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);
      notifier.addArtifact(_makeArtifact(id: 'to-delete', title: 'Delete Me'));

      expect(
        container.read(artifactsNotifierProvider)['to-delete'],
        isNotNull,
      );

      notifier.removeArtifact('to-delete');

      expect(
        container.read(artifactsNotifierProvider)['to-delete'],
        isNull,
      );
    });

    test('artifact with title shows title; without shows id fallback', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);
      notifier.setArtifacts([
        _makeArtifact(id: 'has-title', title: 'My Title'),
        _makeArtifact(id: 'no-title-1234567890'),
      ]);

      final state = container.read(artifactsNotifierProvider);

      // With title: use title.
      expect(state['has-title']?.title, 'My Title');

      // Without title: UI would fallback to id (first 12 chars).
      expect(state['no-title-1234567890']?.title, isNull);
    });
  });
}
