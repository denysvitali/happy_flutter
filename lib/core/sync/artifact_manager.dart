import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../encryption/aes_gcm.dart';
import '../encryption/artifact_encryption.dart';
import '../encryption/base64.dart';
import '../encryption/encryption_manager.dart';
import '../models/artifact.dart';
import '../services/logger_service.dart' show logger;
import '../utils/invalidate_sync.dart';
import '../utils/sync_domain.dart';

class _ArtifactIsolateItem {
  const _ArtifactIsolateItem({
    required this.id,
    required this.secretKey,
    required this.encryptedHeader,
    this.encryptedBody,
  });

  final String id;
  final Uint8List secretKey;
  final Uint8List encryptedHeader;
  final Uint8List? encryptedBody;
}

class _ArtifactIsolateResult {
  const _ArtifactIsolateResult({required this.id, this.header, this.body});

  final String id;
  final Map<String, dynamic>? header;
  final Map<String, dynamic>? body;
}

/// Decrypt artifact headers and bodies in a background isolate.
/// Artifacts always use AES-256-GCM (pure Dart — fully isolate-safe).
/// On web, decryption runs on the main thread.
Future<List<_ArtifactIsolateResult>> _decryptArtifactsInIsolate(
  List<_ArtifactIsolateItem> items,
) async {
  // Collect all payloads for batch isolate decryption.
  // Each entry maps to (itemIndex, 0=header | 1=body).
  final payloads = <Uint8List>[];
  final keys = <Uint8List>[];
  final mapping = <(int, int)>[];

  for (var i = 0; i < items.length; i++) {
    final item = items[i];

    final hRaw = item.encryptedHeader;
    if (hRaw.isNotEmpty && hRaw[0] == 0) {
      payloads.add(hRaw.sublist(1));
      keys.add(item.secretKey);
      mapping.add((i, 0));
    }

    final bRaw = item.encryptedBody;
    if (bRaw != null && bRaw.isNotEmpty && bRaw[0] == 0) {
      payloads.add(bRaw.sublist(1));
      keys.add(item.secretKey);
      mapping.add((i, 1));
    }
  }

  // Run batch in background isolate on native platforms only.
  Map<(int, int), dynamic>? resultMap;
  if (payloads.isNotEmpty && !kIsWeb) {
    try {
      final batchResults = await Isolate.run(
        () => AesGcmEncryption.decryptMultiKeyBatch(payloads, keys),
      );
      resultMap = {
        for (var i = 0; i < mapping.length; i++) mapping[i]: batchResults[i],
      };
    } catch (e) {
      logger.warning(
        'Artifact AES isolate failed, falling back to main thread: $e',
      );
    }
  }

  // Build results — fall back to main-thread decrypt on failure or web.
  final results = <_ArtifactIsolateResult>[];
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    Map<String, dynamic>? header;
    Map<String, dynamic>? body;

    if (resultMap != null) {
      final hResult = resultMap[(i, 0)];
      if (hResult is Map<String, dynamic>) header = hResult;
      final bResult = resultMap[(i, 1)];
      if (bResult is Map<String, dynamic>) {
        body = {'body': bResult['body'] as String?};
      }
    } else {
      // Isolate fallback or web — main thread.
      final hRaw = item.encryptedHeader;
      if (hRaw.isNotEmpty && hRaw[0] == 0) {
        try {
          final d = await AesGcmEncryption.decrypt(hRaw.sublist(1), item.secretKey);
          if (d is Map<String, dynamic>) header = d;
        } catch (e) {
          logger.warning('Failed to decrypt artifact header: $e');
        }
      }

      final bRaw = item.encryptedBody;
      if (bRaw != null && bRaw.isNotEmpty && bRaw[0] == 0) {
        try {
          final d = await AesGcmEncryption.decrypt(bRaw.sublist(1), item.secretKey);
          if (d is Map<String, dynamic>) {
            body = {'body': d['body'] as String?};
          }
        } catch (e) {
          logger.warning('Failed to decrypt artifact body: $e');
        }
      }
    }

    results.add(
      _ArtifactIsolateResult(id: item.id, header: header, body: body),
    );
  }
  return results;
}

/// Manages artifact encryption, server sync, and in-memory state.
class ArtifactManager {
  ArtifactManager({
    required Encryption encryption,
    required InvalidateSync Function() artifactsSyncGetter,
    required void Function(Set<SyncDomain>) onDataChanged,
  })  : _encryption = encryption,
        _artifactsSyncGetter = artifactsSyncGetter,
        _onDataChanged = onDataChanged;

