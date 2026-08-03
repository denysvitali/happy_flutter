import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/components/app_loading_indicator.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import 'auth_animated_widgets.dart';
import 'auth_scan_failed_card.dart';
import 'qr_code_display.dart';
import 'qr_viewfinder_overlay.dart';
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
///
/// The "Sign In with Secret Key" button uses progressive
/// disclosure: the first tap reveals a reassurance hint
/// card; the second tap (or "Enter Secret Key" button)
/// opens the actual key input dialog.
class AuthButtonGroup extends StatefulWidget {
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
  State<AuthButtonGroup> createState() =>
      _AuthButtonGroupState();
}

class _AuthButtonGroupState
    extends State<AuthButtonGroup>
    with SingleTickerProviderStateMixin {
  bool _showKeyHint = false;
  late final AnimationController _hintController;
  late final Animation<double> _hintFade;
  late final Animation<Offset> _hintSlide;

  @override
  void initState() {
    super.initState();
    _hintController = AnimationController(
      vsync: this,
      duration: AppDuration.normal,
    );
    _hintFade = CurvedAnimation(
      parent: _hintController,
      curve: Curves.easeOut,
    );
    _hintSlide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _hintController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _hintController.dispose();
    super.dispose();
  }

  void _handleKeyButtonTap() {
    if (widget.isLoadingCreate) return;
    if (!_showKeyHint) {
      setState(() => _showKeyHint = true);
      _hintController.forward();
    } else {
      widget.onRestoreKey();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RoundButton(
          title: widget.l10n.welcomeCreateAccount,
          onPressed: widget.onCreateAccount,
          isLoading: widget.isLoadingCreate,
          icon: Icons.person_add_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        RoundButton(
          title:
              widget.l10n.welcomeLinkOrRestoreAccount,
          onPressed: widget.isLoadingCreate
              ? null
              : widget.onLinkAccount,
          isPrimary: false,
          icon: Icons.qr_code_rounded,
        ),
        const SizedBox(height: AppSpacing.sm),
        RoundButton(
          title: widget.l10n.authSignInWithSecretKey,
          onPressed: widget.isLoadingCreate
              ? null
              : _handleKeyButtonTap,
          isPrimary: false,
          icon: Icons.key_outlined,
        ),
        if (_showKeyHint) ...[
          const SizedBox(height: AppSpacing.sm),
          FadeTransition(
            opacity: _hintFade,
            child: SlideTransition(
              position: _hintSlide,
              child: _KeyReassuranceCard(
                l10n: widget.l10n,
                scheme: scheme,
                onProceed: widget.onRestoreKey,
                onDismiss: () {
                  _hintController.reverse().then((_) {
                    if (mounted) {
                      setState(
                        () => _showKeyHint = false,
                      );
                    }
                  });
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Inline reassurance hint card shown between the
/// "Sign In with Secret Key" button and the actual
/// key input. Gives users confidence before they
/// proceed to type their sensitive backup key.
class _KeyReassuranceCard extends StatelessWidget {
  const _KeyReassuranceCard({
    required this.l10n,
    required this.scheme,
    required this.onProceed,
    required this.onDismiss,
  });

  final AppLocalizations l10n;
  final ColorScheme scheme;
  final VoidCallback onProceed;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest
            .withValues(alpha: 0.55),
        borderRadius:
            BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: scheme.outline
              .withValues(alpha: AppOpacity.subtle),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: AppSpacing.xl,
                color: scheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.authSecretKeyReassuranceTitle,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Tooltip(
                message: l10n.commonDismiss,
                child: Semantics(
                  button: true,
                  label: l10n.commonDismiss,
                  child: GestureDetector(
                    onTap: onDismiss,
                    child: Icon(
                      Icons.close,
                      size: AppSpacing.lg,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.authSecretKeyReassurance,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
              color: scheme.onSurfaceVariant,
              height: AppLineHeight.normal,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: onProceed,
              style: FilledButton.styleFrom(
                minimumSize: const Size(
                  0,
                  AppTouchTarget.min,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppRadius.smd,
                  ),
                ),
              ),
              child: Text(
                l10n.authContinueToKeyInput,
              ),
            ),
          ),
        ],
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
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      QRCodeDisplay(
                        data: 'happy:///account?'
                            '${base64Url.encode(publicKey!).replaceAll('=', '')}',
                        size: 220,
                      ),
                      // 220 + AppSpacing.xxxl + AppSpacing.xl
                      QRViewfinderOverlay(
                        size: 272,
                        isActive: true,
                      ),
                    ],
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
          ScanFailedCard(
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
