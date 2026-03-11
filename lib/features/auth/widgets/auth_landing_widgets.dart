import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/components/app_loading_indicator.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import 'qr_code_display.dart';
import 'round_button.dart';

/// Wraps [child] in a subtly animated two-hue gradient
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
        final topColor =
            Color.lerp(hintA, hintB, t)!;
        final bottomColor =
            Color.lerp(hintB, hintA, t)!;
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

/// Logo + title + subtitle branding block shown on the
/// landing screen. Uses a gradient logo circle with
/// animated entrance.
class AuthHeader extends StatelessWidget {
  const AuthHeader({required this.theme, super.key});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    const logoSize = 88.0;

    return Column(
      children: [
        // --- Logo circle ---
        Container(
          width: logoSize,
          height: logoSize,
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
            boxShadow: [
              BoxShadow(
                color: scheme.primary
                    .withValues(alpha: 0.25),
                blurRadius: AppSpacing.xxxl,
                offset: const Offset(
                  0,
                  AppSpacing.sm,
                ),
              ),
              BoxShadow(
                color: scheme.primary
                    .withValues(alpha: 0.10),
                blurRadius: AppSpacing.xxxl * 2,
                spreadRadius: AppSpacing.sm,
              ),
            ],
          ),
          child: const Icon(
            Icons.chat_bubble_rounded,
            size: 44,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        // --- Title ---
        Text(
          context.l10n.appTitle,
          style: theme.textTheme.headlineMedium
              ?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // --- Subtitle ---
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
          ),
          child: Text(
            context.l10n.appSubtitle,
            style:
                theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// Icon-only logo mark for landscape left panel.
class LandingLogoMark extends StatelessWidget {
  const LandingLogoMark({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const logoSize = 100.0;

    return Container(
      width: logoSize,
      height: logoSize,
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
        boxShadow: [
          BoxShadow(
            color: scheme.primary
                .withValues(alpha: 0.25),
            blurRadius: AppSpacing.xxxl + AppSpacing.xxl,
            offset: const Offset(
              0,
              AppSpacing.md,
            ),
          ),
          BoxShadow(
            color: scheme.primary
                .withValues(alpha: 0.10),
            blurRadius: AppSpacing.xxxl * 2,
            spreadRadius: AppSpacing.md,
          ),
        ],
      ),
      child: const Icon(
        Icons.chat_bubble_rounded,
        size: 52,
        color: Colors.white,
      ),
    );
  }
}

/// The three auth action buttons on the landing screen.
///
/// Primary CTA is visually prominent with a gradient.
/// Secondary actions are outlined with icons for clarity.
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
          icon: Icons.person_add_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        RoundButton(
          title: l10n.welcomeLinkOrRestoreAccount,
          onPressed: isLoadingCreate
              ? null
              : onLinkAccount,
          isPrimary: false,
          icon: Icons.qr_code_rounded,
        ),
        const SizedBox(height: AppSpacing.sm),
        RoundButton(
          title: l10n.authSignInWithSecretKey,
          onPressed: isLoadingCreate
              ? null
              : onRestoreKey,
          isPrimary: false,
          icon: Icons.key_outlined,
        ),
      ],
    );
  }
}

/// A coloured notice bar for errors, warnings, and
/// success messages. Slides in with animation.
class StatusBanner extends StatefulWidget {
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
  State<StatusBanner> createState() =>
      _StatusBannerState();
}

class _StatusBannerState extends State<StatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppDuration.normal,
    );
    _slide = Tween<double>(begin: -0.15, end: 0.0)
        .animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: AppCurve.enter,
      ),
    );
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: AppCurve.enter,
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isError =
        widget.color == scheme.error ||
            (widget.color.r * 255.0).round().clamp(0, 255) >
                200;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) {
        return FractionalTranslation(
          translation: Offset(0, _slide.value),
          child: Opacity(
            opacity: _fade.value,
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        margin: const EdgeInsets.only(
          bottom: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color:
              widget.color.withValues(alpha: 0.08),
          border: Border.all(
            color: widget.color
                .withValues(alpha: 0.25),
          ),
          borderRadius: BorderRadius.circular(
            AppRadius.md,
          ),
        ),
        child: Row(
          children: [
            if (widget.isLoading)
              AppLoadingIndicator(
                size: 18,
                strokeWidth: 2,
                color: widget.color,
              )
            else if (widget.icon != null)
              Container(
                width: AppSpacing.xxxl,
                height: AppSpacing.xxxl,
                decoration: BoxDecoration(
                  color: widget.color
                      .withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  color: widget.color,
                  size: 18,
                ),
              ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isError)
                    Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: AppSpacing.xxs,
                      ),
                      child: Text(
                        'Error',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w600,
                          color: widget.color,
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  Text(
                    widget.message,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: widget.color
                          .withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onDismiss != null)
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 16,
                ),
                color: widget.color
                    .withValues(alpha: 0.6),
                onPressed: widget.onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: AppSpacing.xxxl,
                  minHeight: AppSpacing.xxxl,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Numbered step list shown above / beside the QR code
/// with styled step badges.
class QRInstructions extends StatelessWidget {
  const QRInstructions({
    required this.theme,
    super.key,
  });

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    const steps = <String>[
      'Open Happy on another device',
      'Go to Settings \u2192 Account',
      'Tap "Link New Device"',
      'Scan this QR code',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to link your account',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...List.generate(
          steps.length,
          (i) => Padding(
            padding: const EdgeInsets.only(
              bottom: AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: AppSpacing.xxl,
                  height: AppSpacing.xxl,
                  decoration: BoxDecoration(
                    color: scheme.primary
                        .withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  width: AppSpacing.md,
                ),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.only(
                      top: AppSpacing.xxs,
                    ),
                    child: Text(
                      steps[i],
                      style: theme
                          .textTheme.bodyMedium
                          ?.copyWith(
                        color: scheme
                            .onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
    final scheme = theme.colorScheme;

    return Column(
      children: [
        if (error != null)
          StatusBanner(
            icon: Icons.error_outline,
            message: error!,
            color: scheme.error,
            isLoading: false,
            onDismiss: onDismissError,
          ),
        AnimatedSwitcher(
          duration: AppDuration.normal,
          switchInCurve: AppCurve.enter,
          switchOutCurve: AppCurve.exit,
          child: isPolling && publicKey != null
              ? Semantics(
                  key: const ValueKey('qr-code'),
                  label: 'Account linking QR code',
                  child: QRCodeDisplay(
                    data: 'happy:///account?'
                        '${base64Url.encode(publicKey!).replaceAll('=', '')}',
                    size: 220,
                  ),
                )
              : isPolling
                  ? _QRLoadingPlaceholder(
                      key: const ValueKey(
                        'qr-loading',
                      ),
                      scheme: scheme,
                    )
                  : const SizedBox.shrink(
                      key: ValueKey('qr-empty'),
                    ),
        ),
      ],
    );
  }
}

class _QRLoadingPlaceholder extends StatelessWidget {
  const _QRLoadingPlaceholder({
    required this.scheme,
    super.key,
  });

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    const placeholderSize = 272.0;

    return Container(
      width: placeholderSize,
      height: placeholderSize,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          AppRadius.xl,
        ),
        border: Border.all(
          color: scheme.outlineVariant
              .withValues(alpha: 0.3),
        ),
        boxShadow: AppShadow.floating,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppLoadingIndicator(
            size: AppSpacing.xxxl,
            strokeWidth: 2.5,
            color: scheme.primary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Generating secure QR code\u2026',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant
                  .withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Waiting for approval" indicator + Try Again / Back
/// buttons with a pulsing status indicator.
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
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isPolling) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: scheme.primary
                  .withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(
                AppRadius.pill,
              ),
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulsingDot(color: scheme.primary),
                const SizedBox(
                  width: AppSpacing.sm,
                ),
                Text(
                  context.l10n
                      .authWaitingForApproval,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (hasError)
          RoundButton(
            title: context.l10n.authTryAgain,
            onPressed: onTryAgain,
            icon: Icons.refresh_rounded,
          )
        else
          RoundButton(
            title: context.l10n.authTryAgain,
            onPressed: onTryAgain,
            isPrimary: false,
            icon: Icons.refresh_rounded,
          ),
        const SizedBox(height: AppSpacing.sm),
        RoundButton(
          title: context.l10n.commonBack,
          onPressed: onBack,
          isPrimary: false,
          icon: Icons.arrow_back_rounded,
        ),
      ],
    );
  }
}

/// A small dot that pulses in opacity to indicate
/// an ongoing waiting state.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() =>
      _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) {
        final opacity = 0.4 + (_ctrl.value * 0.6);
        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
      child: Container(
        width: AppSpacing.sm,
        height: AppSpacing.sm,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
