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
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show Sentry, SpanStatus;

import 'core/api/api_client.dart';
import 'core/encryption/sodium_singleton.dart';
import 'core/i18n/app_localizations.dart';
import 'core/providers/app_providers.dart';
import 'core/routing/app_router.dart';
import 'core/services/app_visibility_coordinator.dart';
import 'core/services/frame_metrics_service.dart';
import 'core/services/logger_service.dart';
import 'core/services/network_monitor_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/opentelemetry_service.dart';
import 'core/services/performance_context_service.dart';
import 'core/services/power_diagnostics_service.dart';
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
import 'sentry_config.dart';
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

  // Sentry MUST finish init before the app renders so its
  // FlutterError.onError handler is installed before the
  // ErrorBoundary captures _previousOnError.  The appRunner
  // callback also wraps the entire app in Sentry's error zone.
  await initSentryForPlatform(_runApp);
}

Future<void> _runApp() async {
  final startupTransaction = Sentry.startTransaction(
    'app.startup',
    'app.load',
    bindToScope: false,
  );
  // Installed here so Sentry's Zone and error handlers are set up first.
  remoteLoggerAutoInstall();

  // Cap Flutter's image cache to avoid unbounded memory growth from
  // decoded network images (avatars, etc.).  The default is 1000 images /
  // 100 MB — tighten both so the cache stays manageable on low-end devices.
  PaintingBinding.instance.imageCache
    ..maximumSize =
        150 // max decoded images
    ..maximumSizeBytes = 30 * 1024 * 1024; // 30 MB

  // All fonts are bundled in google_fonts/ — disable network fetching so
  // the package never attempts HTTP requests for font files at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Register background FCM handler before any Firebase calls.
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Start all independent startup work concurrently.
  // These are awaited before the first frame.
  final deepLinkSpan = startupTransaction.startChild(
    'app.startup.deepLink',
    description: 'Resolve initial deep link',
  );
  final deepLinkFuture = _getInitialDeepLink().whenComplete(() {
    unawaited(deepLinkSpan.finish());
  });
  unawaited(sodiumSingleton); // FFI load overlaps with storage/network

  // Defer Android user certificates, Firebase, OpenTelemetry,
  // and NetworkMonitorService past first frame — none of them are
  // needed to render the first frame, and each adds ~50–400ms to the
  // critical path on cold start.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_deferredInit());
    // Start tracking janky frames for Sentry/GlitchTip visibility.
    if (sentryEnableFrameMetrics && sentryTracesSampleRate > 0) {
      FrameMetricsService.instance.attach();
    }
  });

  final startupServicesFuture = () async {
    // Await essentials: storage + API client. NetworkMonitor is deferred
    // to _deferredInit; its callers (Sync.resume, networkNotifier) all
    // tolerate a not-yet-initialized service.
    // Resolve a provisional server URL immediately so API init can begin
    // while storage warms. Storage may later load a custom URL.
    final serverUrl = getServerUrl();

    final storageSpan = startupTransaction.startChild(
      'app.startup.storage',
      description: 'Initialize storage',
    );
    final apiSpan = startupTransaction.startChild(
      'app.startup.apiClient',
      description: 'Initialize API client',
    );

    final storageInit = storage.Storage().initialize();
    final apiInit = ApiClient().initialize(serverUrl: serverUrl);
    await Future.wait<void>([storageInit, apiInit]);
    await storageSpan.finish();

    final resolvedServerUrl = getServerUrl();
    if (resolvedServerUrl != serverUrl) {
      final urlCorrectionSpan = startupTransaction.startChild(
        'app.startup.apiClient.urlCorrection',
        description: 'Reconfigure API client for stored server URL',
      );
      try {
        await ApiClient().refreshServerUrl();
      } finally {
        await urlCorrectionSpan.finish();
      }
    }
    await apiSpan.finish();

    startupTransaction
      ..setData(
        'serverUrlHost',
        Uri.tryParse(resolvedServerUrl)?.host ?? 'unknown',
      )
      ..setData(
        'currentRoute',
        PerformanceContextService().currentRoute ?? 'unknown',
      );
    await startupTransaction.finish();
  }();

  if (!kIsWeb) {
    await startupServicesFuture;
  }

  final deepLink = await deepLinkFuture;

  runApp(
    ErrorBoundary(
      child: ProviderScope(
        child: SentryWidget(
          child: HappyApp(
            initialDeepLink: deepLink,
            startupServicesFuture: startupServicesFuture,
          ),
        ),
      ),
    ),
  );
}

