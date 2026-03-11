import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_screen.dart';
import '../models/auth.dart';
import '../providers/app_providers.dart';
import '../theme/app_tokens.dart';

/// Authentication gate widget that switches between
/// the auth screen and the main app content.
class AuthGate extends ConsumerWidget {
  const AuthGate({
    required this.child,
    super.key,
    this.initialDeepLink,
  });

  final Widget child;
  final String? initialDeepLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState =
        ref.watch(authStateNotifierProvider);

    if (initialDeepLink != null &&
        authState == AuthState.authenticated) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) {
        ref
            .read(
              authStateNotifierProvider.notifier,
            )
            .handleDeepLink(initialDeepLink!);
      });
    }

    return AnimatedSwitcher(
      duration: AppDuration.slow,
      switchInCurve: AppCurve.enter,
      child: switch (authState) {
        AuthState.authenticated => KeyedSubtree(
            key: const ValueKey('authenticated'),
            child: child,
          ),
        AuthState.unauthenticated => AuthScreen(
            key: const ValueKey('unauth'),
            initialDeepLink: initialDeepLink,
          ),
        AuthState.authenticating =>
          _AuthenticatingView(
            key: const ValueKey('checking'),
          ),
        AuthState.error => AuthScreen(
            key: const ValueKey('auth-error'),
            initialDeepLink: initialDeepLink,
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
          mainAxisAlignment:
              MainAxisAlignment.center,
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
                    Color.lerp(
                      scheme.primary,
                      scheme.tertiary,
                      0.4,
                    )!,
                  ],
                ),
              ),
              child: const Icon(
                Icons.chat_bubble_rounded,
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(
              height: AppSpacing.xxl,
            ),
            Text(
              'Checking sign-in status\u2026',
              style:
                  theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(
              height: AppSpacing.xl,
            ),
            SizedBox(
              width: AppSpacing.xxl,
              height: AppSpacing.xxl,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                strokeCap: StrokeCap.round,
                valueColor:
                    AlwaysStoppedAnimation<Color>(
                  scheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
