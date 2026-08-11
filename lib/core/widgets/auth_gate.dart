import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_screen.dart';
import '../i18n/app_localizations.dart';
import '../models/auth.dart';
import '../providers/app_providers.dart';
import '../services/auth_service.dart';
import '../services/logger_service.dart' show logger;
import '../theme/app_tokens.dart';

/// Authentication gate widget that switches between
/// the auth screen and the main app content.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({required this.child, super.key, this.initialDeepLinkFuture});

  final Widget child;

  /// Optional future for the initial deep link from the platform
  /// channel. Resolved by [AuthGate] and forwarded to [AuthScreen]
  /// when needed. Passing a future (vs. an already-resolved value)
  /// lets the platform-channel call run in parallel with the first
  /// frame instead of blocking it.
  final Future<String?>? initialDeepLinkFuture;

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _deepLinkHandled = false;
  String? _presentedLink;

  Future<void> _confirmLinkRequest(PendingLinkRequest request) async {
    if (!mounted || _presentedLink != null) return;
    _presentedLink = request.url;
    final l10n = context.l10n;
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.authLinkRequestTitle),
        content: Text(
          l10n.authLinkRequestBody(
            request.isTerminal
                ? l10n.authLinkRequestTerminal
                : l10n.authLinkRequestAccount,
            request.fingerprint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.accountApproveLinking),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (approved != true) {
      ref.read(pendingLinkRequestProvider.notifier).clear(request.url);
      _presentedLink = null;
      return;
    }
    try {
      final success = await AuthService().approveLinkingRequest(request.url);
      if (!mounted) return;
      final message = success
          ? l10n.authDeviceLinkedSuccess
          : l10n.authFailedToLinkDevice;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      if (success) {
        ref.read(pendingLinkRequestProvider.notifier).clear(request.url);
      }
    } catch (error, stack) {
      logger.warning('Failed to approve staged linking request', error, stack);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.authFailedToLinkDevice)));
      }
    } finally {
      _presentedLink = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateNotifierProvider);
    final pendingLink = ref.watch(pendingLinkRequestProvider);
    if (authState == AuthState.authenticated && pendingLink != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_confirmLinkRequest(pendingLink));
      });
    }

    // If auth has completed and we haven't dispatched the initial
    // deep link yet, forward it to the auth state notifier.  The
    // future may already be resolved (cached) or still pending;
    // `then` is cheap in both cases and runs at most once because
    // the dispatch is gated on [_deepLinkHandled].  This runs on
    // every build, but the [authState] watch only triggers rebuilds
    // when the auth state actually changes, so the cost is bounded.
    final future = widget.initialDeepLinkFuture;
    if (future != null &&
        authState == AuthState.authenticated &&
        !_deepLinkHandled) {
      future.then((link) {
        if (!mounted || link == null) return;
        if (!_deepLinkHandled) {
          _deepLinkHandled = true;
          ref.read(authStateNotifierProvider.notifier).handleDeepLink(link);
        }
      });
    }

    return AnimatedSwitcher(
      duration: AppDuration.slow,
      switchInCurve: AppCurve.enter,
      switchOutCurve: AppCurve.exit,
      child: switch (authState) {
        AuthState.authenticated => KeyedSubtree(
          key: const ValueKey('authenticated'),
          child: widget.child,
        ),
        AuthState.unauthenticated => AuthScreen(
          key: const ValueKey('unauth'),
          initialDeepLinkFuture: widget.initialDeepLinkFuture,
        ),
        AuthState.authenticating => _AuthenticatingView(
          key: const ValueKey('checking'),
        ),
        AuthState.error => AuthScreen(
          key: const ValueKey('auth-error'),
          initialDeepLinkFuture: widget.initialDeepLinkFuture,
          showError: true,
        ),
      },
    );
  }
}

/// Checking auth status view with branded logo
/// spinner.
class _AuthenticatingView extends StatelessWidget {
  const _AuthenticatingView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary,
                    Color.lerp(scheme.primary, scheme.tertiary, 0.4)!,
                  ],
                ),
              ),
              child: Icon(
                Icons.chat_bubble_rounded,
                size: 32,
                color: scheme.onPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'Checking sign-in status\u2026',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: AppSpacing.xxl,
              height: AppSpacing.xxl,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                strokeCap: StrokeCap.round,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
