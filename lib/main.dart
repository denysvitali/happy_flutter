import 'dart:async';
import 'dart:convert' show base64;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/api/api_client.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/supported_locales.dart';
import 'core/models/auth.dart';
import 'core/providers/app_providers.dart';
import 'core/services/logger_service.dart';
import 'core/services/remote_logger.dart';
import 'core/services/server_config.dart';
import 'core/services/storage_service.dart' as storage;
import 'core/services/sync_service.dart';
import 'core/utils/theme_helper.dart';
import 'core/widgets/auth_gate.dart';
import 'core/widgets/error_boundary.dart';
import 'features/artifacts/artifact_detail_screen.dart';
import 'features/artifacts/artifacts_list_screen.dart';
import 'features/artifacts/edit_artifact_screen.dart';
import 'features/artifacts/new_artifact_screen.dart';
import 'features/chat/agent_conversation_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/chat/message_detail_screen.dart';
import 'features/chat/session_file_viewer_screen.dart';
import 'features/chat/session_files_screen.dart';
import 'features/chat/session_info_screen.dart';
import 'features/chat/session_recent_screen.dart';
import 'features/command_palette/command_palette.dart';
import 'features/dev/dev_logs_screen.dart';
import 'features/dev/network_inspector_screen.dart';
import 'features/inbox/friends_screen.dart';
import 'features/inbox/friends_search_screen.dart';
import 'features/inbox/inbox_screen.dart';
import 'features/machine/machine_detail_screen.dart';
import 'features/sessions/new_session_screen.dart';
import 'features/sessions/pick_machine_screen.dart';
import 'features/sessions/pick_path_screen.dart';
import 'features/sessions/pick_profile_screen.dart';
import 'features/sessions/sessions_screen.dart';
import 'features/settings/account_screen.dart';
import 'features/settings/changelog_screen.dart';
import 'features/settings/claude_connect_screen.dart';
import 'features/settings/developer_screen.dart';
import 'features/settings/features_settings_screen.dart';
import 'features/settings/language_settings_screen.dart';
import 'features/settings/machines_screen.dart';
import 'features/settings/profiles_screen.dart';
import 'features/settings/server_settings_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/theme_settings_screen.dart';
import 'features/settings/usage_screen.dart';
import 'features/settings/voice_language_settings_screen.dart';
import 'features/settings/voice_settings_screen.dart';
import 'features/terminal/terminal_connect_screen.dart';
import 'features/terminal/terminal_screen.dart';
import 'features/user/user_profile_screen.dart';
import 'features/zen/zen_home_screen.dart';
import 'features/zen/zen_new_screen.dart';
import 'features/zen/zen_view_screen.dart';
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
  } catch (e) {
    // Firebase is optional — only needed for push notifications.
    // If google-services.json is absent (e.g. unsigned builds),
    // the app still works; background push notifications won't fire.
    logger.warning('Firebase.initializeApp() failed: $e');
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
    _router = _buildRouter();
    _setupDeepLinkListener();
    Future.delayed(Duration.zero, () {
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

  /// Fade transition for tab-level routes.
  static Page<void> _fadePage(Widget child, GoRouterState state) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 200),
    );
  }

  /// Slide-up transition for creation / modal flows.
  static Page<void> _slideUpPage(Widget child, GoRouterState state) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, _, child) {
        final tween = Tween(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(tween),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// Slide-in transition for detail/push screens with swipe-back
  /// gesture support via [_SwipeBackPage].
  static Page<void> _slidePage(Widget child, GoRouterState state) {
    return _SwipeBackPage(key: state.pageKey, child: child);
  }

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/',
      observers: [SentryNavigatorObserver()],
      routes: [
        GoRoute(
          path: '/',
          name: 'auth',
          pageBuilder: (context, state) {
            final tabParam = state.uri.queryParameters['tab'];
            return _fadePage(
              AuthGate(
                initialDeepLink: widget.initialDeepLink,
                child: SessionsScreen(initialTab: tabParam),
              ),
              state,
            );
          },
        ),
        GoRoute(
          path: '/sessions',
          name: 'sessions',
          pageBuilder: (context, state) {
            final tabParam = state.uri.queryParameters['tab'];
            return _fadePage(
              AuthGate(child: SessionsScreen(initialTab: tabParam)),
              state,
            );
          },
        ),
        GoRoute(
          path: '/chat/:sessionId',
          name: 'chat',
          pageBuilder: (context, state) {
            final sessionId = state.pathParameters['sessionId']!;
            return _slidePage(
              AuthGate(child: ChatScreen(sessionId: sessionId)),
              state,
            );
          },
        ),
        GoRoute(
          path: '/inbox',
          name: 'inbox',
          pageBuilder: (context, state) =>
              _fadePage(const AuthGate(child: InboxScreen()), state),
        ),
        GoRoute(
          path: '/friends/search',
          name: 'friends-search',
          builder: (context, state) =>
              const AuthGate(child: FriendsSearchScreen()),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          pageBuilder: (context, state) =>
              _fadePage(const AuthGate(child: SettingsScreen()), state),
        ),
        GoRoute(
          path: '/settings/account',
          name: 'account',
          pageBuilder: (context, state) =>
              _slidePage(const AuthGate(child: AccountScreen()), state),
        ),
        GoRoute(
          path: '/settings/account/restore',
          name: 'restore',
          builder: (context, state) =>
              const AuthGate(child: RestoreAccountScreen()),
        ),
        GoRoute(
          path: '/settings/account/link',
          name: 'link',
          builder: (context, state) =>
              const AuthGate(child: LinkDeviceScreen()),
        ),
        GoRoute(
          path: '/settings/account/devices',
          name: 'devices',
          builder: (context, state) =>
              const AuthGate(child: LinkedDevicesScreen()),
        ),
        GoRoute(
          path: '/settings/machines',
          name: 'machines',
          pageBuilder: (context, state) =>
              _slidePage(const AuthGate(child: MachinesScreen()), state),
        ),
        GoRoute(
          path: '/settings/theme',
          name: 'theme',
          pageBuilder: (context, state) =>
              _slidePage(const AuthGate(child: ThemeSettingsScreen()), state),
        ),
        GoRoute(
          path: '/settings/language',
          name: 'language',
          pageBuilder: (context, state) => _slidePage(
            const AuthGate(child: LanguageSettingsScreen()),
            state,
          ),
        ),
        GoRoute(
          path: '/settings/voice',
          name: 'voice',
          pageBuilder: (context, state) =>
              _slidePage(const AuthGate(child: VoiceSettingsScreen()), state),
        ),
        GoRoute(
          path: '/settings/features',
          name: 'features',
          pageBuilder: (context, state) => _slidePage(
            const AuthGate(child: FeaturesSettingsScreen()),
            state,
          ),
        ),
        GoRoute(
          path: '/settings/profiles',
          name: 'profiles',
          pageBuilder: (context, state) =>
              _slidePage(const AuthGate(child: ProfilesScreen()), state),
        ),
        GoRoute(
          path: '/settings/usage',
          name: 'usage',
          pageBuilder: (context, state) =>
              _slidePage(const AuthGate(child: UsageScreen()), state),
        ),
        GoRoute(
          path: '/settings/changelog',
          name: 'changelog',
          pageBuilder: (context, state) =>
              _slidePage(const AuthGate(child: ChangelogScreen()), state),
        ),
        GoRoute(
          path: '/settings/developer',
          name: 'developer',
          pageBuilder: (context, state) =>
              _slidePage(AuthGate(child: DeveloperScreen()), state),
          routes: [
            GoRoute(
              path: 'logs',
              name: 'dev-logs',
              pageBuilder: (context, state) =>
                  _slidePage(AuthGate(child: const DevLogsScreen()), state),
            ),
            GoRoute(
              path: 'network',
              name: 'dev-network',
              pageBuilder: (context, state) => _slidePage(
                const AuthGate(child: NetworkInspectorScreen()),
                state,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/session/recent',
          name: 'session-recent',
          builder: (context, state) =>
              const AuthGate(child: SessionRecentScreen()),
        ),
        GoRoute(
          path: '/chat/:sessionId/info',
          name: 'session-info',
          pageBuilder: (context, state) {
            final id = state.pathParameters['sessionId']!;
            return _slidePage(
              AuthGate(child: SessionInfoScreen(sessionId: id)),
              state,
            );
          },
        ),
        GoRoute(
          path: '/chat/:sessionId/files',
          name: 'session-files',
          pageBuilder: (context, state) {
            final id = state.pathParameters['sessionId']!;
            return _slidePage(
              AuthGate(child: SessionFilesScreen(sessionId: id)),
              state,
            );
          },
        ),
        GoRoute(
          path: '/chat/:sessionId/file',
          name: 'session-file',
          pageBuilder: (context, state) {
            final path2 = state.uri.queryParameters['path'] ?? '';
            final content = state.uri.queryParameters['content'];
            return _slidePage(
              AuthGate(
                child: SessionFileViewerScreen(path: path2, content: content),
              ),
              state,
            );
          },
        ),
        GoRoute(
          path: '/chat/:sessionId/message/:messageId',
          name: 'message-detail',
          pageBuilder: (context, state) {
            final sid = state.pathParameters['sessionId']!;
            final mid = state.pathParameters['messageId']!;
            final extra = state.extra as Map<String, dynamic>?;
            return _slidePage(
              AuthGate(
                child: MessageDetailScreen(
                  sessionId: sid,
                  messageId: mid,
                  messageData: extra,
                ),
              ),
              state,
            );
          },
        ),
        GoRoute(
          path: '/chat/:sessionId/agent/:messageId',
          name: 'agent-conversation',
          pageBuilder: (context, state) {
            final sid = state.pathParameters['sessionId']!;
            final mid = state.pathParameters['messageId']!;
            final extra = state.extra as Map<String, dynamic>?;
            return _slidePage(
              AuthGate(
                child: AgentConversationScreen(
                  sessionId: sid,
                  messageId: mid,
                  taskData: extra,
                ),
              ),
              state,
            );
          },
        ),
        GoRoute(
          path: '/new',
          name: 'new-session',
          pageBuilder: (context, state) =>
              _slideUpPage(const AuthGate(child: NewSessionScreen()), state),
        ),
        GoRoute(
          path: '/new/pick/machine',
          name: 'pick-machine',
          pageBuilder: (context, state) =>
              _slidePage(const AuthGate(child: PickMachineScreen()), state),
        ),
        GoRoute(
          path: '/new/pick/path',
          name: 'pick-path',
          pageBuilder: (context, state) =>
              _slidePage(const AuthGate(child: PickPathScreen()), state),
        ),
        GoRoute(
          path: '/new/pick/profile',
          name: 'pick-profile',
          pageBuilder: (context, state) =>
              _slidePage(const AuthGate(child: PickProfileScreen()), state),
        ),
        GoRoute(
          path: '/machine/:machineId',
          name: 'machine-detail',
          pageBuilder: (context, state) {
            final id = state.pathParameters['machineId']!;
            return _slidePage(
              AuthGate(child: MachineDetailScreen(machineId: id)),
              state,
            );
          },
        ),
        GoRoute(
          path: '/user/:userId',
          name: 'user-profile',
          pageBuilder: (context, state) {
            final id = state.pathParameters['userId']!;
            return _slidePage(
              AuthGate(child: UserProfileScreen(userId: id)),
              state,
            );
          },
        ),
        GoRoute(
          path: '/artifacts',
          name: 'artifacts',
          builder: (context, state) =>
              const AuthGate(child: ArtifactsListScreen()),
        ),
        GoRoute(
          path: '/artifacts/new',
          name: 'artifact-new',
          pageBuilder: (context, state) =>
              _slideUpPage(const AuthGate(child: NewArtifactScreen()), state),
        ),
        GoRoute(
          path: '/artifacts/:artifactId',
          name: 'artifact-detail',
          pageBuilder: (context, state) {
            final id = state.pathParameters['artifactId']!;
            return _slidePage(
              AuthGate(child: ArtifactDetailScreen(artifactId: id)),
              state,
            );
          },
        ),
        GoRoute(
          path: '/artifacts/:artifactId/edit',
          name: 'artifact-edit',
          pageBuilder: (context, state) {
            final id = state.pathParameters['artifactId']!;
            return _slidePage(
              AuthGate(child: EditArtifactScreen(artifactId: id)),
              state,
            );
          },
        ),
        GoRoute(
          path: '/zen',
          name: 'zen',
          builder: (context, state) => const AuthGate(child: ZenHomeScreen()),
        ),
        GoRoute(
          path: '/zen/new',
          name: 'zen-new',
          pageBuilder: (context, state) =>
              _slideUpPage(const AuthGate(child: ZenNewScreen()), state),
        ),
        GoRoute(
          path: '/zen/view',
          name: 'zen-view',
          pageBuilder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final todoId = extra?['todoId'] as String? ?? '';
            final sessionId = extra?['sessionId'] as String? ?? 'global';
            return _slidePage(
              AuthGate(
                child: ZenViewScreen(todoId: todoId, sessionId: sessionId),
              ),
              state,
            );
          },
        ),
        GoRoute(
          path: '/friends',
          name: 'friends',
          builder: (context, state) => const AuthGate(child: FriendsScreen()),
        ),
        GoRoute(
          path: '/terminal/connect',
          name: 'terminal-connect',
          builder: (context, state) =>
              const AuthGate(child: TerminalConnectScreen()),
        ),
        GoRoute(
          path: '/terminal',
          name: 'terminal',
          builder: (context, state) => const AuthGate(child: TerminalScreen()),
        ),
        GoRoute(
          path: '/settings/server',
          name: 'server-settings',
          builder: (context, state) =>
              const AuthGate(child: ServerSettingsScreen()),
        ),
        GoRoute(
          path: '/settings/connect/claude',
          name: 'claude-connect',
          builder: (context, state) =>
              const AuthGate(child: ClaudeConnectScreen()),
        ),
        GoRoute(
          path: '/settings/voice/language',
          name: 'voice-language',
          builder: (context, state) =>
              const AuthGate(child: VoiceLanguageSettingsScreen()),
        ),
      ],
      redirect: (context, state) {
        final authState = ref.read(authStateNotifierProvider);

        if (state.matchedLocation == '/') {
          if (authState == AuthState.authenticated) {
            return '/sessions';
          }
          return null;
        }
        // Keep deep links (e.g. /chat/:sessionId) stable across refresh.
        // Per-route AuthGate handles unauthenticated/error states in place.
        return null;
      },
    );
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

/// A [Page] that slides in from the right and supports iOS-style
/// swipe-back gesture on all platforms.
class _SwipeBackPage extends Page<void> {
  const _SwipeBackPage({required this.child, super.key});

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) {
    return _SwipeBackRoute(page: this);
  }
}

class _SwipeBackRoute extends PageRoute<void> {
  _SwipeBackRoute({required _SwipeBackPage page}) : super(settings: page);

  _SwipeBackPage get _page => settings as _SwipeBackPage;

  @override
  bool get popGestureEnabled => true;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 250);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _page.child;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return CupertinoRouteTransitionMixin.buildPageTransitions<void>(
      this,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
