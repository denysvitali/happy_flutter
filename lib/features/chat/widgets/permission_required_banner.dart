import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// A banner shown when permission is required from the user
class PermissionRequiredBanner extends StatelessWidget {
  /// Creates a permission required banner
  const PermissionRequiredBanner({required this.onTap, super.key});

  /// Callback when the banner is tapped
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.08),
          border: Border(
            top: BorderSide(
              color: AppColors.info.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            Icon(
              Icons.shield_outlined,
              size: 15,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.chatPermissionRequired,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
