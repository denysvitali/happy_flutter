import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/app_inline_row.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../markdown/markdown.dart';
import '../thinking_content.dart';

/// Collapsible block showing model thinking/reasoning content.
class ThinkingBlock extends StatefulWidget {
  const ThinkingBlock({required this.content, super.key, this.storageKey});

  final String content;

  /// Optional stable identifier used to persist the expanded/collapsed state
  /// across [ListView.builder] rebuilds and scroll-off disposal. When provided,
  /// tapping the header writes the current state to [PageStorage] so the block
  /// can restore itself if the widget is recreated.
  final String? storageKey;

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

  @override
  void initState() {
    super.initState();
    _cleanedContent = cleanThinkingContent(widget.content);
    final key = widget.storageKey;
    if (key != null && key.isNotEmpty) {
      final saved = PageStorage.of(
        context,
      ).readState(context, identifier: 'thinking_expanded_$key');
      if (saved is bool) {
        _expanded = saved;
      }
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    if (_expanded) {
      _controller.value = 1.0;
      _animationComplete = false;
    }
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
      _cleanedContent = cleanThinkingContent(widget.content);
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
    final key = widget.storageKey;
    if (key != null && key.isNotEmpty) {
      PageStorage.of(
        context,
      ).writeState(context, _expanded, identifier: 'thinking_expanded_$key');
    }
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
    // cleaning this reduces to an empty string.
    if (_cleanedContent.isEmpty) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppInlineRow(
                leading: const Icon(Icons.psychology_outlined),
                onTap: _toggle,
                semanticLabel: 'Thinking',
                expanded: _expanded,
                trailing: AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: AppDuration.normal,
                  child: const Icon(Icons.expand_more_rounded),
                ),
                action: AppInlineAction(
                  label: context.l10n.chatCopyThinking,
                  icon: Icons.copy_outlined,
                  iconOnly: true,
                  onPressed: () async {
                    await HapticFeedback.lightImpact();
                    await Clipboard.setData(
                      ClipboardData(text: _cleanedContent),
                    );
                  },
                ),
                child: Text('Thinking', style: AppInlineText.title(context)),
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
                              color: cs.outlineVariant.withValues(alpha: 0.2),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: DefaultTextStyle.merge(
                                style: TextStyle(
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.85,
                                  ),
                                  fontSize: AppFontSize.md,
                                  height: 1.5,
                                ),
                                child: SelectionArea(
                                  child: SimpleMarkdownView(
                                    markdown: _cleanedContent,
                                  ),
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
    );
  }
}
