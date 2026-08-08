import 'dart:async';
import 'dart:convert' show base64;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
// `show` is required: intl also exports a `TextDirection` that collides with
// dart:ui's.
import 'package:intl/intl.dart' show DateFormat, Intl;
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
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/app_tokens.dart';
import 'core/utils/package_info_cache.dart';
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
final Stopwatch _coldStartStopwatch = Stopwatch()..start();
Duration? _firstFrameDuration;
Duration? _essentialStartupDuration;

/// Anchor the cold-start clock at the earliest point we control.
///
/// Top-level `final`s in Dart are **lazily** initialized on first access, not
/// at program load. The first (and only) reader of [_coldStartStopwatch] used
/// to be the post-frame callback in [_runApp], so the stopwatch was created
/// *at* first frame and `app.cold_start.first_frame` shipped a constant 0s —
/// Prometheus confirmed `app_cold_start_first_frame_seconds_sum == 0` while
/// `essential_ready` silently measured "first frame → storage ready" instead
/// of "process start → storage ready". Calling this as the first statement of
/// `main()` forces construction there and rebases elapsed to that instant.
void _anchorColdStartClock() {
  _coldStartStopwatch.reset();
}

/// Seed intl's date/number formatting from the **platform** locale.
///
/// Two separate things are being set up here:
///
/// 1. [initializeDateFormatting] loads the locale symbol data. Without it,
///    `DateFormat.yMd('de')` throws `LocaleDataException`; intl only ships
///    `en_US` by default.
/// 2. [Intl.defaultLocale] is what every context-free formatting helper
///    (`formatShortDate`, `formatRelativeTime`, `toRelativeTimeString`)
///    resolves against. Without it intl falls back to `en_US`, so dates
///    render in US order on every device.
///
/// The *platform* locale is used on purpose rather than the resolved UI
/// locale: `AppLocalizations.supportedLocales` is English-only, so
/// `Localizations.localeOf` always resolves to `en`. Date and number order
/// must follow the device even when the UI language is English.
///
/// A platform locale intl has no data for is left unset rather than assigned:
/// `Intl.defaultLocale` is global, and pointing it at an unknown tag would
/// make every bare `DateFormat` in the app throw `ArgumentError`.
Future<void> _initFormattingLocale() async {
  await initializeDateFormatting();
  final platformLocale = WidgetsBinding.instance.platformDispatcher.locale;
  final country = platformLocale.countryCode;
  final tag = country != null && country.isNotEmpty
      ? '${platformLocale.languageCode}_$country'
      : platformLocale.languageCode;
  final resolved = Intl.verifiedLocale(
    tag,
    DateFormat.localeExists,
    onFailure: (_) => null,
  );
  if (resolved != null) Intl.defaultLocale = resolved;
}

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

Future<void> _loadAndroidUserCertificates() async {
  if (kIsWeb || !isAndroid) return;

  final certs = await FlutterUserCertificatesAndroid().getUserCertificates();
  for (final derBytes in (certs ?? {}).values) {
    final pem = _derToPem(derBytes);
    SecurityContext.defaultContext.setTrustedCertificatesBytes(pem);
  }
}

