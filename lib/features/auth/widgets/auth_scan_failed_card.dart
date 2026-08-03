import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import 'round_button.dart';


/// Calm illustrated card shown when QR approval fails.
///
/// Displays a tinted icon, a headline, reassuring body
/// copy, and a filled primary retry button.
class ScanFailedCard extends StatelessWidget {
  const ScanFailedCard({
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
