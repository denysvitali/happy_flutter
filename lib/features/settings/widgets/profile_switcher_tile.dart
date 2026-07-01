import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// A settings row that shows a horizontal strip of profile avatar circles
/// (up to [maxVisible]) plus a "See all" trailing chevron.
///
/// Falls back to a plain [SettingsNavRow]-style row when [profiles] is empty.
class ProfileSwitcherTile extends StatelessWidget {
  const ProfileSwitcherTile({
    required this.profiles,
    required this.selectedProfileId,
    required this.onTap,
    required this.title,
    super.key,
    this.maxVisible = 3,
  });

  final List<AIBackendProfile> profiles;

  /// The currently-active profile id, or null for "none".
  final String? selectedProfileId;

  final VoidCallback onTap;
  final String title;

  /// Maximum number of avatar circles shown before "+N" overflow badge.
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final avatarRow = _buildAvatarRow(context, cs);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppTouchTarget.comfortable),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              // Leading icon container — mirrors SettingsIconContainer style
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: AppOpacity.faint),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  Icons.account_tree,
                  size: 18,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Title column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (profiles.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      avatarRow,
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: cs.onSurface.withValues(alpha: AppOpacity.medium),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarRow(BuildContext context, ColorScheme cs) {
    if (profiles.isEmpty) {
      return const SizedBox.shrink();
    }

    final visible = profiles.take(maxVisible).toList();
    final overflow = profiles.length - visible.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          _ProfileAvatar(
            profile: visible[i],
            isSelected: visible[i].id == selectedProfileId,
            size: 22,
          ),
        ],
        if (overflow > 0) ...[
          const SizedBox(width: AppSpacing.xs),
          _OverflowBadge(count: overflow, size: 22, colorScheme: cs),
        ],
      ],
    );
  }
}

// ─── Private helpers ─────────────────────────────────────────────────────────

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.profile,
    required this.isSelected,
    required this.size,
  });

  final AIBackendProfile profile;
  final bool isSelected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = profile.isBuiltIn
        ? colorForProfile(profile.id)
        : cs.primary;
    final initial = profile.name.isNotEmpty
        ? profile.name[0].toUpperCase()
        : '?';
    final fontSize = size * 0.45;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
        border: Border.all(
          color: isSelected
              ? color
              : color.withValues(alpha: 0.5),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _OverflowBadge extends StatelessWidget {
  const _OverflowBadge({
    required this.count,
    required this.size,
    required this.colorScheme,
  });

  final int count;
  final double size;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Center(
        child: Text(
          '+$count',
          style: TextStyle(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
