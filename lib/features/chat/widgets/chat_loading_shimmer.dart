import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/shimmer/shimmer.dart';

/// Shimmer loading skeleton for the chat message list.
class ChatLoadingShimmer extends StatefulWidget {
  const ChatLoadingShimmer({super.key});

  @override
  State<ChatLoadingShimmer> createState() => _ChatLoadingShimmerState();
}

class _ChatLoadingShimmerState extends State<ChatLoadingShimmer> {
  late final List<_ShimmerItem> _items;

  @override
  void initState() {
    super.initState();
    final random = Random();
    _items = List.generate(5, (i) {
      final isUser = i.isEven;
      return _ShimmerItem(
        height: isUser
            ? 32.0 + random.nextDouble() * 24
            : 48.0 + random.nextDouble() * 32,
        width: isUser
            ? 160.0 + random.nextDouble() * 80
            : 200.0 + random.nextDouble() * 120,
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        delayMs: i * 50,
      );
    });
  }

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
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final item = _items[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Shimmer(
              child: Align(
                alignment: item.alignment,
                child: Container(
                  height: item.height,
                  width: item.width,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
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

class _ShimmerItem {
  _ShimmerItem({
    required this.height,
    required this.width,
    required this.alignment,
    required this.delayMs,
  });
  final double height;
  final double width;
  final Alignment alignment;
  final int delayMs;
}
