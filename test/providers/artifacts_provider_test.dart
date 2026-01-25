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
        sessions: ['session-1'],
        draft: false,
        headerVersion: 1,
        seq: 1,
        createdAt: 1234567890,
        updatedAt: 1234567890,
      );

      notifier.addArtifact(artifact);

      final artifacts = container.read(artifactsNotifierProvider);
      expect(artifacts, hasLength(1));
      expect(artifacts['artifact-1']?.id, 'artifact-1');
      expect(artifacts['artifact-1']?.title, 'Test Artifact');
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
      expect(artifactMap['artifact-1']?.title, 'Artifact 1');
      expect(artifactMap['artifact-2']?.title, 'Artifact 2');
      expect(artifactMap['artifact-3']?.title, 'Artifact 3');
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

      notifier.updateArtifact('artifact-1', (existing) {
        return existing.copyWith(
          title: 'Updated Title',
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

    test('should filter artifacts by session ID', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      final artifacts = [
        DecryptedArtifact(
          id: 'artifact-1',
          title: 'Session 1 Artifact',
          sessions: ['session-1'],
          headerVersion: 1,
          seq: 1,
          createdAt: 1234567890,
          updatedAt: 1234567890,
        ),
        DecryptedArtifact(
          id: 'artifact-2',
          title: 'Session 2 Artifact',
          sessions: ['session-2'],
          headerVersion: 1,
          seq: 2,
          createdAt: 1234567891,
          updatedAt: 1234567891,
        ),
        DecryptedArtifact(
          id: 'artifact-3',
          title: 'Shared Artifact',
          sessions: ['session-1', 'session-2'],
          headerVersion: 1,
          seq: 3,
          createdAt: 1234567892,
          updatedAt: 1234567892,
        ),
      ];

      notifier.setArtifacts(artifacts);

      final session1Artifacts = notifier.getBySession('session-1');
      final session2Artifacts = notifier.getBySession('session-2');

      expect(session1Artifacts, hasLength(2));
      expect(session2Artifacts, hasLength(2));

      expect(
        session1Artifacts.any((a) => a.id == 'artifact-1'),
        isTrue,
      );
      expect(
        session1Artifacts.any((a) => a.id == 'artifact-3'),
        isTrue,
      );

      expect(
        session2Artifacts.any((a) => a.id == 'artifact-2'),
        isTrue,
      );
      expect(
        session2Artifacts.any((a) => a.id == 'artifact-3'),
        isTrue,
      );
    });

    test('should handle draft artifacts', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      final draftArtifact = DecryptedArtifact(
        id: 'draft-1',
        title: 'Draft Artifact',
        draft: true,
        headerVersion: 1,
        seq: 1,
        createdAt: 1234567890,
        updatedAt: 1234567890,
      );

      final publishedArtifact = DecryptedArtifact(
        id: 'published-1',
        title: 'Published Artifact',
        draft: false,
        headerVersion: 1,
        seq: 2,
        createdAt: 1234567891,
        updatedAt: 1234567891,
      );

      notifier.addArtifact(draftArtifact);
      notifier.addArtifact(publishedArtifact);

      final artifacts = container.read(artifactsNotifierProvider);
      expect(artifacts['draft-1']?.draft, isTrue);
      expect(artifacts['published-1']?.draft, isFalse);
    });

    test('should handle artifacts with body content', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      final artifactWithBody = DecryptedArtifact(
        id: 'artifact-1',
        title: 'Artifact with Body',
        body: 'This is the body content',
        headerVersion: 1,
        bodyVersion: 1,
        seq: 1,
        createdAt: 1234567890,
        updatedAt: 1234567890,
      );

      notifier.addArtifact(artifactWithBody);

      final artifacts = container.read(artifactsNotifierProvider);
      expect(artifacts['artifact-1']?.body, 'This is the body content');
      expect(artifacts['artifact-1']?.bodyVersion, 1);
    });

    test('should handle artifacts without sessions', () {
      final notifier = container.read(artifactsNotifierProvider.notifier);

      final artifactWithoutSession = DecryptedArtifact(
        id: 'artifact-1',
        title: 'Orphan Artifact',
        sessions: null,
        headerVersion: 1,
        seq: 1,
        createdAt: 1234567890,
        updatedAt: 1234567890,
      );

      notifier.addArtifact(artifactWithoutSession);

      final sessionArtifacts = notifier.getBySession('session-1');
      expect(sessionArtifacts, isEmpty);
    });
  });
}
