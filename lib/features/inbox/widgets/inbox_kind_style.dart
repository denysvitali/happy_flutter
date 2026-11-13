import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/inbox_message.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';

/// Icon, color and label for one [InboxKind].
@immutable
class InboxKindStyle {
  const InboxKindStyle({
    required this.icon,
    required this.color,
    required this.label,
  });

  factory InboxKindStyle.of(BuildContext context, InboxKind kind) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return switch (kind) {
      InboxKind.goalReached => InboxKindStyle(
        icon: Icons.flag_rounded,
        color: AppColors.success,
        label: l10n.inboxKindGoalReached,
      ),
      InboxKind.question => InboxKindStyle(
        icon: Icons.help_rounded,
        color: cs.primary,
        label: l10n.inboxKindQuestion,
      ),
      InboxKind.blocked => InboxKindStyle(
        icon: Icons.front_hand_rounded,
        color: AppColors.warning,
        label: l10n.inboxKindBlocked,
      ),
    };
  }

  final IconData icon;
  final Color color;
  final String label;
}

/// Small tinted label, e.g. "Goal reached" or "Needs reply".
class InboxPill extends StatelessWidget {
  const InboxPill({
    required this.label,
    required this.color,
    this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppIconSize.xs, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.badge(theme, color),
            ),
          ),
        ],
      ),
    );
  }
}

/// [InboxPill] for a message kind.
class InboxKindPill extends StatelessWidget {
  const InboxKindPill({required this.kind, super.key});

  final InboxKind kind;

  @override
  Widget build(BuildContext context) {
    final style = InboxKindStyle.of(context, kind);
    return InboxPill(label: style.label, color: style.color, icon: style.icon);
  }
}

/// One-line plain preview of a Markdown body.
String inboxSnippet(String markdown, {int maxLength = 160}) {
  final plain = markdown
      .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ')
      .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m[1] ?? '')
      .replaceAll(RegExp(r'[#>*_`~|]'), '')
      .replaceAll(RegExp(r'^\s*[-+]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return plain.length <= maxLength
      ? plain
      : '${plain.substring(0, maxLength).trimRight()}…';
}