  final Encryption _encryption;
  final InvalidateSync Function() _artifactsSyncGetter;
  final void Function(Set<SyncDomain>) _onDataChanged;

  final List<DecryptedArtifact> _artifacts = [];
  final Map<String, Uint8List> _artifactDataKeys = {};

  /// All artifacts currently held in memory.
  List<DecryptedArtifact> get artifacts => List.unmodifiable(_artifacts);

  /// Data encryption keys indexed by artifact ID.
  Map<String, Uint8List> get dataKeys => Map.unmodifiable(_artifactDataKeys);

  /// Clears all in-memory artifact state.
  void clear() {
    _artifacts.clear();
    _artifactDataKeys.clear();
  }

  /// Fetch artifacts list from server.
  Future<void> fetchArtifactsList() async {
    logger.info('Fetching artifacts...');
    try {
      final api = ApiClient();
      final response = await api.get('/v1/artifacts');
      if (!api.isSuccess(response)) {
        logger.warning('Failed to fetch artifacts: ${response.statusCode}');
        return;
      }

      final data = response.data;
      final rawArtifacts = (data is Map<String, dynamic>) ? data['artifacts'] : data;
      if (rawArtifacts is! List) {
        _artifacts.clear();
        return;
      }

      // Phase 1: Decrypt artifact data keys on the main thread.
      final keyedArtifacts = <({Artifact artifact, Uint8List key})>[];
      final decryptedArtifacts = <DecryptedArtifact>[];
      for (final raw in rawArtifacts) {
        await Future<void>.delayed(Duration.zero);
        if (raw is! Map<String, dynamic>) continue;
        try {
          final artifact = Artifact.fromJson(raw);
          final decryptedKey = await _encryption.decryptEncryptionKey(
            artifact.dataEncryptionKey,
          );
          if (decryptedKey != null) {
            _artifactDataKeys[artifact.id] = decryptedKey;
            keyedArtifacts.add((artifact: artifact, key: decryptedKey));
          } else {
            decryptedArtifacts.add(
              DecryptedArtifact(
                id: artifact.id,
                headerVersion: artifact.headerVersion,
                bodyVersion: artifact.bodyVersion,
                seq: artifact.seq,
                createdAt: artifact.createdAt,
                updatedAt: artifact.updatedAt,
                isDecrypted: false,
              ),
            );
          }
        } catch (error, stack) {
          logger.error('Failed to parse artifact key', error, stack);
        }
      }

      // Phase 2: Decrypt headers + bodies off the main thread.
      if (keyedArtifacts.isNotEmpty) {
        final artifactIsolateItems = keyedArtifacts.map((e) {
          final encHeader = Base64Utils.decode(e.artifact.header, Encoding.base64);
          final encBody = e.artifact.body != null
              ? Base64Utils.decode(e.artifact.body!, Encoding.base64)
              : null;
          return _ArtifactIsolateItem(
            id: e.artifact.id,
            secretKey: e.key,
            encryptedHeader: encHeader,
            encryptedBody: encBody,
          );
        }).toList();

        final artifactIsolateResults = await _decryptArtifactsInIsolate(
          artifactIsolateItems,
        );
        final artifactResultById = {
          for (final r in artifactIsolateResults) r.id: r,
        };

        for (final e in keyedArtifacts) {
          final artifact = e.artifact;
          final result = artifactResultById[artifact.id];
          final header = result?.header;
          final body = result?.body;
          decryptedArtifacts.add(
            DecryptedArtifact(
              id: artifact.id,
              title: header?['title'] as String?,
              sessions: (header?['sessions'] as List<dynamic>?)
                  ?.whereType<String>()
                  .toList(),
              draft: header?['draft'] as bool?,
              body: body?['body'] as String?,
              headerVersion: artifact.headerVersion,
              bodyVersion: artifact.bodyVersion,
              seq: artifact.seq,
              createdAt: artifact.createdAt,
              updatedAt: artifact.updatedAt,
              isDecrypted: header != null,
            ),
          );
        }
      }

      _artifacts
        ..clear()
        ..addAll(decryptedArtifacts);
      _onDataChanged({SyncDomain.artifacts});
      logger.info('Fetched artifacts: ${_artifacts.length}');
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error('Failed to fetch artifacts', error, stack);
    }
  }

