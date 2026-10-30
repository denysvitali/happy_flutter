import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../api/api_client.dart';
import '../models/auth.dart';
import '../services/app_lifecycle_service.dart';
import '../services/auth_service.dart';
import '../services/logger_service.dart' show logger;
import '../services/opentelemetry_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/token_refresh_manager.dart';
import 'auth_transition_epoch.dart';
import 'profile_notifier.dart';

final authStateNotifierProvider =
    NotifierProvider<AuthStateNotifier, AuthState>(() {
      return AuthStateNotifier();
    });

final pendingLinkRequestProvider =
    NotifierProvider<PendingLinkRequestNotifier, PendingLinkRequest?>(
      PendingLinkRequestNotifier.new,
    );

class PendingLinkRequest {
  const PendingLinkRequest({
    required this.url,
    required this.fingerprint,
    required this.isTerminal,
  });

  final String url;
  final String fingerprint;
  final bool isTerminal;
}

class PendingLinkRequestNotifier extends Notifier<PendingLinkRequest?> {
  @override
  PendingLinkRequest? build() => null;

  void stage(String url) {
    final publicKey = AuthService.parseAuthUrl(url);
    if (publicKey == null) return;
    final fingerprint = sha256.convert(publicKey).toString();
    state = PendingLinkRequest(
      url: url,
      fingerprint: fingerprint,
      isTerminal: url.startsWith('happy://terminal?'),
    );
  }

  void clear([String? expectedUrl]) {
    if (expectedUrl == null || state?.url == expectedUrl) state = null;
  }
}

class AuthStateNotifier extends Notifier<AuthState> {
  final _authService = AuthService();
  OnTokenRefreshFailed? _tokenRefreshFailedListener;
  bool _reauthCheckInFlight = false;
  bool _requiresVerification = false;
  Timer? _tokenRenewalTimer;
  final _transitionEpoch = AuthTransitionEpoch();
  Future<void> _transitionTail = Future<void>.value();
  int _confirmationGeneration = 0;
  int get authTransitionGeneration => _confirmationGeneration;

  @override
  AuthState build() {
    // Register for token refresh failure notifications.
    _tokenRefreshFailedListener = _handleTokenRefreshFailed;
    tokenRefreshManager.onRefreshFailed(_tokenRefreshFailedListener!);
    final removeCredentialListener = _authService.onCredentialsChanging(() {
      sync.setAuthenticationBlocked(true);
      _tokenRenewalTimer?.cancel();
      _tokenRenewalTimer = null;
      _confirmationGeneration++;
      _transitionEpoch.invalidate();
    });
    ref.onDispose(() {
      removeCredentialListener();
      _transitionEpoch.invalidate();
      _tokenRenewalTimer?.cancel();
      final listener = _tokenRefreshFailedListener;
      if (listener != null) {
        tokenRefreshManager.removeOnRefreshFailed(listener);
        _tokenRefreshFailedListener = null;
      }
    });

    return AuthState.unauthenticated;
  }

  void _handleTokenRefreshFailed() {
    if (_reauthCheckInFlight) return;
    _reauthCheckInFlight = true;
    _requiresVerification = true;
    _tokenRenewalTimer?.cancel();
    logger.warning(
      'AuthStateNotifier: token rejected by server - '
      're-verifying credentials',
    );
    unawaited(_verifyAfterRejection());
  }

  /// Re-verifies the stored token after the server rejected it.
  ///
  /// Must go through [AuthService.getAuthState] (which calls
  /// `/v1/auth/verify` and preserves credentials on rejection). Reading
  /// credentials from disk alone cannot establish that a token still works.
  ///
  /// This runs while the user is mid-session, so it must NOT flip the
  /// state to `authenticating`: AuthGate swaps the whole subtree to the
  /// "checking sign-in" view for that state, which unmounts the chat
  /// screen and throws away the composer's staged input. The state only
  /// changes once the verification has a verdict.
  Future<void> _verifyAfterRejection() {
    _confirmationGeneration++;
    final transition = _transitionEpoch.begin();
    return _enqueueAuthTransition(
      () => _runVerificationAfterRejection(transition),
    );
  }

