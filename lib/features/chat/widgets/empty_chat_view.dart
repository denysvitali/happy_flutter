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

  @override
  State<EmptyChatView> createState() =>
      _EmptyChatViewState();
}

class _EmptyChatViewState extends State<EmptyChatView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _headerOpacity;
  late final Animation<Offset> _headerSlide;
  final List<Animation<double>> _cardOpacities = [];
  final List<Animation<Offset>> _cardSlides = [];

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
    // Fractional slide: ~0.05 of the header height ≈ 12 px
    // SlideTransition uses fractions of the child's own size.
    _headerSlide = Tween(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(
          0.0, 0.4,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    // 4 suggestion cards
    for (var i = 0; i < 4; i++) {
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
      // Fractional slide: ~0.12 of the card height ≈ 16 px
      _cardSlides.add(
        Tween(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(
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

    final suggestions = [
      _Suggestion(
        l10n.chatSuggestionWriteCode,
        l10n.chatSuggestionWriteCodeDesc,
        Icons.code_rounded,
      ),
      _Suggestion(
        l10n.chatSuggestionDebugIssue,
        l10n.chatSuggestionDebugIssueDesc,
        Icons.bug_report_rounded,
      ),
      _Suggestion(
        l10n.chatSuggestionExplainCode,
        l10n.chatSuggestionExplainCodeDesc,
        Icons.auto_stories_rounded,
      ),
      _Suggestion(
        l10n.chatSuggestionReviewPr,
        l10n.chatSuggestionReviewPrDesc,
        Icons.rate_review_rounded,
      ),
    ];

    // Build the static header content once; FadeTransition +
    // SlideTransition only update their own RenderObject, the
    // Column subtree is never rebuilt during animation ticks.
    const headerContent = _HeaderContent();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header section — scoped to its own opacity+slide,
            // the static child is hoisted by each transition widget.
            FadeTransition(
              opacity: _headerOpacity,
              child: SlideTransition(
                position: _headerSlide,
                child: headerContent,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            // Suggestion cards in a 2x2 grid
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400,
              ),
              child: _buildSuggestionGrid(
                cs, suggestions,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionGrid(
    ColorScheme cs,
    List<_Suggestion> suggestions,
  ) {
    final count = suggestions.length;
    final rows = <Widget>[];

    for (var row = 0; row < (count / 2).ceil(); row++) {
      final children = <Widget>[];
      for (var col = 0; col < 2; col++) {
        final i = row * 2 + col;
        if (i >= count) break;
        final s = suggestions[i];

        // Build the static card once; FadeTransition +
        // SlideTransition update only their own RenderObjects
        // — the _SuggestionCard subtree is never rebuilt on ticks.
        final card = _SuggestionCard(
          title: s.title,
          subtitle: s.subtitle,
          icon: s.icon,
          onTap: widget.onSuggestionTap == null
              ? null
              : () => widget.onSuggestionTap!(s.title),
        );

        children.add(
          Expanded(
            child: FadeTransition(
              opacity: _cardOpacities[i],
              child: SlideTransition(
                position: _cardSlides[i],
                child: card,
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

/// Static header content extracted as a const widget so it can be
/// hoisted outside the animation tree and never rebuilt on ticks.
class _HeaderContent extends StatelessWidget {
  const _HeaderContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;

    return Column(
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
                cs.primary.withValues(alpha: 0.12),
                cs.tertiary.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(
              AppRadius.xl,
            ),
          ),
          child: Icon(
            Icons.chat_bubble_outline_rounded,
            size: 32,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Title
        Text(
          l10n.chatStartConversation,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Subtitle
        Text(
          l10n.chatHowCanIHelpToday,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant
                .withValues(alpha: 0.7),
          ),
        ),
      ],
    );
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
