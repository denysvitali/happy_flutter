import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// View shown when the chat is empty, with staggered
/// entrance animation and suggestion cards.
class EmptyChatView extends StatefulWidget {
  /// Creates an empty chat view.
  const EmptyChatView({super.key, this.onSuggestionTap});

  /// Called when a suggestion card is tapped.
  final void Function(String)? onSuggestionTap;

  static const _suggestions = [
    _Suggestion(
      'Write code',
      'Generate a function or component',
      Icons.code_rounded,
    ),
    _Suggestion(
      'Debug an issue',
      'Find and fix a bug in your code',
      Icons.bug_report_rounded,
    ),
    _Suggestion(
      'Explain code',
      'Understand how something works',
      Icons.auto_stories_rounded,
    ),
    _Suggestion(
      'Review PR',
      'Get feedback on your changes',
      Icons.rate_review_rounded,
    ),
  ];

  @override
  State<EmptyChatView> createState() =>
      _EmptyChatViewState();
}

class _EmptyChatViewState extends State<EmptyChatView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _headerOpacity;
  late final Animation<double> _headerSlide;
  final List<Animation<double>> _cardOpacities = [];
  final List<Animation<double>> _cardSlides = [];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _headerOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(
          0.0, 0.4,
          curve: Curves.easeOut,
        ),
      ),
    );
    _headerSlide = Tween(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(
          0.0, 0.4,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    for (var i = 0;
        i < EmptyChatView._suggestions.length;
        i++) {
      final start = 0.2 + i * 0.12;
      final end = (start + 0.35).clamp(0.0, 1.0);
      _cardOpacities.add(
        Tween(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: Interval(
              start, end,
              curve: Curves.easeOut,
            ),
          ),
        ),
      );
      _cardSlides.add(
        Tween(begin: 16.0, end: 0.0).animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: Interval(
              start, end,
              curve: Curves.easeOutCubic,
            ),
          ),
        ),
      );
    }

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header section
              Opacity(
                opacity: _headerOpacity.value,
                child: Transform.translate(
                  offset: Offset(
                    0, _headerSlide.value,
                  ),
                  child: Column(
                    children: [
                      // Icon with gradient background
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              cs.primary.withValues(
                                alpha: 0.12,
                              ),
                              cs.tertiary.withValues(
                                alpha: 0.08,
                              ),
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            AppRadius.xl,
                          ),
                        ),
                        child: Icon(
                          Icons
                              .chat_bubble_outline_rounded,
                          size: 32,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(
                        height: AppSpacing.lg,
                      ),
                      // Title
                      Text(
                        l10n.chatStartConversation,
                        textAlign: TextAlign.center,
                        style: theme
                            .textTheme.titleLarge
                            ?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(
                        height: AppSpacing.xs,
                      ),
                      // Subtitle
                      Text(
                        'How can I help you today?',
                        textAlign: TextAlign.center,
                        style: theme
                            .textTheme.bodyMedium
                            ?.copyWith(
                          color: cs.onSurfaceVariant
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              // Suggestion cards in a 2x2 grid
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 400,
                ),
                child: _buildSuggestionGrid(cs),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionGrid(ColorScheme cs) {
    final count = EmptyChatView._suggestions.length;
    final rows = <Widget>[];

    for (var row = 0; row < (count / 2).ceil(); row++) {
      final children = <Widget>[];
      for (var col = 0; col < 2; col++) {
        final i = row * 2 + col;
        if (i >= count) break;
        final s = EmptyChatView._suggestions[i];
        children.add(
          Expanded(
            child: Opacity(
              opacity: _cardOpacities[i].value,
              child: Transform.translate(
                offset: Offset(
                  0, _cardSlides[i].value,
                ),
                child: _SuggestionCard(
                  title: s.title,
                  subtitle: s.subtitle,
                  icon: s.icon,
                  onTap:
                      widget.onSuggestionTap == null
                          ? null
                          : () =>
                              widget.onSuggestionTap!(
                                s.title,
                              ),
                ),
              ),
            ),
          ),
        );
        if (col == 0) {
          children.add(
            const SizedBox(width: AppSpacing.sm),
          );
        }
      }
      if (row > 0) {
        rows.add(
          const SizedBox(height: AppSpacing.sm),
        );
      }
      rows.add(Row(children: children));
    }

    return Column(children: rows);
  }
}

class _Suggestion {
  const _Suggestion(this.title, this.subtitle, this.icon);
  final String title;
  final String subtitle;
  final IconData icon;
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.surfaceContainerHighest.withValues(
        alpha: 0.4,
      ),
      borderRadius: BorderRadius.circular(
        AppRadius.lg,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap != null
            ? () {
                HapticFeedback.lightImpact();
                onTap!();
              }
            : null,
        borderRadius: BorderRadius.circular(
          AppRadius.lg,
        ),
        child: Container(
          padding: const EdgeInsets.all(
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: cs.outlineVariant.withValues(
                alpha: 0.15,
              ),
              width: AppBorder.hairline,
            ),
            borderRadius: BorderRadius.circular(
              AppRadius.lg,
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // Icon in a small rounded square
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    AppRadius.sm,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Title
              Text(
                title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(
                height: AppSpacing.xxs,
              ),
              // Subtitle
              Text(
                subtitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(
                  color: cs.onSurfaceVariant
                      .withValues(alpha: 0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
