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

      notifier.updateArtifact('artifact-1', (existing) {
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
  });
}
