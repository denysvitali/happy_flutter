import 'dart:math' as math;

/// Device-related utility functions for calculating dimensions and detecting device types.
///
/// These functions are platform-agnostic and can be used without dependencies
/// on Flutter's platform-specific APIs.

/// Calculate device dimensions in inches from logical points.
///
/// [widthPoints] - Logical width in points (what Flutter MediaQuery returns)
/// [heightPoints] - Logical height in points (what Flutter MediaQuery returns)
/// [pointsPerInch] - Points per inch (default: 160 for Android, 163 for iOS)
///
/// Returns width, height, and diagonal dimensions in inches.
({double widthInches, double heightInches, double diagonalInches})
    calculateDeviceDimensions({
  required double widthPoints,
  required double heightPoints,
  double pointsPerInch = 160,
}) {
  // Flutter MediaQuery sizes are in logical pixels (points), not physical pixels
  // Points are density-independent units
  // On iOS: 1 point = 1/163 inch (Retina displays)
  // On Android: 1 point = 1/160 inch (dp/dip)
  // pixelDensity from MediaQuery.devicePixelRatio is the scale factor (e.g., 2x, 3x)
  // but it doesn't affect the inch calculation since we're already in points

  final widthInches = widthPoints / pointsPerInch;
  final heightInches = heightPoints / pointsPerInch;
  final diagonalInches = math.sqrt(
    widthInches * widthInches + heightInches * heightInches,
  );

  return (
    widthInches: widthInches,
    heightInches: heightInches,
    diagonalInches: diagonalInches,
  );
}

/// Determine device type based on dimensions and platform.
///
/// [diagonalInches] - Screen diagonal in inches from calculateDeviceDimensions
/// [isPad] - Whether the device is an iPad (for iOS)
/// [tabletThresholdInches] - Threshold for tablet detection (default: 9 inches)
///
/// Returns 'phone' or 'tablet'
String determineDeviceType({
  required double diagonalInches,
  required bool isPad,
  double tabletThresholdInches = 9,
}) {
  // iOS-specific check: iPads with diagonal > 9" are tablets
  // This treats iPad Mini (7.9-8.3") as a phone
  if (isPad) {
    return diagonalInches > tabletThresholdInches ? 'tablet' : 'phone';
  }

  // General check: devices with diagonal >= threshold are tablets
  // 9" threshold ensures foldables (typically 7-8") are treated as phones
  return diagonalInches >= tabletThresholdInches ? 'tablet' : 'phone';
}

/// Calculate header height based on platform, device info, and orientation.
///
/// [isLandscape] - Whether the device is in landscape orientation
/// [isPad] - Whether the device is a tablet (for iOS)
/// [deviceType] - Device type ('phone' or 'tablet') for Android
/// [isMacCatalyst] - Whether running on Mac Catalyst
///
/// Returns the header height in points.
double calculateHeaderHeight({
  required bool isLandscape,
  required bool isPad,
  String? deviceType,
  bool isMacCatalyst = false,
}) {
  // Mac Catalyst: Use dedicated height for desktop environment
  if (isMacCatalyst) {
    return 56; // Mac Catalyst: 56 points (slightly taller for desktop feel)
  }

  if (deviceType != null) {
    // Android: use device type detection
    if (deviceType == 'phone') {
      return isLandscape ? 48 : 56; // Material Design: 48dp landscape, 56dp portrait
    }
    return 64; // Tablet: 64dp
  }

  // iOS: use isPad for accurate native header height
  if (isPad) {
    return 50; // iPad (iOS 12+): 50 points
  }
  return 44; // iPhone: 44 points
}
