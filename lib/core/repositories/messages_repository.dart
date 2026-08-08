import 'package:riverpod/riverpod.dart';

import '../models/outgoing_image.dart';
import '../services/sync_service.dart';

/// Domain boundary for user-initiated message operations.
///
/// The concrete implementation delegates to [Sync] during the incremental
/// migration, while callers depend only on this interface and can override it
/// in tests without constructing the sync singleton.
abstract interface class MessagesRepository {
  bool get isReady;

  Future<String> sendMessage(
    String sessionId,
    String text, {
    String? clientLocalId,
    String? displayText,
    String? permissionMode,
    String? modelMode,
    String? profileId,
    List<OutgoingImage>? images,
  });

  Future<void> abortSession(String sessionId, {String reason = ''});

  Future<void> stopSessionProcess(String sessionId);

  String createLocalMessageId();

  Future<MessageRetryResult> retryFailedMessage(
    String sessionId,
    String localId,
  );
}

class SyncMessagesRepository implements MessagesRepository {
  const SyncMessagesRepository(this._sync);

  final Sync _sync;

  @override
  bool get isReady => _sync.isInitialized;

  @override
  Future<String> sendMessage(
    String sessionId,
    String text, {
    String? clientLocalId,
    String? displayText,
    String? permissionMode,
    String? modelMode,
    String? profileId,
    List<OutgoingImage>? images,
  }) => _sync.sendMessage(
    sessionId,
    text,
    clientLocalId: clientLocalId,
    displayText: displayText,
    permissionMode: permissionMode,
    modelMode: modelMode,
    profileId: profileId,
    images: images,
  );

  @override
  Future<void> abortSession(String sessionId, {String reason = ''}) =>
      _sync.abortSession(sessionId, reason: reason);

  @override
  Future<void> stopSessionProcess(String sessionId) async {
    await _sync.stopSessionProcess(sessionId);
  }

  @override
  String createLocalMessageId() => _sync.createLocalMessageId();

  @override
  Future<MessageRetryResult> retryFailedMessage(
    String sessionId,
    String localId,
  ) => _sync.retryFailedMessage(sessionId, localId);
}

final messagesRepositoryProvider = Provider<MessagesRepository>(
  (ref) => SyncMessagesRepository(sync),
);
