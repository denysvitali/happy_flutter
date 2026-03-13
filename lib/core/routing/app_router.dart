import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/artifacts/artifact_detail_screen.dart';
import '../../features/artifacts/artifacts_list_screen.dart';
import '../../features/artifacts/edit_artifact_screen.dart';
import '../../features/artifacts/new_artifact_screen.dart';
import '../../features/chat/agent_conversation_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/chat/message_detail_screen.dart';
import '../../features/chat/session_file_viewer_screen.dart';
import '../../features/chat/session_files_screen.dart';
import '../../features/chat/session_info_screen.dart';
import '../../features/chat/session_recent_screen.dart';
import '../../features/dev/dev_logs_screen.dart';
import '../../features/dev/encryption_debug_screen.dart';
import '../../features/dev/network_inspector_screen.dart';
import '../../features/dev/notification_test_screen.dart';
import '../../features/dev/session_debug_screen.dart';
import '../../features/inbox/friends_screen.dart';
import '../../features/inbox/friends_search_screen.dart';
import '../../features/inbox/inbox_screen.dart';
import '../../features/machine/machine_detail_screen.dart';
import '../../features/sessions/new_session_screen.dart';
import '../../features/sessions/pick_machine_screen.dart';
import '../../features/sessions/pick_path_screen.dart';
import '../../features/sessions/pick_profile_screen.dart';
import '../../features/sessions/sessions_screen.dart';
import '../../features/sftp/models/sftp_directory.dart';
import '../../features/sftp/screens/sftp_connection_history_screen.dart';
import '../../features/sftp/screens/sftp_directory_manager_screen.dart';
import '../../features/sftp/screens/sftp_log_viewer_screen.dart';
import '../../features/settings/account_screen.dart';
import '../../features/settings/changelog_screen.dart';
import '../../features/settings/claude_connect_screen.dart';
import '../../features/settings/developer_screen.dart';
import '../../features/settings/features_settings_screen.dart';
import '../../features/settings/language_settings_screen.dart';
import '../../features/settings/machines_screen.dart';
import '../../features/settings/profiles_screen.dart';
import '../../features/settings/server_settings_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/theme_settings_screen.dart';
import '../../features/settings/usage_screen.dart';
import '../../features/settings/voice_language_settings_screen.dart';
import '../../features/settings/voice_settings_screen.dart';
import '../../features/terminal/terminal_connect_screen.dart';
import '../../features/terminal/terminal_screen.dart';
import '../../features/user/user_profile_screen.dart';
import '../../features/zen/zen_home_screen.dart';
import '../../features/zen/zen_new_screen.dart';
import '../../features/zen/zen_view_screen.dart';
import '../../sentry_widget.dart'
    if (dart.library.js_interop) '../../sentry_widget_stub.dart';
import '../models/auth.dart';
import '../providers/app_providers.dart';
import '../widgets/auth_gate.dart';

/// Fade transition for tab-level routes.
Page<void> _fadePage(Widget child, GoRouterState state) {
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
Page<void> _slideUpPage(Widget child, GoRouterState state) {
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
Page<void> _slidePage(Widget child, GoRouterState state) {
  return _SwipeBackPage(key: state.pageKey, child: child);
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

/// Creates the [GoRouter] instance for the app.
///
/// [initialDeepLink] is the deep link URL if the app was opened from one.
GoRouter createRouter(String? initialDeepLink) {
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
              initialDeepLink: initialDeepLink,
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
          GoRoute(
            path: 'encryption',
            name: 'dev-encryption',
            pageBuilder: (context, state) => _slidePage(
              const AuthGate(child: EncryptionDebugScreen()),
              state,
            ),
          ),
          GoRoute(
            path: 'session',
            name: 'dev-session',
            pageBuilder: (context, state) => _slidePage(
              const AuthGate(child: SessionDebugScreen()),
              state,
            ),
          ),
          GoRoute(
            path: 'notifications',
            name: 'dev-notifications',
            pageBuilder: (context, state) => _slidePage(
              const AuthGate(child: NotificationTestScreen()),
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
      GoRoute(
        path: '/sftp/logs',
        name: 'sftp-logs',
        pageBuilder: (context, state) {
          final deviceId = state.uri.queryParameters['deviceId'];
          return _slidePage(
            AuthGate(
              child: SftpLogViewerScreen(initialDeviceId: deviceId),
            ),
            state,
          );
        },
      ),
      GoRoute(
        path: '/sftp/directory',
        name: 'sftp-directory',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final directory = extra?['directory'] as SftpDirectory;
          return _slidePage(
            AuthGate(
              child: SftpDirectoryManagerScreen(directory: directory),
            ),
            state,
          );
        },
      ),
      GoRoute(
        path: '/sftp/connections',
        name: 'sftp-connections',
        pageBuilder: (context, state) {
          final deviceId = state.uri.queryParameters['deviceId'];
          return _slidePage(
            AuthGate(
              child: SftpConnectionHistoryScreen(deviceId: deviceId),
            ),
            state,
          );
        },
      ),
    ],
    redirect: (context, state) {
      final authState = ProviderScope.containerOf(
        context,
      ).read(authStateNotifierProvider);
      if (state.matchedLocation == '/') {
        if (authState == AuthState.authenticated) {
          return '/sessions';
        }
        return null;
      }
      return null;
    },
  );
}