  /// Fetch a single artifact with full body decrypted.
  Future<DecryptedArtifact?> fetchArtifactWithBody(String id) async {
    try {
      final api = ApiClient();
      final response = await api.get('/v1/artifacts/$id');
      if (!api.isSuccess(response)) {
        logger.warning('Failed to fetch artifact: ${response.statusCode}');
        return null;
      }
      final raw = response.data;
      if (raw is! Map<String, dynamic>) return null;
      final artifact = Artifact.fromJson(raw);
      final decryptedKey = _artifactDataKeys[artifact.id] ??
          await _encryption.decryptEncryptionKey(artifact.dataEncryptionKey);
      if (decryptedKey == null) return null;
      _artifactDataKeys[artifact.id] = decryptedKey;
      final artifactEncryption = ArtifactEncryption(decryptedKey);
      final header = await artifactEncryption.decryptHeader(artifact.header);
      final body = artifact.body != null
          ? await artifactEncryption.decryptBody(artifact.body!)
          : null;
      return DecryptedArtifact(
        id: artifact.id,
        title: header?['title'] as String?,
        body: body?['body'] as String?,
        headerVersion: artifact.headerVersion,
        bodyVersion: artifact.bodyVersion,
        seq: artifact.seq,
        createdAt: artifact.createdAt,
        updatedAt: artifact.updatedAt,
        isDecrypted: header != null,
      );
    } catch (error, stack) {
      logger.error('Failed to fetch artifact', error, stack);
      return null;
    }
  }

  /// Create a new artifact with optional title and body.
  /// Returns the new artifact's ID.
  Future<String> createArtifact(String? title, String? body) async {
    final dek = ArtifactEncryption.generateDataEncryptionKey();
    final artifactEncryption = ArtifactEncryption(dek);
    final encryptedDek = await _encryption.encryptEncryptionKey(dek);
    final encryptedDekB64 = Base64Utils.encode(encryptedDek, Encoding.base64);
    final encryptedHeader = await artifactEncryption.encryptHeader({'title': title});
    final encryptedBody = await artifactEncryption.encryptBody({'body': body ?? ''});
    final artifactId = _encryption.generateId();
    final request = ArtifactCreateRequest(
      id: artifactId,
      header: encryptedHeader,
      body: encryptedBody,
      dataEncryptionKey: encryptedDekB64,
    );
    final api = ApiClient();
    final response = await api.post('/v1/artifacts', data: request.toJson());
    if (!api.isSuccess(response)) {
      throw StateError('Failed to create artifact: ${response.statusCode}');
    }
    _artifactDataKeys[artifactId] = dek;
    _artifactsSyncGetter().invalidate();
    return artifactId;
  }

  /// Update an existing artifact's title and/or body.
  Future<void> updateArtifact(String id, String? title, String? body) async {
    final dek = _artifactDataKeys[id];
    if (dek == null) {
      throw StateError('No decryption key found for artifact $id');
    }
    final artifactEncryption = ArtifactEncryption(dek);
    final existing = _artifacts.firstWhere(
      (a) => a.id == id,
      orElse: () => throw StateError('Artifact $id not found in cache'),
    );
    final encryptedHeader = await artifactEncryption.encryptHeader({'title': title});
    final encryptedBody = await artifactEncryption.encryptBody({'body': body ?? ''});
    final request = ArtifactUpdateRequest(
      header: encryptedHeader,
      expectedHeaderVersion: existing.headerVersion,
      body: encryptedBody,
      expectedBodyVersion: existing.bodyVersion,
    );
    final api = ApiClient();
    final response = await api.post('/v1/artifacts/$id', data: request.toJson());
    if (!api.isSuccess(response)) {
      throw StateError('Failed to update artifact: ${response.statusCode}');
    }
    _artifactsSyncGetter().invalidate();
  }

  /// Delete an artifact by ID.
  Future<void> deleteArtifact(String id) async {
    final api = ApiClient();
    final response = await api.delete('/v1/artifacts/$id');
    if (!api.isSuccess(response)) {
      throw StateError('Failed to delete artifact: ${response.statusCode}');
    }
    _artifactDataKeys.remove(id);
    _artifacts.removeWhere((a) => a.id == id);
    _onDataChanged({SyncDomain.artifacts});
  }
}
