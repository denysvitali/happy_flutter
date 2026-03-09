import 'package:flutter/material.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// View shown when the chat is empty, with staggered entrance animation.
class EmptyChatView extends StatefulWidget {
  /// Creates an empty chat view
  const EmptyChatView({super.key, this.onSuggestionTap});

  /// Called when a suggestion chip is tapped.
  final void Function(String)? onSuggestionTap;

  static const _suggestions = [
    _Suggestion(
      'Write a function',
      Icons.code_rounded,
    ),
    _Suggestion(
      'Explain this code',
      Icons.auto_stories_rounded,
    ),
    _Suggestion(
      'Debug an error',
      Icons.bug_report_rounded,
    ),
    _Suggestion(
      'Refactor code',
      Icons.construction_rounded,
    ),
  ];

  @override
  State<EmptyChatView> createState() => _EmptyChatViewState();
}

class _EmptyChatViewState extends State<EmptyChatView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _iconScale;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _textOpacity;
  final List<Animation<double>> _chipAnims = [];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _iconScale = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(
          0.0, 0.5,
          curve: Curves.easeOutBack,
        ),
      ),
    );
    _iconOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(
          0.0, 0.35,
          curve: Curves.easeOut,
        ),
      ),
    );
    _textOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(
          0.2, 0.55,
          curve: Curves.easeOut,
        ),
      ),
    );

    for (var i = 0;
        i < EmptyChatView._suggestions.length;
        i++) {
      final start = 0.35 + i * 0.1;
      final end = (start + 0.3).clamp(0.0, 1.0);
      _chipAnims.add(
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Gradient icon container
              Opacity(
                opacity: _iconOpacity.value,
                child: Transform.scale(
                  scale: _iconScale.value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cs.primary
                              .withValues(alpha: 0.12),
                          cs.tertiary
                              .withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        AppRadius.xl,
                      ),
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 36,
                      color: cs.primary
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Title + subtitle
              Opacity(
                opacity: _textOpacity.value,
                child: Column(
                  children: [
                    Text(
                      l10n.chatStartConversation,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'How can I help you today?',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(
                        color: cs.onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              // Staggered suggestion chips
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: List.generate(
                  EmptyChatView._suggestions.length,
                  (i) {
                    final s =
                        EmptyChatView._suggestions[i];
                    final t = _chipAnims[i].value;
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, 8 * (1 - t)),
                        child: _SuggestionChip(
                          label: s.label,
                          icon: s.icon,
                          onTap:
                              widget.onSuggestionTap ==
                                      null
                                  ? null
                                  : () => widget
                                      .onSuggestionTap!(
                                      s.label,
                                    ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Suggestion {
  const _Suggestion(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.icon,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.surfaceContainerHighest.withValues(
        alpha: 0.5,
      ),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: cs.primary),
              const SizedBox(width: AppSpacing.xsm),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
