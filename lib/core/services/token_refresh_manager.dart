import 'dart:async';

import '../api/api_client.dart';
import '../api/socket_io_client.dart';
import '../models/auth.dart';
import 'auth_service.dart';
import 'logger_service.dart' show logger;

/// Callback type for when token refresh fails and re-authentication is needed.
typedef OnTokenRefreshFailed = void Function();

/// Manages token refresh lifecycle across HTTP and WebSocket clients.
///
/// Coordinates token refresh between:
/// - [ApiClient] - updates the auth token for HTTP requests
/// - [SocketIoClient] - updates the auth token for WebSocket connections
///
/// Ensures only one refresh attempt is in flight at a time and notifies
/// listeners when token refresh fails irreversibly.
///
/// SERVER CONTRACT (verified against the happy-server Go implementation):
/// happy-server issues persistent tokens with **no `exp` claim** — they
/// never expire, and verification results are cached permanently
/// (`internal/server/auth/tokens.go`). There is also **no
/// `POST /v1/auth/refresh` route**: such a request falls through to the
/// grpc-gateway catch-all and returns 404. A 401 from this server therefore
/// means the token no longer verifies (rotated master secret, revoked or
/// foreign token), never that it expired. The only recovery is a fresh
/// sign-in, which is why the HTTP layer calls [notifyReauthRequired] rather
/// than [refreshToken]. [refreshToken] is kept for servers that do expose a
/// refresh endpoint, and still returns [AuthForbiddenError] against this one.
class TokenRefreshManager {
  TokenRefreshManager._();
  static final TokenRefreshManager _instance = TokenRefreshManager._();

  final _authService = AuthService();

  /// Minimum spacing between re-auth notifications, so a fan-out of
  /// parallel requests all failing with 401 does not restart the auth
  /// check once per request.
  static const _reauthNotifyThrottle = Duration(seconds: 10);

  DateTime? _lastReauthNotifyAt;

  /// Whether a token refresh is currently in flight.
  bool _isRefreshing = false;

  /// Queue of pending completers that will be resolved when token refresh
  /// completes (whether success or failure).
  final _pendingCompleters = <Completer<String>>[];

  /// Listeners to call when token refresh fails and re-authentication
  /// is required.
  final _onRefreshFailedListeners = <OnTokenRefreshFailed>[];

  /// Registers a callback to be invoked when token refresh fails
  /// and the user must re-authenticate.
  void onRefreshFailed(OnTokenRefreshFailed callback) {
    _onRefreshFailedListeners.add(callback);
  }

  /// Unregisters a previously registered callback.
  void removeOnRefreshFailed(OnTokenRefreshFailed callback) {
    _onRefreshFailedListeners.remove(callback);
  }

  /// Refreshes the token and returns the new token.
  ///
  /// If a refresh is already in flight, waits for that refresh to complete
  /// and returns the new token obtained by that refresh.
  ///
  /// If no refresh is in flight, initiates a new refresh and notifies all
  /// waiting callers of the result.
  ///
  /// Throws [AuthForbiddenError] if the refresh token is invalid or expired
  /// (user must re-authenticate).
  /// Throws [AuthException] if the refresh request fails.
  Future<String> refreshToken() async {
    // Fast path: if not refreshing, initiate a new refresh immediately.
    if (!_isRefreshing) {
      return _doRefresh();
    }

    // Slow path: another refresh is in flight, queue this request.
    final completer = Completer<String>();
    _pendingCompleters.add(completer);
    try {
      return await completer.future;
    } finally {
      _pendingCompleters.remove(completer);
    }
  }

  /// Initiates a new token refresh, waiting for all pending requests.
  Future<String> _doRefresh() async {
    _isRefreshing = true;
    String? newToken;

    try {
      logger.info('TokenRefreshManager: starting token refresh');
      newToken = await _authService.refreshToken();

      // Success: update ApiClient and SocketIoClient with new token.
      ApiClient().updateToken(newToken);
      socketIoClient.updateToken(newToken);

      logger.info('TokenRefreshManager: token refresh succeeded');

      // Resolve all pending completers with the new token.
      for (final completer in _pendingCompleters) {
        completer.complete(newToken);
      }

      return newToken;
    } on AuthForbiddenError catch (e) {
      logger.warning(
        'TokenRefreshManager: token refresh failed - '
        'refresh token expired or invalid: ${e.message}',
      );

      // Notify listeners that re-authentication is required.
      _notifyRefreshFailed();

      // Resolve pending completers with the error.
      for (final completer in _pendingCompleters) {
        completer.completeError(e);
      }

      rethrow;
    } catch (e, stack) {
      logger.error('TokenRefreshManager: token refresh failed: $e', e, stack);

      // Resolve pending completers with the error.
      for (final completer in _pendingCompleters) {
        completer.completeError(e);
      }

      rethrow;
    } finally {
      _isRefreshing = false;
      _pendingCompleters.clear();
    }
  }

  /// Notifies listeners that the current token is no longer accepted and
  /// the user has to sign in again.
  ///
  /// Called by the HTTP layer on a 401. See the class doc: this server has
  /// no refresh endpoint and its tokens never expire, so there is nothing
  /// to refresh — the app can only re-verify and, on failure, re-auth.
  ///
  /// Notifications are throttled to one per [_reauthNotifyThrottle] so a
  /// burst of parallel 401s triggers a single auth re-check.
  void notifyReauthRequired() {
    final now = DateTime.now();
    final last = _lastReauthNotifyAt;
    if (last != null && now.difference(last) < _reauthNotifyThrottle) {
      logger.info(
        'TokenRefreshManager: re-auth already signalled '
        '${now.difference(last).inMilliseconds}ms ago - skipping',
      );
      return;
    }
    _lastReauthNotifyAt = now;
    logger.warning(
      'TokenRefreshManager: token rejected by server - '
      're-authentication required',
    );
    _notifyRefreshFailed();
  }

  void _notifyRefreshFailed() {
    for (final listener in _onRefreshFailedListeners) {
      try {
        listener();
      } catch (e, stack) {
        logger.warning(
          'TokenRefreshManager: refresh failed listener threw: $e',
          e,
          stack,
        );
      }
    }
  }

  /// Resets the refresh manager state.
  ///
  /// Used during sign-out to clear any pending refresh attempts.
  void reset() {
    _isRefreshing = false;
    _lastReauthNotifyAt = null;
    for (final completer in _pendingCompleters) {
      completer.completeError(
        AuthException('Token refresh cancelled due to sign-out'),
      );
    }
    _pendingCompleters.clear();
  }
}

/// Singleton instance of the token refresh manager.
final tokenRefreshManager = TokenRefreshManager._instance;
