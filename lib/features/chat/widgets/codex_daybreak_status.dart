import 'package:flutter/material.dart';

import '../../../core/components/app_badge.dart';
import '../../../core/components/settings_section.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/codex_cyber_access.dart';
import '../../../core/models/session.dart';
import 'session_info_widgets.dart';

/// Short Daybreak label for a published [CodexCyberAccess] status.
String codexDaybreakLabel(AppLocalizations l10n, CodexCyberAccess access) =>
    switch (access.state) {
      CodexCyberAccessState.active => l10n.daybreakActive,
      CodexCyberAccessState.off => l10n.daybreakOff,
      CodexCyberAccessState.requested => l10n.daybreakRequested,
      CodexCyberAccessState.unavailable => l10n.daybreakUnavailable,
      CodexCyberAccessState.unsupported => l10n.daybreakUnsupported,
      CodexCyberAccessState.unknown => l10n.daybreakUnknownState,
    };

/// Badge tone: green only when Daybreak is confirmed on; a requested tier
/// that cannot apply is a warning.
AppBadgeTone codexDaybreakTone(CodexCyberAccess access) =>
    switch (access.state) {
      CodexCyberAccessState.active => AppBadgeTone.success,
      CodexCyberAccessState.requested => AppBadgeTone.info,
      CodexCyberAccessState.unavailable ||
      CodexCyberAccessState.unsupported => AppBadgeTone.warning,
      CodexCyberAccessState.off ||
      CodexCyberAccessState.unknown => AppBadgeTone.neutral,
    };

IconData codexDaybreakIcon(CodexCyberAccess access) => switch (access.state) {
  CodexCyberAccessState.active => Icons.verified_user_outlined,
  CodexCyberAccessState.unavailable ||
  CodexCyberAccessState.unsupported => Icons.gpp_maybe_outlined,
  _ => Icons.shield_outlined,
};

/// Header badge for a Codex session's Daybreak status; the tooltip carries
/// happy-cli-go's explanation.
class SessionDaybreakBadge extends StatelessWidget {
  const SessionDaybreakBadge({required this.metadata, super.key});

  final Metadata metadata;

  @override
  Widget build(BuildContext context) {
    final access = metadata.codexCyberAccess;
    if (metadata.flavor != 'codex' || access == null) {
      return const SizedBox.shrink();
    }
    final badge = AppBadge(
      key: const ValueKey('session-daybreak-badge'),
      label: codexDaybreakLabel(context.l10n, access),
      tone: codexDaybreakTone(access),
    );
    return access.detail.isEmpty
        ? badge
        : Tooltip(message: access.detail, child: badge);
  }
}

/// Session-info section explaining whether Daybreak applies to this Codex
/// session, and why not when it does not.
class SessionDaybreakSection extends StatelessWidget {
  const SessionDaybreakSection({required this.metadata, super.key});

  final Metadata metadata;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final access = metadata.codexCyberAccess;
    if (access == null) {
      return SettingsSection(
        key: const ValueKey('session-daybreak-section'),
        title: l10n.daybreakTitle,
        description: l10n.daybreakNotReported,
        children: [
          InfoRow(
            icon: Icons.shield_outlined,
            label: l10n.daybreakLabelStatus,
            value: l10n.daybreakUnknownState,
            inline: true,
          ),
        ],
      );
    }
    final available = access.available;
    final accepted = available == null
        ? l10n.daybreakAcceptedUnknown
        : available.isEmpty
        ? l10n.daybreakAcceptedNone
        : available.join(', ');
    final tone = AppToneColors.of(context, codexDaybreakTone(access));
    return SettingsSection(
      key: const ValueKey('session-daybreak-section'),
      title: l10n.daybreakTitle,
      description: access.detail.isEmpty ? null : access.detail,
      children: [
        InfoRow(
          icon: codexDaybreakIcon(access),
          iconColor: tone.iconColor,
          label: l10n.daybreakLabelStatus,
          value: codexDaybreakLabel(l10n, access),
          inline: true,
        ),
        InfoRow(
          icon: Icons.tune_rounded,
          label: l10n.daybreakLabelRequested,
          value: access.requested.isEmpty
              ? l10n.daybreakRequestedAutomatic
              : access.requested,
          inline: true,
          mono: access.requested.isNotEmpty,
        ),
        if (access.model != null)
          InfoRow(
            icon: Icons.memory_outlined,
            label: l10n.daybreakLabelModel,
            value: access.model!,
            inline: true,
            mono: true,
          ),
        InfoRow(
          icon: Icons.fact_check_outlined,
          label: l10n.daybreakLabelAccepted,
          value: accepted,
          inline: true,
          mono: available != null && available.isNotEmpty,
        ),
        if (access.lastFlaggedAt != null)
          InfoRow(
            icon: Icons.flag_outlined,
            label: l10n.daybreakLabelLastFlagged,
            value: _formatTimestamp(context, access.lastFlaggedAt!),
            inline: true,
          ),
        if (access.lastReroutedTo != null)
          InfoRow(
            icon: Icons.alt_route_rounded,
            label: l10n.daybreakLabelRerouted,
            value: access.lastReroutedTo!,
            inline: true,
            mono: true,
          ),
      ],
    );
  }

  static String _formatTimestamp(BuildContext context, int ms) {
    final time = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatShortDate(time)} '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(time))}';
  }
}
