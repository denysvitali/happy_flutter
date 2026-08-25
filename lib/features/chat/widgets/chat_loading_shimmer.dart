import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/shimmer/shimmer.dart';
import '../../../core/ui/shimmer/skeleton_list.dart';

/// Shimmer loading skeleton for the chat message list.
class ChatLoadingShimmer extends StatefulWidget {
  const ChatLoadingShimmer({super.key = const ValueKey('chat-loading')});

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
      // User messages are short (1–2 lines); assistant replies are longer
      // (2–4 lines) to mirror real message shapes.
      final lineCount = isUser
          ? 1 + random.nextInt(2)
          : 2 + random.nextInt(3); // 2, 3, or 4
      return _ShimmerItem(
        isUser: isUser,
        lineCount: lineCount,
        delayMs: i * 50,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        itemCount: _items.length,
        itemBuilder: (_, i) => SkeletonChatBubble(
          isUser: _items[i].isUser,
          lineCount: _items[i].lineCount,
        ),
      ),
    );
  }
}

class _ShimmerItem {
  _ShimmerItem({
    required this.isUser,
    required this.lineCount,
    required this.delayMs,
  });
  final bool isUser;
  final int lineCount;
  final int delayMs;
}
