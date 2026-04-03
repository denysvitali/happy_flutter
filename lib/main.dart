import 'dart:async';
import 'dart:convert' show base64;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/api/api_client.dart';
import 'core/encryption/sodium_singleton.dart';
import 'core/i18n/app_localizations.dart';
import 'core/providers/app_providers.dart';
import 'core/routing/app_router.dart';
import 'core/services/logger_service.dart';
import 'core/services/network_monitor_service.dart';
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
  // Bootstrap the Flutter binding first so everything else can proceed
  // in parallel — Sentry, storage, network, deep link, and Firebase.
  WidgetsFlutterBinding.ensureInitialized();

  // Start Sentry init in the background; it no longer blocks first frame.
  unawaited(initSentryForPlatform());

  await _runApp();
}

Future<void> _runApp() async {
  // Installed here so Sentry's Zone and error handlers are set up first.
  remoteLoggerAutoInstall();

  // Cap Flutter's image cache to avoid unbounded memory growth from
  // decoded network images (avatars, etc.).  The default is 1000 images /
  // 100 MB — tighten both so the cache stays manageable on low-end devices.
  PaintingBinding.instance.imageCache
    ..maximumSize = 150       // max decoded images
    ..maximumSizeBytes = 30 * 1024 * 1024; // 30 MB

  // All fonts are bundled in google_fonts/ — disable network fetching so
  // the package never attempts HTTP requests for font files at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Register background FCM handler before any Firebase calls.
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );
  }

  // Start all independent startup work concurrently.
  // These are awaited before the first frame.
  final deepLinkFuture = _getInitialDeepLink();
  unawaited(sodiumSingleton); // FFI load overlaps with storage/network

  // Defer Android user certificates and Firebase past first frame —
  // they provide zero value before the user sees the first screen.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_deferredInit());
  });

  // Await essentials: storage + network (server URL is needed for network).
  await storage.Storage().initialize();
  final serverUrl = getServerUrl();
  await Future.wait([
    NetworkMonitorService().initialize(),
    ApiClient().initialize(serverUrl: serverUrl),
  ]);

  final deepLink = await deepLinkFuture;

  runApp(
    ErrorBoundary(
      child: ProviderScope(
        child: SentryWidget(
          child: HappyApp(initialDeepLink: deepLink),
        ),
      ),
    ),
  );
}

/// Deferred initialization that runs after first frame. Keeps heavy,
/// non-essential work (Firebase, Android certs) off the critical path.
Future<void> _deferredInit() async {
  // Android user certificates — JNI calls + ASN.1 parsing.
  if (!kIsWeb && isAndroid) {
    try {
      final certs = await FlutterUserCertificatesAndroid().getUserCertificates();
      for (final derBytes in (certs ?? {}).values) {
        final pem = _derToPem(derBytes);
        SecurityContext.defaultContext.setTrustedCertificatesBytes(pem);
      }
    } catch (e) {
      logger.warning('Failed to load Android user certificates: $e');
    }
  }

  // Firebase push notifications — not needed for first screen.
  await _initializeOptionalFirebase();
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

  // Battery diagnostics — track paused↔resumed cycle frequency.
  // Only paused/resumed are counted (not intermediate states like inactive,
  // hidden, detached) because Android sends ~6 callbacks per single
  // background/foreground cycle.
  int _lifecycleCycleCount = 0;
  DateTime? _lastLifecycleCycleAt;
  /// Warn if full paused↔resumed cycles exceed this many per minute.
  static const int _lifecycleCyclingWarningThreshold = 6;

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

    // Battery diagnostics: only count actual paused/resumed transitions.
    // Intermediate states (inactive, hidden, detached) are ignored because
    // Android sends ~6 callbacks per single background/foreground cycle.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.resumed) {
      _lifecycleCycleCount++;
      final now = DateTime.now();
      if (_lastLifecycleCycleAt != null) {
        final elapsed =
            now.difference(_lastLifecycleCycleAt!).inSeconds;
        if (elapsed < 60) {
          if (_lifecycleCycleCount > _lifecycleCyclingWarningThreshold) {
            // Log locally for dev logs — not worth a Sentry event
            // since Android routinely cycles the lifecycle on low
            // battery or when the OS manages background apps.
            logger.info(
              '[Battery] Rapid lifecycle cycling: '
              '$_lifecycleCycleCount transitions in ${elapsed}s',
            );
          }
        } else {
          _lifecycleCycleCount = 1;
        }
      }
      _lastLifecycleCycleAt = now;
    }

    switch (state) {
      case AppLifecycleState.paused:
        // App is fully backgrounded — disconnect the socket and cancel
        // all timers to ensure zero network traffic and battery drain.
        sync.suspend();
        storage.SettingsStorage().suspend();
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
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales:
                      AppLocalizations.supportedLocales,
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

}
