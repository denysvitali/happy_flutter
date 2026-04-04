import 'dart:async';

import 'package:riverpod/riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../api/api_client.dart';
import '../api/socket_io_client.dart' as socket_io;
import '../models/auth.dart';
import '../providers/profile_notifier.dart';
import '../services/app_lifecycle_service.dart';
import '../services/auth_service.dart';
import '../services/logger_service.dart' show logger;
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/token_refresh_manager.dart';

final authStateNotifierProvider =
    NotifierProvider<AuthStateNotifier, AuthState>(() {
      return AuthStateNotifier();
    });

class AuthStateNotifier extends Notifier<AuthState> {
  final _authService = AuthService();
  String? _pendingDeepLink;
  OnTokenRefreshFailed? _tokenRefreshFailedListener;

  @override
  AuthState build() {
    // Register for token refresh failure notifications.
    _tokenRefreshFailedListener = _handleTokenRefreshFailed;
    tokenRefreshManager.onRefreshFailed(_tokenRefreshFailedListener!);

    return AuthState.unauthenticated;
  }

  void dispose() {
    if (_tokenRefreshFailedListener != null) {
      tokenRefreshManager.removeOnRefreshFailed(_tokenRefreshFailedListener!);
    }
  }

  void _handleTokenRefreshFailed() {
    logger.warning(
      'AuthStateNotifier: token refresh failed - '
      're-verifying credentials',
    );
    // Re-check authentication after a failed token refresh.
    // This will attempt to verify the current token. If it fails
    // (expected after refresh failure), the user will be signed out.
    checkAuth();
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

          // Remaining syncs (settings, profile, friends, etc.) complete
          // in the background.  sync.onDataChanged already triggers
          // loadFromSync() on each screen's subscription, so we don't
          // need to block here.  Fire-and-forget the final batch and
          // Sentry user setup.
          unawaited(
            Future.wait<void>([
              sync.settingsSync.awaitQueue(),
              sync.profileSync.awaitQueue(),
              sync.friendsSync.awaitQueue(),
              sync.feedSync.awaitQueue(),
              sync.artifactsSync.awaitQueue(),
              sync.todosSync.awaitQueue(),
            ], eagerError: false).then((_) {
              AppLifecycleService.loadAll(ref);
              final profile = ref.read(profileNotifierProvider);
              if (profile != null) {
                Sentry.configureScope(
                  (scope) => scope.setUser(SentryUser(id: profile.id)),
                );
              }
            }),
          );
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
    } catch (e, stack) {
      logger.warning('Failed to handle deep link', e, stack);
    }
  }

  Future<void> signOut() async {
    await syncShutdown();
    await _authService.signOut();
    AppLifecycleService.clearAll(ref);
    state = AuthState.unauthenticated;
    Sentry.configureScope((scope) => scope.setUser(null));
  }
}
