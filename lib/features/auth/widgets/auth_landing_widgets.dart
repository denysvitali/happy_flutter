import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/components/app_loading_indicator.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import 'qr_code_display.dart';
import 'round_button.dart';

/// Wraps [child] in a very subtly animated two-hue gradient
/// that shifts slowly to add depth to the landing screen.
class AnimatedGradientBackground extends StatefulWidget {
  const AnimatedGradientBackground({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState
    extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surface;
    final hintA =
        Color.lerp(base, scheme.primary, 0.03)!;
    final hintB =
        Color.lerp(base, scheme.primary, 0.07)!;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) {
        final t =
            (math.sin(_ctrl.value * math.pi) + 1) / 2;
        final topColor = Color.lerp(hintA, hintB, t)!;
        final bottomColor = Color.lerp(hintB, hintA, t)!;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [topColor, bottomColor],
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Logo + title + subtitle block shown on the landing
/// screen.
class AuthHeader extends StatelessWidget {
  const AuthHeader({required this.theme, super.key});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: AppSpacing.xxxl +
              AppSpacing.xxxl +
              AppSpacing.xxl,
          height: AppSpacing.xxxl +
              AppSpacing.xxxl +
              AppSpacing.xxl,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary,
                Color.lerp(
                  theme.colorScheme.primary,
                  theme.colorScheme.tertiary,
                  0.4,
                )!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary
                    .withValues(alpha: 0.30),
                blurRadius: AppSpacing.xxxl,
                offset:
                    const Offset(0, AppSpacing.lg),
              ),
            ],
          ),
          child: Icon(
            Icons.chat_bubble_rounded,
            size: 64,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          context.l10n.appTitle,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.l10n.appSubtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Icon-only logo mark used in landscape left panel.
class LandingLogoMark extends StatelessWidget {
  const LandingLogoMark({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logoSize = AppSpacing.xxxl +
        AppSpacing.xxxl +
        AppSpacing.xxxl +
        AppSpacing.xs;
    return Container(
      width: logoSize,
      height: logoSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            Color.lerp(
              theme.colorScheme.primary,
              theme.colorScheme.tertiary,
              0.4,
            )!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary
                .withValues(alpha: 0.30),
            blurRadius:
                AppSpacing.xxxl + AppSpacing.xxl,
            offset: const Offset(
              0,
              AppSpacing.xl - AppSpacing.sm,
            ),
          ),
        ],
      ),
      child: Icon(
        Icons.chat_bubble_rounded,
        size: 64,
        color: theme.colorScheme.onPrimary,
      ),
    );
  }
}

/// The three auth action buttons on the landing screen.
class AuthButtonGroup extends StatelessWidget {
  const AuthButtonGroup({
    required this.onCreateAccount,
    required this.onLinkAccount,
    required this.onRestoreKey,
    required this.isLoadingCreate,
    required this.l10n,
    super.key,
  });

  final VoidCallback onCreateAccount;
  final VoidCallback onLinkAccount;
  final VoidCallback onRestoreKey;
  final bool isLoadingCreate;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RoundButton(
          title: l10n.welcomeCreateAccount,
          onPressed: onCreateAccount,
          isLoading: isLoadingCreate,
          isPrimary: true,
        ),
        const SizedBox(height: AppSpacing.md),
        RoundButton(
          title: l10n.welcomeLinkOrRestoreAccount,
          onPressed:
              isLoadingCreate ? null : onLinkAccount,
          isPrimary: false,
        ),
        const SizedBox(height: AppSpacing.sm),
        RoundButton(
          title: l10n.authSignInWithSecretKey,
          onPressed:
              isLoadingCreate ? null : onRestoreKey,
          isPrimary: false,
        ),
      ],
    );
  }
}

/// A coloured notice bar used for errors, warnings
/// and success messages.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    required this.message,
    required this.color,
    required this.isLoading,
    required this.onDismiss,
    super.key,
    this.icon,
  });

  final IconData? icon;
  final String message;
  final Color color;
  final bool isLoading;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      margin:
          const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
        borderRadius:
            BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          if (isLoading)
            AppLoadingIndicator(
              size: 20,
              strokeWidth: 2,
              color: color,
            )
          else if (icon != null)
            Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: color,
                fontSize: 13,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: color,
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
              ),
            ),
        ],
      ),
    );
  }
}

/// Numbered step list shown above / beside the QR code.
class QRInstructions extends StatelessWidget {
  const QRInstructions({required this.theme, super.key});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    const steps = [
      '1. Open Happy on another device',
      '2. Go to Settings \u2192 Account',
      '3. Tap "Link New Device"',
      '4. Scan this QR code',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: steps
          .map(
            (s) => Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 2,
              ),
              child: Text(
                s,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          )
          .toList(),
    );
  }
}

/// Shows the QR code or a loading placeholder, plus
/// the error banner.
class QRCodeSection extends StatelessWidget {
  const QRCodeSection({
    required this.isPolling,
    required this.publicKey,
    required this.error,
    required this.onDismissError,
    required this.theme,
    super.key,
  });

  final bool isPolling;
  final Uint8List? publicKey;
  final String? error;
  final VoidCallback onDismissError;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (error != null)
          StatusBanner(
            icon: Icons.warning,
            message: error!,
            color: Colors.red,
            isLoading: false,
            onDismiss: onDismissError,
          ),
        if (isPolling && publicKey != null)
          Semantics(
            label: 'Account linking QR code',
            child: QRCodeDisplay(
              data: 'happy:///account?'
                  '${base64Url.encode(publicKey!).replaceAll('=', '')}',
              size: 250,
            ),
          )
        else if (isPolling)
          Container(
            width: 250,
            height: 250,
            padding:
                const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                AppRadius.lg,
              ),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary
                      .withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                const AppLoadingIndicator(),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Generating secure QR code...',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// "Waiting for approval" indicator + Try Again / Back
/// buttons.
class PollingView extends StatelessWidget {
  const PollingView({
    required this.isPolling,
    required this.hasError,
    required this.onTryAgain,
    required this.onBack,
    required this.theme,
    super.key,
  });

  final bool isPolling;
  final bool hasError;
  final VoidCallback onTryAgain;
  final VoidCallback onBack;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isPolling) ...[
          Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              AppLoadingIndicator(
                size: AppSpacing.lg,
                strokeWidth: 2,
                color:
                    theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                context.l10n.authWaitingForApproval,
                style:
                    theme.textTheme.bodyMedium?.copyWith(
                  color:
                      theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        RoundButton(
          title: context.l10n.authTryAgain,
          onPressed: onTryAgain,
          isPrimary: false,
          isLoading: isPolling && hasError,
        ),
        const SizedBox(height: AppSpacing.md),
        RoundButton(
          title: context.l10n.commonBack,
          onPressed: onBack,
          isPrimary: false,
        ),
      ],
    );
  }
}
