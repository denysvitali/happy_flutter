import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/artifact.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('ArtifactsProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should initialize with empty map', () {
      final artifacts = container.read(artifactsNotifierProvider);
      expect(artifacts, isEmpty);
    });

    test('should add an artifact', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      final artifact = DecryptedArtifact(
        id: 'artifact-1',
        title: 'Test Artifact',
        headerVersion: 1,
        seq: 1,
        createdAt: 1234567890,
        updatedAt: 1234567890,
      );

      notifier.addArtifact(artifact);

      final artifacts = container.read(artifactsNotifierProvider);
      expect(artifacts, hasLength(1));
      expect(artifacts['artifact-1']?.id, 'artifact-1');
    });

    test('should add multiple artifacts', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      final artifact1 = DecryptedArtifact(
        id: 'artifact-1',
        title: 'Artifact 1',
        headerVersion: 1,
        seq: 1,
        createdAt: 1234567890,
        updatedAt: 1234567890,
      );

      final artifact2 = DecryptedArtifact(
        id: 'artifact-2',
        title: 'Artifact 2',
        headerVersion: 1,
        seq: 2,
        createdAt: 1234567891,
        updatedAt: 1234567891,
      );

      notifier.addArtifact(artifact1);
      notifier.addArtifact(artifact2);

      final artifacts = container.read(artifactsNotifierProvider);
      expect(artifacts, hasLength(2));
    });

    test('should set all artifacts at once', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      final artifacts = [
        DecryptedArtifact(
          id: 'artifact-1',
          title: 'Artifact 1',
          headerVersion: 1,
          seq: 1,
          createdAt: 1234567890,
          updatedAt: 1234567890,
        ),
        DecryptedArtifact(
          id: 'artifact-2',
          title: 'Artifact 2',
          headerVersion: 1,
          seq: 2,
          createdAt: 1234567891,
          updatedAt: 1234567891,
        ),
        DecryptedArtifact(
          id: 'artifact-3',
          title: 'Artifact 3',
          headerVersion: 1,
          seq: 3,
          createdAt: 1234567892,
          updatedAt: 1234567892,
        ),
      ];

      notifier.setArtifacts(artifacts);

      final artifactMap = container.read(artifactsNotifierProvider);
      expect(artifactMap, hasLength(3));
      expect(artifactMap['artifact-1']?.id, 'artifact-1');
      expect(artifactMap['artifact-2']?.id, 'artifact-2');
      expect(artifactMap['artifact-3']?.id, 'artifact-3');
    });

    test('should update an existing artifact', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      final artifact = DecryptedArtifact(
        id: 'artifact-1',
        title: 'Original Title',
        headerVersion: 1,
        seq: 1,
        createdAt: 1234567890,
        updatedAt: 1234567890,
      );

      notifier.addArtifact(artifact);

      notifier.updateArtifactInState('artifact-1', (existing) {
        return existing.copyWith(
          title: 'Updated Title',
          headerVersion: 2,
          updatedAt: 1234567900,
        );
      });

      final artifacts = container.read(artifactsNotifierProvider);
      expect(artifacts['artifact-1']?.title, 'Updated Title');
      expect(artifacts['artifact-1']?.updatedAt, 1234567900);
    });

    test('should remove an artifact', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      final artifact1 = DecryptedArtifact(
        id: 'artifact-1',
        title: 'Artifact 1',
        headerVersion: 1,
        seq: 1,
        createdAt: 1234567890,
        updatedAt: 1234567890,
      );

      final artifact2 = DecryptedArtifact(
        id: 'artifact-2',
        title: 'Artifact 2',
        headerVersion: 1,
        seq: 2,
        createdAt: 1234567891,
        updatedAt: 1234567891,
      );

      notifier.addArtifact(artifact1);
      notifier.addArtifact(artifact2);

      expect(container.read(artifactsNotifierProvider), hasLength(2));

      notifier.removeArtifact('artifact-1');

      final artifacts = container.read(artifactsNotifierProvider);
      expect(artifacts, hasLength(1));
      expect(artifacts.containsKey('artifact-1'), isFalse);
      expect(artifacts.containsKey('artifact-2'), isTrue);
    });

    test('should store artifacts with all required fields', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      final artifacts = [
        DecryptedArtifact(
          id: 'artifact-1',
          title: 'Artifact 1',
          headerVersion: 1,
          seq: 1,
          createdAt: 1234567890,
          updatedAt: 1234567890,
        ),
        DecryptedArtifact(
          id: 'artifact-2',
          title: 'Artifact 2',
          headerVersion: 1,
          seq: 2,
          createdAt: 1234567891,
          updatedAt: 1234567891,
        ),
        DecryptedArtifact(
          id: 'artifact-3',
          title: 'Artifact 3',
          headerVersion: 1,
          seq: 3,
          createdAt: 1234567892,
          updatedAt: 1234567892,
        ),
      ];

      notifier.setArtifacts(artifacts);

      final storedArtifacts = container.read(artifactsNotifierProvider);
      expect(storedArtifacts, hasLength(3));
      expect(storedArtifacts['artifact-1']?.id, 'artifact-1');
      expect(storedArtifacts['artifact-2']?.id, 'artifact-2');
      expect(storedArtifacts['artifact-3']?.id, 'artifact-3');
    });

    test('should handle artifacts with body', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      final artifactWithBody = DecryptedArtifact(
        id: 'artifact-1',
        title: 'Artifact with body',
        body: 'decrypted-body-content',
        headerVersion: 1,
        bodyVersion: 1,
        seq: 1,
        createdAt: 1234567890,
        updatedAt: 1234567890,
      );

      notifier.addArtifact(artifactWithBody);

      final artifacts = container.read(artifactsNotifierProvider);
      expect(artifacts['artifact-1']?.body, 'decrypted-body-content');
      expect(artifacts['artifact-1']?.bodyVersion, 1);
    });

    test('should handle artifacts without optional fields', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      final artifactWithoutOptional = DecryptedArtifact(
        id: 'artifact-1',
        headerVersion: 1,
        seq: 1,
        createdAt: 1234567890,
        updatedAt: 1234567890,
      );

      notifier.addArtifact(artifactWithoutOptional);

      final artifacts = container.read(artifactsNotifierProvider);
      expect(artifacts['artifact-1']?.body, isNull);
      expect(artifacts['artifact-1']?.bodyVersion, isNull);
    });

    test('should clear all artifacts', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      notifier.addArtifact(DecryptedArtifact(
        id: 'a1',
        headerVersion: 1,
        seq: 1,
        createdAt: 1000,
        updatedAt: 1000,
      ));
      notifier.addArtifact(DecryptedArtifact(
        id: 'a2',
        headerVersion: 1,
        seq: 2,
        createdAt: 2000,
        updatedAt: 2000,
      ));

      expect(container.read(artifactsNotifierProvider), hasLength(2));

      notifier.clear();

      expect(container.read(artifactsNotifierProvider), isEmpty);
    });

    test('updateArtifact does nothing for non-existent id', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      notifier.addArtifact(DecryptedArtifact(
        id: 'existing',
        headerVersion: 1,
        seq: 1,
        createdAt: 1000,
        updatedAt: 1000,
      ));

      // Should not throw and should not modify state.
      notifier.updateArtifactInState('non-existent', (a) => a.copyWith(title: 'X'));

      final artifacts = container.read(artifactsNotifierProvider);
      expect(artifacts, hasLength(1));
      expect(artifacts['existing']?.title, isNull);
    });

    test('adding artifact with same id overwrites previous', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      notifier.addArtifact(DecryptedArtifact(
        id: 'dup',
        title: 'First',
        headerVersion: 1,
        seq: 1,
        createdAt: 1000,
        updatedAt: 1000,
      ));

      notifier.addArtifact(DecryptedArtifact(
        id: 'dup',
        title: 'Second',
        headerVersion: 2,
        seq: 2,
        createdAt: 2000,
        updatedAt: 2000,
      ));

      final artifacts = container.read(artifactsNotifierProvider);
      expect(artifacts, hasLength(1));
      expect(artifacts['dup']?.title, 'Second');
      expect(artifacts['dup']?.headerVersion, 2);
    });

    test('setArtifacts replaces all existing artifacts', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      notifier.addArtifact(DecryptedArtifact(
        id: 'old-1',
        headerVersion: 1,
        seq: 1,
        createdAt: 1000,
        updatedAt: 1000,
      ));

      notifier.setArtifacts([
        DecryptedArtifact(
          id: 'new-1',
          headerVersion: 1,
          seq: 10,
          createdAt: 5000,
          updatedAt: 5000,
        ),
      ]);

      final artifacts = container.read(artifactsNotifierProvider);
      expect(artifacts, hasLength(1));
      expect(artifacts.containsKey('old-1'), isFalse);
      expect(artifacts['new-1']?.id, 'new-1');
    });

    test('setArtifacts with empty list clears all', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      notifier.addArtifact(DecryptedArtifact(
        id: 'a',
        headerVersion: 1,
        seq: 1,
        createdAt: 1000,
        updatedAt: 1000,
      ));

      notifier.setArtifacts([]);

      expect(container.read(artifactsNotifierProvider), isEmpty);
    });

    test('removeArtifact on non-existent id is a no-op', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      notifier.addArtifact(DecryptedArtifact(
        id: 'keep',
        headerVersion: 1,
        seq: 1,
        createdAt: 1000,
        updatedAt: 1000,
      ));

      // Should not throw.
      notifier.removeArtifact('non-existent');

      final artifacts = container.read(artifactsNotifierProvider);
      expect(artifacts, hasLength(1));
      expect(artifacts['keep'], isNotNull);
    });

    test('loadFromSync handles uninitialized sync', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      // Should not throw when sync is not initialized.
      notifier.loadFromSync();

      final artifacts = container.read(artifactsNotifierProvider);
      expect(artifacts, isEmpty);
    });

    test('refreshFromSync handles uninitialized sync', () async {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      // Should not throw when sync is not initialized.
      await notifier.refreshFromSync();

      final artifacts = container.read(artifactsNotifierProvider);
      expect(artifacts, isEmpty);
    });

    test('state preserves draft flag', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      notifier.addArtifact(DecryptedArtifact(
        id: 'draft-1',
        title: 'Draft Artifact',
        draft: true,
        headerVersion: 1,
        seq: 1,
        createdAt: 1000,
        updatedAt: 1000,
      ));

      notifier.addArtifact(DecryptedArtifact(
        id: 'published-1',
        title: 'Published Artifact',
        draft: false,
        headerVersion: 1,
        seq: 2,
        createdAt: 2000,
        updatedAt: 2000,
      ));

      final artifacts = container.read(artifactsNotifierProvider);
      expect(artifacts['draft-1']?.draft, isTrue);
      expect(artifacts['published-1']?.draft, isFalse);
    });

    test('state preserves sessions list', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      notifier.addArtifact(DecryptedArtifact(
        id: 'with-sessions',
        headerVersion: 1,
        seq: 1,
        createdAt: 1000,
        updatedAt: 1000,
        sessions: ['sess-1', 'sess-2'],
      ));

      final artifacts = container.read(artifactsNotifierProvider);
      expect(artifacts['with-sessions']?.sessions, ['sess-1', 'sess-2']);
    });

    test('updateArtifact preserves unchanged fields', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      notifier.addArtifact(DecryptedArtifact(
        id: 'upd-1',
        title: 'Original',
        body: 'Body text',
        draft: true,
        headerVersion: 1,
        seq: 1,
        createdAt: 1000,
        updatedAt: 1000,
        sessions: ['s1'],
      ));

      notifier.updateArtifactInState('upd-1', (a) => a.copyWith(title: 'Changed'));

      final artifact = container.read(artifactsNotifierProvider)['upd-1'];
      expect(artifact?.title, 'Changed');
      expect(artifact?.body, 'Body text');
      expect(artifact?.draft, isTrue);
      expect(artifact?.sessions, ['s1']);
    });
  });
}
