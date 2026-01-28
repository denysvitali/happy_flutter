import 'dart:async';

import 'draft_storage.dart';
import 'mmkv_storage.dart';

/// Service for managing chat message drafts with auto-save functionality.
///
/// Provides draft persistence keyed by sessionId using MMKV storage with
/// debounced auto-save to reduce storage operations.
class DraftService {
  /// Singleton instance
  static final DraftService _instance = DraftService._();
  DraftService._();

  /// Get the singleton instance
  factory DraftService() => _instance;

  final DraftStorage _storage = DraftStorage();

  /// Get draft content for a session
  ///
  /// Returns the draft text or null if no draft exists.
  Future<String?> getDraft(String sessionId) async {
    return _storage.getDraft(sessionId);
  }

  /// Save draft content for a session
  ///
  /// If the draft is empty, removes any existing draft for the session.
  Future<void> saveDraft(String sessionId, String draft) async {
    if (draft.trim().isEmpty) {
      await _storage.removeDraft(sessionId);
    } else {
      await _storage.saveDraft(sessionId, draft);
    }
  }

  /// Remove draft for a session
  Future<void> removeDraft(String sessionId) async {
    await _storage.removeDraft(sessionId);
  }

  /// Clear all draft data for a session (including permission mode)
  Future<void> clearSessionData(String sessionId) async {
    await _storage.clearSessionData(sessionId);
  }

  /// Get all session drafts
  ///
  /// Returns a map of sessionId to draft text.
  Future<Map<String, String>> getAllDrafts() async {
    final draftsJson = await MMKVStorage().getSessionDrafts();
    return draftsJson;
  }

  /// Clear all session drafts
  Future<void> clearAllDrafts() async {
    await MMKVStorage().clearSessionDrafts();
  }
}

/// Auto-save controller for real-time draft synchronization.
///
/// Creates a DraftAutoSave instance configured for 500ms debouncing
/// as specified in the requirements.
///
/// Example usage:
/// ```dart
/// final autoSave = DraftAutoSaveController(
///   sessionId: sessionId,
///   onSave: (draft) => DraftService().saveDraft(sessionId, draft),
/// );
///
/// // In text field onChanged
/// autoSave.update(text);
///
/// // In dispose
/// autoSave.dispose();
/// ```
class DraftAutoSaveController {
  /// The sessionId this controller is associated with
  String sessionId;

  /// Callback invoked when a draft should be saved
  final void Function(String draft) onSave;

  /// The underlying DraftAutoSave instance
  final DraftAutoSave _autoSave;

  /// Create a new controller with the given sessionId and save callback.
  ///
  /// Debouncing is set to 500ms by default as specified in requirements.
  DraftAutoSaveController({
    required this.sessionId,
    required this.onSave,
    Duration debounceDuration = const Duration(milliseconds: 500),
  }) : _autoSave = DraftAutoSave(
         sessionId: sessionId,
         onSave: onSave,
         debounceDuration: debounceDuration,
       );

  /// Update the draft content with debouncing.
  ///
  /// Draft will be saved after [debounceDuration] of no new updates.
  void update(String draft) {
    _autoSave.update(draft);
  }

  /// Save the pending draft immediately without waiting for debounce.
  void saveNow() {
    _autoSave.saveNow();
  }

  /// Cancel any pending saves and clear pending draft.
  ///
  /// Must be called when the controller is no longer needed to prevent
  /// memory leaks and ensure clean shutdown.
  void dispose() {
    _autoSave.dispose();
  }
}

/// Utility class for draft-related state transitions.
///
/// Provides static methods to detect changes in draft text state.
abstract class DraftUtils {
  /// Check if transitioning between empty and non-empty states.
  ///
  /// Returns true if one state is empty and the other is not.
  static bool isStateTransition(String previousText, String currentText) {
    return DraftStateTransition.isStateTransition(previousText, currentText);
  }

  /// Check if text became empty.
  ///
  /// Returns true if previous text was non-empty and current is empty.
  static bool becameEmpty(String previousText, String currentText) {
    return DraftStateTransition.becameEmpty(previousText, currentText);
  }

  /// Check if text became non-empty.
  ///
  /// Returns true if previous text was empty and current is non-empty.
  static bool becameNonEmpty(String previousText, String currentText) {
    return DraftStateTransition.becameNonEmpty(previousText, currentText);
  }
}
