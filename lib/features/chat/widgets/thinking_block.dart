import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../markdown/markdown.dart';

/// Collapsible block showing model thinking/reasoning content.
class ThinkingBlock extends StatefulWidget {
  const ThinkingBlock({required this.content, super.key});

  final String content;

  @override
  State<ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<ThinkingBlock>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  /// Whether the collapse animation has fully completed (value == 0).
  /// When true and [_expanded] is false, we skip building the markdown
  /// content entirely to avoid unnecessary layout work.
  bool _animationComplete = true;

  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;

  /// Cached result of the content-cleaning logic. Recomputed only when
  /// [widget.content] changes (in [didUpdateWidget]), not on every build.
  late String _cleanedContent;

  static final _thinkingPrefix =
      RegExp(r'^\*Thinking\.\.\.\*\s*\n*');

  static String _computeCleanContent(String raw) {
    var text = raw.replaceFirst(_thinkingPrefix, '').trim();
    // Strip outer *...* italic markers baked in by
    // message_processor/sync_service.
    if (text.startsWith('*') &&
        text.endsWith('*') &&
        text.length > 2) {
      text = text.substring(1, text.length - 1);
    }
    return text;
  }

  @override
  void initState() {
    super.initState();
    _cleanedContent = _computeCleanContent(widget.content);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    // Listen for animation status so we can drop the markdown subtree once
    // the collapse transition finishes.
    _controller.addStatusListener(_onAnimationStatus);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      // Collapse animation finished — safe to remove markdown from tree.
      setState(() => _animationComplete = true);
    } else if (_animationComplete) {
      // Animation is running again; re-insert markdown so the transition
      // has content to animate.
      setState(() => _animationComplete = false);
    }
  }

  @override
  void didUpdateWidget(ThinkingBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.content != oldWidget.content) {
      _cleanedContent = _computeCleanContent(widget.content);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onAnimationStatus)
      ..dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      // About to expand — ensure markdown is in the tree before animating.
      _animationComplete = false;
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hide the block entirely when there is no real reasoning to show.
    // Opus 4.7 redacts thinking traces, producing an empty `thinking`
    // field that the parser wraps into `*Thinking...*\n\n**`; after
    // cleaning this reduces to the literal `**` (or empty string).
    if (_cleanedContent.isEmpty || _cleanedContent == '**') {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Only build the markdown content when expanded or animating.
    final showContent = _expanded || !_animationComplete;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: cs.outlineVariant.withValues(
                  alpha: AppOpacity.subtle,
                ),
                width: 0.5,
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header — always visible, tap to toggle.
                GestureDetector(
                  onTap: _toggle,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.psychology_outlined,
                          size: 14,
                          color: cs.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Thinking',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.expand_more_rounded,
                            size: 16,
                            color: cs.onSurfaceVariant.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Expanded content — ClipRect prevents overflow
                // during animation.
                ClipRect(
                  child: SizeTransition(
                    sizeFactor: _expandAnimation,
                    child: showContent
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Divider(
                                height: 0.5,
                                thickness: 0.5,
                                color: cs.outlineVariant.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(
                                  AppSpacing.md,
                                ),
                                child: DefaultTextStyle.merge(
                                  style: TextStyle(
                                    color:
                                        cs.onSurfaceVariant.withValues(
                                      alpha: 0.85,
                                    ),
                                    fontSize: AppFontSize.md,
                                    height: 1.5,
                                  ),
                                  child: SimpleMarkdownView(
                                    markdown: _cleanedContent,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
