import 'dart:async' show unawaited;

import 'package:riverpod/riverpod.dart';

import '../models/outgoing_image.dart';
import '../repositories/messages_repository.dart';
import '../rpc/rpc_types.dart' show CodexModelsResponse;
import '../services/draft_storage.dart';
import '../services/codex_speed_selection.dart';
import '../services/pending_session_configuration.dart';
import '../services/sync_service.dart';
import 'settings_notifier.dart';

/// Encapsulates chat-related sync operations so screens don't
/// call sync directly.
class ChatActionNotifier extends Notifier<void> {
  @override
  void build() {}

  MessagesRepository get _messages => ref.read(messagesRepositoryProvider);

  /// Send a message to a session. Returns the actual session ID
  /// (may differ if redirected).
  ///
  /// [clientLocalId] is the canonical client identity. Always pass the
  /// localId backing the optimistic row (mint via [createLocalMessageId])
  /// so ack/merge/retry converge on it. Only sends with no optimistic row
  /// (option taps, `/clear`) may omit it — the sync layer then mints one
  /// internally (`_sync_messaging_send.dart`).
  Future<String> sendMessage(
    String sessionId,
    String text, {
    String? clientLocalId,
    String? displayText,
    String? permissionMode,
    String? modelMode,
    String? profileId,
    List<OutgoingImage>? images,
    String? codexDeliveryMode,
  }) async {
    if (!_messages.isReady) {
      throw StateError('Sync is not initialized');
    }
    return _messages.sendMessage(
      sessionId,
      text,
      clientLocalId: clientLocalId,
      displayText: displayText,
      permissionMode: permissionMode,
      modelMode: modelMode,
      profileId: profileId,
      images: images,
      codexDeliveryMode: codexDeliveryMode,
    );
  }

  /// Abort a running session.
  Future<void> abortSession(String sessionId, {String reason = ''}) async {
    if (!_messages.isReady) {
      throw StateError('Sync is not initialized');
    }
    await _messages.abortSession(sessionId, reason: reason);
  }

  /// Stop the daemon-owned process or pod, distinct from aborting one turn.
  Future<void> stopSessionProcess(String sessionId) async {
    if (!_messages.isReady) {
      throw StateError('Sync is not initialized');
    }
    await _messages.stopSessionProcess(sessionId);
  }

  /// Mint a new canonical local message ID for optimistic UI.
  String createLocalMessageId() {
    if (!_messages.isReady) {
      throw StateError('Sync is not initialized');
    }
    return _messages.createLocalMessageId();
  }

  /// Retry a failed message, preserving its original localId.
  Future<MessageRetryResult> retryFailedMessage(
    String sessionId,
    String localId,
  ) async {
    if (!_messages.isReady) {
      throw StateError('Sync is not initialized');
    }
    return _messages.retryFailedMessage(sessionId, localId);
  }

  /// Load available Codex models for a machine.
  Future<CodexModelsResponse> loadCodexModels(
    String machineId, {
    String? profileId,
    String? directory,
    bool refresh = false,
  }) async {
    if (!sync.isInitialized) {
      throw StateError('Sync is not initialized');
    }
    return sync.machineGetCodexModels(
      machineId: machineId,
      profileId: profileId,
      directory: directory,
      refresh: refresh,
    );
  }

  /// Delete a session. Returns true on success.
  Future<bool> deleteSession(String sessionId) async {
    return sync.deleteSession(sessionId);
  }

  /// Save the permission mode for a session and update settings.
  void savePermissionMode(String sessionId, String modeString) {
    unawaited(DraftStorage().savePermissionMode(sessionId, modeString));
    // Keep a session-scoped copy in synced settings so another device can
    // restore this exact session without inheriting a different session's
    // most recently used mode. Keep the legacy global value for new-session
    // defaults and migration from older app versions.
    final settings = ref.read(settingsNotifierProvider);
    final permissionModesBySession = {
      ...settings.permissionModesBySession,
      sessionId: modeString,
    };
    final notifier = ref.read(settingsNotifierProvider.notifier);
    // updateSetting() calls sync.applySettings() internally.
    unawaited(
      notifier.updateSetting(
        'permissionModesBySession',
        permissionModesBySession,
      ),
    );
    unawaited(notifier.updateSetting('lastUsedPermissionMode', modeString));
  }

