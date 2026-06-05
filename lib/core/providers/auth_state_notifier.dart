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
  String? _activeDeepLink;
  OnTokenRefreshFailed? _tokenRefreshFailedListener;

  @override
  AuthState build() {
    // Register for token refresh failure notifications.
    _tokenRefreshFailedListener = _handleTokenRefreshFailed;
    tokenRefreshManager.onRefreshFailed(_tokenRefreshFailedListener!);
    ref.onDispose(() {
      final listener = _tokenRefreshFailedListener;
      if (listener != null) {
        tokenRefreshManager.removeOnRefreshFailed(listener);
        _tokenRefreshFailedListener = null;
      }
    });

    return AuthState.unauthenticated;
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

  void beginAuthCheck() {
    state = AuthState.authenticating;
  }

  void failAuthCheck() {
    state = AuthState.error;
  }

  Future<void> checkAuth() async {
    state = AuthState.authenticating;
    try {
      final credentials = await TokenStorage().getCredentials();
      final isAuth = credentials != null;
      state = isAuth ? AuthState.authenticated : AuthState.unauthenticated;
      if (credentials != null) {
        ApiClient().updateToken(credentials.token);
        // Keep the WebSocket token in sync with the HTTP token.
        socket_io.socketIoClient.updateToken(credentials.token);
        await syncRestore(credentials);

        // Kick off the list-heavy invalidations in the background so
        // the network fetch overlaps with the SessionsScreen mount.
        // Without this, the screens would only see cached state
        // until their own initState called `refreshFromSync`,
        // adding a visible spinner (or empty list) on first paint.
        // The awaitQueue() pair below only waits for the cheap,
        // auth-critical syncs.  `invalidate()` is idempotent on
        // InvalidateSync (debounced / single-flight), so the later
        // refreshFromSync() from the screen is a cheap no-op.
        unawaited(sync.sessionsSync.invalidate());
        unawaited(sync.machinesSync.invalidate());
        unawaited(sync.artifactsSync.invalidate());
        unawaited(sync.sessionGitStatusSync.invalidate());

        // Remaining auth-critical syncs complete in the background.
        unawaited(
          Future.wait<void>([
            sync.settingsSync.awaitQueue(),
            sync.profileSync.awaitQueue(),
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
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty || !normalizedUrl.startsWith('happy://')) {
      logger.warning('Ignoring unsupported deep link');
      return;
    }
    if (normalizedUrl == _pendingDeepLink || normalizedUrl == _activeDeepLink) {
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'Duplicate deep link ignored',
            category: 'deep_link',
            data: _deepLinkBreadcrumbData(normalizedUrl),
          ),
        ),
      );
      return;
    }

    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Deep link received',
          category: 'deep_link',
          data: {
            ..._deepLinkBreadcrumbData(normalizedUrl),
            'authState': state.name,
          },
        ),
      ),
    );

    if (state == AuthState.authenticated) {
      unawaited(_handleDeepLink(normalizedUrl));
    } else {
      _pendingDeepLink = normalizedUrl;
    }
  }

  Future<void> _handleDeepLink(String url) async {
    if (url == _activeDeepLink) return;
    _activeDeepLink = url;
    try {
      await _authService.approveLinkingRequest(url);
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'Deep link handled',
            category: 'deep_link',
            data: _deepLinkBreadcrumbData(url),
          ),
        ),
      );
    } catch (e, stack) {
      logger.warning('Failed to handle deep link', e, stack);
    } finally {
      if (_activeDeepLink == url) {
        _activeDeepLink = null;
      }
    }
  }

  Map<String, Object?> _deepLinkBreadcrumbData(String url) {
    final uri = Uri.tryParse(url);
    return {
      'scheme': uri?.scheme,
      'host': uri?.host,
      'path': uri?.path,
      'hasQuery': uri?.hasQuery,
    };
  }

  Future<void> signOut() async {
    await syncShutdown();
    await _authService.signOut();
    AppLifecycleService.clearAll(ref);
    state = AuthState.unauthenticated;
    Sentry.configureScope((scope) => scope.setUser(null));
  }
}
