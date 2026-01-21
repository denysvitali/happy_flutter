import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/api/api_client.dart';
import 'core/models/auth.dart';
import 'core/providers/app_providers.dart';
import 'core/services/server_config.dart';
import 'core/services/storage_service.dart' as storage;
import 'features/auth/auth_screen.dart';
import 'features/sessions/sessions_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage
  await storage.Storage().initialize();

  // Get server URL and initialize API client
  final serverUrl = await getServerUrl();
  await ApiClient().initialize(serverUrl: serverUrl);

  runApp(
    const ProviderScope(
      child: HappyApp(),
    ),
  );
}

/// Main app widget
class HappyApp extends ConsumerStatefulWidget {
  const HappyApp({super.key});

  @override
  ConsumerState<HappyApp> createState() => _HappyAppState();
}

class _HappyAppState extends ConsumerState<HappyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          name: 'auth',
          builder: (context, state) => const AuthGate(
            child: SessionsScreen(),
          ),
        ),
        GoRoute(
          path: '/sessions',
          name: 'sessions',
          builder: (context, state) => const AuthGate(
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
      ],
      redirect: (context, state) {
        final authState = ref.read(authStateNotifierProvider);

        // Allow access to auth screen when unauthenticated
        if (state.matchedLocation == '/') {
          if (authState == AuthState.authenticated) {
            return '/sessions';
          }
          return null;
        }

        // Redirect to auth if not authenticated
        if (authState != AuthState.authenticated) {
          return '/';
        }

        return null;
      },
    );
    // Check authentication on startup
    Future.delayed(Duration.zero, () {
      ref.read(authStateNotifierProvider.notifier).checkAuth();
    });
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
      routerConfig: _router,
    );
  }
}
