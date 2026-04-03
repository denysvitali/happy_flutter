// Stub for non-supported platforms — Sentry not initialized.
Future<void> initSentryForPlatform([
  Future<void> Function()? appRunner,
]) async {
  if (appRunner != null) await appRunner();
}
