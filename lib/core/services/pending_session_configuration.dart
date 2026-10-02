import 'dart:convert';

import 'logger_service.dart';
import 'mmkv_storage.dart';

typedef SessionConfigurationSelection = ({String profileId, String modelMode});

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
        return (
          profileId: json['profileId'] as String,
          modelMode: json['modelMode'] as String,
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
  }) {
    final selection = (profileId: profileId, modelMode: modelMode);
    MMKVStorage().setString(
      _key(sessionId),
      jsonEncode({'profileId': profileId, 'modelMode': modelMode}),
    );
    return selection;
  }

  void clearIfCurrent(String sessionId, SessionConfigurationSelection applied) {
    if (read(sessionId) == applied) MMKVStorage().removeKey(_key(sessionId));
  }
}
