import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/api/api_client.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/supported_locales.dart';
import 'core/models/auth.dart';
import 'core/providers/app_providers.dart';
import 'core/services/server_config.dart';
import 'core/services/storage_service.dart' as storage;
import 'core/utils/theme_helper.dart';
import 'features/auth/auth_screen.dart';
import 'features/sessions/sessions_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/account_screen.dart';
import 'features/settings/theme_settings_screen.dart';
import 'features/settings/language_settings_screen.dart';
import 'features/settings/voice_settings_screen.dart';
import 'features/settings/features_settings_screen.dart';
import 'features/settings/profiles_screen.dart';
import 'features/settings/usage_screen.dart';
import 'features/settings/developer_screen.dart';
import 'features/settings/changelog_screen.dart';
import 'features/dev/dev_logs_screen.dart';
import 'features/inbox/inbox_screen.dart';
import 'features/inbox/friends_search_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await storage.Storage().initialize();

  final serverUrl = getServerUrl();
  await ApiClient().initialize(serverUrl: serverUrl);

  runApp(const ProviderScope(child: HappyApp()));
}

class HappyApp extends ConsumerStatefulWidget {
  const HappyApp({super.key});

  @override
  ConsumerState<HappyApp> createState() => _HappyAppState();
}

class _HappyAppState extends ConsumerState<HappyApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = _buildRouter();
    Future.delayed(Duration.zero, () {
      ref.read(authStateNotifierProvider.notifier).checkAuth();
      _initializeTheme();
    });
  }

  void _initializeTheme() async {
    // Load settings and apply the theme
    await ref.read(settingsNotifierProvider.notifier).loadSettings();
    _applyThemeFromSettings();
  }

  void _applyThemeFromSettings() {
    final settings = ref.read(settingsNotifierProvider);
    final themeMode = AppThemeMode.fromString(settings.themeMode);
    themeMode.applySystemChromeWithContext(ref.context);
  }

  GoRouter _buildRouter() {
    return GoRouter(
      routes: [
        GoRoute(
          path: '/',
          name: 'auth',
          builder: (context, state) => const AuthGate(child: SessionsScreen()),
        ),
        GoRoute(
          path: '/sessions',
          name: 'sessions',
          builder: (context, state) => AuthGate(child: SessionsScreen()),
        ),
        GoRoute(
          path: '/chat/:sessionId',
          name: 'chat',
          builder: (context, state) {
            final sessionId = state.pathParameters['sessionId']!;
            return AuthGate(child: ChatScreen(sessionId: sessionId));
          },
        ),
        GoRoute(
          path: '/inbox',
          name: 'inbox',
          builder: (context, state) => const AuthGate(child: InboxScreen()),
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
          builder: (context, state) => const AuthGate(child: SettingsScreen()),
        ),
        GoRoute(
          path: '/settings/account',
          name: 'account',
          builder: (context, state) => const AuthGate(child: AccountScreen()),
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
          path: '/settings/theme',
          name: 'theme',
          builder: (context, state) =>
              const AuthGate(child: ThemeSettingsScreen()),
        ),
        GoRoute(
          path: '/settings/language',
          name: 'language',
          builder: (context, state) =>
              const AuthGate(child: LanguageSettingsScreen()),
        ),
        GoRoute(
          path: '/settings/voice',
          name: 'voice',
          builder: (context, state) =>
              const AuthGate(child: VoiceSettingsScreen()),
        ),
        GoRoute(
          path: '/settings/features',
          name: 'features',
          builder: (context, state) =>
              const AuthGate(child: FeaturesSettingsScreen()),
        ),
        GoRoute(
          path: '/settings/profiles',
          name: 'profiles',
          builder: (context, state) => const AuthGate(child: ProfilesScreen()),
        ),
        GoRoute(
          path: '/settings/usage',
          name: 'usage',
          builder: (context, state) => const AuthGate(child: UsageScreen()),
        ),
        GoRoute(
          path: '/settings/changelog',
          name: 'changelog',
          builder: (context, state) => const AuthGate(child: ChangelogScreen()),
        ),
        GoRoute(
          path: '/settings/developer',
          name: 'developer',
          builder: (context, state) => AuthGate(child: DeveloperScreen()),
        ),
        GoRoute(
          path: '/settings/developer/logs',
          name: 'dev-logs',
          builder: (context, state) => AuthGate(child: const DevLogsScreen()),
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

        if (authState != AuthState.authenticated) {
          return '/';
        }

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
    // Re-apply theme when app resumes (helps with theme changes while app was in background)
    if (state == AppLifecycleState.resumed) {
      _applyThemeFromSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final settings = ref.watch(settingsNotifierProvider);
        final themeMode = AppThemeMode.fromString(settings.themeMode);

        // Apply system chrome for theme
        WidgetsBinding.instance.addPostFrameCallback((_) {
          themeMode.applySystemChromeWithContext(context);
        });

        return MaterialApp.router(
          title: 'Happy',
          theme: ThemeHelper.buildLightTheme(),
          darkTheme: ThemeHelper.buildDarkTheme(),
          themeMode: _getThemeMode(themeMode),
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: supportedLocales,
          routerConfig: _router,
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

bool get kIsWeb => identical(0, 0.0);
