import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationPosition', () {
    test('fromJson creates correct instance', () {
      final json = {
        'latitude': 37.7749,
        'longitude': -122.4194,
        'accuracy': 10.5,
        'altitude': 15.0,
        'heading': 90.0,
        'speed': 5.5,
        'timestamp': '2026-03-13T10:30:00.000Z',
      };

      final position = LocationPosition.fromJson(json);

      expect(position.latitude, equals(37.7749));
      expect(position.longitude, equals(-122.4194));
      expect(position.accuracy, equals(10.5));
      expect(position.altitude, equals(15.0));
      expect(position.heading, equals(90.0));
      expect(position.speed, equals(5.5));
      expect(position.timestamp, isNotNull);
      expect(position.timestamp!.year, equals(2026));
      expect(position.timestamp!.month, equals(3));
      expect(position.timestamp!.day, equals(13));
    });

    test('fromJson handles null timestamp', () {
      final json = {
        'latitude': 0.0,
        'longitude': 0.0,
        'accuracy': 0.0,
        'altitude': 0.0,
        'heading': 0.0,
        'speed': 0.0,
        'timestamp': null,
      };

      final position = LocationPosition.fromJson(json);

      expect(position.timestamp, isNull);
    });

    test('toJson produces correct map', () {
      final timestamp = DateTime(2026, 3, 13, 10, 30, 0);
      final position = LocationPosition(
        latitude: 40.7128,
        longitude: -74.0060,
        accuracy: 5.0,
        altitude: 10.0,
        heading: 180.0,
        speed: 0.0,
        timestamp: timestamp,
      );

      final json = position.toJson();

      expect(json['latitude'], equals(40.7128));
      expect(json['longitude'], equals(-74.0060));
      expect(json['accuracy'], equals(5.0));
      expect(json['altitude'], equals(10.0));
      expect(json['heading'], equals(180.0));
      expect(json['speed'], equals(0.0));
      expect(json['timestamp'], equals(timestamp.toIso8601String()));
    });

    test('toJson handles null timestamp', () {
      final position = LocationPosition(
        latitude: 0.0,
        longitude: 0.0,
        accuracy: 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        timestamp: null,
      );

      final json = position.toJson();

      expect(json['timestamp'], isNull);
    });

    test('fromJson and toJson are symmetric', () {
      final original = {
        'latitude': 51.5074,
        'longitude': -0.1278,
        'accuracy': 8.0,
        'altitude': 25.0,
        'heading': 45.0,
        'speed': 3.2,
        'timestamp': '2026-06-15T14:00:00.000Z',
      };

      final position = LocationPosition.fromJson(original);
      final roundTrip = position.toJson();

      expect(roundTrip['latitude'], equals(original['latitude']));
      expect(roundTrip['longitude'], equals(original['longitude']));
      expect(roundTrip['accuracy'], equals(original['accuracy']));
      expect(roundTrip['altitude'], equals(original['altitude']));
      expect(roundTrip['heading'], equals(original['heading']));
      expect(roundTrip['speed'], equals(original['speed']));
      // Timestamps round-trip through DateTime parsing
      expect(roundTrip['timestamp'], isNotNull);
    });

    test('all fields are accessible', () {
      final position = LocationPosition(
        latitude: 1.0,
        longitude: 2.0,
        accuracy: 3.0,
        altitude: 4.0,
        heading: 5.0,
        speed: 6.0,
        timestamp: DateTime(2026),
      );

      expect(position.latitude, equals(1.0));
      expect(position.longitude, equals(2.0));
      expect(position.accuracy, equals(3.0));
      expect(position.altitude, equals(4.0));
      expect(position.heading, equals(5.0));
      expect(position.speed, equals(6.0));
      expect(position.timestamp, equals(DateTime(2026)));
    });

    test('handles extreme coordinate values', () {
      final json = {
        'latitude': -90.0,
        'longitude': 180.0,
        'accuracy': 0.1,
        'altitude': -50.0,
        'heading': 359.9,
        'speed': 340.0,
        'timestamp': null,
      };

      final position = LocationPosition.fromJson(json);

      expect(position.latitude, equals(-90.0));
      expect(position.longitude, equals(180.0));
      expect(position.altitude, equals(-50.0));
      expect(position.heading, equals(359.9));
      expect(position.speed, equals(340.0));
    });
  });
}
