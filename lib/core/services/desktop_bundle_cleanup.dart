import 'dart:io';

/// Only completed swaps carry this marker. Unmarked backups may be the sole
/// recoverable installation after a failed rollback and must be preserved.
const desktopRetiredBundleMarker = '.happy_flutter.retired';

/// Prunes retired bundles after every process using them has exited.
///
/// Flutter keeps an open directory descriptor for assets. Deleting a renamed
/// running bundle breaks later shader/font loads even though its executable
/// remains mapped. Run under the updater lock, outside the UI isolate.
void pruneRetiredDesktopBundles(
  ({String installPath, String processDirectory}) paths,
) {
  final installPath = paths.installPath;
  final install = Directory(installPath);
  if (!File('$installPath/happy_flutter').existsSync()) return;
  final canonicalInstall = install.resolveSymbolicLinksSync();
  final liveExecutables = _liveExecutables(paths.processDirectory);
  if (liveExecutables == null) return;

  for (final entry in install.parent.listSync(followLinks: false)) {
    if (entry is! Directory ||
        !RegExp(r'^\.happy_flutter\.backup\.\d+$').hasMatch(
          entry.uri.pathSegments.where((part) => part.isNotEmpty).last,
        )) {
      continue;
    }
    final marker = File('${entry.path}/$desktopRetiredBundleMarker');
    if (!marker.existsSync() ||
        Directory(
              marker.readAsStringSync().trim(),
            ).resolveSymbolicLinksSync() !=
            canonicalInstall) {
      continue;
    }
    final canonicalBackup = entry.resolveSymbolicLinksSync();
    if (liveExecutables.any((path) => path.startsWith('$canonicalBackup/'))) {
      continue;
    }
    entry.deleteSync(recursive: true);
  }
}

Set<String>? _liveExecutables(String processDirectory) {
  // /proc is Linux-only. If process inspection is unavailable, preserving
  // disk space takes second place to retaining assets for a live process.
  final proc = Directory(processDirectory);
  if (!proc.existsSync()) return null;
  final executables = <String>{Link('$processDirectory/self/exe').targetSync()};
  for (final process in proc.listSync()) {
    if (process is! Directory ||
        !RegExp(r'^\d+$').hasMatch(
          process.uri.pathSegments.where((part) => part.isNotEmpty).last,
        )) {
      continue;
    }
    try {
      executables.add(Link('${process.path}/exe').targetSync());
    } on FileSystemException catch (error) {
      // A process can exit between the directory walk and readlink. Linux
      // kernel threads also have no executable link.
      if (error.osError?.errorCode == 2) continue;
      // Process names and user IDs do not prove an unreadable executable is
      // unrelated. Restricted /proc hosts may defer cleanup; retaining disk
      // space is preferable to breaking assets in another running process.
      return null;
    }
  }
  return executables;
}
