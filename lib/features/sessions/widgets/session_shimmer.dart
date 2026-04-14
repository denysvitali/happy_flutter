import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/shimmer/shimmer.dart';
import '../../../core/ui/shimmer/skeleton_list.dart';

/// Skeleton placeholder shown while sessions are loading.
///
/// Mirrors the real list hierarchy with section headers and
/// active/archived row styles for a smoother content transition.
class SessionListShimmer extends StatelessWidget {
  const SessionListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.onSurface.withValues(alpha: 0.08);

    Widget sectionHeader(double width) {
      return Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.lg,
          bottom: AppSpacing.sm,
        ),
        child: Container(
          height: 14,
          width: width,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(
              AppRadius.xs,
            ),
          ),
        ),
      );
    }

    return ShimmerScope(
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        children: [
          sectionHeader(80),
          const SkeletonListTile(
            avatarSize: 32,
            height: 56,
            titleWidth: 1.0,
            subtitleWidth: 0.4,
            trailingWidth: 36,
          ),
          const SkeletonListTile(
            avatarSize: 32,
            height: 56,
            titleWidth: 1.0,
            subtitleWidth: 0.4,
            trailingWidth: 36,
          ),
          const SkeletonListTile(
            avatarSize: 32,
            height: 56,
            titleWidth: 1.0,
            subtitleWidth: 0.4,
            trailingWidth: 36,
          ),
          sectionHeader(100),
          const SkeletonListTile(
            avatarSize: 40,
            height: 68,
            titleWidth: 1.0,
            subtitleWidth: 0.4,
            trailingWidth: 36,
          ),
          const SkeletonListTile(
            avatarSize: 40,
            height: 68,
            titleWidth: 1.0,
            subtitleWidth: 0.4,
            trailingWidth: 36,
          ),
        ],
      ),
    );
  }
}
