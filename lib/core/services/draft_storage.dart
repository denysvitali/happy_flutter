import 'dart:async';
import 'package:flutter/foundation.dart';
import 'mmkv_storage.dart';

/// Service for managing draft message persistence
class DraftStorage {
  final MMKVStorage _storage;

  DraftStorage({MMKVStorage? storage}) : _storage = storage ?? MMKVStorage();

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

  /// Clear all drafts for a session (including permission mode)
  Future<void> clearSessionData(String sessionId) async {
    await removeDraft(sessionId);
    await _storage.removeSessionPermissionMode(sessionId);
  }
}

/// Auto-save mechanism for drafts with debouncing
class DraftAutoSave {
  String sessionId;
  void Function(String draft) onSave;
  Timer? _debounceTimer;
  String _pendingDraft = '';
  Duration debounceDuration;

  DraftAutoSave({
    required this.sessionId,
    required this.onSave,
    this.debounceDuration = const Duration(seconds: 1),
  });

  /// Update the draft content
  void update(String draft) {
    _pendingDraft = draft;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, _save);
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
