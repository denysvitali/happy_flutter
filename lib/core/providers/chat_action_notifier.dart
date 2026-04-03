import 'dart:async' show unawaited;

import 'package:riverpod/riverpod.dart';

import '../services/draft_storage.dart';
import '../services/logger_service.dart' show logger;
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
    String? displayText,
    String? permissionMode,
    String? modelMode,
  }) async {
    if (!sync.isInitialized) {
      throw StateError('Sync is not initialized');
    }
    return sync.sendMessage(
      sessionId,
      text,
      displayText: displayText,
      permissionMode: permissionMode,
      modelMode: modelMode,
    );
  }

  /// Abort a running session.
  Future<void> abortSession(
    String sessionId, {
    String reason = '',
  }) async {
    if (!sync.isInitialized) {
      throw StateError('Sync is not initialized');
    }
    await sync.abortSession(sessionId, reason: reason);
  }

  /// Delete a session. Returns true on success.
  Future<bool> deleteSession(String sessionId) async {
    return sync.deleteSession(sessionId);
  }

  /// Apply settings through sync.
  void applySettings(Map<String, dynamic> settings) {
    if (!sync.isInitialized) return;
    try {
      sync.applySettings(settings);
    } catch (e) {
      logger.warning('Failed to apply settings: $e');
    }
  }

  /// Save the permission mode for a session and update settings.
  void savePermissionMode(String sessionId, String modeString) {
    DraftStorage().savePermissionMode(sessionId, modeString);
    unawaited(
      ref
          .read(settingsNotifierProvider.notifier)
          .updateSetting('lastUsedPermissionMode', modeString),
    );
    applySettings({'lastUsedPermissionMode': modeString});
  }

  /// Save the model mode for a session and update settings.
  void saveModelMode(String sessionId, String modeString) {
    DraftStorage().saveModelMode(sessionId, modeString);
    unawaited(
      ref
          .read(settingsNotifierProvider.notifier)
          .updateSetting('lastUsedModelMode', modeString),
    );
    applySettings({'lastUsedModelMode': modeString});
  }

  /// Save the profile selection and update settings.
  void saveProfile(String sessionId, String? profileId) {
    if (profileId != null) {
      DraftStorage().saveProfileId(sessionId, profileId);
    }
    // Update the Settings notifier state so PickProfileScreen
    // and other screens see the new selection immediately.
    unawaited(
      ref
          .read(settingsNotifierProvider.notifier)
          .updateSetting('lastUsedProfile', profileId),
    );
    applySettings({'lastUsedProfile': profileId});
  }
}

final chatActionNotifierProvider =
    NotifierProvider<ChatActionNotifier, void>(() {
  return ChatActionNotifier();
});
