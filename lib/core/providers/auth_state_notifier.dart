import 'dart:async';

import 'package:riverpod/riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../api/api_client.dart';
import '../api/socket_io_client.dart' as socket_io;
import '../models/auth.dart';
import '../services/auth_service.dart';
import '../services/logger_service.dart' show logger;
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import 'artifacts_notifier.dart';
import 'current_session_notifier.dart';
import 'feed_notifier.dart';
import 'friends_notifier.dart';
import 'machines_notifier.dart';
import 'profile_notifier.dart';
import 'session_git_status_notifier.dart';
import 'sessions_notifier.dart';
import 'settings_notifier.dart';
import 'todo_notifier.dart';

final authStateNotifierProvider =
    NotifierProvider<AuthStateNotifier, AuthState>(() {
      return AuthStateNotifier();
    });

class AuthStateNotifier extends Notifier<AuthState> {
  final _authService = AuthService();
  String? _pendingDeepLink;

  @override
  AuthState build() {
    return AuthState.unauthenticated;
  }

  Future<void> checkAuth() async {
    state = AuthState.authenticating;
    try {
      final isAuth = await _authService.isAuthenticated();
      state = isAuth ? AuthState.authenticated : AuthState.unauthenticated;
      if (isAuth) {
        // Set the token on ApiClient when authenticated
        final credentials = await TokenStorage().getCredentials();
        if (credentials != null) {
          ApiClient().updateToken(credentials.token);
          // Keep the WebSocket token in sync with the HTTP token.
          // syncRestore() is a no-op when sync is already initialized,
          // so the socket would keep a stale token after re-linking.
          socket_io.socketIoClient.updateToken(credentials.token);
          await syncRestore(credentials);

          ref.read(sessionsNotifierProvider.notifier).loadFromSync();
          ref.read(machinesNotifierProvider.notifier).loadFromSync();
          ref.read(settingsNotifierProvider.notifier).loadFromSync();
          ref.read(todoStateNotifierProvider.notifier).loadFromSync();

          // syncRestore() already kicks off the initial server sync.
          // Await those queues here instead of triggering a second
          // full wave.
          await Future.wait<void>([
            sync.sessionsSync.awaitQueue(),
            sync.machinesSync.awaitQueue(),
            sync.settingsSync.awaitQueue(),
            sync.profileSync.awaitQueue(),
            sync.friendsSync.awaitQueue(),
            sync.feedSync.awaitQueue(),
            sync.artifactsSync.awaitQueue(),
            sync.todosSync.awaitQueue(),
          ], eagerError: false);
          ref.read(sessionsNotifierProvider.notifier).loadFromSync();
          ref.read(machinesNotifierProvider.notifier).loadFromSync();
          ref.read(settingsNotifierProvider.notifier).loadFromSync();
          ref.read(profileNotifierProvider.notifier).loadFromSync();
          ref.read(friendsNotifierProvider.notifier).loadFromSync();
          ref.read(feedNotifierProvider.notifier).loadFromSync();
          ref.read(artifactsNotifierProvider.notifier).loadFromSync();
          ref.read(todoStateNotifierProvider.notifier).loadFromSync();
          final profile = ref.read(profileNotifierProvider);
          if (profile != null) {
            Sentry.configureScope(
              (scope) =>
                  scope.setUser(SentryUser(id: profile.id)),
            );
          }
        }
        if (_pendingDeepLink != null) {
          await _handleDeepLink(_pendingDeepLink!);
          _pendingDeepLink = null;
        }
      }
    } catch (e, stack) {
      unawaited(Sentry.captureException(e, stackTrace: stack));
      state = AuthState.error;
    }
  }

  void handleDeepLink(String url) {
    if (state == AuthState.authenticated) {
      _handleDeepLink(url);
    } else {
      _pendingDeepLink = url;
    }
  }

  Future<void> _handleDeepLink(String url) async {
    try {
      await _authService.approveLinkingRequest(url);
    } catch (e) {
      logger.warning('Failed to handle deep link: $e');
    }
  }

  Future<void> signOut() async {
    await syncShutdown();
    await _authService.signOut();
    ref.read(sessionsNotifierProvider.notifier).clear();
    ref.read(machinesNotifierProvider.notifier).clear();
    ref.read(profileNotifierProvider.notifier).clear();
    ref.read(friendsNotifierProvider.notifier).clear();
    ref.read(feedNotifierProvider.notifier).clear();
    ref.read(settingsNotifierProvider.notifier).clear();
    ref.read(currentSessionNotifierProvider.notifier).clear();
    ref.read(artifactsNotifierProvider.notifier).clear();
    ref.read(todoStateNotifierProvider.notifier).clear();
    ref.read(sessionGitStatusNotifierProvider.notifier).clear();
    state = AuthState.unauthenticated;
    Sentry.configureScope((scope) => scope.setUser(null));
  }
}
