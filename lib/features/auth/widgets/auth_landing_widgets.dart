import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/components/app_loading_indicator.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import 'auth_animated_widgets.dart';
import 'qr_code_display.dart';
import 'round_button.dart';

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
                color: scheme.primary.withValues(
                  alpha: AppOpacity.medium,
                ),
                blurRadius: AppSpacing.xxxl,
                offset: const Offset(
                  0,
                  AppSpacing.sm,
                ),
              ),
              BoxShadow(
                color: scheme.primary.withValues(
                  alpha: AppOpacity.subtle,
                ),
                blurRadius: AppSpacing.xxxl * 2,
                spreadRadius: AppSpacing.sm,
              ),
            ],
          ),
          child: Icon(
            Icons.chat_bubble_rounded,
            size: AppTouchTarget.min,
            color: scheme.onPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        Text(
          context.l10n.appTitle,
          style: theme.textTheme.headlineMedium
              ?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
          ),
          child: Text(
            context.l10n.appSubtitle,
            style:
                theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: AppLineHeight.relaxed,
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
            color: scheme.primary.withValues(
              alpha: AppOpacity.medium,
            ),
            blurRadius: AppSpacing.xxxl + AppSpacing.xxl,
            offset: const Offset(
              0,
              AppSpacing.md,
            ),
          ),
          BoxShadow(
            color: scheme.primary.withValues(
              alpha: AppOpacity.subtle,
            ),
            blurRadius: AppSpacing.xxxl * 2,
            spreadRadius: AppSpacing.md,
          ),
        ],
      ),
      child: Icon(
        Icons.chat_bubble_rounded,
        size: AppTouchTarget.comfortable + 4,
        color: scheme.onPrimary,
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
                        .withValues(
                      alpha: AppOpacity.subtle,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
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
                        height: AppLineHeight
                            .normal,
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
                  ? QRLoadingPlaceholder(
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

/// Loading placeholder shown while generating the QR code.
class QRLoadingPlaceholder extends StatelessWidget {
  const QRLoadingPlaceholder({
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
              .withValues(
            alpha: AppOpacity.medium,
          ),
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
              fontSize: AppFontSize.md,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant
                  .withValues(
                alpha: AppOpacity.high,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Waiting for approval" indicator + Try Again / Back
/// buttons with a pulsing status indicator.
///
/// When [hasError] is true, shows a calm illustrated card
/// with a reassuring headline, body copy, and a filled
/// retry button before the Back button.
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
              color: scheme.primary.withValues(
                alpha: AppOpacity.faint,
              ),
              borderRadius: BorderRadius.circular(
                AppRadius.pill,
              ),
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                PulsingDot(color: scheme.primary),
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
        if (hasError) ...[
          _ScanFailedCard(
            theme: theme,
            onTryAgain: onTryAgain,
          ),
          const SizedBox(height: AppSpacing.sm),
        ] else ...[
          RoundButton(
            title: context.l10n.authTryAgain,
            onPressed: onTryAgain,
            isPrimary: false,
            icon: Icons.refresh_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
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

/// Calm illustrated card shown when QR approval fails.
///
/// Displays a tinted icon, a headline, reassuring body
/// copy, and a filled primary retry button.
class _ScanFailedCard extends StatelessWidget {
  const _ScanFailedCard({
    required this.theme,
    required this.onTryAgain,
  });

  final ThemeData theme;
  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    const iconBoxSize = AppSpacing.xxxl * 2.0;
    const iconSize = AppSpacing.xxxl + AppSpacing.sm;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(
          AppRadius.lg,
        ),
        border: Border.all(
          color: scheme.outlineVariant.withValues(
            alpha: AppOpacity.subtle,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Illustrated icon container.
          Container(
            width: iconBoxSize,
            height: iconBoxSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.errorContainer,
                  scheme.errorContainer.withValues(
                    alpha: AppOpacity.high,
                  ),
                ],
              ),
              borderRadius: BorderRadius.circular(
                AppRadius.pill,
              ),
              border: Border.all(
                color: scheme.error.withValues(
                  alpha: AppOpacity.subtle,
                ),
                width: AppBorder.hairline,
              ),
            ),
            child: Icon(
              Icons.qr_code_scanner_rounded,
              size: iconSize,
              color: scheme.onErrorContainer
                  .withValues(
                alpha: AppOpacity.high,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Headline.
          Text(
            context.l10n.authApprovalFailedTitle,
            style: theme.textTheme.titleMedium
                ?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          // Body copy.
          Text(
            context.l10n.authApprovalFailedBody,
            style: theme.textTheme.bodySmall
                ?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          // Filled retry button.
          SizedBox(
            width: double.infinity,
            child: RoundButton(
              title: context.l10n.authTryAgain,
              onPressed: onTryAgain,
              icon: Icons.refresh_rounded,
            ),
          ),
        ],
      ),
    );
  }
}
