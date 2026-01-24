import 'dart:math' as math;

/// Version comparison and validation utilities.
///
/// Provides functions for comparing semantic versions, checking minimum
/// version requirements, and parsing version strings.

/// Minimum required CLI version for full compatibility
const String minimumCliVersion = '0.10.0';

/// Compare two semantic version strings.
///
/// [version1] - First version to compare
/// [version2] - Second version to compare
///
/// Returns -1 if version1 < version2, 0 if equal, 1 if version1 > version2
int compareVersions(String version1, String version2) {
  // Handle pre-release versions by stripping suffix (e.g., "0.10.0-1" -> "0.10.0")
  String cleanVersion(String v) => v.split('-')[0];

  final v1Parts = cleanVersion(version1).split('.').map(int.tryParse).toList();
  final v2Parts = cleanVersion(version2).split('.').map(int.tryParse).toList();

  // Pad with zeros if needed
  final maxLength = math.max(v1Parts.length, v2Parts.length);
  while (v1Parts.length < maxLength) {
    v1Parts.add(null);
  }
  while (v2Parts.length < maxLength) {
    v2Parts.add(null);
  }

  for (var i = 0; i < maxLength; i++) {
    final v1 = v1Parts[i] ?? 0;
    final v2 = v2Parts[i] ?? 0;
    if (v1 > v2) return 1;
    if (v1 < v2) return -1;
  }

  return 0;
}

/// Check if a version meets the minimum requirement.
///
/// [version] - Version to check
/// [minimumVersion] - Minimum required version (defaults to [minimumCliVersion])
///
/// Returns true if version >= minimumVersion
bool isVersionSupported(String? version, [String minimumVersion = minimumCliVersion]) {
  if (version == null) return false;

  try {
    return compareVersions(version, minimumVersion) >= 0;
  } catch (_) {
    // If version comparison fails, assume it's not supported
    return false;
  }
}

/// Parsed version components.
class ParsedVersion {
  final int major;
  final int minor;
  final int patch;

  const ParsedVersion({required this.major, required this.minor, required this.patch});

  @override
  String toString() => '$major.$minor.$patch';

  @override
  bool operator ==(Object other) {
    return other is ParsedVersion &&
        major == other.major &&
        minor == other.minor &&
        patch == other.patch;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch);
}

/// Parse version string to extract major, minor, and patch numbers.
///
/// [version] - Version string to parse (e.g., "1.2.3" or "1.2.3-beta")
///
/// Returns [ParsedVersion] with components, or null if invalid
ParsedVersion? parseVersion(String version) {
  try {
    final cleanVersion = version.split('-')[0];
    final parts = cleanVersion.split('.');

    if (parts.length < 3) {
      return null;
    }

    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    final patch = int.tryParse(parts[2]);

    if (major == null || minor == null || patch == null) {
      return null;
    }

    return ParsedVersion(major: major, minor: minor, patch: patch);
  } catch (_) {
    return null;
  }
}

/// Check if a version is a pre-release (has suffix like "-beta", "-alpha", etc.)
bool isPreRelease(String version) {
  return version.contains('-');
}

/// Get the pre-release suffix from a version string.
String? getPreReleaseSuffix(String version) {
  final parts = version.split('-');
  if (parts.length > 1) {
    return parts.sublist(1).join('-');
  }
  return null;
}

/// Format version parts as a string.
String formatVersion(int major, int minor, int patch, [String? suffix]) {
  var version = '$major.$minor.$patch';
  if (suffix != null && suffix.isNotEmpty) {
    version = '$version-$suffix';
  }
  return version;
}