  Future<void> _runVerificationAfterRejection(int transition) async {
    try {
      final verdict = await _authService.getAuthState();
      if (!_transitionEpoch.isCurrent(transition)) return;
      if (verdict == AuthState.unauthenticated) {
        _requiresVerification = false;
        // No stored credentials remain; tear down the synced state.
        logger.warning(
          'AuthStateNotifier: stored token is no longer valid - '
          'signing out',
        );
        await syncShutdown();
        if (!_transitionEpoch.isCurrent(transition)) return;
        AppLifecycleService.clearAll(ref);
        Sentry.configureScope((scope) => scope.setUser(null));
        state = AuthState.unauthenticated;
      } else if (verdict == AuthState.authenticated) {
        _requiresVerification = false;
        // Transport/server blip on the failing request, token still good.
        final credentials = await TokenStorage().getCredentials();
        if (!_transitionEpoch.isCurrent(transition)) return;
        sync.setAuthenticationBlocked(false);
        _scheduleTokenRenewal(credentials);
        if (sync.isInitialized) sync.resumeAfterAuthentication();
        state = AuthState.authenticated;
      } else if (_authService.lastAuthFailure == AuthFailureKind.rejected) {
        // Retain the runtime and its outbox for same-account recovery while
        // pausing background requests made with the rejected bearer token.
        sync.setAuthenticationBlocked(true);
        state = AuthState.error;
      }
      // AuthState.error: the verification itself could not reach a verdict
      // (network failure). Keep the current state and let the next 401 or
      // the next foreground check retry.
    } catch (e, stack) {
      if (!_transitionEpoch.isCurrent(transition)) return;
      logger.error('AuthStateNotifier: re-auth verification failed', e, stack);
      if (_authService.cleanupPending) {
        sync.setAuthenticationBlocked(true);
        await syncShutdown();
        if (!_transitionEpoch.isCurrent(transition)) return;
        AppLifecycleService.clearAll(ref);
        state = AuthState.error;
      }
      unawaited(Sentry.captureException(e, stackTrace: stack));
    } finally {
      _reauthCheckInFlight = false;
    }
  }

  void beginAuthCheck() {
    _tokenRenewalTimer?.cancel();
    state = AuthState.authenticating;
  }

  void failAuthCheck() {
    _tokenRenewalTimer?.cancel();
    state = AuthState.error;
  }

  /// Verifies the stored credentials and restores the synced state.
  ///
  /// Set [showProgress] to false for background re-checks of an already
  /// mounted session: [AuthState.authenticating] makes `AuthGate` replace
  /// the whole app subtree with the "checking sign-in" view, unmounting
  /// whatever screen the user is on. The state then only changes once the
  /// check has a verdict.
  Future<void> checkAuth({bool showProgress = true}) {
    _tokenRenewalTimer?.cancel();
    _confirmationGeneration++;
    final transition = _transitionEpoch.begin();
    if (showProgress) {
      state = AuthState.authenticating;
    }
    return _enqueueAuthTransition(() => _runCheckAuth(transition));
  }

