import 'dart:io';

/// Import Flatpak's host trust export before any network clients are created.
/// Dart does not consult the p11-kit proxy provided by the sandbox itself.
void loadFlatpakHostCertificates({
  Map<String, String>? environment,
  SecurityContext? context,
}) {
  if (!Platform.isLinux) return;
  final env = environment ?? Platform.environment;
  if (!env.containsKey('FLATPAK_ID')) return;
  final path = env['HAPPY_HOST_CA_BUNDLE'];
  if (path == null || path.isEmpty) return;

  try {
    (context ?? SecurityContext.defaultContext).setTrustedCertificates(path);
  } finally {
    // The export is unique per launch; do not retain stale host trust on disk.
    File(path).deleteSync();
  }
}
