import 'dart:async';
import 'logger_service.dart' show logger;
import 'mmkv_storage.dart';

/// Service for managing draft message persistence
class DraftStorage {

  DraftStorage({MMKVStorage? storage}) : _storage = storage ?? MMKVStorage();
  final MMKVStorage _storage;

  /// Get a draft for a session
  Future<String?> getDraft(String sessionId) async {
    return _storage.getSessionDraft(sessionId);
  }

  /// Save a draft for a session
  Future<void> saveDraft(String sessionId, String draft) async {
    await _storage.saveSessionDraft(sessionId, draft);
  }

  /// Remove a draft for a session
  Future<void> removeDraft(String sessionId) async {
    await _storage.removeSessionDraft(sessionId);
  }

  /// Get saved permission mode for a session
  Future<String?> getPermissionMode(String sessionId) async {
    return _storage.getSessionPermissionMode(sessionId);
  }

  /// Save permission mode for a session
  Future<void> savePermissionMode(String sessionId, String mode) async {
    await _storage.saveSessionPermissionMode(sessionId, mode);
  }

  /// Get saved model mode for a session
  Future<String?> getModelMode(String sessionId) async {
    return _storage.getSessionModelMode(sessionId);
  }

  /// Save model mode for a session
  Future<void> saveModelMode(String sessionId, String mode) async {
    await _storage.saveSessionModelMode(sessionId, mode);
  }

  /// Get saved profile ID for a session
  Future<String?> getProfileId(String sessionId) async {
    return _storage.getSessionProfile(sessionId);
  }

  /// Save profile ID for a session
  Future<void> saveProfileId(String sessionId, String profileId) async {
    await _storage.saveSessionProfile(sessionId, profileId);
  }

  /// Remove saved profile ID for a session
  Future<void> removeProfileId(String sessionId) async {
    await _storage.removeSessionProfile(sessionId);
  }

  /// Clear all drafts for a session (including permission mode)
  Future<void> clearSessionData(String sessionId) async {
    await removeDraft(sessionId);
    await _storage.removeSessionPermissionMode(sessionId);
    await _storage.removeSessionProfile(sessionId);
  }

  /// Remove every per-session profile mapping that points at [profileId].
  ///
  /// Called when an AI backend profile is deleted from settings so that
  /// future ChatScreen loads do not look up a ghost reference and trip
  /// the `firstWhere` fallback (which previously produced 9 warning-level
  /// events per day in production).
  ///
  /// Returns the session IDs whose stored profile mapping was cleared.
  Future<List<String>> sweepProfileReferences(String profileId) async {
    if (profileId.isEmpty) return const [];
    final all = await _storage.getAllSessionProfiles();
    final stale = computeStaleSessions(all, profileId);
    for (final sessionId in stale) {
      await _storage.removeSessionProfile(sessionId);
    }
    if (stale.isNotEmpty) {
      logger.info(
        '[DraftStorage] swept ${stale.length} stale references to '
        'deleted profile $profileId',
      );
    }
    return stale;
  }

  /// Pure helper that picks out every session whose stored profile id
  /// matches [profileId]. Extracted so it can be unit-tested without
  /// touching MMKV.
  static List<String> computeStaleSessions(
    Map<String, String> entries,
    String profileId,
  ) {
    if (profileId.isEmpty) return const [];
    final stale = <String>[];
    entries.forEach((sessionId, mappedProfileId) {
      if (mappedProfileId == profileId) stale.add(sessionId);
    });
    return stale;
  }
}

/// Auto-save mechanism for drafts with debouncing
class DraftAutoSave {

  DraftAutoSave({
    required this.sessionId,
    required this.onSave,
    this.debounceDuration = const Duration(milliseconds: 500),
  });
  String sessionId;
  void Function(String draft) onSave;
  Timer? _debounceTimer;
  String _pendingDraft = '';
  Duration debounceDuration;

  /// Update the draft content
  void update(String draft) {
    _debounceTimer?.cancel();
    if (draft.trim().isEmpty) {
      _pendingDraft = '';
      return;
    }
    _pendingDraft = draft;
    _debounceTimer = Timer(debounceDuration, _save);
  }

  /// Cancel any pending save without invoking [onSave].
  void discardPending() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingDraft = '';
  }

  /// Save immediately without debouncing
  void saveNow() {
    _debounceTimer?.cancel();
    if (_pendingDraft.isNotEmpty) {
      onSave(_pendingDraft);
      _pendingDraft = '';
    }
  }

  void _save() {
    if (_pendingDraft.isNotEmpty) {
      onSave(_pendingDraft);
      _pendingDraft = '';
    }
  }

  /// Cancel any pending saves and clear pending draft
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingDraft = '';
  }

  /// Suspend pending saves when app goes to background.
  /// Cancel the debounce timer without saving (draft remains in memory).
  void suspend() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}

/// Utility class for detecting state transitions in draft text
abstract class DraftStateTransition {
  /// Check if transitioning between empty and non-empty states
  static bool isStateTransition(String previousText, String currentText) {
    final previousEmpty = previousText.trim().isEmpty;
    final currentEmpty = currentText.trim().isEmpty;
    return previousEmpty != currentEmpty;
  }

  /// Check if text became empty
  static bool becameEmpty(String previousText, String currentText) {
    final previousEmpty = previousText.trim().isEmpty;
    final currentEmpty = currentText.trim().isEmpty;
    return !previousEmpty && currentEmpty;
  }

  /// Check if text became non-empty
  static bool becameNonEmpty(String previousText, String currentText) {
    final previousEmpty = previousText.trim().isEmpty;
    final currentEmpty = currentText.trim().isEmpty;
    return previousEmpty && !currentEmpty;
  }
}
