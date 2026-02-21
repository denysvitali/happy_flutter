// Stub for web platform - Sentry not initialized
Future<void> initSentryForPlatform(Future<void> Function() appRunner) async {
  // On web, just run the app directly without Sentry
  await appRunner();
}
