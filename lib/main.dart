import 'dart:async';
import 'dart:convert' show base64;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/api/api_client.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/supported_locales.dart';
import 'core/providers/app_providers.dart';
import 'core/routing/app_router.dart';
import 'core/services/logger_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/remote_logger.dart';
import 'core/services/server_config.dart';
import 'core/services/storage_service.dart' as storage;
import 'core/services/sync_service.dart';
import 'core/utils/theme_helper.dart';
import 'core/widgets/error_boundary.dart';
import 'features/command_palette/command_palette.dart';
import 'platform_io.dart' if (dart.library.js_interop) 'platform_stub.dart';
import 'security_context_io.dart'
    if (dart.library.js_interop) 'security_context_stub.dart';
import 'sentry_init_native.dart'
    if (dart.library.js_interop) 'sentry_init_web.dart';
import 'sentry_widget.dart'
    if (dart.library.js_interop) 'sentry_widget_stub.dart';
import 'user_certs_io.dart' if (dart.library.js_interop) 'user_certs_stub.dart';

// Deep link handler for receiving happy:// URLs
const _deepLinkChannel = MethodChannel('com.example.happy_flutter/deep_links');

/// Converts a DER-encoded certificate to PEM format.
Uint8List _derToPem(Uint8List der) {
  final b64 = base64.encode(der);
  final buf = StringBuffer()..writeln('-----BEGIN CERTIFICATE-----');
  for (var i = 0; i < b64.length; i += 64) {
    buf.writeln(b64.substring(i, i + 64 < b64.length ? i + 64 : b64.length));
  }
  buf.write('-----END CERTIFICATE-----');
  return Uint8List.fromList(buf.toString().codeUnits);
}

Future<void> main() async {
  // Use conditional initialization - Sentry only on native, not on web
  await initSentryForPlatform(_runApp);
}

Future<void> _runApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Installed here so Sentry's Zone and error handlers are set up first.
  remoteLoggerAutoInstall();

  // Register background FCM handler before any Firebase calls.
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );
  }

  if (!kIsWeb && isAndroid) {
    final certs = await FlutterUserCertificatesAndroid().getUserCertificates();
    for (final derBytes in (certs ?? {}).values) {
      // Android KeyStore returns DER; Dart's SecurityContext needs PEM.
      final pem = _derToPem(derBytes);
      SecurityContext.defaultContext.setTrustedCertificatesBytes(pem);
    }
  }

  final firebaseInitialization = _initializeOptionalFirebase();
  final deepLinkFuture = _getInitialDeepLink();

  await storage.Storage().initialize();

  final serverUrl = getServerUrl();
  await ApiClient().initialize(serverUrl: serverUrl);

  // Handle initial deep link if the app was opened from a link
  final deepLink = await deepLinkFuture;
  await firebaseInitialization;

  runApp(
    ErrorBoundary(
      child: ProviderScope(
        child: SentryWidget(child: HappyApp(initialDeepLink: deepLink)),
      ),
    ),
  );
}

Future<void> _initializeOptionalFirebase() async {
  if (kIsWeb) {
    return;
  }

  try {
    await Firebase.initializeApp();
    // Firebase succeeded — wire up notification handling.
    await NotificationService.instance.initialize();
  } on FirebaseException catch (e) {
    // Firebase is optional — only needed for push notifications.
    // If google-services.json is absent (e.g. unsigned builds),
    // the app still works; background push notifications won't fire.
    logger.warning(
      'Firebase initialization failed (push notifications unavailable): '
      '${e.message} '
      'This is expected if Firebase is not configured.',
    );
  } catch (e) {
    logger.warning(
      'Firebase initialization failed (push notifications unavailable): $e',
    );
  }
}

/// Get the initial deep link if the app was opened from one
Future<String?> _getInitialDeepLink() async {
  try {
    final result = await _deepLinkChannel.invokeMethod('getInitialDeepLink');
    return result as String?;
  } catch (e) {
    return null;
  }
}

class HappyApp extends ConsumerStatefulWidget {
  const HappyApp({super.key, this.initialDeepLink});
  final String? initialDeepLink;

