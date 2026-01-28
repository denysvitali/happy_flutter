import 'dart:math' as math;

/// Device type enumeration for clear type distinction.
enum DeviceType {
  phone('phone'),
  tablet('tablet');

  final String value;

  const DeviceType(this.value);

  /// Parse a string value to DeviceType
  static DeviceType fromString(String value) {
    return switch (value.toLowerCase()) {
      'tablet' => DeviceType.tablet,
      _ => DeviceType.phone,
    };
  }
}

/// Platform enumeration for cross-platform header height calculations.
enum PlatformType {
  ios,
  android,
  macos,
  windows,
  linux,
  web,
}

/// Result type for device dimension calculations.
class DeviceDimensions {
  final double widthInches;
  final double heightInches;
  final double diagonalInches;

  const DeviceDimensions({
    required this.widthInches,
    required this.heightInches,
    required this.diagonalInches,
  });

  @override
  String toString() {
    return 'DeviceDimensions('
        'widthInches: ${widthInches.toStringAsFixed(2)}, '
        'heightInches: ${heightInches.toStringAsFixed(2)}, '
        'diagonalInches: ${diagonalInches.toStringAsFixed(2)})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DeviceDimensions) return false;
    return widthInches == other.widthInches &&
        heightInches == other.heightInches &&
        diagonalInches == other.diagonalInches;
  }

  @override
  int get hashCode => Object.hash(widthInches, heightInches, diagonalInches);
}

/// Calculate device dimensions in inches from logical points.
///
/// [widthPoints] - Logical width in points (what Flutter MediaQuery returns)
/// [heightPoints] - Logical height in points (what Flutter MediaQuery returns)
/// [pointsPerInch] - Points per inch (default: 160 for Android, 163 for iOS)
///
/// Returns a [DeviceDimensions] with width, height, and diagonal dimensions in inches.
DeviceDimensions getDeviceDimensions({
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

  return DeviceDimensions(
    widthInches: widthInches,
    heightInches: heightInches,
    diagonalInches: diagonalInches,
  );
}

/// Determine device type based on dimensions and platform.
///
/// [diagonalInches] - Screen diagonal in inches from getDeviceDimensions
/// [isPad] - Whether the device is an iPad (for iOS)
/// [tabletThresholdInches] - Threshold for tablet detection (default: 9 inches)
///
/// Returns the device type as a [DeviceType]
DeviceType getDeviceType({
  required double diagonalInches,
  required bool isPad,
  double tabletThresholdInches = 9,
}) {
  // iOS-specific check: iPads with diagonal > 9" are tablets
  // This treats iPad Mini (7.9-8.3") as a phone
  if (isPad) {
    return diagonalInches > tabletThresholdInches
        ? DeviceType.tablet
        : DeviceType.phone;
  }

  // General check: devices with diagonal >= threshold are tablets
  // 9" threshold ensures foldables (typically 7-8") are treated as phones
  return diagonalInches >= tabletThresholdInches
      ? DeviceType.tablet
      : DeviceType.phone;
}

/// Check if the device is a tablet based on screen dimensions.
///
/// [diagonalInches] - Screen diagonal in inches
/// [tabletThresholdInches] - Threshold for tablet detection (default: 9 inches)
///
/// Returns true if the device is a tablet, false otherwise
bool isTablet({
  required double diagonalInches,
  double tabletThresholdInches = 9,
}) {
  return diagonalInches >= tabletThresholdInches;
}

/// Check if the device is a phone based on screen dimensions.
///
/// [diagonalInches] - Screen diagonal in inches
/// [tabletThresholdInches] - Threshold for tablet detection (default: 9 inches)
///
/// Returns true if the device is a phone, false otherwise
bool isPhone({
  required double diagonalInches,
  double tabletThresholdInches = 9,
}) {
  return diagonalInches < tabletThresholdInches;
}

/// Determine if device is a tablet with iOS-specific logic.
///
/// For iOS, uses the isPad flag to accurately detect iPads.
/// For other platforms, uses screen diagonal measurement.
///
/// [diagonalInches] - Screen diagonal in inches
/// [isPad] - Whether the device is an iPad (true for iOS iPads)
/// [tabletThresholdInches] - Threshold for non-iOS tablet detection (default: 9 inches)
bool getIsTablet({
  required double diagonalInches,
  required bool isPad,
  double tabletThresholdInches = 9,
}) {
  // iOS: use Platform.isPad for accurate native detection
  if (isPad) {
    // iPads with diagonal > 9" are tablets (iPad Mini is phone-sized)
    return diagonalInches > tabletThresholdInches;
  }

  // Other platforms: use diagonal threshold
  return diagonalInches >= tabletThresholdInches;
}

/// Calculate header height based on platform, device info, and orientation.
///
/// [platformType] - The current platform
/// [isLandscape] - Whether the device is in landscape orientation
/// [isPad] - Whether the device is a tablet (for iOS)
/// [deviceType] - Device type (phone or tablet) for Android
/// [isMacCatalyst] - Whether running on Mac Catalyst
///
/// Returns the header height in points (logical pixels).
double getHeaderHeight({
  required PlatformType platformType,
  required bool isLandscape,
  required bool isPad,
  DeviceType deviceType = DeviceType.phone,
  bool isMacCatalyst = false,
}) {
  // Mac Catalyst: Use dedicated height for desktop environment
  if (isMacCatalyst) {
    return 56; // Mac Catalyst: 56 points (slightly taller for desktop feel)
  }

  switch (platformType) {
    case PlatformType.ios:
      // iOS: use isPad for accurate native header height
      if (isPad) {
        return 50; // iPad (iOS 12+): 50 points
      }
      return 44; // iPhone: 44 points

    case PlatformType.android:
      // Android: use device type detection
      if (deviceType == DeviceType.phone) {
        return isLandscape ? 48 : 56; // Material Design: 48dp landscape, 56dp portrait
      }
      return 64; // Tablet: 64dp

    case PlatformType.web:
      return 56; // Web: 56px for consistency with Material Design

    case PlatformType.macos:
      return 56; // macOS: 56 points for desktop feel

    case PlatformType.windows:
    case PlatformType.linux:
      return 56; // Desktop platforms: 56 points
  }
}

/// Get the standard points per inch for a given platform.
///
/// [platformType] - The current platform
///
/// Returns points per inch: 163 for iOS, 160 for others
double getPointsPerInch(PlatformType platformType) {
  return switch (platformType) {
    PlatformType.ios => 163,
    _ => 160,
  };
}
