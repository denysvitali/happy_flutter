import 'dart:async';
import 'dart:convert';

import '../api/api_client.dart';
import '../api/sessions_api.dart';
import '../models/local_settings.dart';
import '../models/session.dart';
import '../services/sync_service.dart';
import 'logger_service.dart' show logger;
import 'mmkv_storage.dart';
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

  static const _settingsKey = 'auto-archive-settings';

  static const defaultIdleArchive = Duration(hours: 2);

  static const defaultSettings = AutoArchiveSettings(
    autoArchiveIdleAfterDays: -120,
  );

  final _storage = MMKVStorage();

  /// Returns the current auto-archive settings from storage.
  AutoArchiveSettings _loadSettings() {
    try {
      final raw = _storage.getString(_settingsKey);
      if (raw != null && raw.isNotEmpty) {
        return AutoArchiveSettings.fromJson(_parseSettings(raw));
      }
    } catch (e) {
      logger.warning('AutoArchiveService: Failed to load settings: $e');
    }
    return defaultSettings;
  }

  Map<String, dynamic> _parseSettings(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return _parseLegacyMapString(raw);
    }
    return {};
  }

  Map<String, dynamic> _parseLegacyMapString(String raw) {
    final result = <String, dynamic>{};
    if (raw.isEmpty || raw == '{}') return result;

    final content = raw.trim();
    if (content.isEmpty || content == '{}') return result;

    final regex = RegExp(r'''['"]?([^'",{}:\s]+)['"]?:\s*([^,}]+)''');
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

  /// Saves auto-archive settings to storage.
  Future<void> _saveSettings(AutoArchiveSettings settings) async {
    try {
      final map = {
        if (settings.autoArchiveAfterDays != null)
          'autoArchiveAfterDays': settings.autoArchiveAfterDays,
        if (settings.autoArchiveIdleAfterDays != null)
          'autoArchiveIdleAfterDays': settings.autoArchiveIdleAfterDays,
        'autoArchiveOnAppClose': settings.autoArchiveOnAppClose,
      };
      _storage.setString(_settingsKey, jsonEncode(map));
    } catch (e) {
      logger.warning('AutoArchiveService: Failed to save settings: $e');
    }
  }

  static Duration? idleArchiveDuration(AutoArchiveSettings settings) {
    final encoded = settings.autoArchiveIdleAfterDays;
    if (encoded == null) return null;
    if (encoded < 0) return Duration(minutes: -encoded);
    if (encoded == 0) return Duration.zero;
    return Duration(days: encoded);
  }

  static int encodeIdleDuration(Duration duration) {
    if (duration.inMinutes < Duration.minutesPerDay) {
      return -duration.inMinutes;
    }
    return duration.inDays;
  }

  static bool hasPendingPermission(Session session) {
    final requests = session.agentState?.requests;
    return requests != null && requests.isNotEmpty;
  }

  static bool hasUnsettledSend(List<Map<String, dynamic>> messages) {
    return messages.any((message) {
      final status = message['sendStatus'];
      return status == 'sending' || status == 'pending' || status == 'failed';
    });
  }

  static bool shouldArchiveSession({
    required Session session,
    required AutoArchiveSettings settings,
    required int nowMs,
    required bool isPinned,
    required bool hasUnsettledSend,
  }) {
    if (session.archived || isPinned) return false;
    if (session.active) return false;
    if (session.presence == 'online' || session.thinking) return false;
    if (hasPendingPermission(session)) return false;
    if (hasUnsettledSend) return false;
    if (session.draft != null && session.draft!.isNotEmpty) return false;

    final ageDays = settings.autoArchiveAfterDays;
    if (ageDays != null) {
      final age = Duration(milliseconds: nowMs - session.createdAt);
      if (age >= Duration(days: ageDays)) return true;
    }

    final idleDuration = idleArchiveDuration(settings);
    if (idleDuration != null) {
      final idle = Duration(milliseconds: nowMs - session.updatedAt);
      if (idle >= idleDuration) return true;
    }

    return false;
  }

  /// Checks all sessions and archives ones matching the criteria.
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
        idleArchiveDuration(settings) == null &&
        !settings.autoArchiveOnAppClose) {
      return;
    }

    if (!sync.isInitialized) return;

    final sessions = sync.sessions;
    if (sessions.isEmpty) return;

    final pinnedStorage = PinnedSessionsStorage.instance;
    final pinned = pinnedStorage.getPinned();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final toArchive = <String>[];

    for (final entry in sessions.entries) {
      final id = entry.key;
      final session = entry.value;

      if (shouldArchiveSession(
        session: session,
        settings: settings,
        nowMs: nowMs,
        isPinned: pinned.contains(id),
        hasUnsettledSend: hasUnsettledSend(sync.messagesForSession(id)),
      )) {
        toArchive.add(id);
      }
    }

    if (toArchive.isEmpty) return;

    logger.info('AutoArchiveService: archiving ${toArchive.length} sessions');

    for (final id in toArchive) {
      try {
        await SessionsApi(client: ApiClient()).setSessionArchived(id, true);
      } catch (e) {
        logger.warning('AutoArchiveService: failed to archive $id', e);
      }
    }
  }

  /// Called when the app is closing - archives if enabled.
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
