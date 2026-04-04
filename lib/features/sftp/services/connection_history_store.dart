import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/connection_event.dart';

/// Persists SFTP connection events to local storage
class ConnectionHistoryStore {
  static const int _maxEvents = 5000;

  List<ConnectionEvent> _events = [];
  bool _initialized = false;

  Future<File> get _historyFile async {
    final appDir = await getApplicationSupportDirectory();
    return File(
      '${appDir.path}/sftp_connection_history.json',
    );
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final file = await _historyFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final jsonList = jsonDecode(content) as List;
        _events = jsonList
            .map(
              (j) => ConnectionEvent.fromJson(
                j as Map<String, dynamic>,
              ),
            )
            .toList();
      }
    } catch (_) {
      _events = [];
    }
  }

  Future<void> addEvent(ConnectionEvent event) async {
    _events.insert(0, event);

    if (_events.length > _maxEvents) {
      _events = _events.sublist(0, _maxEvents);
    }

    await _save();
  }

  List<ConnectionEvent> getEvents({
    String? deviceId,
    String? username,
    ConnectionEventType? eventType,
    int limit = 100,
  }) {
    var events = _events;

    if (deviceId != null) {
      events = events
          .where((e) => e.deviceId == deviceId)
          .toList();
    }
    if (username != null) {
      events = events
          .where((e) => e.username == username)
          .toList();
    }
    if (eventType != null) {
      events = events
          .where((e) => e.eventType == eventType)
          .toList();
    }

    return events.take(limit).toList();
  }

  List<String> get allUsernames {
    return _events.map((e) => e.username).toSet().toList()
      ..sort();
  }

  List<String> get allDeviceIds {
    return _events.map((e) => e.deviceId).toSet().toList()
      ..sort();
  }

  Future<void> clear() async {
    _events = [];
    await _save();
  }

  /// Returns connection stats for a single device
  Map<String, dynamic> getDeviceStats(String deviceId) {
    final deviceEvents =
        _events.where((e) => e.deviceId == deviceId).toList();

    final connects = deviceEvents
        .where(
          (e) => e.eventType == ConnectionEventType.connect,
        )
        .length;
    final disconnects = deviceEvents
        .where(
          (e) =>
              e.eventType == ConnectionEventType.disconnect,
        )
        .length;
    final authFailures = deviceEvents
        .where(
          (e) =>
              e.eventType == ConnectionEventType.authFailure,
        )
        .length;

    final sessions = deviceEvents
        .where(
          (e) =>
              e.eventType == ConnectionEventType.sessionEnd,
        )
        .where((e) => e.duration != null)
        .toList();

    var totalDuration = Duration.zero;
    for (final s in sessions) {
      totalDuration += s.duration!;
    }

    final avgDuration = sessions.isNotEmpty
        ? Duration(
            milliseconds:
                totalDuration.inMilliseconds ~/
                sessions.length,
          )
        : Duration.zero;

    return {
      'totalConnections': connects,
      'totalDisconnections': disconnects,
      'authFailures': authFailures,
      'totalSessions': sessions.length,
      'totalDuration': totalDuration,
      'avgDuration': avgDuration,
      'uniqueUsers':
          deviceEvents.map((e) => e.username).toSet().length,
    };
  }

  Future<void> _save() async {
    try {
      final file = await _historyFile;
      final jsonList =
          _events.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (_) {
      // Silently fail on save errors
    }
  }
}

/// Global singleton for connection history
final connectionHistoryStore = ConnectionHistoryStore();
