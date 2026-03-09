import 'package:flutter/material.dart';

import '../../../core/components/shimmer_view.dart';
import '../../../core/theme/app_tokens.dart';

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

    Widget row({
      double avatarSize = 32,
      double height = 56,
    }) {
      return ShimmerView(
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    color: base,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: base,
                          borderRadius:
                              BorderRadius.circular(
                            AppRadius.xs,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: AppSpacing.xs,
                      ),
                      Container(
                        height: 12,
                        width: 160,
                        decoration: BoxDecoration(
                          color: base,
                          borderRadius:
                              BorderRadius.circular(
                            AppRadius.xs,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Container(
                  height: 12,
                  width: 36,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(
                      AppRadius.xs,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      children: [
        sectionHeader(80),
        row(),
        row(),
        row(),
        sectionHeader(100),
        row(avatarSize: 40, height: 68),
        row(avatarSize: 40, height: 68),
      ],
    );
  }
}