  /// Save the model mode for a session and update settings.
  void saveModelMode(String sessionId, String modeString) {
    unawaited(DraftStorage().saveModelMode(sessionId, modeString));
    // updateSetting() calls sync.applySettings() internally.
    unawaited(
      ref
          .read(settingsNotifierProvider.notifier)
          .updateSetting('lastUsedModelMode', modeString),
    );
  }

  /// Save the profile selection and update settings.
  void saveProfile(String sessionId, String? profileId) {
    final storage = DraftStorage();
    if (profileId != null) {
      unawaited(storage.saveProfileId(sessionId, profileId));
    } else {
      // Explicitly clear the stale profile from MMKV so auto-restore
      // doesn't pick up a leftover value when the user selects "None".
      unawaited(storage.removeProfileId(sessionId));
    }
    // Update the Settings notifier state so PickProfileScreen
    // and other screens see the new selection immediately.
    // updateSetting() calls sync.applySettings() internally —
    // no separate applySettings() needed here.
    final settings = ref.read(settingsNotifierProvider);
    final agent = sync.sessions[sessionId]?.metadata?.flavor;
    unawaited(
      ref
          .read(settingsNotifierProvider.notifier)
          .updateSetting(
            'lastUsedProfilesByAgent',
            settings.lastUsedProfilesWithAgent(agent, profileId),
          ),
    );
    if (profileId == null) {
      // "None" must also drop the legacy global selection: without a scoped
      // entry resolveSelectedProfileIdForAgent falls back to it, which
      // resurrected the deselected gateway profile (and its routing env) on
      // the next spawn.
      unawaited(
        ref
            .read(settingsNotifierProvider.notifier)
            .updateSetting('lastUsedProfile', null),
      );
    }
  }

  /// Save profile, model mode, and (optionally) permission mode as a
  /// single atomic call so the profile/model pairing can never desync -
  /// e.g. a profile switch must always persist its `defaultModelMode`
  /// alongside the new profile id, never one without the other.
  void saveSelection(
    String sessionId, {
    required String modelMode,
    String? profileId,
    String? permissionMode,
  }) {
    PendingSessionConfiguration().save(
      sessionId,
      profileId: profileId ?? 'default',
      modelMode: modelMode,
    );
    saveProfile(sessionId, profileId);
    saveModelMode(sessionId, modelMode);
    if (permissionMode != null) {
      savePermissionMode(sessionId, permissionMode);
    }
  }

  /// Persist a per-session Codex speed choice and queue a replacement when
  /// it differs from the running process configuration.
  void saveCodexFastMode(
    String sessionId,
    bool enabled, {
    required String? profileId,
    required String modelMode,
  }) {
    final speed = enabled ? 'fast' : 'standard';
    final session = sync.sessions[sessionId];
    final pending = PendingSessionConfiguration().read(sessionId);
    final previousOverride = CodexSpeedSelection().read(sessionId);
    final knownSpeed = session?.metadata?.codexFastMode ?? previousOverride;
    CodexSpeedSelection().save(sessionId, enabled);

    // A speed choice must not overwrite a provider/model change that is
    // already waiting for a replacement spawn.
    if (pending == null && knownSpeed == enabled) return;
    PendingSessionConfiguration().save(
      sessionId,
      profileId: pending?.profileId ?? profileId ?? 'default',
      modelMode: pending?.modelMode ?? modelMode,
      codexSpeed: speed,
    );
  }
}

final chatActionNotifierProvider = NotifierProvider<ChatActionNotifier, void>(
  () {
    return ChatActionNotifier();
  },
);
