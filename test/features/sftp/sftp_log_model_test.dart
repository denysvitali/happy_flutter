import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/sftp/models/sftp_log.dart';

void main() {
  group('SftpLogEntry', () {
    group('fromJson', () {
      test('parses required fields', () {
        final json = {
          'timestamp': '2026-03-13T10:00:00.000Z',
          'deviceId': 'device-1',
          'deviceName': 'Laptop',
          'level': 'info',
          'message': 'Connection established',
        };

        final entry = SftpLogEntry.fromJson(json);

        expect(entry.timestamp, DateTime.utc(2026, 3, 13, 10, 0, 0));
        expect(entry.deviceId, 'device-1');
        expect(entry.deviceName, 'Laptop');
        expect(entry.level, 'info');
        expect(entry.message, 'Connection established');
        expect(entry.username, isNull);
        expect(entry.ipAddress, isNull);
        expect(entry.operation, isNull);
        expect(entry.details, isNull);
      });

      test('parses all fields including optional', () {
        final json = {
          'timestamp': '2026-03-13T12:30:45.123Z',
          'deviceId': 'device-2',
          'deviceName': 'Server',
          'level': 'error',
          'message': 'Upload failed',
          'username': 'admin',
          'ipAddress': '192.168.1.100',
          'operation': 'upload',
          'details': 'Permission denied',
        };

        final entry = SftpLogEntry.fromJson(json);

        expect(entry.timestamp, DateTime.utc(2026, 3, 13, 12, 30, 45, 123));
        expect(entry.deviceId, 'device-2');
        expect(entry.deviceName, 'Server');
        expect(entry.level, 'error');
        expect(entry.message, 'Upload failed');
        expect(entry.username, 'admin');
        expect(entry.ipAddress, '192.168.1.100');
        expect(entry.operation, 'upload');
        expect(entry.details, 'Permission denied');
      });

      test('defaults deviceName to Unknown when missing', () {
        final json = {
          'timestamp': '2026-03-13T08:00:00.000Z',
          'deviceId': 'device-3',
          'level': 'info',
          'message': 'Test',
        };

        final entry = SftpLogEntry.fromJson(json);
        expect(entry.deviceName, 'Unknown');
      });

      test('defaults level to info when missing', () {
        final json = {
          'timestamp': '2026-03-13T08:00:00.000Z',
          'deviceId': 'device-4',
          'deviceName': 'Test',
          'message': 'Test message',
        };

        final entry = SftpLogEntry.fromJson(json);
        expect(entry.level, 'info');
      });
    });

    group('toJson', () {
      test('serializes required fields', () {
        final entry = SftpLogEntry(
          timestamp: DateTime.utc(2026, 3, 13, 10, 0, 0),
          deviceId: 'device-1',
          deviceName: 'Laptop',
          level: 'info',
          message: 'Connected',
        );

        final json = entry.toJson();

        expect(json['timestamp'], '2026-03-13T10:00:00.000Z');
        expect(json['deviceId'], 'device-1');
        expect(json['deviceName'], 'Laptop');
        expect(json['level'], 'info');
        expect(json['message'], 'Connected');
        expect(json.containsKey('username'), isFalse);
        expect(json.containsKey('ipAddress'), isFalse);
        expect(json.containsKey('operation'), isFalse);
        expect(json.containsKey('details'), isFalse);
      });

      test('serializes optional fields when present', () {
        final entry = SftpLogEntry(
          timestamp: DateTime.utc(2026, 3, 13, 12, 0, 0),
          deviceId: 'device-2',
          deviceName: 'Server',
          level: 'warning',
          message: 'Slow transfer',
          username: 'user1',
          ipAddress: '10.0.0.1',
          operation: 'download',
          details: 'Network latency high',
        );

        final json = entry.toJson();

        expect(json['username'], 'user1');
        expect(json['ipAddress'], '10.0.0.1');
        expect(json['operation'], 'download');
        expect(json['details'], 'Network latency high');
      });

      test('omits null optional fields', () {
        final entry = SftpLogEntry(
          timestamp: DateTime.utc(2026, 3, 13),
          deviceId: 'device-3',
          deviceName: 'Test',
          level: 'info',
          message: 'Test',
          username: null,
          ipAddress: null,
          operation: null,
          details: null,
        );

        final json = entry.toJson();

        expect(json.containsKey('username'), isFalse);
        expect(json.containsKey('ipAddress'), isFalse);
        expect(json.containsKey('operation'), isFalse);
        expect(json.containsKey('details'), isFalse);
      });
    });

    group('toJson/fromJson round-trip', () {
      test('preserves all fields', () {
        final original = SftpLogEntry(
          timestamp: DateTime.utc(2026, 3, 13, 14, 30, 0, 500),
          deviceId: 'device-rt',
          deviceName: 'RoundTrip',
          level: 'debug',
          message: 'Testing round trip',
          username: 'tester',
          ipAddress: '127.0.0.1',
          operation: 'list',
          details: 'Directory listing',
        );

        final json = original.toJson();
        final restored = SftpLogEntry.fromJson(json);

        expect(restored.timestamp, original.timestamp);
        expect(restored.deviceId, original.deviceId);
        expect(restored.deviceName, original.deviceName);
        expect(restored.level, original.level);
        expect(restored.message, original.message);
        expect(restored.username, original.username);
        expect(restored.ipAddress, original.ipAddress);
        expect(restored.operation, original.operation);
        expect(restored.details, original.details);
      });

      test('round-trip without optional fields', () {
        final original = SftpLogEntry(
          timestamp: DateTime.utc(2026, 1, 1),
          deviceId: 'device-min',
          deviceName: 'Minimal',
          level: 'info',
          message: 'Minimal entry',
        );

        final json = original.toJson();
        final restored = SftpLogEntry.fromJson(json);

        expect(restored.timestamp, original.timestamp);
        expect(restored.deviceId, original.deviceId);
        expect(restored.username, isNull);
        expect(restored.ipAddress, isNull);
        expect(restored.operation, isNull);
        expect(restored.details, isNull);
      });
    });

    group('SftpLogStore', () {
      test('initial state is empty', () {
        final store = SftpLogStore();
        expect(store.totalLogCount, 0);
        expect(store.deviceIdsWithLogs, isEmpty);
      });

      test('getLogs returns empty list for unknown device', () {
        final store = SftpLogStore();
        final logs = store.getLogs('unknown-device');
        expect(logs, isEmpty);
      });

      test('getLogs returns unmodifiable list', () {
        final store = SftpLogStore();
        final logs = store.getLogs('device-1');
        expect(() => logs.add(
          SftpLogEntry(
            timestamp: DateTime.now(),
            deviceId: 'device-1',
            deviceName: 'Test',
            level: 'info',
            message: 'Test',
          ),
        ), throwsUnsupportedError);
      });

      test('deviceIdsWithLogs returns unmodifiable list', () {
        final store = SftpLogStore();
        final ids = store.deviceIdsWithLogs;
        expect(() => ids.add('new-id'), throwsUnsupportedError);
      });

      test('totalLogCount is initially zero', () {
        final store = SftpLogStore();
        expect(store.totalLogCount, 0);
      });
    });
  });
}
