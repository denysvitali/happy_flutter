import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/artifact.dart';

void main() {
  // ── Artifact (encrypted) ─────────────────────────────────────

  group('Artifact', () {
    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = <String, dynamic>{
          'id': 'art-1',
          'header': 'encrypted-header-base64',
          'headerVersion': 3,
          'body': 'encrypted-body-base64',
          'bodyVersion': 2,
          'dataEncryptionKey': 'dek-base64',
          'seq': 42,
          'createdAt': 1700000000000,
          'updatedAt': 1700001000000,
        };

        final artifact = Artifact.fromJson(json);

        expect(artifact.id, 'art-1');
        expect(artifact.header, 'encrypted-header-base64');
        expect(artifact.headerVersion, 3);
        expect(artifact.body, 'encrypted-body-base64');
        expect(artifact.bodyVersion, 2);
        expect(artifact.dataEncryptionKey, 'dek-base64');
        expect(artifact.seq, 42);
        expect(artifact.createdAt, 1700000000000);
        expect(artifact.updatedAt, 1700001000000);
      });

      test('handles optional body fields as null', () {
        final json = <String, dynamic>{
          'id': 'art-2',
          'header': 'hdr',
          'headerVersion': 1,
          'dataEncryptionKey': 'dek',
          'seq': 1,
          'createdAt': 1000,
          'updatedAt': 2000,
        };

        final artifact = Artifact.fromJson(json);

        expect(artifact.body, isNull);
        expect(artifact.bodyVersion, isNull);
      });

      test('accepts double for int fields (API compatibility)', () {
        final json = <String, dynamic>{
          'id': 'art-3',
          'header': 'hdr',
          'headerVersion': 1.0,
          'dataEncryptionKey': 'dek',
          'seq': 5.0,
          'createdAt': 1000.0,
          'updatedAt': 2000.0,
        };

        final artifact = Artifact.fromJson(json);

        expect(artifact.headerVersion, 1);
        expect(artifact.seq, 5);
        expect(artifact.createdAt, 1000);
      });

      test('throws on missing required string field', () {
        final json = <String, dynamic>{
          'header': 'hdr',
          'headerVersion': 1,
          'dataEncryptionKey': 'dek',
          'seq': 1,
          'createdAt': 1000,
          'updatedAt': 2000,
        };

        expect(() => Artifact.fromJson(json), throwsFormatException);
      });

      test('throws on missing required int field', () {
        final json = <String, dynamic>{
          'id': 'art-4',
          'header': 'hdr',
          'headerVersion': 1,
          'dataEncryptionKey': 'dek',
          'seq': 1,
          'createdAt': 1000,
          // updatedAt missing
        };

        expect(() => Artifact.fromJson(json), throwsFormatException);
      });
    });

    group('toJson', () {
      test('round-trips through fromJson', () {
        final original = Artifact(
          id: 'art-rt',
          header: 'hdr',
          headerVersion: 2,
          body: 'body',
          bodyVersion: 1,
          dataEncryptionKey: 'dek',
          seq: 10,
          createdAt: 1700000000000,
          updatedAt: 1700001000000,
        );

        final json = original.toJson();
        final restored = Artifact.fromJson(json);

        expect(restored, equals(original));
      });

      test('includes null body fields', () {
        final artifact = Artifact(
          id: 'art-null',
          header: 'hdr',
          headerVersion: 1,
          dataEncryptionKey: 'dek',
          seq: 1,
          createdAt: 1000,
          updatedAt: 2000,
        );

        final json = artifact.toJson();

        expect(json['body'], isNull);
        expect(json['bodyVersion'], isNull);
      });
    });

    group('copyWith', () {
      test('copies with overridden fields', () {
        final original = Artifact(
          id: 'art-cw',
          header: 'hdr',
          headerVersion: 1,
          dataEncryptionKey: 'dek',
          seq: 1,
          createdAt: 1000,
          updatedAt: 2000,
        );

        final updated = original.copyWith(
          header: 'new-hdr',
          headerVersion: 2,
          updatedAt: 3000,
        );

        expect(updated.id, 'art-cw');
        expect(updated.header, 'new-hdr');
        expect(updated.headerVersion, 2);
        expect(updated.updatedAt, 3000);
        expect(updated.dataEncryptionKey, 'dek');
        expect(updated.seq, 1);
      });

      test('preserves original when no overrides', () {
        final original = Artifact(
          id: 'art-cw2',
          header: 'hdr',
          headerVersion: 1,
          dataEncryptionKey: 'dek',
          seq: 1,
          createdAt: 1000,
          updatedAt: 2000,
        );

        final copy = original.copyWith();

        expect(copy, equals(original));
      });
    });

    group('equality', () {
      test('equal artifacts compare equal', () {
        final a = Artifact(
          id: 'x', header: 'h', headerVersion: 1,
          dataEncryptionKey: 'k', seq: 1,
          createdAt: 100, updatedAt: 200,
        );
        final b = Artifact(
          id: 'x', header: 'h', headerVersion: 1,
          dataEncryptionKey: 'k', seq: 1,
          createdAt: 100, updatedAt: 200,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different artifacts are not equal', () {
        final a = Artifact(
          id: 'x', header: 'h', headerVersion: 1,
          dataEncryptionKey: 'k', seq: 1,
          createdAt: 100, updatedAt: 200,
        );
        final b = a.copyWith(id: 'y');

        expect(a, isNot(equals(b)));
      });
    });
  });

  // ── ArtifactHeader ───────────────────────────────────────────

  group('ArtifactHeader', () {
    test('fromJson parses all fields', () {
      final json = <String, dynamic>{
        'title': 'My Artifact',
        'sessions': ['s1', 's2'],
        'draft': true,
      };

      final header = ArtifactHeader.fromJson(json);

      expect(header.title, 'My Artifact');
      expect(header.sessions, ['s1', 's2']);
      expect(header.draft, isTrue);
    });

    test('fromJson handles null optional fields', () {
      final json = <String, dynamic>{};

      final header = ArtifactHeader.fromJson(json);

      expect(header.title, isNull);
      expect(header.sessions, isNull);
      expect(header.draft, isNull);
    });

    test('toJson round-trips', () {
      final original = ArtifactHeader(
        title: 'Test',
        sessions: ['a', 'b'],
        draft: false,
      );

      final json = original.toJson();
      final restored = ArtifactHeader.fromJson(json);

      // Compare fields individually (sessions uses list identity).
      expect(restored.title, original.title);
      expect(restored.sessions, original.sessions);
      expect(restored.draft, original.draft);
    });

    test('equality with same list instance', () {
      final sessions = ['s'];
      final a = ArtifactHeader(title: 'T', sessions: sessions, draft: true);
      final b = ArtifactHeader(title: 'T', sessions: sessions, draft: true);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality with null fields', () {
      final a = ArtifactHeader();
      final b = ArtifactHeader();

      expect(a, equals(b));
    });
  });

  // ── ArtifactBody ─────────────────────────────────────────────

  group('ArtifactBody', () {
    test('fromJson parses body', () {
      final json = <String, dynamic>{'body': 'content here'};

      final body = ArtifactBody.fromJson(json);

      expect(body.body, 'content here');
    });

    test('fromJson handles null body', () {
      final json = <String, dynamic>{};

      final body = ArtifactBody.fromJson(json);

      expect(body.body, isNull);
    });

    test('toJson includes body', () {
      final body = ArtifactBody(body: 'data');
      final json = body.toJson();

      expect(json['body'], 'data');
    });
  });

  // ── DecryptedArtifact ────────────────────────────────────────

  group('DecryptedArtifact', () {
    group('fromJson', () {
      test('parses all fields', () {
        final json = <String, dynamic>{
          'id': 'da-1',
          'title': 'Decrypted',
          'sessions': ['s1'],
          'draft': false,
          'body': 'plain text',
          'headerVersion': 2,
          'bodyVersion': 1,
          'seq': 5,
          'createdAt': 1700000000000,
          'updatedAt': 1700001000000,
          'isDecrypted': true,
        };

        final da = DecryptedArtifact.fromJson(json);

        expect(da.id, 'da-1');
        expect(da.title, 'Decrypted');
        expect(da.sessions, ['s1']);
        expect(da.draft, isFalse);
        expect(da.body, 'plain text');
        expect(da.headerVersion, 2);
        expect(da.bodyVersion, 1);
        expect(da.seq, 5);
        expect(da.createdAt, 1700000000000);
        expect(da.updatedAt, 1700001000000);
        expect(da.isDecrypted, isTrue);
      });

      test('defaults isDecrypted to true', () {
        final json = <String, dynamic>{
          'id': 'da-2',
          'headerVersion': 1,
          'seq': 1,
          'createdAt': 1000,
          'updatedAt': 2000,
        };

        final da = DecryptedArtifact.fromJson(json);

        expect(da.isDecrypted, isTrue);
      });

      test('parses isDecrypted false', () {
        final json = <String, dynamic>{
          'id': 'da-3',
          'headerVersion': 1,
          'seq': 1,
          'createdAt': 1000,
          'updatedAt': 2000,
          'isDecrypted': false,
        };

        final da = DecryptedArtifact.fromJson(json);

        expect(da.isDecrypted, isFalse);
      });
    });

    group('fromArtifact factory', () {
      test('creates DecryptedArtifact from encrypted Artifact + header', () {
        final artifact = Artifact(
          id: 'from-art',
          header: 'enc-hdr',
          headerVersion: 3,
          body: 'enc-body',
          bodyVersion: 2,
          dataEncryptionKey: 'dek',
          seq: 7,
          createdAt: 1000,
          updatedAt: 2000,
        );
        final header = ArtifactHeader(
          title: 'My Title',
          sessions: ['sess-1'],
          draft: true,
        );
        final body = ArtifactBody(body: 'decrypted content');

        final da = DecryptedArtifact.fromArtifact(artifact, header, body);

        expect(da.id, 'from-art');
        expect(da.title, 'My Title');
        expect(da.sessions, ['sess-1']);
        expect(da.draft, isTrue);
        expect(da.body, 'decrypted content');
        expect(da.headerVersion, 3);
        expect(da.bodyVersion, 2);
        expect(da.seq, 7);
        expect(da.createdAt, 1000);
        expect(da.updatedAt, 2000);
        expect(da.isDecrypted, isTrue);
      });

      test('handles null body parameter', () {
        final artifact = Artifact(
          id: 'no-body',
          header: 'h',
          headerVersion: 1,
          dataEncryptionKey: 'k',
          seq: 1,
          createdAt: 100,
          updatedAt: 200,
        );
        final header = ArtifactHeader(title: 'T');

        final da = DecryptedArtifact.fromArtifact(artifact, header);

        expect(da.body, isNull);
        expect(da.bodyVersion, isNull);
      });
    });

    group('toJson/fromJson round-trip', () {
      test('round-trips all fields', () {
        final original = DecryptedArtifact(
          id: 'rt-1',
          title: 'Round Trip',
          sessions: ['a', 'b'],
          draft: true,
          body: 'content',
          headerVersion: 4,
          bodyVersion: 3,
          seq: 99,
          createdAt: 1700000000000,
          updatedAt: 1700001000000,
          isDecrypted: false,
        );

        final json = original.toJson();
        final restored = DecryptedArtifact.fromJson(json);

        // Compare fields individually (sessions uses list identity).
        expect(restored.id, original.id);
        expect(restored.title, original.title);
        expect(restored.sessions, original.sessions);
        expect(restored.draft, original.draft);
        expect(restored.body, original.body);
        expect(restored.headerVersion, original.headerVersion);
        expect(restored.bodyVersion, original.bodyVersion);
        expect(restored.seq, original.seq);
        expect(restored.createdAt, original.createdAt);
        expect(restored.updatedAt, original.updatedAt);
        expect(restored.isDecrypted, original.isDecrypted);
      });
    });

    group('copyWith', () {
      test('copies with overrides', () {
        final original = DecryptedArtifact(
          id: 'cw-1',
          title: 'Original',
          headerVersion: 1,
          seq: 1,
          createdAt: 1000,
          updatedAt: 2000,
        );

        final updated = original.copyWith(
          title: 'Updated',
          headerVersion: 2,
        );

        expect(updated.id, 'cw-1');
        expect(updated.title, 'Updated');
        expect(updated.headerVersion, 2);
        expect(updated.createdAt, 1000);
      });

      test('deep copies sessions list', () {
        final original = DecryptedArtifact(
          id: 'cw-2',
          headerVersion: 1,
          seq: 1,
          createdAt: 1000,
          updatedAt: 2000,
          sessions: ['s1', 's2'],
        );

        final updated = original.copyWith();

        expect(updated.sessions, isNot(same(original.sessions)));
        expect(updated.sessions, equals(original.sessions));
      });

      test('can override sessions', () {
        final original = DecryptedArtifact(
          id: 'cw-3',
          headerVersion: 1,
          seq: 1,
          createdAt: 1000,
          updatedAt: 2000,
          sessions: ['s1'],
        );

        final updated = original.copyWith(sessions: ['s2', 's3']);

        expect(updated.sessions, ['s2', 's3']);
      });
    });

    group('equality', () {
      test('equal artifacts compare equal', () {
        final a = DecryptedArtifact(
          id: 'eq', title: 'T', headerVersion: 1,
          seq: 1, createdAt: 100, updatedAt: 200,
        );
        final b = DecryptedArtifact(
          id: 'eq', title: 'T', headerVersion: 1,
          seq: 1, createdAt: 100, updatedAt: 200,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different artifacts are not equal', () {
        final a = DecryptedArtifact(
          id: 'eq', title: 'T', headerVersion: 1,
          seq: 1, createdAt: 100, updatedAt: 200,
        );
        final b = a.copyWith(title: 'Different');

        expect(a, isNot(equals(b)));
      });
    });
  });

  // ── ArtifactCreateRequest ────────────────────────────────────

  group('ArtifactCreateRequest', () {
    test('toJson includes all fields', () {
      final req = ArtifactCreateRequest(
        id: 'new-id',
        header: 'enc-hdr',
        body: 'enc-body',
        dataEncryptionKey: 'dek',
      );

      final json = req.toJson();

      expect(json['id'], 'new-id');
      expect(json['header'], 'enc-hdr');
      expect(json['body'], 'enc-body');
      expect(json['dataEncryptionKey'], 'dek');
    });
  });

  // ── ArtifactUpdateRequest ────────────────────────────────────

  group('ArtifactUpdateRequest', () {
    test('toJson includes header fields when header provided', () {
      final req = ArtifactUpdateRequest(
        header: 'new-hdr',
        expectedHeaderVersion: 3,
      );

      final json = req.toJson();

      expect(json['header'], 'new-hdr');
      expect(json['expectedHeaderVersion'], 3);
      expect(json.containsKey('body'), isFalse);
    });

    test('toJson includes body fields when body provided', () {
      final req = ArtifactUpdateRequest(
        body: 'new-body',
        expectedBodyVersion: 2,
      );

      final json = req.toJson();

      expect(json['body'], 'new-body');
      expect(json['expectedBodyVersion'], 2);
      expect(json.containsKey('header'), isFalse);
    });

    test('toJson includes both when both provided', () {
      final req = ArtifactUpdateRequest(
        header: 'h',
        expectedHeaderVersion: 1,
        body: 'b',
        expectedBodyVersion: 1,
      );

      final json = req.toJson();

      expect(json.containsKey('header'), isTrue);
      expect(json.containsKey('body'), isTrue);
    });

    test('toJson returns empty map when nothing provided', () {
      final req = ArtifactUpdateRequest();
      final json = req.toJson();

      expect(json, isEmpty);
    });
  });

  // ── ArtifactUpdateResponse ───────────────────────────────────

  group('ArtifactUpdateResponse', () {
    test('fromJson parses success response', () {
      final json = <String, dynamic>{
        'success': true,
        'headerVersion': 5,
        'bodyVersion': 3,
      };

      final resp = ArtifactUpdateResponse.fromJson(json);

      expect(resp.success, isTrue);
      expect(resp.headerVersion, 5);
      expect(resp.bodyVersion, 3);
      expect(resp.error, isNull);
    });

    test('fromJson parses conflict response', () {
      final json = <String, dynamic>{
        'success': false,
        'error': 'Version conflict',
        'currentHeaderVersion': 10,
        'currentBodyVersion': 8,
        'currentHeader': 'server-hdr',
        'currentBody': 'server-body',
      };

      final resp = ArtifactUpdateResponse.fromJson(json);

      expect(resp.success, isFalse);
      expect(resp.error, 'Version conflict');
      expect(resp.currentHeaderVersion, 10);
      expect(resp.currentBodyVersion, 8);
      expect(resp.currentHeader, 'server-hdr');
      expect(resp.currentBody, 'server-body');
    });

    test('toJson round-trips', () {
      final original = ArtifactUpdateResponse(
        success: true,
        headerVersion: 2,
        bodyVersion: 1,
      );

      final json = original.toJson();
      final restored = ArtifactUpdateResponse.fromJson(json);

      expect(restored.success, original.success);
      expect(restored.headerVersion, original.headerVersion);
      expect(restored.bodyVersion, original.bodyVersion);
    });
  });

  // ── ArtifactFolder ───────────────────────────────────────────

  group('ArtifactFolder', () {
    test('fromJson parses all fields', () {
      final json = <String, dynamic>{
        'id': 'folder-1',
        'sessionId': 'sess-1',
        'parentId': 'parent-1',
        'name': 'My Folder',
        'createdAt': 1000,
        'updatedAt': 2000,
      };

      final folder = ArtifactFolder.fromJson(json);

      expect(folder.id, 'folder-1');
      expect(folder.sessionId, 'sess-1');
      expect(folder.parentId, 'parent-1');
      expect(folder.name, 'My Folder');
      expect(folder.createdAt, 1000);
      expect(folder.updatedAt, 2000);
    });

    test('fromJson handles null parentId', () {
      final json = <String, dynamic>{
        'id': 'folder-2',
        'sessionId': 'sess-1',
        'name': 'Root Folder',
        'createdAt': 1000,
        'updatedAt': 2000,
      };

      final folder = ArtifactFolder.fromJson(json);

      expect(folder.parentId, isNull);
    });

    test('toJson round-trips', () {
      final original = ArtifactFolder(
        id: 'f-rt',
        sessionId: 's-1',
        parentId: 'p-1',
        name: 'Test',
        createdAt: 1000,
        updatedAt: 2000,
      );

      final json = original.toJson();
      final restored = ArtifactFolder.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.sessionId, original.sessionId);
      expect(restored.parentId, original.parentId);
      expect(restored.name, original.name);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('throws on missing required fields', () {
      final json = <String, dynamic>{
        'id': 'f',
        // sessionId missing
        'name': 'Test',
        'createdAt': 1000,
        'updatedAt': 2000,
      };

      expect(() => ArtifactFolder.fromJson(json), throwsFormatException);
    });
  });
}
