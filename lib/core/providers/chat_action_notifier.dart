import 'dart:async' show unawaited;

import 'package:riverpod/riverpod.dart';

import '../rpc/rpc_types.dart' show CodexModelsResponse;
import '../services/draft_storage.dart';
import '../services/sync_service.dart';
import 'settings_notifier.dart';

/// Encapsulates chat-related sync operations so screens don't
/// call sync directly.
class ChatActionNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Send a message to a session. Returns the actual session ID
  /// (may differ if redirected).
  Future<String> sendMessage(
    String sessionId,
    String text, {
    String? clientLocalId,
    String? displayText,
    String? permissionMode,
    String? modelMode,
    String? profileId,
  }) async {
    if (!sync.isInitialized) {
      throw StateError('Sync is not initialized');
    }
    return sync.sendMessage(
      sessionId,
      text,
      clientLocalId: clientLocalId,
      displayText: displayText,
      permissionMode: permissionMode,
      modelMode: modelMode,
      profileId: profileId,
    );
  }

  /// Abort a running session.
  Future<void> abortSession(String sessionId, {String reason = ''}) async {
    if (!sync.isInitialized) {
      throw StateError('Sync is not initialized');
    }
    await sync.abortSession(sessionId, reason: reason);
  }

  /// Mint a new canonical local message ID for optimistic UI.
  String createLocalMessageId() {
    if (!sync.isInitialized) {
      throw StateError('Sync is not initialized');
    }
    return sync.createLocalMessageId();
  }

  /// Retry a failed message, preserving its original localId.
  Future<void> retryFailedMessage(String sessionId, String localId) async {
    if (!sync.isInitialized) {
      throw StateError('Sync is not initialized');
    }
    await sync.retryFailedMessage(sessionId, localId);
  }

  /// Load available Codex models for a machine.
  Future<CodexModelsResponse> loadCodexModels(String machineId) async {
    if (!sync.isInitialized) {
      throw StateError('Sync is not initialized');
    }
    return sync.machineGetCodexModels(machineId: machineId);
  }

  /// Delete a session. Returns true on success.
  Future<bool> deleteSession(String sessionId) async {
    return sync.deleteSession(sessionId);
  }

  /// Save the permission mode for a session and update settings.
  void savePermissionMode(String sessionId, String modeString) {
    unawaited(DraftStorage().savePermissionMode(sessionId, modeString));
    // updateSetting() calls sync.applySettings() internally.
    unawaited(
      ref
          .read(settingsNotifierProvider.notifier)
          .updateSetting('lastUsedPermissionMode', modeString),
    );
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
    saveProfile(sessionId, profileId);
    saveModelMode(sessionId, modelMode);
    if (permissionMode != null) {
      savePermissionMode(sessionId, permissionMode);
    }
  }
}

final chatActionNotifierProvider = NotifierProvider<ChatActionNotifier, void>(
  () {
    return ChatActionNotifier();
  },
);
