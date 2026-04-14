import 'dart:io' show Platform;

/// Returns the Dart runtime version string.
String getDartVersion() {
  // Platform.version format:
  // '3.10.0 (stable) (...) on "linux_x64"'
  final match = RegExp(r'^(\d+\.\d+\.\d+)').firstMatch(Platform.version);
  return match?.group(1) ?? Platform.version;
}
