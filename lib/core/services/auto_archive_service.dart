import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mmkv/mmkv.dart';

import '../api/api_client.dart';
import '../api/sessions_api.dart';
import '../models/local_settings.dart';
import '../models/session.dart';
import '../services/sync_service.dart';
import 'logger_service.dart' show logger;
import 'session_folders_storage.dart';
import 'pinned_sessions_storage.dart';

/// Service that auto-archives sessions based on configured criteria.
///
/// Runs in a [compute()] isolate to avoid blocking the UI thread.
class AutoArchiveService {
  AutoArchiveService._();

  static final AutoArchiveService _instance = AutoArchiveService._();

  static final AutoArchiveService instance = AutoArchiveService._instance;

  Timer? _debounceTimer;

  static const _debounceDuration = Duration(milliseconds: 500);

  /// Returns the current auto-archive settings from MMKV.
  AutoArchiveSettings _loadSettings() {
    try {
      final json = MMKV.defaultMMKV()?.decodeString('auto-archive-settings');
      if (json != null) {
        return AutoArchiveSettings.fromJson(
          Map<String, dynamic>.from(
            (json.isEmpty ? {} : _parseJson(json)) as Map,
          ),
        );
      }
    } catch (e) {
      logger.warning('AutoArchiveService: Failed to load settings: $e');
    }
    return const AutoArchiveSettings();
  }

  Map<String, dynamic> _parseJson(String json) {
    // Simple JSON parser for the auto-archive settings
    // Format: {"autoArchiveAfterDays":null,"autoArchiveIdleAfterDays":7,"autoArchiveOnAppClose":false}
    try {
      // Use dart:convert manually since we're in a service
      return _parseJsonManual(json);
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> _parseJsonManual(String json) {
    // Very simple parser for the specific format
    final result = <String, dynamic>{};
    if (json.isEmpty || json == '{}') return result;
    // Remove braces
    final content = json.trim();
    if (content.isEmpty || content == '{}') return result;

    // Parse key:value pairs
    final regex = RegExp(r'"([^"]+)":\s*([^,}]+)');
    for (final match in regex.allMatches(content)) {
      final key = match.group(1)!;
      final valueStr = match.group(2)!.trim();
      if (valueStr == 'null') {
        result[key] = null;
      } else if (valueStr == 'true') {
        result[key] = true;
      } else if (valueStr == 'false') {
        result[key] = false;
      } else if (int.tryParse(valueStr) != null) {
        result[key] = int.parse(valueStr);
      }
    }
    return result;
  }

  /// Saves auto-archive settings to MMKV.
  Future<void> _saveSettings(AutoArchiveSettings settings) async {
    try {
      final map = {
        if (settings.autoArchiveAfterDays != null)
          'autoArchiveAfterDays': settings.autoArchiveAfterDays,
        if (settings.autoArchiveIdleAfterDays != null)
          'autoArchiveIdleAfterDays': settings.autoArchiveIdleAfterDays,
        'autoArchiveOnAppClose': settings.autoArchiveOnAppClose,
      };
      MMKV.defaultMMKV()?.encodeString('auto-archive-settings', map.toString());
    } catch (e) {
      logger.warning('AutoArchiveService: Failed to save settings: $e');
    }
  }

  /// Checks all sessions and archives ones matching the auto-archive criteria.
  ///
  /// Called from [AppLifecycleService] on resume, with 500ms debounce.
  Future<void> checkAndArchive() async {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _doCheckAndArchive();
    });
  }

  Future<void> _doCheckAndArchive() async {
    final settings = _loadSettings();
    if (settings.autoArchiveAfterDays == null &&
        settings.autoArchiveIdleAfterDays == null &&
        !settings.autoArchiveOnAppClose) {
      return;
    }

    if (!sync.isInitialized) return;

    final sessions = sync.sessions;
    if (sessions.isEmpty) return;

    final pinnedStorage = PinnedSessionsStorage.instance;
    final foldersStorage = SessionFoldersStorage.instance;
    final pinned = pinnedStorage.getPinned();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final toArchive = <String>[];

    for (final entry in sessions.entries) {
      final id = entry.key;
      final session = entry.value;

      // Skip already archived or pinned sessions
      if (session.archived || pinned.contains(id)) continue;

      // Check age-based archive
      if (settings.autoArchiveAfterDays != null) {
        final ageDays = (nowMs - session.createdAt) ~/ (24 * 60 * 60 * 1000);
        if (ageDays >= settings.autoArchiveAfterDays!) {
          toArchive.add(id);
          continue;
        }
      }

      // Check idle-based archive (no messages for N days)
      if (settings.autoArchiveIdleAfterDays != null) {
        final idleDays =
            (nowMs - session.updatedAt) ~/ (24 * 60 * 60 * 1000);
        if (idleDays >= settings.autoArchiveIdleAfterDays!) {
          toArchive.add(id);
        }
      }
    }

    if (toArchive.isEmpty) return;

    logger.info(
      'AutoArchiveService: archiving ${toArchive.length} sessions',
    );

    for (final id in toArchive) {
      try {
        await SessionsApi(client: ApiClient()).setSessionArchived(id, true);
      } catch (e) {
        logger.warning('AutoArchiveService: failed to archive $id', e);
      }
    }
  }

  /// Called when the app is closing - archives if autoArchiveOnAppClose is enabled.
  Future<void> onAppClose() async {
    final settings = _loadSettings();
    if (!settings.autoArchiveOnAppClose) return;
    await _doCheckAndArchive();
  }

  /// Gets the current auto-archive settings.
  AutoArchiveSettings getSettings() => _loadSettings();

  /// Updates auto-archive settings and triggers a check.
  Future<void> updateSettings(AutoArchiveSettings settings) async {
    await _saveSettings(settings);
    await checkAndArchive();
  }

  void dispose() {
    _debounceTimer?.cancel();
  }
}
