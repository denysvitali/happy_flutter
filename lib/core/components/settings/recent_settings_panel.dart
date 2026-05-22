import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

// ─── Recent Settings Panel ────────────────────────────────────────────────────

/// A compact strip of tappable quick-access chips shown below the profile
/// header in the settings screen.
///
/// Each chip navigates to a high-value settings destination with a single tap.
///
/// ## MRU note
/// The current list is hardcoded to the four most universally useful
/// destinations (Theme, Profiles, Voice, Language). When a most-recently-used
/// tracking mechanism is available (e.g. MMKV key `settings_mru`), swap in a
/// dynamic list sourced from storage and keep this widget's chip-rendering
/// logic unchanged.
class RecentSettingsPanel extends StatelessWidget {
  const RecentSettingsPanel({required this.chips, super.key});

  /// The chips to render. Typically 3–4 items.
  final List<RecentSettingChip> chips;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick access',
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant.withValues(alpha: AppOpacity.high),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: chips
              .map((chip) => _QuickChip(chip: chip))
              .toList(growable: false),
        ),
      ],
    );
  }
}

// ─── Chip data ────────────────────────────────────────────────────────────────

/// Data class for a single quick-access chip.
class RecentSettingChip {
  const RecentSettingChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

// ─── Internal chip widget ─────────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.chip});

  final RecentSettingChip chip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: chip.onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: dark
              ? cs.surfaceContainerHighest.withValues(
                  alpha: AppOpacity.medium,
                )
              : cs.surfaceContainerHighest.withValues(
                  alpha: AppOpacity.soft,
                ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: AppOpacity.faint)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              chip.icon,
              size: AppFontSize.sm,
              color: cs.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              chip.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
