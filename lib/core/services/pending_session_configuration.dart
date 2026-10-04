import 'dart:convert';

import 'logger_service.dart';
import 'mmkv_storage.dart';

typedef SessionConfigurationSelection = ({
  String profileId,
  String modelMode,
  String? codexSpeed,
  int revision,
});

/// Picker intent remains pending until a replacement process acknowledges it.
/// Keep it separate from launch history, which is lost on app restart.
class PendingSessionConfiguration {
  String _key(String sessionId) => 'pending-session-configuration-$sessionId';

  SessionConfigurationSelection? read(String sessionId) {
    final value = MMKVStorage().getString(_key(sessionId));
    if (value == null) return null;
    try {
      final json = jsonDecode(value);
      if (json is Map<String, dynamic> &&
          json['profileId'] is String &&
          json['modelMode'] is String) {
        final codexSpeed = json['codexSpeed'];
        if (codexSpeed != null &&
            codexSpeed != 'standard' &&
            codexSpeed != 'fast') {
          logger.warning('Unsupported pending Codex speed: $sessionId');
          return null;
        }
        return (
          profileId: json['profileId'] as String,
          modelMode: json['modelMode'] as String,
          codexSpeed: codexSpeed as String?,
          revision: json['revision'] is int ? json['revision'] as int : 0,
        );
      }
    } on FormatException {
      logger.warning('Invalid pending session configuration: $sessionId');
    }
    return null;
  }

  SessionConfigurationSelection save(
    String sessionId, {
    required String profileId,
    required String modelMode,
    String? codexSpeed,
  }) {
    if (codexSpeed != null &&
        codexSpeed != 'standard' &&
        codexSpeed != 'fast') {
      throw ArgumentError.value(codexSpeed, 'codexSpeed');
    }
    final previous = read(sessionId);
    final revision = (previous?.revision ?? 0) + 1;
    final selection = (
      profileId: profileId,
      modelMode: modelMode,
      codexSpeed: codexSpeed ?? previous?.codexSpeed,
      revision: revision,
    );
    MMKVStorage().setString(
      _key(sessionId),
      jsonEncode({
        'profileId': profileId,
        'modelMode': modelMode,
        'codexSpeed': selection.codexSpeed,
        'revision': revision,
      }),
    );
    return selection;
  }

  /// Move the latest unacknowledged intent when restore redirects to a new ID.
  void moveCurrent(String sourceSessionId, String restoredSessionId) {
    if (sourceSessionId == restoredSessionId) return;
    final current = read(sourceSessionId);
    if (current == null) return;
    final restoredPrevious = read(restoredSessionId);
    final selection = (
      profileId: current.profileId,
      modelMode: current.modelMode,
      codexSpeed: current.codexSpeed,
      revision: (restoredPrevious?.revision ?? 0) + 1,
    );
    _write(restoredSessionId, selection);
    clearIfCurrent(sourceSessionId, current);
  }

  void clearIfCurrent(String sessionId, SessionConfigurationSelection applied) {
    if (read(sessionId) == applied) MMKVStorage().removeKey(_key(sessionId));
  }

  void _write(String sessionId, SessionConfigurationSelection selection) {
    MMKVStorage().setString(
      _key(sessionId),
      jsonEncode({
        'profileId': selection.profileId,
        'modelMode': selection.modelMode,
        'codexSpeed': selection.codexSpeed,
        'revision': selection.revision,
      }),
    );
  }
}
