import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_links/app_links.dart';
import 'core/api/api_client.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/supported_locales.dart';
import 'core/models/auth.dart';
import 'core/providers/app_providers.dart';
import 'core/services/auth_service.dart';
import 'core/services/server_config.dart';
import 'core/services/storage_service.dart' as storage;
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await storage.Storage().initialize();

  final serverUrl = getServerUrl();
  await ApiClient().initialize(serverUrl: serverUrl);

  runApp(
    const ProviderScope(
      child: HappyApp(),
    ),
  );
}

class HappyApp extends ConsumerStatefulWidget {
  const HappyApp({super.key});

  @override
  ConsumerState<HappyApp> createState() => _HappyAppState();
}

class _HappyAppState extends ConsumerState<HappyApp> with WidgetsBindingObserver {
  late final GoRouter _router;
  late final AppLinks _appLinks;
  StreamSubscription<Uri?>? _appLinksSubscription;
  Uri? _initialUri;
  bool _initialUriHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appLinks = AppLinks();
    _initUniLinks();
    _router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          name: 'auth',
          builder: (context, state) => AuthGate(
            child: SessionsScreen(),
            initialDeepLink: state.uri.queryParameters['link'],
          ),
        ),
        GoRoute(
          path: '/sessions',
          name: 'sessions',
          builder: (context, state) => AuthGate(
            child: SessionsScreen(),
          ),
        ),
        GoRoute(
          path: '/chat/:sessionId',
          name: 'chat',
          builder: (context, state) {
            final sessionId = state.pathParameters['sessionId']!;
            return AuthGate(
              child: ChatScreen(sessionId: sessionId),
            );
          },
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const AuthGate(
            child: SettingsScreen(),
          ),
        ),
        GoRoute(
          path: '/settings/account',
          name: 'account',
          builder: (context, state) => const AuthGate(
            child: AccountScreen(),
          ),
        ),
        GoRoute(
          path: '/settings/account/restore',
          name: 'restore',
          builder: (context, state) => const AuthGate(
            child: RestoreAccountScreen(),
          ),
        ),
        GoRoute(
          path: '/settings/account/link',
          name: 'link',
          builder: (context, state) => const AuthGate(
            child: LinkDeviceScreen(),
          ),
        ),
        GoRoute(
          path: '/settings/account/devices',
          name: 'devices',
          builder: (context, state) => const AuthGate(
            child: LinkedDevicesScreen(),
          ),
        ),
        GoRoute(
          path: '/settings/theme',
          name: 'theme',
          builder: (context, state) => const AuthGate(
            child: ThemeSettingsScreen(),
          ),
        ),
        GoRoute(
          path: '/settings/language',
          name: 'language',
          builder: (context, state) => const AuthGate(
            child: LanguageSettingsScreen(),
          ),
        ),
        GoRoute(
          path: '/settings/voice',
          name: 'voice',
          builder: (context, state) => const AuthGate(
            child: VoiceSettingsScreen(),
          ),
        ),
        GoRoute(
          path: '/settings/features',
          name: 'features',
          builder: (context, state) => const AuthGate(
            child: FeaturesSettingsScreen(),
          ),
        ),
        GoRoute(
          path: '/settings/profiles',
          name: 'profiles',
          builder: (context, state) => const AuthGate(
            child: ProfilesScreen(),
          ),
        ),
        GoRoute(
          path: '/settings/usage',
          name: 'usage',
          builder: (context, state) => const AuthGate(
            child: UsageScreen(),
          ),
        ),
        GoRoute(
          path: '/settings/developer',
          name: 'developer',
          builder: (context, state) => AuthGate(
            child: DeveloperScreen(),
          ),
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
    Future.delayed(Duration.zero, () {
      ref.read(authStateNotifierProvider.notifier).checkAuth();
    });
  }

  Future<void> _initUniLinks() async {
    if (!kIsWeb) {
      try {
        final uri = await _appLinks.getInitialAppLink();
        if (uri != null && mounted) {
          setState(() {
            _initialUri = uri;
          });
          _handleDeepLink(uri);
        }
      } catch (e) {
        print('Error getting initial app link URI: $e');
      }

      _appLinksSubscription = _appLinks.uriLinkStream.listen(
        (Uri? uri) {
          if (uri != null && mounted) {
            _handleDeepLink(uri);
          }
        },
        onError: (err) {
          print('Error listening to app links: $err');
        },
      );
    }
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'happy') {
      final url = uri.toString();
      final publicKey = AuthService.parseAuthUrl(url);
      if (publicKey != null) {
        ref.read(authStateNotifierProvider.notifier).handleDeepLink(url);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appLinksSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForDeepLink();
    }
  }

  Future<void> _checkForDeepLink() async {
    if (!kIsWeb) {
      try {
        final uri = await _appLinks.getInitialAppLink();
        if (uri != null && uri.scheme == 'happy') {
          _handleDeepLink(uri);
        }
      } catch (e) {
        print('Error checking for deep link on resume: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Happy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue,
          secondary: Colors.blueAccent,
        ),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: supportedLocales,
      routerConfig: _router,
    );
  }
}

bool get kIsWeb => identical(0, 0.0);
