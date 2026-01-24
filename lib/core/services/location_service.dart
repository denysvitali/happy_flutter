import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Service for GPS location functionality.
///
/// Provides location access with:
/// - Current position retrieval
/// - Continuous position updates
/// - Location permission handling
class LocationService {
  final GeolocatorPlatform _geolocator = GeolocatorPlatform.instance;

  /// Check if location services are enabled on the device
  Future<bool> get isLocationServiceEnabled async {
    return await _geolocator.isLocationServiceEnabled();
  }

  /// Check current location permission status
  Future<LocationPermission> get permissionStatus async {
    return await _geolocator.checkPermission();
  }

  /// Request location permission from user
  Future<LocationPermission> requestPermission() async {
    return await _geolocator.requestPermission();
  }

  /// Get current location position.
  ///
  /// [accuracy] Desired accuracy level
  /// [timeLimit] Maximum time to wait for position
  Future<LocationPosition?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeLimit = const Duration(seconds: 30),
  }) async {
    try {
      final hasPermission = await _checkPermission();
      if (!hasPermission) {
        return null;
      }

      final position = await _geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
        ),
      );

      return LocationPosition(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        heading: position.heading,
        speed: position.speed,
        timestamp: position.timestamp,
      );
    } catch (e) {
      return null;
    }
  }

  /// Stream of continuous location updates.
  ///
  /// [accuracy] Desired accuracy level
  /// [distanceFilter] Minimum distance (meters) between updates
  Stream<LocationPosition> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 0,
  }) async* {
    final hasPermission = await _checkPermission();
    if (!hasPermission) {
      return;
    }

    final stream = _geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );

    await for (final position in stream) {
      yield LocationPosition(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        heading: position.heading,
        speed: position.speed,
        timestamp: position.timestamp,
      );
    }
  }

  /// Calculate distance between two points in meters.
  ///
  /// Returns null if calculation fails
  double? calculateDistance({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    try {
      return _geolocator.distanceBetween(
        startLatitude,
        startLongitude,
        endLatitude,
        endLongitude,
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if permission is granted, request if not
  Future<bool> _checkPermission() async {
    var permission = await permissionStatus;

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await requestPermission();
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Open app location settings
  Future<void> openLocationSettings() async {
    await _geolocator.openAppSettings();
  }
}

/// Wrapper class for position data
class LocationPosition {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double altitude;
  final double heading;
  final double speed;
  final DateTime? timestamp;

  LocationPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.altitude,
    required this.heading,
    required this.speed,
    required this.timestamp,
  });

  /// Convert to JSON for storage/transmission
  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'altitude': altitude,
        'heading': heading,
        'speed': speed,
        'timestamp': timestamp?.toIso8601String(),
      };

  /// Create from JSON
  factory LocationPosition.fromJson(Map<String, dynamic> json) {
    return LocationPosition(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      accuracy: json['accuracy'] as double,
      altitude: json['altitude'] as double,
      heading: json['heading'] as double,
      speed: json['speed'] as double,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}