/// Deferred initialization that runs after first frame. Keeps heavy,
/// non-essential work (Firebase, Android certs) off the critical path.
Future<void> _deferredInit() async {
  final transaction = Sentry.startTransaction(
    'app.deferredInit',
    'app.load.deferred',
    bindToScope: false,
  );
  // Run Android certs, Firebase, OpenTelemetry, and NetworkMonitor
  // init in parallel — they are all independent and each can take
  // 100–500ms+. None are needed to render the first frame.
  final futures = <Future<void>>[];

  // OpenTelemetry — gRPC tracer init. Off the critical path; the
  // GoRouter observer list tolerates a null routeObserver until init
  // completes (see app_router.dart `?OpenTelemetryService().routeObserver`).
  futures.add(() async {
    final otelSpan = transaction.startChild(
      'app.deferredInit.opentelemetry',
      description: 'Initialize OpenTelemetry',
    );
    try {
      await OpenTelemetryService().initialize();
    } catch (e) {
      otelSpan
        ..status = const SpanStatus.internalError()
        ..setData('error', e.toString());
    } finally {
      await otelSpan.finish();
    }
  }());

  // NetworkMonitor — `Connectivity.checkConnectivity()` is a platform
  // channel round-trip (~50–150ms warm, more on cold). The service is
  // only consumed once the user authenticates and Sync resumes; all
  // callers (suspend/resume, networkNotifier) tolerate not-yet-init.
  futures.add(() async {
    final networkSpan = transaction.startChild(
      'app.deferredInit.networkMonitor',
      description: 'Initialize network monitor',
    );
    try {
      await NetworkMonitorService().initialize();
    } catch (e) {
      networkSpan
        ..status = const SpanStatus.internalError()
        ..setData('error', e.toString());
    } finally {
      await networkSpan.finish();
    }
  }());

  // Android user certificates — JNI calls + ASN.1 parsing.
  if (!kIsWeb && isAndroid) {
    futures.add(() async {
      final certsSpan = transaction.startChild(
        'app.deferredInit.userCerts',
        description: 'Load Android user certificates',
      );
      try {
        final certs = await FlutterUserCertificatesAndroid()
            .getUserCertificates();
        for (final derBytes in (certs ?? {}).values) {
          final pem = _derToPem(derBytes);
          SecurityContext.defaultContext.setTrustedCertificatesBytes(pem);
        }
      } catch (e) {
        logger.warning('Failed to load Android user certificates: $e');
        certsSpan
          ..status = const SpanStatus.internalError()
          ..setData('error', e.toString());
      } finally {
        await certsSpan.finish();
      }
    }());
  }

  // Firebase push notifications — not needed for first screen.
  // Use unawaited() so this never blocks _deferredInit from completing.
  // Firebase can take 1-3s on first init; keeping it off the critical
  // path saves ~2s on cold/warm start.  Errors are caught and logged
  // inside _initializeOptionalFirebase so they never propagate.
  unawaited(() async {
    final firebaseSpan = transaction.startChild(
      'app.deferredInit.firebase',
      description: 'Initialize optional Firebase services',
    );
    try {
      await _initializeOptionalFirebase();
    } catch (e) {
      firebaseSpan
        ..status = const SpanStatus.internalError()
        ..setData('error', e.toString());
    } finally {
      await firebaseSpan.finish();
    }
  }());

  await Future.wait(futures);
  await transaction.finish();
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
    // Log at info to avoid Sentry noise — this is expected.
    logger.info(
      'Firebase initialization failed (push notifications unavailable): '
      '${e.message}',
    );
  } catch (e) {
    // PlatformException when google-services.json is missing — also expected.
    logger.info(
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
  const HappyApp({super.key, this.initialDeepLink, this.startupServicesFuture});

  final String? initialDeepLink;
  final Future<void>? startupServicesFuture;

  @override
  ConsumerState<HappyApp> createState() => _HappyAppState();
}

class _HappyAppState extends ConsumerState<HappyApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;
  final AppVisibilityCoordinator _visibilityCoordinator =
      AppVisibilityCoordinator();
  AppThemeMode? _lastAppliedThemeMode;

  /// If non-null, the app should show the changelog on first frame.
  ({String? fromVersion, String toVersion})? _changelogInfo;

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
    _router = createRouter();
    NotificationService.instance.updateRouter(_router);
    _setupDeepLinkListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!kIsWeb) {
        unawaited(
          ref
              .read(offlineDictationNotifierProvider.notifier)
              .initialize(context),
        );
      }
    });
    ref.read(authStateNotifierProvider.notifier).beginAuthCheck();
    Future<void>.microtask(() async {
      try {
        await widget.startupServicesFuture;
      } catch (error, stack) {
        logger.error('Startup initialization failed', error, stack);
        unawaited(Sentry.captureException(error, stackTrace: stack));
        if (mounted) {
          ref.read(authStateNotifierProvider.notifier).failAuthCheck();
        }
        return;
      }
      if (!mounted) return;
      unawaited(ref.read(authStateNotifierProvider.notifier).checkAuth());
      unawaited(_initializeTheme());
      unawaited(_loadChangelogInfo());
      _processInitialDeepLink();
      _maybeShowChangelog();
    });
  }

  Future<void> _loadChangelogInfo() async {
    if (_changelogInfo != null) return;
    final transaction = Sentry.startTransaction(
      'app.changelogCheck',
      'app.load.deferred',
      bindToScope: false,
    );
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final info = storage.Storage().checkVersionChange(packageInfo.version);
      transaction.setData('hasChangelog', info != null);
      if (!mounted || info == null) {
        await transaction.finish();
        return;
      }
      setState(() {
        _changelogInfo = info;
      });
      _maybeShowChangelog();
      await transaction.finish();
    } catch (error) {
      transaction
        ..status = const SpanStatus.internalError()
        ..setData('error', error.toString());
      await transaction.finish();
    }
  }

  void _maybeShowChangelog() {
    final info = _changelogInfo;
    if (info == null) return;
    // Show changelog after the first frame has rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _router.pushNamed(
        'changelog',
        extra: {'fromVersion': info.fromVersion, 'toVersion': info.toVersion},
      );
      // Only show once.
      _changelogInfo = null;
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
    final initialDeepLink = widget.initialDeepLink;
    if (initialDeepLink == null) return;
    ref
        .read(authStateNotifierProvider.notifier)
        .handleDeepLink(initialDeepLink);
  }

  Future<void> _initializeTheme() async {
    // Load only MMKV-backed settings here so first paint does not block on
    // secure-storage API key hydration.
    await ref.read(settingsNotifierProvider.notifier).loadLocalSettings();
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

  void _recordLifecycleEdge(String state) {
    _lifecycleCycleCount++;
    final now = DateTime.now();
    var isRapidLifecycleCycle = false;
    if (_lastLifecycleCycleAt != null) {
      final elapsed = now.difference(_lastLifecycleCycleAt!).inSeconds;
      if (elapsed < 60) {
        if (_lifecycleCycleCount > _lifecycleCyclingWarningThreshold) {
          isRapidLifecycleCycle = true;
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
    powerDiagnostics.recordLifecycle(state, rapidCycle: isRapidLifecycleCycle);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.resumed:
        _visibilityCoordinator.handleLifecycleState(
          state,
          onSuspend: () {
            _recordLifecycleEdge('paused');
            // App is no longer visible — disconnect the socket and cancel
            // all timers to ensure zero network traffic and battery drain.
            FrameMetricsService.instance.detach();
            sync.suspend();
            storage.SettingsStorage().suspend();
          },
          onResume: () {
            _recordLifecycleEdge('resumed');
            // App is foregrounded — reconnect and catch up on missed events.
            if (sentryEnableFrameMetrics && sentryTracesSampleRate > 0) {
              FrameMetricsService.instance.attach();
            }
            sync.resume();
            // Re-apply theme in case system dark/light mode changed.
            _applyThemeFromSettings();
          },
        );
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
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
          textDirection: _textDirectionForPlatformLocale(),
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
                  supportedLocales: AppLocalizations.supportedLocales,
                  routerConfig: _router,
                  builder: (context, child) {
                    return child ?? const SizedBox.shrink();
                  },
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

  TextDirection _textDirectionForPlatformLocale() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    const rtlLanguageCodes = <String>{'ar', 'fa', 'he', 'ps', 'ur'};
    return rtlLanguageCodes.contains(locale.languageCode.toLowerCase())
        ? TextDirection.rtl
        : TextDirection.ltr;
  }
}
