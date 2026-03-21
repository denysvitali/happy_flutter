import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/shimmer/shimmer.dart';

/// Shimmer loading skeleton for the chat message list.
class ChatLoadingShimmer extends StatelessWidget {
  const ChatLoadingShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.onSurface.withValues(alpha: 0.08);
    return ShimmerScope(
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        itemCount: 5,
        itemBuilder: (_, i) {
          final isUser = i.isEven;
          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xs,
            ),
            child: Shimmer(
              child: Align(
                alignment: isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  height: isUser ? 40 : 60,
                  width: isUser ? 200 : 260,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(
                      AppRadius.lg,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
