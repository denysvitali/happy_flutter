import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A single log entry captured from the SFTP server
class SftpLogEntry {
  const SftpLogEntry({
    required this.timestamp,
    required this.deviceId,
    required this.deviceName,
    required this.level,
    required this.message,
    this.username,
    this.ipAddress,
    this.operation,
    this.details,
  });

  factory SftpLogEntry.fromJson(Map<String, dynamic> json) {
    return SftpLogEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String? ?? 'Unknown',
      level: json['level'] as String? ?? 'info',
      message: json['message'] as String,
      username: json['username'] as String?,
      ipAddress: json['ipAddress'] as String?,
      operation: json['operation'] as String?,
      details: json['details'] as String?,
    );
  }

  final DateTime timestamp;
  final String deviceId;
  final String deviceName;
  final String level;
  final String message;
  final String? username;
  final String? ipAddress;
  final String? operation;
  final String? details;

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'deviceId': deviceId,
      'deviceName': deviceName,
      'level': level,
      'message': message,
      if (username != null) 'username': username,
      if (ipAddress != null) 'ipAddress': ipAddress,
      if (operation != null) 'operation': operation,
      if (details != null) 'details': details,
    };
  }
}

/// Manages per-device SFTP logs with local persistence
class SftpLogStore {
  static const int _maxLogsPerDevice = 1000;
  static const Duration _logRetention = Duration(days: 7);

  final Map<String, List<SftpLogEntry>> _logs = {};
  bool _initialized = false;

  Future<Directory> get _logDir async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory('${appDir.path}/sftp_logs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _loadFromDisk();
  }

  /// Add a log entry for a device
  Future<void> addLog(SftpLogEntry entry) async {
    _logs.putIfAbsent(entry.deviceId, () => []);
    final deviceLogs = _logs[entry.deviceId]!;
    deviceLogs.insert(0, entry);

    // Enforce max logs per device
    if (deviceLogs.length > _maxLogsPerDevice) {
      deviceLogs.removeRange(_maxLogsPerDevice, deviceLogs.length);
    }

    await _saveToDevice(entry.deviceId);
  }

  /// Get logs for a specific device
  List<SftpLogEntry> getLogs(String deviceId) {
    return List.unmodifiable(_logs[deviceId] ?? []);
  }

  /// Get all device IDs that have logs
  List<String> get deviceIdsWithLogs => List.unmodifiable(_logs.keys);

  /// Clear logs for a specific device
  Future<void> clearDeviceLogs(String deviceId) async {
    _logs.remove(deviceId);
    await _deleteDeviceFile(deviceId);
  }

  /// Clear all logs
  Future<void> clearAll() async {
    _logs.clear();
    final dir = await _logDir;
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Rotate logs: remove entries older than [_logRetention]
  Future<void> rotateLogs() async {
    final cutoff = DateTime.now().subtract(_logRetention);
    var changed = false;

    for (final entry in _logs.entries) {
      final originalLength = entry.value.length;
      entry.value.removeWhere((log) => log.timestamp.isBefore(cutoff));
      if (entry.value.length != originalLength) {
        changed = true;
      }
    }

    if (changed) {
      await _saveAllToDisk();
    }
  }

  /// Get total log count across all devices
  int get totalLogCount {
    var count = 0;
    for (final logs in _logs.values) {
      count += logs.length;
    }
    return count;
  }

  Future<File> _deviceFile(String deviceId) async {
    final dir = await _logDir;
    return File('${dir.path}/$deviceId.json');
  }

  Future<void> _saveToDevice(String deviceId) async {
    final logs = _logs[deviceId];
    if (logs == null || logs.isEmpty) return;

    final file = await _deviceFile(deviceId);
    final jsonList = logs.map((l) => l.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  Future<void> _saveAllToDisk() async {
    for (final deviceId in _logs.keys) {
      await _saveToDevice(deviceId);
    }
  }

  Future<void> _deleteDeviceFile(String deviceId) async {
    final file = await _deviceFile(deviceId);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _loadFromDisk() async {
    final dir = await _logDir;
    if (!await dir.exists()) return;

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final jsonList = jsonDecode(content) as List;
          final logs = jsonList
              .map(
                (j) =>
                    SftpLogEntry.fromJson(j as Map<String, dynamic>),
              )
              .toList();

          if (logs.isNotEmpty) {
            _logs[logs.first.deviceId] = logs;
          }
        } catch (_) {
          // Skip corrupted files
        }
      }
    }
  }
}

/// Global singleton log store
final sftpLogStore = SftpLogStore();