  Future<void> _runCheckAuth(int transition) async {
    if (!_transitionEpoch.isCurrent(transition)) return;
    try {
      logger.info('AuthStateNotifier: checking stored credentials');
      if (_authService.cleanupPending) {
        sync.setAuthenticationBlocked(true);
        state = AuthState.error;
        return;
      }
      final requiresVerification =
          _requiresVerification ||
          _authService.lastAuthFailure == AuthFailureKind.rejected;
      if (requiresVerification) {
        _requiresVerification = true;
        final verdict = await _authService.getAuthState();
        if (!_transitionEpoch.isCurrent(transition)) return;
        if (verdict != AuthState.authenticated) {
          sync.setAuthenticationBlocked(true);
          state = verdict;
          return;
        }
        _requiresVerification = false;
      }
      final credentials = await _authService.refreshCredentialsIfNeeded();
      if (!_transitionEpoch.isCurrent(transition)) return;
      _scheduleTokenRenewal(credentials);
      final isAuth = credentials != null;
      state = isAuth ? AuthState.authenticated : AuthState.unauthenticated;
      if (credentials != null) {
        logger.info('AuthStateNotifier: restoring authenticated sync state');
        if (sync.isInitialized && sync.credentials.token != credentials.token) {
          await syncShutdown();
          if (!_transitionEpoch.isCurrent(transition)) return;
        }
        ApiClient().updateToken(credentials.token);
        // Keep the WebSocket token in sync with the HTTP token.
        _authService.updateSocketToken(credentials.token);
        sync.setAuthenticationBlocked(false);
        await OpenTelemetryService().waitUntilReady();
        if (!_transitionEpoch.isCurrent(transition)) return;
        await syncRestore(credentials);
        if (!_transitionEpoch.isCurrent(transition)) {
          await syncShutdown();
          return;
        }
        sync.resumeAfterAuthentication();

        // Kick off the list-heavy invalidations in the background so
        // the network fetch overlaps with the SessionsScreen mount.
        // Without this, the screens would only see cached state
        // until their own initState called `refreshFromSync`,
        // adding a visible spinner (or empty list) on first paint.
        // The awaitQueue() pair below only waits for the cheap,
        // auth-critical syncs.  `invalidate()` is idempotent on
        // InvalidateSync (debounced / single-flight), so the later
        // refreshFromSync() from the screen is a cheap no-op.
        // invalidate() returns void (not Future) so we just call
        // it directly without unawaited().
        // Only invalidate the two syncs needed for the default screen.
        // Artifacts and git-status are deferred to a post-frame callback so
        // they don't compete with the first paint for the main-thread event
        // loop.
        sync.sessionsSync.invalidate();
        sync.machinesSync.invalidate();

        // Defer non-critical syncs to a post-frame callback so they don't
        // compete with the first paint for the main-thread event loop.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_transitionEpoch.isCurrent(transition)) return;
          sync.artifactsSync.invalidate();
          sync.sessionGitStatusSync.invalidate();
        });

        // Remaining auth-critical syncs complete in the background.
        unawaited(
          Future.wait<void>([
            sync.settingsSync.awaitQueue(),
            sync.profileSync.awaitQueue(),
          ], eagerError: false).then((_) {
            if (!_transitionEpoch.isCurrent(transition)) return;
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
    } on AuthForbiddenError {
      if (!_transitionEpoch.isCurrent(transition)) return;
      _requiresVerification = true;
      sync.setAuthenticationBlocked(true);
      state = AuthState.error;
    } catch (e, stack) {
      if (!_transitionEpoch.isCurrent(transition)) return;
      logger.error('AuthStateNotifier: auth check failed', e, stack);
      unawaited(Sentry.captureException(e, stackTrace: stack));
      sync.setAuthenticationBlocked(true);
      state = AuthState.error;
    }
  }

  void _scheduleTokenRenewal(AuthCredentials? credentials) {
    _tokenRenewalTimer?.cancel();
    _tokenRenewalTimer = null;
    if (credentials == null) return;
    final delay = _authService.nextTokenRefreshDelay(credentials);
    if (delay == null) return;
    _tokenRenewalTimer = Timer(delay, () {
      _tokenRenewalTimer = null;
      if (ref.mounted && state == AuthState.authenticated) {
        unawaited(checkAuth(showProgress: false));
      }
    });
  }

  Future<void> _enqueueAuthTransition(Future<void> Function() transition) {
    final previous = _transitionTail;
    final next = () async {
      try {
        await previous;
      } catch (_) {
        // Each transition reports its own failure. A rejected predecessor
        // must not prevent a newer auth intent from running.
      }
      await transition();
    }();
    _transitionTail = next;
    return next;
  }

  void handleDeepLink(String url) {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty || !normalizedUrl.startsWith('happy://')) {
      logger.warning('Ignoring unsupported deep link');
      return;
    }
    final pending = ref.read(pendingLinkRequestProvider);
    if (normalizedUrl == pending?.url) {
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

    if (AuthService.parseAuthUrl(normalizedUrl) == null) {
      logger.warning('Ignoring invalid linking deep link');
      return;
    }
    ref.read(pendingLinkRequestProvider.notifier).stage(normalizedUrl);
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

  Future<void> signOut() {
    sync.setAuthenticationBlocked(true);
    _tokenRenewalTimer?.cancel();
    _tokenRenewalTimer = null;
    _authService.invalidateLinkingApprovals();
    _confirmationGeneration++;
    _transitionEpoch.invalidate();
    return _enqueueAuthTransition(() async {
      await syncShutdown();
      try {
        await _authService.signOut();
        state = AuthState.unauthenticated;
      } catch (_) {
        state = AuthState.error;
        rethrow;
      } finally {
        ref.read(pendingLinkRequestProvider.notifier).clear();
        AppLifecycleService.clearAll(ref);
        Sentry.configureScope((scope) => scope.setUser(null));
      }
    });
  }
}
