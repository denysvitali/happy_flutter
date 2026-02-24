import 'dart:math' as math;

/// Calculate device dimensions in inches
///
/// [widthPoints] - Logical points (what Flutter MediaQuery returns)
/// [heightPoints] - Logical points (what Flutter MediaQuery returns)
/// [pointsPerInch] - Default is 160 for Android, 163 for iOS
///
/// Returns the width, height, and diagonal in inches
DeviceDimensions calculateDeviceDimensions({
  required double widthPoints,
  required double heightPoints,
  double pointsPerInch = 160,
}) {
  // Flutter MediaQuery returns points, not pixels
  // Points are density-independent units
  // On iOS: 1 point = 1/163 inch (Retina displays)
  // On Android: 1 point = 1/160 inch (dp/dip)
  // pixelDensity from PixelRatio.get() is the scale factor (e.g., 2x, 3x)
  // but it doesn't affect the inch calculation since we're already in points

  final widthInches = widthPoints / pointsPerInch;
  final heightInches = heightPoints / pointsPerInch;
  final diagonalInches =
      math.sqrt(widthInches * widthInches + heightInches * heightInches);

  return DeviceDimensions(
    widthInches: widthInches,
    heightInches: heightInches,
    diagonalInches: diagonalInches,
  );
}

/// Device dimensions result
class DeviceDimensions {
  const DeviceDimensions({
    required this.widthInches,
    required this.heightInches,
    required this.diagonalInches,
  });

  final double widthInches;
  final double heightInches;
  final double diagonalInches;
}

/// Determine device type based on dimensions and platform
///
/// [diagonalInches] - Device diagonal in inches
/// [platform] - Platform string ('ios', 'android', 'web', 'mac')
/// [isPad] - For iOS, whether the device is an iPad
/// [tabletThresholdInches] - Default is 9 inches
///
/// Returns 'phone' or 'tablet'
DeviceType determineDeviceType({
  required double diagonalInches,
  required String platform,
  bool isPad = false,
  double tabletThresholdInches = 9,
}) {
  // iOS-specific check: iPads with diagonal > 9" are tablets
  // This treats iPad Mini (7.9-8.3") as a phone
  if (platform == 'ios' && isPad) {
    return diagonalInches > 9 ? DeviceType.tablet : DeviceType.phone;
  }

  // General check: devices with diagonal >= threshold are tablets
  // 9" threshold ensures foldables (typically 7-8") are treated as phones
  return diagonalInches >= tabletThresholdInches
      ? DeviceType.tablet
      : DeviceType.phone;
}

/// Device type enum
enum DeviceType {
  phone,
  tablet,
}

/// Calculate header height based on platform, device info, and orientation
///
/// [platform] - Platform string ('ios', 'android', 'web', 'mac')
/// [isLandscape] - Whether the device is in landscape orientation
/// [isPad] - For iOS, whether the device is an iPad (use Platform.isPad)
/// [deviceType] - For Android, use our device type detection
/// [isMacCatalyst] - For Mac Catalyst apps
///
/// Returns the header height in points
double calculateHeaderHeight({
  required String platform,
  required bool isLandscape,
  bool isPad = false,
  DeviceType? deviceType,
  bool isMacCatalyst = false,
}) {
  // Mac Catalyst: Use dedicated height for desktop environment
  if (isMacCatalyst) {
    // Mac Catalyst: 52 points (slightly taller than iOS for desktop feel)
    return 56;
  }

  // Web platform: Use Material Design height
  if (platform == 'web') {
    return 56; // Web: 64px for consistency with Material Design
  }

  if (platform == 'android') {
    // For Android, use our custom device type detection
    if (deviceType == DeviceType.phone) {
      // Material Design: 48dp landscape, 56dp portrait
      return isLandscape ? 48 : 56;
    }
    return 64; // Tablet: 64dp
  }

  // iOS: Use Platform.isPad for accurate native header height
  if (isPad) {
    return 50; // iPad (iOS 12+): 50 points
  }
  return 44; // iPhone: 44 points
}
