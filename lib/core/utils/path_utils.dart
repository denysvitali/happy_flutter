/// Path resolution utilities for handling relative and absolute paths.
///
/// Provides functions to resolve paths relative to a root and to expand
/// home directory references.

import 'package:path/path.dart' as path_lib;

typedef MetadataPath = String;

/// Metadata structure containing a root path for path resolution.
class Metadata {
  final String path;

  const Metadata({required this.path});
}

/// Resolves a path relative to the root path from metadata.
///
/// ALL paths are treated as relative to the metadata root, regardless of their format.
/// If metadata is not provided, returns the original path.
///
/// [path] - The path to resolve (always treated as relative to the metadata root)
/// [metadata] - Optional metadata containing the root path (can be Map or Metadata)
///
/// Returns the resolved absolute path
String resolvePath(String path, dynamic metadata) {
  if (metadata == null) {
    return path;
  }
  
  String metadataPath;
  if (metadata is Metadata) {
    metadataPath = metadata.path;
  } else if (metadata is Map<String, dynamic>) {
    metadataPath = metadata['path'] as String? ?? '';
  } else {
    return path;
  }
  
  final normalizedRoot = metadataPath.toLowerCase();
  final pathLower = path.toLowerCase();

  if (pathLower.startsWith(normalizedRoot)) {
    final remainder = path.substring(metadataPath.length);
    if (remainder.isEmpty || remainder.startsWith('/') || remainder.startsWith('\\')) {
      var out = remainder;
      if (out.startsWith('/') || out.startsWith('\\')) {
        out = out.substring(1);
      }
      if (out.isEmpty) {
        return '<root>';
      }
      return out;
    }
  }
  return path;
}

/// Resolves paths starting with ~ to absolute paths using the provided home directory.
///
/// Non-tilde paths are returned unchanged.
///
/// [path] - The path to resolve (may start with ~)
/// [homeDir] - The user's home directory (e.g., '/Users/user' or 'C:\Users\user')
///
/// Returns the resolved absolute path
String resolveAbsolutePath(String path, {String? homeDir}) {
  // Return original path if it doesn't start with ~
  if (!path.startsWith('~')) {
    return path;
  }

  // Return original path if no home directory provided
  if (homeDir == null) {
    return path;
  }

  // Handle exact ~ (home directory)
  if (path == '~') {
    // Remove trailing separator for consistency
    return homeDir.endsWith('/') || homeDir.endsWith('\\')
        ? homeDir.substring(0, homeDir.length - 1)
        : homeDir;
  }

  // Handle ~/ and ~/path (home directory with subdirectory)
  if (path.startsWith('~/')) {
    final relativePart = path.substring(2); // Remove '~/'
    // Detect path separator based on homeDir - prefer the last separator found
    final hasBackslash =
        homeDir.lastIndexOf('\\') > homeDir.lastIndexOf('/');
    final separator = hasBackslash ? '\\' : '/';
    final normalizedHome = homeDir.endsWith('/') || homeDir.endsWith('\\')
        ? homeDir.substring(0, homeDir.length - 1)
        : homeDir;
    return normalizedHome + separator + relativePart;
  }

  // Handle ~username paths (not supported, return original)
  return path;
}

/// Get the file name from a path.
String getFileName(String filePath) {
  return path_lib.basename(filePath);
}

/// Get the directory name from a path.
String getDirectoryName(String filePath) {
  return path_lib.dirname(filePath);
}

/// Get the file extension from a path.
String getFileExtension(String filePath) {
  return path_lib.extension(filePath);
}

/// Check if a path is absolute.
bool isAbsolutePath(String filePath) {
  return path_lib.isAbsolute(filePath);
}

/// Check if a path is relative.
bool isRelativePath(String filePath) {
  return path_lib.isRelative(filePath);
}

/// Join path segments.
String joinPath(String part1, String part2, [String? part3, String? part4]) {
  if (part3 != null) {
    if (part4 != null) {
      return path_lib.join(part1, part2, part3, part4);
    }
    return path_lib.join(part1, part2, part3);
  }
  return path_lib.join(part1, part2);
}