Future<void> main() async {
  // MUST stay the first statement: see [_anchorColdStartClock].
  _anchorColdStartClock();

  // Bootstrap the Flutter binding first so everything else can proceed
  // in parallel — Sentry, storage, network, deep link, and Firebase.
  WidgetsFlutterBinding.ensureInitialized();

  await _initFormattingLocale();

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

  // Register background FCM handler before any Firebase calls.
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Warm storage in parallel with everything else. This initializes both
  // MMKV and the separate server-config store so startup can recover custom
  // server URLs before the first auth/sync request.
  final storageWarmup = storage.Storage().initialize();

  // Start the initial deep-link platform-channel call in parallel
  // with first frame.  Previously this was awaited before `runApp`,
  // adding 10–50ms (or more on cold start) to time-to-first-paint
  // for every app launch.  The future is now passed down to
  // HappyApp, which awaits it in parallel with `startupServicesFuture`
  // and forwards the resolved value to AuthGate / AuthScreen.
  final deepLinkSpan = startupTransaction.startChild(
    'app.startup.deepLink',
    description: 'Resolve initial deep link',
  );
  final deepLinkFuture = _getInitialDeepLink().whenComplete(() {
    unawaited(deepLinkSpan.finish());
  });
  unawaited(sodiumSingleton); // FFI load overlaps with storage/network

  // REMOVED: unawaited(OpenTelemetryService().initialize());
  // OTel init is already handled inside _deferredInit, which runs
  // after first frame. Keeping it here duplicates work and adds
  // ~10-30ms to the critical path for zero benefit.

  // Defer Android user certificates, Firebase,
  // and NetworkMonitorService past first frame — none of them are
  // needed to render the first frame, and each adds ~50–400ms to the
  // critical path on cold start.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _firstFrameDuration ??= _coldStartStopwatch.elapsed;
    unawaited(_deferredInit());
    // Aggregate UI frame metrics for OTel. Frozen-frame Sentry transactions
    // remain independently controlled by the Sentry sampling configuration.
    FrameMetricsService.instance.attach(
      enableSentryTransactions:
          sentryEnableFrameMetrics && sentryTracesSampleRate > 0,
    );
  });

  final startupServicesFuture =
      () async {
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

        // Storage is already warming; just await the completer here.
        final storageInit = storageWarmup;
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
      }().whenComplete(() {
        _essentialStartupDuration = _coldStartStopwatch.elapsed;
        // Slow launches: OTel was already initialized by _deferredInit before
        // this resolved — record now instead of leaving the sample censored.
        // Fast launches resolved before OTel init; _deferredInit's call to
        // the same helper records those. The helper guarantees exactly once.
        _recordEssentialReady();
      });

  // Do NOT block the first frame on storage + API init or the
  // initial deep-link platform channel.  Both futures already run
  // concurrently above; _HappyAppState awaits them in parallel and
  // AuthGate renders a loading state until they settle.  Awaiting
  // either here previously added 10–300ms+ to time-to-first-frame
  // on every cold start.

  runApp(
    ErrorBoundary(
      child: ProviderScope(
        child: SentryWidget(
          child: HappyApp(
            initialDeepLinkFuture: deepLinkFuture,
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
  final deferredStopwatch = Stopwatch()..start();
  final transaction = Sentry.startTransaction(
    'app.deferredInit',
    'app.load.deferred',
    bindToScope: false,
  );
  // Run Android certs, Firebase, and NetworkMonitor init in parallel —
  // they are all independent and each can take 100–500ms+. None are
  // needed to render the first frame.
  final futures = <Future<void>>[];

  final userCertificatesFuture = () async {
    final certsSpan = transaction.startChild(
      'app.deferredInit.userCerts',
      description: 'Load Android user certificates',
    );
    try {
      await _loadAndroidUserCertificates();
    } catch (e) {
      logger.warning('Failed to load Android user certificates: $e');
      certsSpan
        ..status = const SpanStatus.internalError()
        ..setData('error', e.toString());
    } finally {
      await certsSpan.finish();
    }
  }();
  OpenTelemetryService().setTrustedCertificatesFuture(userCertificatesFuture);

  // OpenTelemetry starts after first frame to keep SDK initialization off the
  // startup critical path. Startup timings captured above are recorded once
  // initialization completes.
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
  deferredStopwatch.stop();
  final otel = OpenTelemetryService();
  final firstFrameDuration = _firstFrameDuration;
  if (firstFrameDuration != null) {
    otel.recordDuration(
      'app.cold_start.first_frame',
      firstFrameDuration,
      // Honest anchor: the stopwatch starts at Dart `main()`, not at
      // native process start — engine startup precedes both. The Sentry
      // app-start span covers the native portion; do not compare the two
      // as if they shared an anchor.
      description: 'Dart main() to first rendered Flutter frame',
    );
  }
  // OTel is initialized only now — essential_ready may have resolved
  // earlier (fast launch) or later (slow launch); the helper records it
  // exactly once whenever BOTH the duration and OTel are ready.
  _recordEssentialReady();
  otel.recordDuration(
    'app.deferred_init',
    deferredStopwatch.elapsed,
    description: 'Post-frame deferred initialization duration',
  );
  await transaction.finish();
}

bool _essentialReadyRecorded = false;

/// Records `app.cold_start.essential_ready` exactly once, as soon as the
/// duration is known AND OTel is initialized — in whichever order those
/// two happen. Recording only from `_deferredInit` censored the metric on
/// the slowest launches (audit 2026-08-03): there, storage/API init
/// finished AFTER deferred init, so the duration was still null at record
/// time and the sample vanished — precisely the tail the re-baseline needs.
void _recordEssentialReady() {
  final duration = _essentialStartupDuration;
  final otel = OpenTelemetryService();
  if (duration == null || !otel.isInitialized || _essentialReadyRecorded) {
    return;
  }
  _essentialReadyRecorded = true;
  otel.recordDuration(
    'app.cold_start.essential_ready',
    duration,
    description: 'Dart main() to storage and API readiness',
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
  const HappyApp({
    super.key,
    this.initialDeepLinkFuture,
    this.startupServicesFuture,
  });

  /// Future for the initial deep-link from the platform channel.
  /// Resolved in [initState] so the platform call can run in parallel
  /// with the first frame instead of blocking `runApp`.
  final Future<String?>? initialDeepLinkFuture;

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
      }
      if (!mounted) return;
      unawaited(ref.read(authStateNotifierProvider.notifier).checkAuth());
      unawaited(_initializeTheme());
      unawaited(_loadChangelogInfo());
      unawaited(_processInitialDeepLink());
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
      final packageInfo = await PackageInfoCache.get();
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

  /// Awaits the deep-link platform channel call (kicked off in
  /// `_runApp` in parallel with first frame) and forwards the
  /// resolved URL to the auth state notifier. Returns the future
  /// so the caller can `unawaited` it; the future is fire-and-forget
  /// because the deep link is best-effort — failure to resolve just
  /// means the user opens the app at the default screen.
  Future<void> _processInitialDeepLink() async {
    final initialDeepLinkFuture = widget.initialDeepLinkFuture;
    if (initialDeepLinkFuture == null) return;
    try {
      final initialDeepLink = await initialDeepLinkFuture;
      if (!mounted || initialDeepLink == null) return;
      ref
          .read(authStateNotifierProvider.notifier)
          .handleDeepLink(initialDeepLink);
    } catch (e, stack) {
      logger.warning('Initial deep link resolution failed', e, stack);
    }
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
            FrameMetricsService.instance.attach(
              enableSentryTransactions:
                  sentryEnableFrameMetrics && sentryTracesSampleRate > 0,
            );
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
          child: MaterialApp.router(
            title: 'Happy',
            debugShowCheckedModeBanner: false,
            scrollBehavior: const AppScrollBehavior(),
            theme: ThemeHelper.buildLightTheme(),
            darkTheme: ThemeHelper.buildDarkTheme(),
            themeMode: _getThemeMode(themeMode),
            themeAnimationDuration: AppDuration.slow,
            themeAnimationCurve: AppCurve.standard,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: _router,
            builder: (context, child) {
              return CommandPaletteKeyboardHandler(
                child: CommandPaletteAppOverlay(
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
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
