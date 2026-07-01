part of 'sync_service.dart';

// ── Isolate helpers: machine payload decryption ───────────────────────

class _MachineIsolateItem {
  const _MachineIsolateItem({
    required this.id,
    required this.secretKey,
    required this.isAes,
    required this.metadataVersion,
    required this.daemonStateVersion,
    this.encryptedMetadata,
    this.encryptedDaemonState,
  });

  final String id;
  final Uint8List secretKey;
  final bool isAes;
  final Uint8List? encryptedMetadata;
  final int metadataVersion;
  final Uint8List? encryptedDaemonState;
  final int daemonStateVersion;
}

class _MachineIsolateResult {
  const _MachineIsolateResult({
    required this.id,
    this.metadata,
    this.daemonState,
  });

  final String id;
  final Map<String, dynamic>? metadata;
  final dynamic daemonState;
}

/// Decrypt machine metadata and daemonState.
/// AES-256-GCM items run in a background isolate on native; on web they
/// decrypt on the main thread. NaCl always stays on main thread.
/// (isAes=false, legacy machines).
Future<List<_MachineIsolateResult>> _decryptMachinesInIsolate(
  List<_MachineIsolateItem> items,
) async {
  // Collect AES payloads for batch isolate decryption.
  // Each entry maps back to (itemIndex, 0=metadata | 1=daemonState).
  final aesPayloads = <Uint8List>[];
  final aesKeys = <Uint8List>[];
  final aesMapping = <(int, int)>[];

  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    if (!item.isAes) continue;

    final encMeta = item.encryptedMetadata;
    if (encMeta != null && encMeta.isNotEmpty && encMeta[0] == 0) {
      aesPayloads.add(encMeta.sublist(1));
      aesKeys.add(item.secretKey);
      aesMapping.add((i, 0));
    }

    final encDs = item.encryptedDaemonState;
    if (encDs != null && encDs.isNotEmpty && encDs[0] == 0) {
      aesPayloads.add(encDs.sublist(1));
      aesKeys.add(item.secretKey);
      aesMapping.add((i, 1));
    }
  }

  // Run AES batch in a background isolate (pure Dart — no FFI).
  // Skip isolate on web since it's not supported.
  Map<(int, int), dynamic>? aesResultMap;
  if (aesPayloads.isNotEmpty && !kIsWeb) {
    try {
      final aesResults = await Isolate.run(
        () => AesGcmEncryption.decryptMultiKeyBatch(
          aesPayloads,
          aesKeys,
        ),
      );
      aesResultMap = {
        for (var i = 0; i < aesMapping.length; i++)
          aesMapping[i]: aesResults[i],
      };
    } catch (e) {
      logger.warning('Machine AES isolate failed, '
          'falling back to main thread: $e');
    }
  }

  // Build results. AES items use isolate results; NaCl and
  // isolate-fallback items decrypt on the main thread.
  final results = <_MachineIsolateResult>[];
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    Map<String, dynamic>? metadata;
    dynamic daemonState;

    if (item.isAes && aesResultMap != null) {
      final metaResult = aesResultMap[(i, 0)];
      if (metaResult is Map<String, dynamic>) {
        metadata = metaResult;
      }
      daemonState = aesResultMap[(i, 1)];
    } else {
      // NaCl (legacy) or AES isolate fallback or web.
      final encMeta = item.encryptedMetadata;
      if (encMeta != null) {
        try {
          if (item.isAes) {
            if (encMeta.isNotEmpty && encMeta[0] == 0) {
              final d = await AesGcmEncryption.decrypt(
                encMeta.sublist(1),
                item.secretKey,
              );
              if (d is Map<String, dynamic>) metadata = d;
            }
          } else {
            final d = await CryptoSecretBox.decrypt(
              encMeta,
              item.secretKey,
              scope: 'machine:${item.id}:metadata',
            );
            if (d is Map<String, dynamic>) metadata = d;
          }
        } catch (e) {
          logger.warning(
            'Failed to decrypt machine metadata: $e',
          );
        }
      }

      final encDs = item.encryptedDaemonState;
      if (encDs != null) {
        try {
          if (item.isAes) {
            if (encDs.isNotEmpty && encDs[0] == 0) {
              daemonState = await AesGcmEncryption.decrypt(
                encDs.sublist(1),
                item.secretKey,
              );
            }
          } else {
            daemonState = await CryptoSecretBox.decrypt(
              encDs,
              item.secretKey,
              scope: 'machine:${item.id}:daemon-state',
            );
          }
        } catch (e) {
          logger.warning(
            'Failed to decrypt machine daemon state: $e',
          );
        }
      }
    }

    results.add(
      _MachineIsolateResult(
        id: item.id,
        metadata: metadata,
        daemonState: daemonState,
      ),
    );
  }
  return results;
}

int? _asSessionInt(dynamic value) {
  return WireParsers.parseInt(value);
}

int? _clampTimestampToNow(int? value, int nowMs) {
  if (value == null) return null;
  return value > nowMs ? nowMs : value;
}

bool? _asSessionBool(dynamic value) {
  return WireParsers.parseBool(value);
}