  @override
  ConsumerState<HappyApp> createState() => _HappyAppState();
}

class _HappyAppState extends ConsumerState<HappyApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;
  AppThemeMode? _lastAppliedThemeMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = createRouter(widget.initialDeepLink);
    NotificationService.instance.updateRouter(_router);
    _setupDeepLinkListener();
    Future<void>.microtask(() {
      ref.read(authStateNotifierProvider.notifier).checkAuth();
      unawaited(_initializeTheme());
      _processInitialDeepLink();
    });
  }

  void _setupDeepLinkListener() {
    // Listen for deep links received while app is running
    _deepLinkChannel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final deepLink = call.arguments as String?;
        if (deepLink != null) {
          ref.read(authStateNotifierProvider.notifier).handleDeepLink(deepLink);
        }
      }
    });
  }

  void _processInitialDeepLink() {
    if (widget.initialDeepLink != null) {
      ref
          .read(authStateNotifierProvider.notifier)
          .handleDeepLink(widget.initialDeepLink!);
    }
  }

  Future<void> _initializeTheme() async {
    // Load settings and apply the theme
    await ref.read(settingsNotifierProvider.notifier).loadSettings();
    _applyThemeFromSettings();
  }

  void _applyThemeFromSettings() {
    final settings = ref.read(settingsNotifierProvider);
    AppThemeMode.fromString(
      settings.themeMode,
    ).applySystemChromeWithContext(ref.context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    // Re-apply theme when platform brightness changes (for adaptive mode)
    _applyThemeFromSettings();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
        // App is fully backgrounded — disconnect the socket so the OS
        // does not keep firing reconnect callbacks (which saturate the
        // main thread and cause ANRs when Tailscale / VPN drops).
        sync.suspend();
      case AppLifecycleState.resumed:
        // App is foregrounded — reconnect and catch up on missed events.
        sync.resume();
        // Re-apply theme in case system dark/light mode changed.
        _applyThemeFromSettings();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        // Watch only the specific fields needed to avoid unnecessary rebuilds
        final themeModeString = ref.watch(
          settingsNotifierProvider.select((s) => s.themeMode),
        );
        final preferredLanguage = ref.watch(
          settingsNotifierProvider.select((s) => s.preferredLanguage),
        );
        final themeMode = AppThemeMode.fromString(themeModeString);

        // Apply system chrome only when theme mode actually changes.
        if (themeMode != _lastAppliedThemeMode) {
          _lastAppliedThemeMode = themeMode;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            themeMode.applySystemChromeWithContext(context);
          });
        }

        return Directionality(
          textDirection: TextDirection.ltr,
          child: CommandPaletteKeyboardHandler(
            child: Stack(
              children: [
                MaterialApp.router(
                  title: 'Happy',
                  debugShowCheckedModeBanner: false,
                  theme: ThemeHelper.buildLightTheme(),
                  darkTheme: ThemeHelper.buildDarkTheme(),
                  themeMode: _getThemeMode(themeMode),
                  locale: _resolveLocale(preferredLanguage),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: supportedLocales,
                  routerConfig: _router,
                ),
                // Command palette overlay
                const CommandPaletteOverlayWrapper(),
              ],
            ),
          ),
        );
      },
    );
  }

  ThemeMode _getThemeMode(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.adaptive => ThemeMode.system,
    };
  }

  /// Resolves a preferred language code (e.g. 'en-US', 'fr-FR', 'zh-CN')
  /// to a [Locale], but only if it matches a supported locale.
  /// Returns null to fall back to the system locale.
  Locale? _resolveLocale(String? preferredLanguage) {
    if (preferredLanguage == null || preferredLanguage.isEmpty) {
      return null;
    }
    // Language codes are stored in BCP 47 hyphen format (e.g. 'en-US').
    // Convert to underscore format for parseLocaleString (e.g. 'en_US').
    final normalized = preferredLanguage.replaceAll('-', '_');
    final candidate = parseLocaleString(normalized);
    // Only apply if the candidate language is among the supported locales.
    final isSupported = supportedLocales.any(
      (l) => l.languageCode == candidate.languageCode,
    );
    return isSupported ? candidate : null;
  }
}
