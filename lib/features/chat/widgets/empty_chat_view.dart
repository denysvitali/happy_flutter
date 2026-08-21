import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// View shown when the chat is empty: a quiet aurora showpiece behind
/// the greeting plus glass suggestion affordances.
///
/// Static paint only — nothing here animates, so an idle chat costs
/// zero frames.
class EmptyChatView extends StatelessWidget {
  /// Creates an empty chat view.
  const EmptyChatView({super.key, this.onSuggestionTap});

  /// Called when a suggestion card is tapped.
  final void Function(String)? onSuggestionTap;

  @override
  Widget build(BuildContext context) {
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

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _AuroraHeader(),
            const SizedBox(height: AppSpacing.xxl),
            // Responsive suggestion wrap: reflows instead of forcing a
            // fixed grid, so wide windows never stretch a two-column row.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 424),
              child: Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                alignment: WrapAlignment.center,
                children: [
                  for (final s in suggestions)
                    _SuggestionCard(
                      title: s.title,
                      subtitle: s.subtitle,
                      icon: s.icon,
                      onTap: onSuggestionTap == null
                          ? null
                          : () => onSuggestionTap!(s.title),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Greeting block with one soft radial aurora glow behind it.
///
/// The glow is a pre-composited radial gradient painted once — not a
/// ShaderMask over text and not animated — so the resting surface stays
/// frame-free.
class _AuroraHeader extends StatelessWidget {
  const _AuroraHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appColors = theme.extension<AppColorScheme>();
    final accent = appColors?.accentGradient;
    final glowColor =
        (accent != null && accent.isNotEmpty) ? accent.first : cs.primary;

    return Column(
      children: [
        // Static aurora glow behind the icon mark.
        SizedBox(
          width: 168,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.9,
                      colors: [
                        glowColor.withValues(alpha: AppOpacity.subtle),
                        glowColor.withValues(alpha: AppOpacity.faint),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
              _IconMark(accentColor: glowColor),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Greeting — promoted one typographic step.
        Text(
          context.l10n.chatStartConversation,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          context.l10n.chatHowCanIHelpToday,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _IconMark extends StatelessWidget {
  const _IconMark({required this.accentColor});

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: AppOpacity.subtle),
        shape: BoxShape.circle,
        border: Border.all(
          color: accentColor.withValues(alpha: AppOpacity.soft),
          width: AppBorder.hairline,
        ),
      ),
      child: Icon(
        Icons.chat_bubble_outline_rounded,
        size: 28,
        color: accentColor,
      ),
    );
  }
}

class _Suggestion {
  const _Suggestion(this.title, this.subtitle, this.icon);
  final String title;
  final String subtitle;
  final IconData icon;
}

/// Glass suggestion card: hairline glass border, faint fill, hover/press
/// tint from the accent, comfortable touch target.
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
    final appColors = theme.extension<AppColorScheme>();
    final accent = appColors?.accentGradient;
    final accentColor =
        (accent != null && accent.isNotEmpty) ? accent.first : cs.primary;
    final glassBorder = appColors?.glassBorder ?? cs.outlineVariant;

    return SizedBox(
      width: 200,
      child: Material(
        color: cs.surfaceContainerHighest.withValues(
          alpha: AppOpacity.subtle,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap != null
              ? () {
                  HapticFeedback.lightImpact();
                  onTap!();
                }
              : null,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          hoverColor: accentColor.withValues(alpha: AppOpacity.faint),
          focusColor: accentColor.withValues(alpha: AppOpacity.faint),
          highlightColor: accentColor.withValues(
            alpha: AppOpacity.soft,
          ),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppTouchTarget.comfortable + AppSpacing.xl,
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(
                color: glassBorder,
                width: AppBorder.hairline,
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: AppOpacity.subtle),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: accentColor),
                ),
                const SizedBox(height: AppSpacing.smd),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
