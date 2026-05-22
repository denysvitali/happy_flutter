import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'shimmer.dart';

/// Structured skeleton loading widgets.
///
/// Each variant mirrors a real widget's visual hierarchy so the
/// transition from skeleton → real content feels seamless.
///
/// Wrap a group of skeletons in [ShimmerScope] to share the animation
/// controller across all items (recommended for lists).
///
/// ## Variants
/// - [SkeletonListTile]       — avatar + title + subtitle (sessions, friends)
/// - [SkeletonCard]           — rectangular card (artifacts, feed)
/// - [SkeletonChatBubble]     — user or assistant message bubble
/// - [SkeletonFormSection]    — label + stacked field lines (settings)
/// - [SkeletonTwoColumn]       — two-column grid of card skeletons
/// - [SkeletonAvatarList]     — avatar + two text lines (generic list)
///
/// ## Usage
/// ```dart
/// ShimmerScope(
///   child: ListView.builder(
///     itemCount: 5,
///     itemBuilder: (_, i) => const SkeletonListTile(),
///   ),
/// )
/// ```
class SkeletonListTile extends StatelessWidget {
  /// Avatar + title + subtitle + optional trailing width.
  ///
  /// [avatarSize] — diameter of the leading circle (default 32).
  /// [titleWidth] — fraction of available width for title line (default 0.6).
  /// [subtitleWidth] — fraction for subtitle line (default 0.4).
  /// [trailingWidth] — fixed width for trailing widget (default 36).
  /// [height] — total height of the tile (default 56).
  const SkeletonListTile({
    super.key,
    this.avatarSize = 32,
    this.titleWidth = 0.6,
    this.subtitleWidth = 0.4,
    this.trailingWidth = 36,
    this.height = 56,
  });

  final double avatarSize;
  final double titleWidth;
  final double subtitleWidth;
  final double trailingWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.onSurface.withValues(alpha: 0.08);

    return Shimmer(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FractionallySizedBox(
                      widthFactor: titleWidth,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: base,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    FractionallySizedBox(
                      widthFactor: subtitleWidth,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: base,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                height: 12,
                width: trailingWidth,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card-shaped skeleton with configurable dimensions.
class SkeletonCard extends StatelessWidget {
  /// Rectangular card skeleton.
  ///
  /// [height] — total card height (default 120).
  /// [width] — card width; [double.infinity] if omitted.
  /// [borderRadius] — corner radius (default [AppRadius.lg]).
  const SkeletonCard({
    super.key,
    this.height = 120,
    this.width = double.infinity,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.lg)),
  });

  final double height;
  final double width;
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Shimmer(
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.08),
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

/// Chat message bubble skeleton with simulated multi-line text.
class SkeletonChatBubble extends StatelessWidget {
  /// Message bubble skeleton.
  ///
  /// [isUser] — aligns right for user, left for assistant.
  /// [lineCount] — number of simulated text lines to render (1–6,
  ///   default 3). Use 1 for short user messages, 2–4 for typical
  ///   assistant replies, 5–6 for long responses.
  /// [maxWidthFraction] — fraction of available width for the widest
  ///   line. Defaults to 0.72 for user bubbles and 0.88 for assistant.
  const SkeletonChatBubble({
    super.key,
    this.isUser = false,
    this.lineCount = 3,
    this.maxWidthFraction,
  });

  final bool isUser;

  /// Number of simulated text lines. Clamped to [1, 6].
  final int lineCount;

  /// Fraction of available width for the widest line.
  /// Defaults to 0.72 for user bubbles, 0.88 for assistant bubbles.
  final double? maxWidthFraction;

  /// Width fractions for each line index (index 0 = first/top line).
  ///
  /// Full lines run 80–100 %; the terminal line is noticeably shorter
  /// (50 %) to mimic how real messages end mid-line.
  static const List<double> _lineWidthFractions = <double>[
    1.00, // line 1 — spans full bubble width
    0.95, // line 2
    0.90, // line 3
    0.85, // line 4
    0.80, // line 5
    0.50, // line 6 — tail line, always shorter
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final clampedCount = lineCount.clamp(1, 6);
    final resolvedMaxFraction =
        maxWidthFraction ?? (isUser ? 0.72 : 0.88);

    return Shimmer(
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth =
                  constraints.maxWidth * resolvedMaxFraction;
              return Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int i = 0; i < clampedCount; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i < clampedCount - 1
                            ? AppSpacing.xxs
                            : 0,
                      ),
                      child: Container(
                        height: 14,
                        width: maxWidth *
                            (clampedCount > 1 &&
                                    i == clampedCount - 1
                                ? 0.50
                                : _lineWidthFractions[i.clamp(
                                    0,
                                    _lineWidthFractions.length -
                                        1)]),
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppRadius.xs),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Form section skeleton with label + stacked field lines.
class SkeletonFormSection extends StatelessWidget {
  /// Label + N field lines.
  ///
  /// [labelWidth] — fraction of width for the section label (default 0.25).
  /// [fieldCount] — number of field lines to show (default 2).
  /// [fieldHeight] — height of each field line (default 14).
  /// [spacing] — vertical gap between fields (default 8).
  const SkeletonFormSection({
    super.key,
    this.labelWidth = 0.25,
    this.fieldCount = 2,
    this.fieldHeight = 14,
    this.spacing = 8,
  });

  final double labelWidth;
  final int fieldCount;
  final double fieldHeight;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.onSurface.withValues(alpha: 0.08);

    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 12,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            ),
            ...List.generate(fieldCount, (i) {
              return Padding(
                padding: i > 0
                  ? EdgeInsets.only(top: spacing)
                  : EdgeInsets.zero,
                child: FractionallySizedBox(
                  widthFactor: i == fieldCount - 1 ? 0.6 : 1.0,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: fieldHeight,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Two-column grid of card skeletons.
class SkeletonTwoColumn extends StatelessWidget {
  /// Two-column grid of [SkeletonCard] items.
  ///
  /// [itemCount] — total number of card skeletons (default 4).
  /// [itemHeight] — height of each card (default 140).
  /// [spacing] — gap between cards (default AppSpacing.md).
  const SkeletonTwoColumn({
    super.key,
    this.itemCount = 4,
    this.itemHeight = 140,
    this.spacing = AppSpacing.md,
  });

  final int itemCount;
  final double itemHeight;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          for (int row = 0; row < (itemCount / 2).ceil(); row++)
            Padding(
              padding: EdgeInsets.only(
                bottom: row < (itemCount / 2).ceil() - 1 ? spacing : 0,
              ),
              child: Row(
                children: [
                  for (int col = 0; col < 2; col++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: col > 0 ? spacing / 2 : 0,
                          right: col == 0 ? spacing / 2 : 0,
                        ),
                        child: SkeletonCard(height: itemHeight),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Avatar + two text lines — generic list item skeleton.
class SkeletonAvatarList extends StatelessWidget {
  /// Avatar + title + subtitle rows for a list.
  ///
  /// [itemCount] — number of avatar-list rows (default 5).
  /// [avatarSize] — diameter of leading circle (default 40).
  const SkeletonAvatarList({
    super.key,
    this.itemCount = 5,
    this.avatarSize = 40,
  });

  final int itemCount;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: Column(
        children: List.generate(itemCount, (_) => SkeletonListTile(
          avatarSize: avatarSize,
          height: avatarSize + AppSpacing.md,
          titleWidth: 0.5,
          subtitleWidth: 0.35,
        )),
      ),
    );
  }
}
